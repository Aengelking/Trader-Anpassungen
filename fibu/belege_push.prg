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

//#include 'trader.ch'

#define CRLF Chr(13)+Chr(10)

//Belege je Aufruf. erp-push schreibt sie in Bloecken zu 500; 100 je Anfrage
//haelt den Rumpf klein genug fuer eine Zeitueberschreitung.
#define PUSH_BATCH 100

#define FIBU_DEFAULT_YEAR 2026

STATIC snProtokoll := 0
STATIC shIni := NIL
STATIC shWaehrungen := {=>}

FUNCTION RUN_PUSH_BELEGE(lLive)
   LOCAL oRest := RestApi():New()
   LOCAL dFrom
   LOCAL aBelege
   LOCAL aUebergangen := {}
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
   _Log("Firma: " + _Firma() + "   Quelle: " + _Quelle())
   _Log(IF(lLive, "ECHTLAUF - Belege werden gesendet", "TROCKENLAUF - es wird nichts gesendet"))
   _Log("Belege ab " + DToC(dFrom))
   _Log("Trader wird ausschliesslich gelesen")
   _Log("")

   IF Empty(_Quelle())
      _Log("*** ABBRUCH: FIRMNO ist leer - das Mandantenkennzeichen fehlt.")
      _Log("*** Es gehoert in den Schluessel, unter dem Finova eintraegt.")
      _Log("*** Ohne ihn wuerde dieser Lauf die Belege der anderen Firma")
      _Log("*** ueberschreiben, sobald eine Belegnummer in beiden vorkommt.")
      _Finish(cProtokoll)
      UnLockEntity("FIBU", 0)
      RETURN .F.
   ENDIF

   IF ! _LoadIni()
      _Log("*** ABBRUCH: lexware.ini nicht lesbar - ohne die Auffangkonten")
      _Log("*** waeren Belege ohne Steuerschluessel unkontiert.")
      _Finish(cProtokoll)
      UnLockEntity("FIBU", 0)
      RETURN .F.
   ENDIF

   aBelege := _CollectOutbound(dFrom, @aUebergangen)
   _Log("Ausgangsrechnungen: " + LTrim(Str(Len(aBelege))))

   _CollectInbound(dFrom, @aBelege, @aUebergangen)
   _Log("Belege gesamt:      " + LTrim(Str(Len(aBelege))))
   _Log("")

   _LogUebergangen(aUebergangen)
   _LogZusammenfassung(aBelege)
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
  * Die Quelle - und zugleich das Mandantenkennzeichen.
  *
  * Finova traegt ueber (user_id, source, erp_reference) ein. Beide Firmen
  * laufen unter derselben user_id, und die Belegnummern sind je Firma
  * vergeben: "ER-100-12345" kann es in Automotive und in Elektronik geben,
  * mit verschiedenen Lieferanten und verschiedenen Betraegen.
  *
  * Stuende in source fuer beide dasselbe, wuerde der zweite Lauf den Beleg
  * des ersten ueberschreiben - kein Fehler, keine Meldung, die Zeile ist
  * einfach weg. Die Firmennummer im Schluessel haelt sie auseinander.
  *
  * FIRMNO und nicht FIRMPATH: dieselbe Nummer steht in Finova an der Firma
  * (companies.erp_company_id), womit derselbe Wert die Zuordnung traegt.
  **/
STATIC FUNCTION _Quelle()
   LOCAL xNummer := GetConfigValue("FIRMNO")
   LOCAL cNummer := ""

   DO CASE
   CASE ValType(xNummer) == "N"
      cNummer := LTrim(Str(xNummer))
   CASE ValType(xNummer) == "C"
      cNummer := AllTrim(xNummer)
   ENDCASE

   IF Empty(cNummer)
      RETURN ""
   ENDIF

RETURN "trader-" + cNummer

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
STATIC FUNCTION _CollectOutbound(dFrom, aUebergangen)
   LOCAL aBelege := {}
   LOCAL hBeleg, hKonten
   LOCAL oRechnung
   LOCAL nScanned := 0
   LOCAL cName, cKonto, cUstId
   LOCAL nSkontoRate, dSkontoDatum, dFaellig
   LOCAL nRec

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

      //Wer im Zeitraum liegt und trotzdem nicht mitkommt, wird benannt. Die
      //Filter sind richtig - eine ungepackte Rechnung ist nicht fertig, und
      //eine Rechnung ueber 0,00 ist keine Buchung, die Datenbank weist sie
      //ohnehin ab. Aber sie duerfen nicht lautlos verschwinden: sonst klafft
      //in der Belegnummernfolge eine Luecke, die niemand mehr erklaeren kann,
      //ohne in Trader nachzusehen.
      DO CASE
      CASE re->Rechdat < dFrom
         //ausserhalb des Zeitraums - kein Uebergehen, sondern der Zuschnitt
      CASE ! re->Packed
         AAdd(aUebergangen, {"RE" + StrZero(re->Rechnr, 6), "nicht gepackt"})
      CASE re->PosWt == 0
         AAdd(aUebergangen, {"RE" + StrZero(re->Rechnr, 6), "Betrag 0,00"})
      OTHERWISE

         oRechnung := Rechnung():New()
         oRechnung:Load(re->Rechnr)

         cName  := Trim(re->Kunde)
         cKonto := ""
         cUstId := ""
         IF ku->(dbSeek(Pad(re->Kunde, 8) + "K"))
            cName  := IF(! Empty(Trim(ku->Name1)), Trim(ku->Name1), Trim(ku->Kunde))
            cKonto := _KontoStr(ku->Nummer)

            //Die Umsatzsteuer-Identifikation gehoert zu der Adresse, die die
            //Besteuerung bestimmt - bei abweichendem Lieferland ist das die
            //Lieferadresse, nicht die Rechnungsadresse.
            //GotoRechnungsTaxCustomer setzt ku genau darauf. Die Satznummer
            //wird vorher gemerkt und danach zurueckgestellt, wie in
            //LX_BookOutInvoice: der Rest der Schleife erwartet ku beim Kunden.
            nRec := ku->(RecNo())
            BEGIN SEQUENCE
               GotoRechnungsTaxCustomer(re->Kunde, re->AbNr, re->DelAd)
               cUstId := StrTran(AllTrim(ku->VatNr), " ", "")
            RECOVER
               cUstId := ""
            END SEQUENCE
            ku->(dbGoTo(nRec))
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
         hBeleg["counterparty_vat_id"]  := cUstId

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

         hBeleg["source"]     := _Quelle()
         hBeleg["company_id"] := GetConfigValue("FIRMNO")
         AAdd(aBelege, hBeleg)
      ENDCASE

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
STATIC FUNCTION _CollectInbound(dFrom, aBelege, aUebergangen)
   LOCAL hBeleg, hKonten
   LOCAL nScanned := 0
   LOCAL cName, cUstId
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

      //Wie bei den Ausgangsrechnungen: was im Zeitraum liegt und trotzdem
      //nicht mitkommt, wird benannt. Bei "nicht gebucht" ist das mehr als
      //Buchfuehrung ueber den Lauf - eine erfasste, aber nicht gebuchte
      //Eingangsrechnung im abzurechnenden Monat ist liegengebliebene Arbeit.
      DO CASE
      CASE rech->Rechdat < dFrom
         //ausserhalb des Zeitraums
      CASE ! rech->Booked
         AAdd(aUebergangen, {_ErRef(), "nicht gebucht"})
      CASE Empty(rech->Liefma) .OR. Empty(rech->Rechnr)
         AAdd(aUebergangen, {_ErRef(), "Lieferant oder Belegnummer fehlt"})
      CASE rech->GrAmt == 0
         AAdd(aUebergangen, {_ErRef(), "Betrag 0,00"})
      OTHERWISE

         cName    := Trim(rech->Liefma)
         cUstId   := ""
         nMwst    := 0
         nVatRate := 0
         IF ku->(dbSeek(Pad(rech->Liefma, 8) + "L"))
            cName  := IF(! Empty(Trim(ku->Name1)), Trim(ku->Name1), Trim(ku->Kunde))
            cUstId := StrTran(AllTrim(ku->VatNr), " ", "")
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
         hBeleg["counterparty_vat_id"]  := cUstId

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

         hBeleg["source"]     := _Quelle()
         hBeleg["company_id"] := GetConfigValue("FIRMNO")
         AAdd(aBelege, hBeleg)
      ENDCASE

      rech->(dbSkip())
   ENDDO

   _Log("  ENGRECH gelesen: " + LTrim(Str(nScanned)))

RETURN NIL

/**
  * Kennung einer Eingangsrechnung fuer das Protokoll. Faellt Lieferant oder
  * Belegnummer aus, bleibt die Satznummer - ohne sie waere ein Datenfehler
  * genau der Fall, den man anschliessend nicht wiederfindet.
  **/
STATIC FUNCTION _ErRef()
   IF Empty(rech->Liefma) .OR. Empty(rech->Rechnr)
      RETURN "ER-Satz " + LTrim(Str(rech->(RecNo())))
   ENDIF
RETURN "ER-" + Trim(rech->Liefma) + "-" + Trim(rech->Rechnr)

/**
  * Was im Zeitraum liegt, aber nicht mitkommt - nach Grund gebuendelt.
  *
  * Die Filter sind richtig; sichtbar muessen sie trotzdem sein. Die beiden
  * Nullbelege aus dem ersten Automotive-Lauf (RE001025 und RE001031) liessen
  * eine Luecke in der Belegnummernfolge, die sich nur durch einen Blick in
  * Trader erklaeren liess. Genau das soll das Protokoll abnehmen.
  **/
STATIC FUNCTION _LogUebergangen(aUebergangen)
   LOCAL hGruende := {=>}
   LOCAL aEintrag, cGrund, cListe
   LOCAL nZeile

   IF Len(aUebergangen) == 0
      RETURN NIL
   ENDIF

   FOR EACH aEintrag IN aUebergangen
      IF ! HHasKey(hGruende, aEintrag[2])
         hGruende[aEintrag[2]] := {}
      ENDIF
      AAdd(hGruende[aEintrag[2]], aEintrag[1])
   NEXT

   _Log("IM ZEITRAUM, ABER NICHT UEBERNOMMEN: " + LTrim(Str(Len(aUebergangen))))
   FOR EACH cGrund IN HGetKeys(hGruende)
      cListe := ""
      nZeile := 0
      FOR EACH aEintrag IN hGruende[cGrund]
         nZeile++
         IF nZeile > 20
            cListe += ", ... und " + LTrim(Str(Len(hGruende[cGrund]) - 20)) + " weitere"
            EXIT
         ENDIF
         cListe += IF(Empty(cListe), "", ", ") + aEintrag
      NEXT
      _Log("  " + PadR(cGrund, 34) + LTrim(Str(Len(hGruende[cGrund]))) + "  " + cListe)
   NEXT
   _Log("")

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
/**
  * Die Summen, bevor die Einzelzeilen kommen.
  *
  * Der erste Elektronik-Trockenlauf brachte 2686 Belege; die Vorschau zeigt
  * hoechstens 200 davon, und weil ENGLSRE nach Kunde sortiert gelesen wird,
  * sind das die Buchstaben A bis C. Sieben Prozent, und die nicht einmal
  * zufaellig - ueber Fremdwaehrung, Reverse Charge oder den Schweizer Satz
  * sagte die Liste nichts, obwohl es sie gibt.
  *
  * Eine Aufstellung nach Waehrung, Steuerart und Erloes- beziehungsweise
  * Aufwandskonto deckt dagegen alle Belege ab und ist die Zahl, die sich
  * gegen die Umsatzsteuer-Voranmeldung halten laesst.
  *
  * Summiert wird IMMER je Waehrung. Betraege verschiedener Waehrungen zu
  * addieren ergaebe eine Zahl, die nichts bedeutet - und der Umrechnungskurs
  * gehoert hier nicht her, den setzt Finova am Belegtag.
  **/
STATIC FUNCTION _LogZusammenfassung(aBelege)
   LOCAL hWaehrung := {=>}, hArt := {=>}, hKonto := {=>}
   LOCAL hBeleg
   LOCAL cArt, cKonto

   IF Len(aBelege) == 0
      RETURN NIL
   ENDIF

   FOR EACH hBeleg IN aBelege
      cArt := IF(Empty(hBeleg["tax_kind"]), "(ohne Schluessel)", AllTrim(hBeleg["tax_kind"]))

      //Bei der Ausgangsrechnung traegt das Habenkonto den Erloes, bei der
      //Eingangsrechnung das Sollkonto den Aufwand. Das Gegenkonto ist in
      //beiden Faellen das Personenkonto und sagt ueber die Art nichts.
      cKonto := IF(hBeleg["doc_type"] == "sales_invoice", ;
                   hBeleg["account_credit"], hBeleg["account_debit"])
      IF Empty(cKonto)
         cKonto := "(ohne Konto)"
      ENDIF

      _Zaehle(hWaehrung, hBeleg["currency"], hBeleg["gross_amount"])
      _Zaehle(hArt, PadR(cArt, 18) + hBeleg["currency"], hBeleg["gross_amount"])
      _Zaehle(hKonto, PadR(cKonto, 18) + hBeleg["currency"], hBeleg["gross_amount"])
   NEXT

   _Log("ZUSAMMENFASSUNG ueber alle " + LTrim(Str(Len(aBelege))) + " Belege")
   _LogGruppe("nach Waehrung", hWaehrung)
   _LogGruppe("nach Steuerart", hArt)
   _LogGruppe("nach Erloes- bzw. Aufwandskonto", hKonto)
   _Log("")

RETURN NIL

STATIC FUNCTION _Zaehle(hZiel, cSchluessel, nBetrag)
   IF ! HHasKey(hZiel, cSchluessel)
      hZiel[cSchluessel] := {0, 0}
   ENDIF
   hZiel[cSchluessel][1]++
   hZiel[cSchluessel][2] += nBetrag
RETURN NIL

STATIC FUNCTION _LogGruppe(cTitel, hGruppe)
   LOCAL aSchluessel := HGetKeys(hGruppe)
   LOCAL cSchluessel

   ASort(aSchluessel)

   _Log("  " + cTitel)
   FOR EACH cSchluessel IN aSchluessel
      _Log("    " + PadR(cSchluessel, 24) + ;
           PadL(LTrim(Str(hGruppe[cSchluessel][1])), 7) + "  " + ;
           PadL(LTrim(Str(Round(hGruppe[cSchluessel][2], 2), 16, 2)), 17))
   NEXT

RETURN NIL

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
      //Bei EG fehlt ohne USt-IdNr. eine Pflichtangabe - in beiden Richtungen,
      //aber aus verschiedenen Gruenden: bei der Lieferung braucht sie die
      //Zusammenfassende Meldung, beim Erwerb die Erwerbsbesteuerung und der
      //Vorsteuerabzug. Fuer die Buchung reicht das Konto, dafuer nicht.
      IF Upper(AllTrim(hBeleg["tax_kind"])) == "EG" .AND. Empty(hBeleg["counterparty_vat_id"])
         cFehlt += "USt-IdNr "
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
      //Faelligkeit und Skonto gehoeren in die Vorschau. Sie sind die einzigen
      //Angaben, die sich ausserhalb von Trader nicht nachrechnen lassen (bei
      //ziel1 = -4 stecken sie in einem kundeneigenen Programm) - wenn sie hier
      //nicht zu sehen sind, sieht sie vor dem Echtlauf ueberhaupt niemand.
      _Log("  " + PadR(hBeleg["erp_reference"], 22) + PadR(hBeleg["doc_date"], 12) + ;
           PadL(LTrim(Str(hBeleg["gross_amount"], 14, 2)), 14) + " " + hBeleg["currency"] + ;
           "  " + PadR(Left(hBeleg["counterparty_name"], 22), 24) + ;
           "S " + PadR(hBeleg["account_debit"], 8) + ;
           "H " + PadR(hBeleg["account_credit"], 8) + ;
           "faellig " + PadR(hBeleg["due_date"], 12) + ;
           PadR(_SkontoText(hBeleg), 30) + ;
           PadR(hBeleg["tax_kind"], 9) + ;
           IF(Empty(hBeleg["counterparty_vat_id"]), "", hBeleg["counterparty_vat_id"]))
   NEXT
   _Log("")

RETURN NIL

/**
  * Senden, in Bloecken.
  **/
/**
  * Die Skontokondition als Text, leer wenn keine vereinbart ist.
  **/
STATIC FUNCTION _SkontoText(hBeleg)
   IF ! HHasKey(hBeleg, "discount_date") .OR. Empty(hBeleg["discount_date"])
      RETURN ""
   ENDIF
RETURN "Skonto " + AllTrim(Str(hBeleg["discount_rate"], 6, 2)) + "% bis " + hBeleg["discount_date"]

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

/**
  * Traders Waehrungskennzeichen als ISO-Kuerzel.
  *
  * Das Kuerzel steht in der Waehrungstabelle (cur->Symbol) und ist zugleich
  * der Feldname in curhist, Traders eigener Kursreihe - es ist also gepflegt
  * und vollstaendig, solange dort eine Waehrung angelegt ist.
  *
  * Vorher stand hier eine feste Liste mit vier Eintraegen. Die war genau bis
  * zur ersten weiteren Waehrung richtig und danach stillschweigend falsch:
  * ein unbekanntes Kennzeichen ging als einzelner Buchstabe raus, fand
  * drueben keinen Kurs, und der Beleg blieb unbewertet. Die Liste bleibt als
  * Rueckfall, falls die Waehrungstabelle kein Symbol fuehrt.
  *
  * Das Ergebnis wird gemerkt: CURRATE durchsucht die Tabelle sequenziell, und
  * bei ein paar tausend Belegen sind das ein paar tausend Durchlaeufe fuer
  * eine Handvoll verschiedener Waehrungen.
  **/
STATIC FUNCTION _CurrencyISO(cCurrency)
   LOCAL hMap := {"E" => "EUR", "U" => "USD", "P" => "GBP", "Y" => "JPY"}
   LOCAL cCur := Upper(AllTrim(cCurrency))
   LOCAL xSymbol

   IF Empty(cCur)
      cCur := "E"
   ENDIF

   IF HHasKey(shWaehrungen, cCur)
      RETURN shWaehrungen[cCur]
   ENDIF

   xSymbol := NIL
   BEGIN SEQUENCE
      xSymbol := CURRATE(cCur, "X")
   RECOVER
      xSymbol := NIL
   END SEQUENCE

   DO CASE
   CASE ValType(xSymbol) == "C" .AND. Len(AllTrim(xSymbol)) == 3
      shWaehrungen[cCur] := Upper(AllTrim(xSymbol))
   CASE HHasKey(hMap, cCur)
      shWaehrungen[cCur] := hMap[cCur]
   OTHERWISE
      //Weder Symbol noch Rueckfall: der Rohwert geht raus und der Beleg
      //landet drueben in der Arbeitsliste, weil sich dazu kein Kurs findet.
      //Sichtbar falsch ist besser als unsichtbar falsch.
      shWaehrungen[cCur] := cCur
   ENDCASE

RETURN shWaehrungen[cCur]

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
