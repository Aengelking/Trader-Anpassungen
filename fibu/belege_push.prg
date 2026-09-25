/**
  * RUN_PUSH_BELEGE - Belege an Finova senden
  *
  * Etappe 1 der vorbereitenden Buchhaltung, Trader-Seite. Sammelt die
  * Ausgangs- und Eingangsrechnungen ab dem Stichtag und liefert sie mit
  * ihrem vollstaendigen Buchungssatz an die Tabelle `documents`.
  *
  *   DIESES PROGRAMM SCHREIBT NICHTS IN TRADER.
  *
  * Kein Kennzeichen, kein Status, nirgends ein Rec_Lock. Alle Tabellen
  * werden ausschliesslich gelesen. Der Lauf darf beliebig oft wiederholt
  * werden; Finova traegt ueber (source, erp_reference) ein und aktualisiert,
  * statt zu verdoppeln.
  *
  * WARUM TRADER DEN BUCHUNGSSATZ BILDET UND NICHT FINOVA
  *
  * Die Kontierung steht vollstaendig in Trader und wird dort seit Jahren
  * gepflegt: die Erloes-, Wareneingangs- und Skontokonten je Steuersatz in
  * der vat-Tabelle, die Auffangkonten in der lexware.ini, das Debitorenkonto
  * am Kunden und das Kreditorenkonto an der Rechnung. Genau daraus baut
  * LX_BookOutInvoice/LX_BookInInvoice den Satz fuer Lexware.
  *
  * Dieselbe Logik in Finova noch einmal zu bauen hiesse, zwei Wahrheiten zu
  * pflegen, die irgendwann auseinanderlaufen - und zwar unbemerkt, weil
  * beide plausibel aussehen.
  *
  * BESONDERS DIE FAELLIGKEIT
  *
  * Sie wird hier fertig gerechnet uebergeben und ist ausserhalb von Trader
  * gar nicht reproduzierbar: bei Zahlungsbedingung ziel1 = -4 holt GetSkonto
  * die Staffel nicht aus skontoa, sondern fuehrt ein kundeneigenes Programm
  * aus (PT_PATH\<Kundennummer>.prg, ueber MBaseRun). Ein Nachbau in SQL
  * koennte diese Kunden nur raten.
  *
  * DER KURS KOMMT NICHT VON HIER
  *
  * Bewusst kein fx_rate im Rumpf. Trader fuehrt zwar in curhist eine eigene
  * Tagesreihe, aber Finova bewertet den Beleg an seinem Belegtag aus der
  * EZB-Reihe (fx_rates). Zwei Kursquellen hiessen, dass dieselbe Rechnung je
  * nach Weg einen anderen Euro-Wert bekommt.
  *
  * WAS UNKONTIERT IST, GEHT TROTZDEM RAUS
  *
  * Eine Eingangsrechnung ohne rech->Konto wird NICHT uebergangen - genau das
  * tut LexwareSync, und deshalb faellt eine Rechnung, die in keiner
  * Buchhaltung ankommt, niemandem auf. Sie geht ohne Habenkonto hinueber und
  * steht drueben in documents_unkontiert.
  *
  * AUFRUF
  *
  *   RUN_PUSH_BELEGE()      Trockenlauf - sammelt, zeigt und protokolliert,
  *                          sendet nichts
  *   RUN_PUSH_BELEGE(.T.)   Echtlauf
  *
  * Stichtag ueber den Wertespeicher FIBU_SINCE, Vorgabe 01.01.2026.
  * Protokoll unter \export\belege_<Firma>_<Datum>_<Zeit>.txt
  **/

#include 'trader.ch'

#define CRLF Chr(13)+Chr(10)

//Belege je Aufruf. erp-push schreibt sie in Bloecken zu 500; 100 je Anfrage
//haelt den Rumpf klein genug fuer eine Zeitueberschreitung.
#define PUSH_BATCH 100

#define FIBU_DEFAULT_YEAR 2026

STATIC snProtokoll := 0
STATIC shIni := NIL

FUNCTION RUN_PUSH_BELEGE(lLive)
   LOCAL oRest := RestApi():New()
   LOCAL dFrom
   LOCAL aBelege
   LOCAL cProtokoll
   LOCAL nGesendet := 0, nFehler := 0

   Default(@lLive, .F.)

   IF ! LockEntity("FIBU", 0, "%% wird bereits von % durchgefuehrt")
      RETURN .F.
   ENDIF

   dFrom := _BelegSince()
   cProtokoll := Path("\export\belege_" + _Firma() + "_" + DToS(Date()) + "_" + ;
                      StrTran(Time(), ":", "-") + ".txt")
   snProtokoll := FCreate(cProtokoll)

   Head("Belege an Finova senden")
   _Log("Trader -> Finova, " + DToC(Date()) + " " + Time())
   _Log("Firma: " + _Firma())
   _Log(IF(lLive, "ECHTLAUF - Belege werden gesendet", "TROCKENLAUF - es wird nichts gesendet"))
   _Log("Belege ab " + DToC(dFrom))
   _Log("Trader wird ausschliesslich gelesen")
   _Log("")

   IF ! _LoadIni()
      _Log("*** ABBRUCH: lexware.ini nicht lesbar - ohne die Auffangkonten")
      _Log("*** waeren Belege ohne Steuerschluessel unkontiert.")
      _Finish(cProtokoll)
      UnLockEntity("FIBU", 0)
      RETURN .F.
   ENDIF

   aBelege := _CollectOutbound(dFrom)
   _Log("Ausgangsrechnungen: " + LTrim(Str(Len(aBelege))))

   _CollectInbound(dFrom, @aBelege)
   _Log("Belege gesamt:      " + LTrim(Str(Len(aBelege))))
   _Log("")

   _LogUnkontiert(aBelege)

   IF Len(aBelege) == 0
      _Log("Nichts zu senden.")
   ELSEIF ! lLive
      _LogVorschau(aBelege)
   ELSE
      _Send(oRest, aBelege, @nGesendet, @nFehler)
      _Log("")
      _Log("Gesendet: " + LTrim(Str(nGesendet)) + "   Fehler: " + LTrim(Str(nFehler)))
   ENDIF

   _Finish(cProtokoll)
   UnLockEntity("FIBU", 0)

RETURN .T.

/**
  * Ab welchem Belegdatum gesammelt wird.
  **/
STATIC FUNCTION _BelegSince()
   LOCAL xWert := GetValue("FIBU_SINCE", "")

   IF ValType(xWert) == "D" .AND. ! Empty(xWert)
      RETURN xWert
   ENDIF
   IF ValType(xWert) == "C" .AND. Len(AllTrim(xWert)) == 8
      RETURN SToD(AllTrim(xWert))
   ENDIF

RETURN SToD(LTrim(Str(FIBU_DEFAULT_YEAR)) + "0101")

STATIC FUNCTION _Firma()
   LOCAL cFirma := AllTrim(GetConfigValue("FIRMPATH"))
RETURN IF(Empty(cFirma), "default", cFirma)

/**
  * Die Auffangkonten aus der lexware.ini.
  *
  * Sie greifen bei Steuerschluessel 0. ErloeseOhneUSt steht dort auf 8120 -
  * im SKR03 die steuerfreie Ausfuhrlieferung; so wird die Drittlandslieferung
  * gefuehrt.
  **/
STATIC FUNCTION _LoadIni()
   LOCAL cFile := Path(AllTrim(GetConfigValue("FIRMPATH")) + "\lexware.ini")

   IF ! File(cFile)
      RETURN .F.
   ENDIF

   BEGIN SEQUENCE
      shIni := HB_ReadIni(cFile)
   RECOVER
      shIni := NIL
   END SEQUENCE

RETURN ValType(shIni) == "H" .AND. HB_HHasKey(shIni, "KONTEN")

STATIC FUNCTION _IniKonto(cName)
   IF ValType(shIni) == "H" .AND. HB_HHasKey(shIni, "KONTEN") .AND. ;
      HB_HHasKey(shIni["KONTEN"], cName)
      RETURN AllTrim(shIni["KONTEN"][cName])
   ENDIF
RETURN ""

/**
  * Die Konten zu einem Steuerschluessel.
  *
  * Der Schluessel ist die SATZNUMMER in vat - taxit() macht ein schlichtes
  * "GO mitax", re->TaxCode und rech->Steuer sind also Satznummern.
  *
  * Welches der beiden Felder gilt, entscheidet das Belegdatum gegen
  * vat->Date, genau wie in lexware.prg. Das Feld ist fuer einen echten
  * Steuersatzwechsel da: Elektronik fuehrt dort 19% ab 01.01.2021 und davor
  * 16% auf Konto 8340, das in DATEV datumsunabhaengig immer 16% rechnet.
  *
  * Bei Steuerschluessel 0 greifen die Auffangkonten aus der ini.
  **/
STATIC FUNCTION _VatKonten(nTaxCode, dBelegDatum)
   LOCAL hKonten := {"erloes" => "", "ek" => "", "skonto" => "", "art" => ""}
   LOCAL lNeu

   IF nTaxCode <= 0
      hKonten["erloes"] := _IniKonto("ErloeseOhneUSt")
      hKonten["ek"]     := _IniKonto("WareneingangOhneUSt")
      hKonten["skonto"] := _IniKonto("SkontiOhneUSt")
      RETURN hKonten
   ENDIF

   NetUse("vat", "vat", .F., 0)
   vat->(dbGoTo(nTaxCode))

   IF vat->(EOF()) .OR. vat->(BOF())
      RETURN hKonten
   ENDIF

   lNeu := dBelegDatum >= vat->Date

   hKonten["erloes"] := AllTrim(IF(lNeu, vat->VerkNeu, vat->VerkAlt))
   hKonten["ek"]     := AllTrim(IF(lNeu, vat->EkNeu, vat->EkAlt))
   hKonten["skonto"] := AllTrim(IF(lNeu, vat->SkontoNeu, vat->SkontoAlt))
   hKonten["art"]    := AllTrim(vat->Text)

RETURN hKonten

/**
  * Zahlungsziel und Skontokondition zu einem Skonto-Code.
  *
  * Die Auswahl der geltenden Staffel ist woertlich die aus LX_BookOutInvoice
  * uebernommen - dieselbe Kondition, die seit Jahren nach Lexware geht.
  * Negative Ziele sind Sonderfaelle: -2 Lastschrift, -3 Vorkasse, -4
  * kundenindividuell.
  *
  * GetSkontoWait kann bei -4 ein kundeneigenes Programm ausfuehren. Faellt
  * das aus, darf es nicht den ganzen Lauf mitnehmen - dann gilt das
  * Belegdatum als Faelligkeit und der Beleg faellt drueben in die
  * Arbeitsliste.
  *
  * Der Schluessel ist die Satznummer MINUS EINS: dbGoto(nCode + 1).
  **/
STATIC FUNCTION _Zahlungsziel(nSkontoCode, dRechdat, nSkontoRate, dSkontoDatum)
   LOCAL nWait
   LOCAL nTage

   nSkontoRate := 0
   dSkontoDatum := NIL

   NetUse("skontoa", "sk", .F., 0)
   sk->(dbGoTo(nSkontoCode + 1))

   IF sk->(EOF()) .OR. sk->(BOF())
      RETURN dRechdat
   ENDIF

   nSkontoRate := IF(sk->Rate1 != 0, sk->Rate1, ;
                     IF(sk->Ziel1 == -2 .AND. sk->Rate1 == 0, sk->Rate2, 0))
   nTage := IF(sk->Rate1 != 0 .AND. sk->Ziel1 > 0, sk->Ziel1, ;
               IF(sk->Ziel1 == -2 .AND. sk->Rate1 == 0, sk->Ziel2, 0))

   BEGIN SEQUENCE
      nWait := sk->(GetSkontoWait(nSkontoCode, dRechdat, dRechdat))
   RECOVER
      nWait := 0
   END SEQUENCE

   IF ValType(nWait) != "N" .OR. nWait < 0
      nWait := 0
   ENDIF

   IF nSkontoRate != 0 .AND. nTage > 0
      dSkontoDatum := dRechdat + nTage
   ENDIF

RETURN dRechdat + nWait

/**
  * Ausgangsrechnungen aus ENGLSRE.
  *
  * Traversierung wie in lexware_import.prg und bbbsync.prg: Index 2, nur
  * Kopfsaetze (Reposnr == 0), nur gepackte Rechnungen, Betrag ungleich null.
  *
  * Soll und Haben wie in LX_BookOutInvoice: Soll ist das Debitorenkonto,
  * Haben das Erloeskonto.
  **/
STATIC FUNCTION _CollectOutbound(dFrom)
   LOCAL aBelege := {}
   LOCAL hBeleg, hKonten
   LOCAL oRechnung
   LOCAL nScanned := 0
   LOCAL cName, cKonto
   LOCAL nSkontoRate, dSkontoDatum, dFaellig

   NetUse("englsre", "re")
   NetUse("engkund", "ku")
   NetUse("skontoa", "sk", .F., 0)
   NetUse("vat", "vat", .F., 0)

   ku->(dbSetOrder(1))
   re->(dbSetOrder(2))
   re->(dbSetFilter({|| ! Empty(re->Kunde) }, "! Empty(kunde)"))
   re->(dbGoTop())

   DO WHILE ! re->(EOF()) .AND. re->Reposnr == 0
      nScanned++

      IF re->Rechdat >= dFrom .AND. re->Packed .AND. re->PosWt != 0

         oRechnung := Rechnung():New()
         oRechnung:Load(re->Rechnr)

         cName  := Trim(re->Kunde)
         cKonto := ""
         IF ku->(dbSeek(Pad(re->Kunde, 8) + "K"))
            cName  := IF(! Empty(Trim(ku->Name1)), Trim(ku->Name1), Trim(ku->Kunde))
            cKonto := _KontoStr(ku->Nummer)
         ENDIF

         hKonten  := _VatKonten(re->TaxCode, re->Rechdat)
         dFaellig := _Zahlungsziel(re->Skonto, re->Rechdat, @nSkontoRate, @dSkontoDatum)

         hBeleg := {=>}
         hBeleg["erp_reference"] := "RE" + StrZero(re->Rechnr, 6)
         hBeleg["doc_type"]      := "sales_invoice"
         hBeleg["doc_number"]    := LTrim(Str(re->Rechnr))
         hBeleg["doc_date"]      := _IsoDate(re->Rechdat)

         hBeleg["counterparty_name"]    := hb_StrToUTF8(cName)
         hBeleg["counterparty_ref"]     := Trim(re->Kunde)
         hBeleg["counterparty_account"] := cKonto

         hBeleg["currency"]     := _CurrencyISO(re->Money)
         hBeleg["gross_amount"] := Round(oRechnung:Brutto, 2)
         hBeleg["net_amount"]   := Round(oRechnung:Brutto - oRechnung:Mwst, 2)
         hBeleg["vat_amount"]   := Round(oRechnung:Mwst, 2)
         hBeleg["vat_rate"]     := oRechnung:MwstRate

         hBeleg["tax_code"] := re->TaxCode
         hBeleg["tax_kind"] := hKonten["art"]
         //Soll Debitor, Haben Erloes - Richtung wie in LX_BookOutInvoice.
         hBeleg["account_debit"]    := cKonto
         hBeleg["account_credit"]   := hKonten["erloes"]
         hBeleg["account_discount"] := hKonten["skonto"]

         hBeleg["due_date"] := _IsoDate(dFaellig)
         IF dSkontoDatum != NIL
            hBeleg["discount_date"] := _IsoDate(dSkontoDatum)
            hBeleg["discount_rate"] := nSkontoRate
         ENDIF

         hBeleg["company_id"] := GetConfigValue("FIRMNO")
         AAdd(aBelege, hBeleg)
      ENDIF

      re->(dbSkip())
   ENDDO

   re->(dbClearFilter())

   _Log("  ENGLSRE gelesen: " + LTrim(Str(nScanned)))

RETURN aBelege

/**
  * Eingangsrechnungen aus ENGRECH.
  *
  * Nur gebuchte (rech->Booked). Eine nur teilweise erfasste Rechnung hat im
  * Kopf noch keinen belastbaren Betrag; im Liquiditaetsplan darf sie
  * hochgerechnet werden, in der Buchhaltung nicht.
  *
  * Ohne rech->Konto geht sie TROTZDEM mit, nur ohne Habenkonto. LexwareSync
  * uebergeht sie an dieser Stelle stillschweigend - und eine Rechnung, die in
  * keiner Buchhaltung ankommt, faellt niemandem auf.
  *
  * Soll und Haben wie in LX_BookInInvoice: Soll ist das Wareneingangskonto,
  * Haben das Kreditorenkonto an der Rechnung. An der Rechnung, nicht am
  * Lieferanten - ein Lieferant kann je Waehrung ein eigenes Konto haben.
  **/
STATIC FUNCTION _CollectInbound(dFrom, aBelege)
   LOCAL hBeleg, hKonten
   LOCAL nScanned := 0
   LOCAL cName
   LOCAL nMwst, nVatRate
   LOCAL dFaellig

   NetUse("engrech", "rech")
   NetUse("engkund", "ku")
   NetUse("vat", "vat", .F., 0)

   ku->(dbSetOrder(1))
   rech->(dbSetOrder(0))
   rech->(dbGoTop())

   DO WHILE ! rech->(EOF())
      nScanned++

      IF rech->Booked .AND. rech->Rechdat >= dFrom .AND. rech->GrAmt != 0 .AND. ;
         ! Empty(rech->Liefma) .AND. ! Empty(rech->Rechnr)

         cName    := Trim(rech->Liefma)
         nMwst    := 0
         nVatRate := 0
         IF ku->(dbSeek(Pad(rech->Liefma, 8) + "L"))
            cName := IF(! Empty(Trim(ku->Name1)), Trim(ku->Name1), Trim(ku->Kunde))
         ENDIF

         //Der Steuersatz kommt aus demselben Schluessel wie die Konten.
         IF rech->Steuer > 0
            taxit(rech->Steuer, @nMwst, rech->Rechdat, .F.)
            nVatRate := nMwst
         ENDIF

         hKonten := _VatKonten(rech->Steuer, rech->Rechdat)

         dFaellig := rech->Rechdat + Max(rech->Wait, rech->WaitSkonto)
         IF Empty(dFaellig)
            dFaellig := rech->Rechdat
         ENDIF

         hBeleg := {=>}
         hBeleg["erp_reference"] := "ER-" + Trim(rech->Liefma) + "-" + Trim(rech->Rechnr)
         hBeleg["doc_type"]      := "purchase_invoice"
         hBeleg["doc_number"]    := Trim(rech->Rechnr)
         hBeleg["doc_date"]      := _IsoDate(rech->Rechdat)

         hBeleg["counterparty_name"]    := hb_StrToUTF8(cName)
         hBeleg["counterparty_ref"]     := Trim(rech->Liefma)
         hBeleg["counterparty_account"] := _KontoStr(rech->Konto)

         hBeleg["currency"]     := _CurrencyISO(rech->Money)
         hBeleg["gross_amount"] := Round(rech->GrAmt, 2)
         hBeleg["net_amount"]   := Round(rech->GrAmt / (1 + nVatRate / 100), 2)
         hBeleg["vat_amount"]   := Round(rech->GrAmt - rech->GrAmt / (1 + nVatRate / 100), 2)
         hBeleg["vat_rate"]     := nVatRate

         hBeleg["tax_code"] := rech->Steuer
         hBeleg["tax_kind"] := hKonten["art"]
         //Soll Wareneingang, Haben Kreditor - Richtung wie in LX_BookInInvoice.
         hBeleg["account_debit"]    := hKonten["ek"]
         hBeleg["account_credit"]   := _KontoStr(rech->Konto)
         hBeleg["account_discount"] := hKonten["skonto"]

         hBeleg["due_date"] := _IsoDate(dFaellig)

         hBeleg["company_id"] := GetConfigValue("FIRMNO")
         AAdd(aBelege, hBeleg)
      ENDIF

      rech->(dbSkip())
   ENDDO

   _Log("  ENGRECH gelesen: " + LTrim(Str(nScanned)))

RETURN NIL

/**
  * Kontonummer als Text. Der Feldtyp ist nicht ueberall gleich - engkund
  * fuehrt die Nummer numerisch, andere Tabellen als Zeichenkette. Str() auf
  * eine Zeichenkette bricht zur Laufzeit ab, und zwar erst auf dem
  * Windows-Rechner, wo es niemand mehr erwartet.
  **/
STATIC FUNCTION _KontoStr(xKonto)
   IF ValType(xKonto) == "N"
      RETURN IF(xKonto == 0, "", LTrim(Str(xKonto)))
   ENDIF
   IF ValType(xKonto) == "C" .OR. ValType(xKonto) == "M"
      RETURN AllTrim(xKonto)
   ENDIF
RETURN ""

/**
  * Was zum Buchen fehlt, noch vor dem Senden.
  *
  * Finova fuehrt dieselbe Liste als Sicht documents_unkontiert. Sie hier
  * schon zu zeigen erspart den Umweg: wer den Trockenlauf liest, sieht
  * sofort, was nachzupflegen ist.
  **/
STATIC FUNCTION _LogUnkontiert(aBelege)
   LOCAL hBeleg
   LOCAL cFehlt
   LOCAL nZeile := 0
   LOCAL aOffen := {}

   FOR EACH hBeleg IN aBelege
      cFehlt := ""
      IF Empty(hBeleg["account_debit"])
         cFehlt += "Soll "
      ENDIF
      IF Empty(hBeleg["account_credit"])
         cFehlt += "Haben "
      ENDIF
      IF Empty(hBeleg["counterparty_account"])
         cFehlt += "Personenkonto "
      ENDIF
      IF ! Empty(cFehlt)
         AAdd(aOffen, {hBeleg, cFehlt})
      ENDIF
   NEXT

   IF Len(aOffen) == 0
      _Log("Alle Belege sind kontiert.")
      _Log("")
      RETURN NIL
   ENDIF

   _Log("NICHT KONTIERT: " + LTrim(Str(Len(aOffen))) + " von " + ;
        LTrim(Str(Len(aBelege))) + " Belegen. Sie gehen trotzdem mit und")
   _Log("stehen in Finova unter documents_unkontiert.")
   FOR EACH hBeleg IN aOffen
      nZeile++
      IF nZeile > 100
         _Log("  ... und " + LTrim(Str(Len(aOffen) - 100)) + " weitere")
         EXIT
      ENDIF
      _Log("  " + PadR(hBeleg[1]["erp_reference"], 26) + ;
           PadR(Left(hBeleg[1]["counterparty_name"], 28), 30) + "es fehlt: " + hBeleg[2])
   NEXT
   _Log("")

RETURN NIL

STATIC FUNCTION _LogVorschau(aBelege)
   LOCAL hBeleg
   LOCAL nZeile := 0

   _Log("Trockenlauf - diese Belege wuerden gesendet:")
   FOR EACH hBeleg IN aBelege
      nZeile++
      IF nZeile > 200
         _Log("  ... und " + LTrim(Str(Len(aBelege) - 200)) + " weitere")
         EXIT
      ENDIF
      _Log("  " + PadR(hBeleg["erp_reference"], 26) + PadR(hBeleg["doc_date"], 12) + ;
           PadL(LTrim(Str(hBeleg["gross_amount"], 14, 2)), 14) + " " + hBeleg["currency"] + ;
           "  " + PadR(Left(hBeleg["counterparty_name"], 24), 26) + ;
           "S " + PadR(hBeleg["account_debit"], 8) + ;
           "H " + PadR(hBeleg["account_credit"], 8) + ;
           IF(Empty(hBeleg["tax_kind"]), "", hBeleg["tax_kind"]))
   NEXT
   _Log("")

RETURN NIL

/**
  * Senden, in Bloecken.
  **/
STATIC FUNCTION _Send(oRest, aBelege, nGesendet, nFehler)
   LOCAL aBatches := _SplitIntoBatches(aBelege, PUSH_BATCH)
   LOCAL aBatch
   LOCAL aHeader := {}
   LOCAL hBody, hResponse
   LOCAL cResponse
   LOCAL nStatus := 0
   LOCAL nBatch := 0
   LOCAL cSyncRun := DToS(Date()) + StrTran(Time(), ":", "")

   oRest:cBaseUrl := "https://fhyvjvjyszbqzefwvtpz.supabase.co/"
   oRest:cApiKeyName := "LIQUIDITY"

   AAdd(aHeader, "x-api-key: $APIKEY$")
   AAdd(aHeader, "accept: application/json")
   AAdd(aHeader, "content-type: application/json")

   FOR EACH aBatch IN aBatches
      nBatch++

      hBody := {=>}
      hBody["user_id"]     := _FinovaUserId()
      hBody["documents"]   := aBatch
      hBody["sync_run_id"] := cSyncRun

      _Log("Sende Block " + LTrim(Str(nBatch)) + " von " + LTrim(Str(Len(aBatches))) + ;
           " (" + LTrim(Str(Len(aBatch))) + " Belege)")

      cResponse := oRest:Execute("functions/v1/erp-push", "POST", hBody, aHeader, .T., @nStatus)

      IF nStatus < 200 .OR. nStatus > 299
         nFehler += Len(aBatch)
         _Log("*** Block " + LTrim(Str(nBatch)) + " abgelehnt, HTTP " + LTrim(Str(nStatus)))
         _Log("*** " + Left(_Text(cResponse), 300))
         LOOP
      ENDIF

      hResponse := _Json(cResponse)
      IF ValType(hResponse) == "H" .AND. HHasKey(hResponse, "documents_synced")
         nGesendet += hResponse["documents_synced"]
      ELSE
         nGesendet += Len(aBatch)
      ENDIF

      //Abgewiesene Belege nennt erp-push einzeln. Sie gehoeren ins Protokoll,
      //sonst faellt eine Ablehnung nur in der Gesamtzahl auf.
      IF ValType(hResponse) == "H" .AND. HHasKey(hResponse, "errors") .AND. ;
         ValType(hResponse["errors"]) == "A"
         _LogFehler(hResponse["errors"], @nFehler)
      ENDIF
   NEXT

RETURN NIL

STATIC FUNCTION _LogFehler(aErrors, nFehler)
   LOCAL hError

   FOR EACH hError IN aErrors
      nFehler++
      IF ValType(hError) == "H" .AND. HHasKey(hError, "ref") .AND. HHasKey(hError, "error")
         _Log("*** " + _Text(hError["ref"]) + ": " + _Text(hError["error"]))
      ENDIF
   NEXT

RETURN NIL

STATIC FUNCTION _FinovaUserId()
   LOCAL xWert := GetValue("LIQUIDITY_USER_ID", "")

   IF ValType(xWert) == "C" .AND. ! Empty(AllTrim(xWert))
      RETURN AllTrim(xWert)
   ENDIF

RETURN "6efd3371-fc1a-4883-a0ad-cf540a3f84ee"

STATIC FUNCTION _Json(cText)
   LOCAL xWert := NIL

   IF ValType(cText) != "C" .OR. Empty(cText)
      RETURN NIL
   ENDIF

   BEGIN SEQUENCE
      xWert := HB_JsonDecode(cText)
   RECOVER
      xWert := NIL
   END SEQUENCE

RETURN xWert

STATIC FUNCTION _Text(xWert)
   IF ValType(xWert) == "C" .OR. ValType(xWert) == "M"
      RETURN AllTrim(xWert)
   ENDIF
   IF ValType(xWert) == "N"
      RETURN AllTrim(Str(xWert))
   ENDIF
RETURN ""

STATIC FUNCTION _CurrencyISO(cCurrency)
   LOCAL hMap := {"E" => "EUR", "U" => "USD", "P" => "GBP", "Y" => "JPY"}
   LOCAL cCur := Upper(AllTrim(cCurrency))

   IF Empty(cCur)
      cCur := "E"
   ENDIF
   IF HHasKey(hMap, cCur)
      RETURN hMap[cCur]
   ENDIF

RETURN cCur

STATIC FUNCTION _IsoDate(dDate)
   IF ValType(dDate) != "D" .OR. Empty(dDate)
      RETURN ""
   ENDIF
RETURN Str(Year(dDate), 4) + "-" + StrZero(Month(dDate), 2) + "-" + StrZero(Day(dDate), 2)

STATIC FUNCTION _SplitIntoBatches(aSource, nBatchSize)
   LOCAL aBatches := {}
   LOCAL aBatch := {}
   LOCAL xItem

   FOR EACH xItem IN aSource
      AAdd(aBatch, xItem)
      IF Len(aBatch) >= nBatchSize
         AAdd(aBatches, aBatch)
         aBatch := {}
      ENDIF
   NEXT

   IF Len(aBatch) > 0
      AAdd(aBatches, aBatch)
   ENDIF

RETURN aBatches

STATIC FUNCTION _Log(cText)
   ? cText
   IF snProtokoll > 0
      FWrite(snProtokoll, cText + CRLF)
   ENDIF

RETURN NIL

STATIC FUNCTION _Finish(cProtokoll)
   IF snProtokoll > 0
      FClose(snProtokoll)
      snProtokoll := 0
   ENDIF

   IF ! GetConfigValue("BATCHMODE")
      WAPI_ShellExecute(NIL, "open", cProtokoll, "", "")
      Sinkey(0)
   ENDIF

RETURN NIL
