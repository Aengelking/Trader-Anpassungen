/**
  * RUN_SYNC_BBB - Belegabgleich Trader -> BuchhaltungsButler
  *
  * Gegenstueck zu LexwareSync (lexware_import.prg), aber mit einem
  * entscheidenden Unterschied:
  *
  *   DIESES PROGRAMM SCHREIBT NICHTS IN TRADER.
  *
  * Kein re->transfer, kein Code, kein Status, kein Paydate, kein AoQty -
  * nirgends ein Rec_Lock. Alle Trader-Tabellen werden ausschliesslich
  * gelesen. Das ist Absicht und keine Sparmassnahme:
  *
  *   - Der Abgleich laeuft neben Lexware her. Wuerde er Trader-Kennzeichen
  *     setzen, saehe LexwareSync die Rechnung als erledigt an und wuerde sie
  *     nie nach Lexware buchen. Ein Probelauf wuerde die laufende Buchhaltung
  *     beschaedigen.
  *   - Ein Lauf ohne Nebenwirkung darf beliebig oft wiederholt werden. Das
  *     ist beim Ausprobieren einer neuen Schnittstelle die halbe Miete.
  *
  * Woher weiss der Lauf dann, was schon uebertragen ist? Er fragt die
  * Gegenseite. BuchhaltungsButler liefert ueber /receipts/get seinen
  * Belegbestand mit Belegnummer und Betrag; daraus entsteht bei jedem Lauf
  * ein frischer Index, und gesendet wird nur, was dort fehlt. Der Zustand
  * liegt damit dort, wo er hingehoert - im Zielsystem, nicht in einem Flag,
  * das bei einem abgebrochenen Lauf falsch stehen bleibt.
  *
  * SCHNITTSTELLE (Stand API 1.9.1)
  *
  *   Basis   https://webapp.buchhaltungsbutler.de/api/v1
  *   Auth    HTTP-Basic mit API-Client und API-Secret (global),
  *           dazu api_key im Rumpf (waehlt den Mandanten)
  *   Alles   POST, auch das Lesen
  *   Grenzen 100 Anfragen je Mandant und Minute
  *           /receipts/get   hoechstens 500 Zeilen je Aufruf
  *           /receipts/addBatch hoechstens 50 Belege je Aufruf
  *
  * KEYCHAIN
  *
  *   ZWEI Eintraege, weil zwei verschiedene Geheimnisse gebraucht werden:
  *
  *     "BBB"     Password = "APICLIENT:APISECRET"
  *               RestApi reicht das Kennwortfeld bei gesetztem cKeyName
  *               unveraendert als CURLOPT_USERPWD an curl weiter - genau die
  *               Form, die HTTP-Basic braucht.
  *
  *     "BBBKEY"  Password = der api_key des Mandanten
  *               ueber cApiKeyName geladen und im Rumpf als $APIKEY$ ersetzt.
  *
  *   Warum nicht der api_key im Username-Feld von "BBB"? Das ist ein kurzes
  *   Klartextfeld, in das der Schluessel nicht hineinpasst. Lang genug (247
  *   Zeichen) und verschluesselt ist nur das Kennwortfeld - also braucht es
  *   einen zweiten Eintrag.
  *
  *   Den Schluessel hier selbst aus dem Keychain zu lesen geht nicht:
  *   Keychain_GetPassword prueft ProcName(1) gegen eine feste Liste und laesst
  *   nur RestApi:Execute und wenige andere durch. Der Weg ueber RestApi ist
  *   deshalb nicht der bequemere, sondern der einzige.
  *
  * AUFRUF
  *
  *   RUN_SYNC_BBB()          Trockenlauf - liest beide Seiten, zeigt und
  *                           protokolliert, was zu senden waere, sendet nichts
  *   RUN_SYNC_BBB(.T.)       Echtlauf - legt die fehlenden Belege an
  *   RUN_SYNC_BBB(.F., .T.)  zusaetzlich die Summen- und Saldenliste ziehen
  *
  * Der Trockenlauf ist die Voreinstellung. Ein Beleg in einer Buchhaltung
  * laesst sich nicht so leicht zurueckholen wie eine Zeile in einer Liste.
  *
  * KONTROLLWERT
  *
  * Jeder Lauf rechnet die Betraege beider Seiten gegeneinander - Trader gegen
  * BuchhaltungsButler, je Richtung, mit der Luecke und dem, was nach dem
  * Senden davon uebrig bleibt. Das kostet keinen zusaetzlichen Aufruf und ist
  * der eigentliche Zweck der Uebung: eine Stueckzahl verdeckt den einen
  * fehlenden Beleg ueber 40.000 Euro zwischen dreihundert kleinen.
  *
  * Die Summen- und Saldenliste (zweiter Parameter) geht einen Schritt weiter
  * und haelt die Salden der Personenkonten gegen die offenen Posten aus
  * Trader. Sie traegt allerdings erst, wenn die Belege drueben auch verbucht
  * sind - siehe _BbbSumsReport.
  **/

//#include 'trader.ch'

#define CRLF Chr(13)+Chr(10)

//Grenzen der Gegenseite, siehe Kopfkommentar
#define BBB_GET_LIMIT    500
#define BBB_BATCH_SIZE    50

//Ab wann Belege betrachtet werden, wenn nichts anderes hinterlegt ist.
#define BBB_DEFAULT_YEAR 2026

STATIC snProtokoll := 0
STATIC scFehlerText := ""

FUNCTION RUN_SYNC_BBB(lLive, lSummen)
   LOCAL oRest := RestApi():New()
   LOCAL dFrom
   LOCAL hBestandAus := {=>}
   LOCAL hBestandEin := {=>}
   LOCAL aAus, aEin
   LOCAL aNeu := {}, aKlaerung := {}
   LOCAL hDebitoren := {=>}, hKreditoren := {=>}
   LOCAL cProtokoll
   LOCAL nGesendet := 0, nFehler := 0
   LOCAL nKonten := 0, nKontenFehler := 0
   LOCAL nOffenDeb := 0, nOffenKred := 0
   LOCAL lOk

   Default(@lLive, .F.)
   Default(@lSummen, .F.)

   IF ! LockEntity("BBBS", 0, "%% wird bereits von % durchgefuehrt")
      RETURN .F.
   ENDIF

   dFrom := _BbbSince()
   cProtokoll := Path("\export\bbb_protocol_" + DToS(Date()) + "_" + StrTran(Time(), ":", "-") + ".txt")
   snProtokoll := FCreate(cProtokoll)
   scFehlerText := ""

   Head("BuchhaltungsButler Belegabgleich")
   _Log("Trader -> BuchhaltungsButler, " + DToC(Date()) + " " + Time())
   _Log(IF(lLive, "ECHTLAUF - fehlende Belege werden angelegt", "TROCKENLAUF - es wird nichts gesendet"))
   _Log("Belege ab " + DToC(dFrom))
   _Log("Trader wird ausschliesslich gelesen - keine Kennzeichen werden gesetzt")
   _Log("")

   oRest:cBaseUrl := "https://webapp.buchhaltungsbutler.de/api/v1/"
   oRest:cKeyName := "BBB"       //Basic-Auth: APICLIENT:APISECRET
   oRest:cApiKeyName := "BBBKEY" //Mandanten-Schluessel, im Rumpf als $APIKEY$
   oRest:lUseBasicAuth := .T.

   //1. Bestand der Gegenseite. Ohne ihn darf nichts gesendet werden - sonst
   //   entstuenden bei jedem Lauf dieselben Belege noch einmal.
   lOk := _BbbFetchReceipts(oRest, "outbound", dFrom, @hBestandAus)
   IF lOk
      lOk := _BbbFetchReceipts(oRest, "inbound", dFrom, @hBestandEin)
   ENDIF

   IF ! lOk
      _Log("ABBRUCH: Bestand von BuchhaltungsButler nicht lesbar. Es wird nichts gesendet.")
      _Finish(cProtokoll)
      UnLockEntity("BBBS", 0)
      RETURN .F.
   ENDIF

   _Log("Bestand BuchhaltungsButler: " + LTrim(Str(Len(hBestandAus))) + " Ausgangsbelege, " + ;
        LTrim(Str(Len(hBestandEin))) + " Eingangsbelege")
   _Log("")

   //2. Trader-Seite sammeln
   aAus := _CollectOutbound(dFrom, @nOffenDeb)
   _Log("Trader Ausgangsrechnungen: " + LTrim(Str(Len(aAus))))

   aEin := _CollectInbound(dFrom, @nOffenKred)
   _Log("Trader Eingangsrechnungen: " + LTrim(Str(Len(aEin))))
   _Log("")

   //3. Abgleich
   _Diff(aAus, hBestandAus, @aNeu, @aKlaerung)
   _Diff(aEin, hBestandEin, @aNeu, @aKlaerung)

   _Log("Fehlend in BuchhaltungsButler: " + LTrim(Str(Len(aNeu))))
   _Log("Zur Klaerung (Belegnummer vorhanden, Betrag abweichend): " + LTrim(Str(Len(aKlaerung))))
   _Log("")

   _LogKlaerung(aKlaerung)

   //4. Kontrollrechnung. Kostet keinen einzigen Aufruf - beide Seiten liegen
   //   schon im Speicher. Genau der Rueckkanal, dessen Fehlen bei den anderen
   //   geprueften Systemen der Hauptkritikpunkt war.
   _Kontrollrechnung(aAus, aEin, hBestandAus, hBestandEin, aNeu, aKlaerung)

   //5. Personenkonten. Erst die Konten, dann die Belege - ein Beleg kann sich
   //   nur auf ein Konto beziehen, das es schon gibt.
   IF Len(aNeu) > 0 .OR. lSummen
      IF _BbbFetchAccounts(oRest, "debtors", @hDebitoren) .AND. ;
         _BbbFetchAccounts(oRest, "creditors", @hKreditoren)

         _EnsureAccounts(oRest, aNeu, "debtors", "invoice outbound", @hDebitoren, ;
                         lLive, @nKonten, @nKontenFehler)
         _EnsureAccounts(oRest, aNeu, "creditors", "invoice inbound", @hKreditoren, ;
                         lLive, @nKonten, @nKontenFehler)

         _AssignAccounts(aNeu, hDebitoren, hKreditoren)
      ELSE
         //Kein Abbruch: ein Beleg ohne Personenkonto landet auf dem
         //Sammelkonto und ist damit immer noch besser als kein Beleg. Die
         //Buchhaltung sieht ihn und kann ihn umkontieren.
         _Log("*** Personenkonten nicht lesbar - Belege gehen ohne Kontobezug")
      ENDIF
      _Log("")
   ENDIF

   //6. Summen- und Saldenliste, nur auf Anforderung. Zwei Gruende fuer die
   //   Zurueckhaltung: der Bericht laeuft asynchron und muss abgewartet
   //   werden, und ein neuer Bericht ERSETZT den zuletzt erzeugten - wer in
   //   BuchhaltungsButler gerade selbst einen gezogen hat, verlore ihn.
   IF lSummen
      _BbbSumsReport(oRest, dFrom, hDebitoren, hKreditoren, nOffenDeb, nOffenKred)
      _Log("")
   ENDIF

   //7. Senden
   IF Len(aNeu) == 0
      _Log("Nichts zu senden.")
   ELSEIF ! lLive
      _LogVorschau(aNeu)
   ELSE
      _BbbSend(oRest, aNeu, @nGesendet, @nFehler)
      _Log("")
      _Log("Gesendet: " + LTrim(Str(nGesendet)) + "  Fehler: " + LTrim(Str(nFehler)) + ;
           "  Personenkonten angelegt: " + LTrim(Str(nKonten)) + ;
           "  davon fehlgeschlagen: " + LTrim(Str(nKontenFehler)))
   ENDIF

   _Finish(cProtokoll)
   UnLockEntity("BBBS", 0)

RETURN .T.

/**
  * Ab welchem Belegdatum abgeglichen wird.
  *
  * Bewusst ein harter Schnitt und kein "seit dem letzten Lauf": ein
  * Zeitstempel des letzten Laufs waere genau das Stueck Zustand, das dieses
  * Programm nicht fuehren will. Der Bestandsabgleich gegen die Gegenseite
  * macht ihn ueberfluessig - er kostet nur ein paar Zeilen mehr im Lesen.
  **/
STATIC FUNCTION _BbbSince()
   LOCAL dFrom := GetValue("BBB_SINCE", SToD(""))

   IF ValType(dFrom) != "D" .OR. Empty(dFrom)
      dFrom := SToD(LTrim(Str(BBB_DEFAULT_YEAR, 4)) + "0101")
   ENDIF

RETURN dFrom

/**
  * Belegbestand der Gegenseite holen, geblaettert.
  *
  * cDirection ist "outbound" (Ausgangsbelege) oder "inbound".
  * Der Index bildet Belegnummer -> Array der dort vorhandenen Belege; die
  * Belegnummer allein reicht nicht als Schluessel, weil zwei Lieferanten
  * dieselbe Nummer vergeben koennen. Den Betrag entscheidet der Abgleich.
  **/
STATIC FUNCTION _BbbFetchReceipts(oRest, cDirection, dFrom, hIndex)
   LOCAL hBody, hResponse
   LOCAL nOffset := 0
   LOCAL nGelesen := 0
   LOCAL aData, hRow, cKey
   LOCAL cResponse, nStatus := 0

   DO WHILE .T.
      hBody := {=>}
      hBody["api_key"] := "$APIKEY$"
      hBody["list_direction"] := cDirection
      hBody["date_from"] := _IsoDate(dFrom)
      hBody["limit"] := BBB_GET_LIMIT
      hBody["offset"] := nOffset
      //Pflichtfeld, trotz des Namens die Sortierrichtung
      hBody["field"] := "ASC"

      cResponse := oRest:Execute("receipts/get", "POST", hBody, _BbbHeader(), .T., @nStatus)

      IF Empty(cResponse)
         _Log("*** receipts/get " + cDirection + ": keine Antwort (HTTP " + LTrim(Str(nStatus)) + ")")
         RETURN .F.
      ENDIF

      hResponse := HB_JsonDecode(cResponse)
      IF ValType(hResponse) != "H" .OR. ! HHasKey(hResponse, "success") .OR. ! hResponse["success"]
         _Log("*** receipts/get " + cDirection + " fehlgeschlagen (HTTP " + LTrim(Str(nStatus)) + "): " + Left(cResponse, 300))
         RETURN .F.
      ENDIF

      aData := IF(HHasKey(hResponse, "data"), hResponse["data"], {})
      IF ValType(aData) != "A"
         aData := {}
      ENDIF

      FOR EACH hRow IN aData
         IF ValType(hRow) != "H"
            LOOP
         ENDIF
         //Geloeschte Belege zaehlen nicht als vorhanden - sonst faende ein
         //spaeterer Lauf eine Rechnung nie wieder, die jemand hier entfernt hat.
         IF _RowStr(hRow, "deleted") == "1"
            LOOP
         ENDIF
         cKey := _BbbKey(_RowStr(hRow, "invoicenumber"))
         IF Empty(cKey)
            LOOP
         ENDIF
         IF ! HHasKey(hIndex, cKey)
            hIndex[cKey] := {}
         ENDIF
         AAdd(hIndex[cKey], {"betrag" => Val(_RowStr(hRow, "amount")), ;
                             "gegenpartei" => _RowStr(hRow, "counterparty"), ;
                             "id" => _RowStr(hRow, "id_by_customer")})
         nGelesen++
      NEXT

      IF Len(aData) < BBB_GET_LIMIT
         EXIT
      ENDIF
      nOffset += BBB_GET_LIMIT
   ENDDO

   _Log("receipts/get " + cDirection + ": " + LTrim(Str(nGelesen)) + " Belege gelesen")

RETURN .T.

STATIC FUNCTION _BbbHeader()
RETURN {"Content-Type: application/json", "Accept: application/json"}

STATIC FUNCTION _BbbKey(cInvoiceNo)
RETURN Upper(AllTrim(cInvoiceNo))

/**
  * Ein Feld aus einer Antwortzeile als Zeichenkette. Die API liefert Zahlen
  * teils als Text ("123.99"), teils als Zahl - beides muss hier durch.
  **/
STATIC FUNCTION _RowStr(hRow, cField)
   LOCAL xValue

   IF ! HHasKey(hRow, cField)
      RETURN ""
   ENDIF

   xValue := hRow[cField]
   DO CASE
   CASE ValType(xValue) == "C"
      RETURN AllTrim(xValue)
   CASE ValType(xValue) == "N"
      RETURN AllTrim(Str(xValue, 20, 2))
   CASE ValType(xValue) == "L"
      RETURN IF(xValue, "1", "0")
   ENDCASE

RETURN ""

/**
  * Abgleich eines Stapels gegen den Bestand.
  *
  * Drei Ausgaenge je Beleg:
  *   - Belegnummer und Betrag stimmen ueberein -> vorhanden, nichts zu tun
  *   - Belegnummer unbekannt                   -> fehlt, wird gesendet
  *   - Belegnummer da, Betrag anders           -> zur Klaerung, NICHT gesendet
  *
  * Der dritte Fall ist der wichtige. Er trifft zwei echte Faelle: dieselbe
  * Belegnummer bei zwei Lieferanten, und eine Rechnung, die sich nach der
  * Uebertragung geaendert hat. Beides darf kein zweiter Beleg werden, und
  * beides darf auch nicht stillschweigend als erledigt gelten - es gehoert
  * ins Protokoll, damit ein Mensch hinsieht.
  **/
STATIC FUNCTION _Diff(aBelege, hBestand, aNeu, aKlaerung)
   LOCAL hBeleg, hVorhanden, aTreffer
   LOCAL cKey
   LOCAL lGefunden

   FOR EACH hBeleg IN aBelege
      cKey := _BbbKey(hBeleg["invoice_number"])

      IF Empty(cKey) .OR. ! HHasKey(hBestand, cKey)
         AAdd(aNeu, hBeleg)
         LOOP
      ENDIF

      lGefunden := .F.
      aTreffer := hBestand[cKey]
      FOR EACH hVorhanden IN aTreffer
         IF Abs(hVorhanden["betrag"] - hBeleg["amount"]) <= 0.01
            lGefunden := .T.
            EXIT
         ENDIF
      NEXT

      IF ! lGefunden
         hBeleg["_bbb_betraege"] := aTreffer
         AAdd(aKlaerung, hBeleg)
      ENDIF
   NEXT

RETURN NIL

/**
  * Ausgangsrechnungen aus ENGLSRE.
  *
  * Traversierung wie in lexware_import.prg: Index 2, nur Kopfsaetze
  * (Reposnr == 0), nur gepackte Rechnungen. Was dort zusaetzlich abgefragt
  * wird - ! re->transfer - faellt hier bewusst weg: dieses Flag gehoert
  * Lexware, und wir wollen den vollstaendigen Belegbestand ab dem Stichtag,
  * nicht nur das, was Lexware noch nicht kennt.
  *
  * Nullrechnungen bleiben draussen. BuchhaltungsButler weist 0,00 als
  * ungueltigen Betrag zurueck, und ein Beleg ohne Wert hilft der Buchhaltung
  * ohnehin nicht.
  **/
STATIC FUNCTION _CollectOutbound(dFrom, nOffen)
   LOCAL aBelege := {}
   LOCAL hNamen := {=>}
   LOCAL hBeleg
   LOCAL oRechnung
   LOCAL nScanned := 0
   LOCAL nWait
   LOCAL cName
   LOCAL lVorkasse

   NetUse("englsre", "re")
   NetUse("engkund", "ku")
   NetUse("skontoa", "sk")

   ku->(dbSetOrder(1))
   re->(dbSetOrder(2))
   re->(dbSetFilter({|| ! Empty(re->Kunde) }, "! Empty(kunde)"))
   re->(dbGoTop())

   DO WHILE ! re->(EOF()) .AND. re->Reposnr == 0
      nScanned++

      IF re->Rechdat >= dFrom .AND. re->Packed .AND. re->PosWt != 0

         //Offene Posten mitrechnen - der Trader-Teil des Kontrollwerts.
         //Bedingung und Betrag wie in lexware_import.prg, wo dieselbe Summe
         //seit Jahren gegen den Lexware-Debitorensaldo laeuft. Nur auf Belege
         //ab dem Stichtag beschraenkt: BuchhaltungsButler kennt die aelteren
         //nicht, und eine kumulierte Summe gegen einen Teilbestand zu halten
         //waere eine Differenz, die nichts bedeutet.
         lVorkasse := sk->(IsPrePay(re->Skonto))
         IF (re->Status < 3 .AND. re->Code != 3) .OR. lVorkasse
            nOffen += Round(re->PosWt - IF(lVorkasse, 0, re->AoQty), 2)
         ENDIF

         oRechnung := Rechnung():New()
         oRechnung:Load(re->Rechnr)

         cName := _GetCustomerName(re->Kunde, hNamen)

         nWait := 0
         IF ku->(dbSeek(Pad(re->Kunde, 8) + "K"))
            nWait := sk->(GetSkontoWait(ku->Skonto, re->Rechdat, re->Rechdat))
         ENDIF

         hBeleg := {=>}
         hBeleg["type"] := "invoice outbound"
         hBeleg["counterparty"] := cName
         hBeleg["invoice_number"] := LTrim(Str(re->Rechnr))
         hBeleg["date"] := _IsoDate(re->Rechdat)
         hBeleg["amount"] := Round(oRechnung:Brutto, 2)
         hBeleg["currency"] := _CurrencyISO(re->Money)
         hBeleg["vat_rate"] := oRechnung:MwstRate
         hBeleg["date_payment_due"] := _IsoDate(re->Rechdat + nWait)
         //Felder mit fuehrendem Unterstrich sind intern und werden vor dem
         //Senden entfernt - siehe _BbbSend.
         hBeleg["_quelle"] := "AR " + LTrim(Str(re->Rechnr))
         //Das Debitorenkonto steht am Kunden. Dieselbe Nummer fuehrt schon
         //Lexware (LX_CreateDebtor schreibt sie als Kontonummer), also bleiben
         //beide Buchhaltungen auf demselben Kontenrahmen - das ist beim
         //Vergleichen der zwei Systeme mehr wert als eine frei vergebene Nummer.
         hBeleg["_konto"] := _KontoStr(_KundenKonto(re->Kunde))
         hBeleg["_kontoname"] := cName
         hBeleg["_matchcode"] := Trim(re->Kunde)
         AAdd(aBelege, hBeleg)
      ENDIF

      re->(dbSkip())
   ENDDO

   re->(dbClearFilter())

   _Log("  ENGLSRE gelesen: " + LTrim(Str(nScanned)))

RETURN aBelege

/**
  * Debitorenkonto zu einem Kunden-Matchcode. 0, wenn der Kunde fehlt.
  **/
STATIC FUNCTION _KundenKonto(cKundma)
   LOCAL nKonto := 0

   ku->(dbSetOrder(1))
   IF ku->(dbSeek(Pad(cKundma, 8) + "K"))
      nKonto := ku->Nummer
   ENDIF

RETURN nKonto

/**
  * Eingangsrechnungen aus ENGRECH.
  *
  * Nur gebuchte Rechnungen (rech->Booked). Eine nur teilweise erfasste
  * Rechnung hat im Kopf noch keinen belastbaren Betrag - die waere als Beleg
  * in der Buchhaltung eine Falschmeldung. Der Liquiditaetsplan rechnet sie
  * aus den erfassten Positionen hoch, hier ist das nicht zulaessig.
  **/
STATIC FUNCTION _CollectInbound(dFrom, nOffen)
   LOCAL aBelege := {}
   LOCAL hNamen := {=>}
   LOCAL hBeleg
   LOCAL nScanned := 0, nOhneKonto := 0
   LOCAL nMwst, nVatRate
   LOCAL dDue
   LOCAL cName

   NetUse("engrech", "rech")
   NetUse("engkund", "ku")

   ku->(dbSetOrder(1))
   rech->(dbSetOrder(0))
   rech->(dbGoTop())

   DO WHILE ! rech->(EOF())
      nScanned++

      IF rech->Booked .AND. rech->Rechdat >= dFrom .AND. rech->GrAmt != 0 .AND. ;
         ! Empty(rech->Liefma) .AND. ! Empty(rech->Rechnr)

         //Ohne Kreditorenkonto laesst sich die Rechnung nicht kontieren.
         //LexwareSync verlangt dasselbe (! Empty(rech->Konto)) und uebergeht
         //sie sonst - hier wird sie gezaehlt und gemeldet, statt lautlos zu
         //fehlen: eine Eingangsrechnung, die in keiner Buchhaltung ankommt,
         //faellt sonst niemandem auf.
         IF Empty(rech->Konto)
            nOhneKonto++
            rech->(dbSkip())
            LOOP
         ENDIF

         //Steuersatz nur, wenn er aus dem Lieferantenstamm eindeutig folgt.
         //Bei Import und innergemeinschaftlichem Erwerb (TaxCode 0) haengt die
         //Behandlung am Vorgang, nicht am Stammsatz - BuchhaltungsButler laesst
         //das Feld ausdruecklich leer, und geraten waere hier schlimmer als
         //offen gelassen: die Buchhaltung sieht die Luecke, einen falschen
         //Satz sieht sie nicht.
         nMwst := 0
         nVatRate := NIL
         cName := _GetSupplierName(rech->Liefma, hNamen)
         IF ku->(dbSeek(rech->Liefma + "L")) .AND. ku->TaxCode != 0
            taxit(ku->TaxCode, @nMwst, rech->Rechdat, .F.)
            nVatRate := nMwst
         ENDIF

         dDue := rech->Rechdat + Max(rech->Wait, rech->WAITSkonto)
         IF Empty(dDue)
            dDue := rech->Rechdat
         ENDIF

         hBeleg := {=>}
         hBeleg["type"] := "invoice inbound"
         hBeleg["counterparty"] := cName
         hBeleg["invoice_number"] := Trim(rech->Rechnr)
         hBeleg["date"] := _IsoDate(rech->Rechdat)
         hBeleg["amount"] := Round(rech->GrAmt, 2)
         hBeleg["currency"] := _CurrencyISO(rech->Money)
         IF nVatRate != NIL
            hBeleg["vat_rate"] := nVatRate
         ENDIF
         hBeleg["date_payment_due"] := _IsoDate(dDue)
         hBeleg["_quelle"] := "ER " + Trim(rech->Liefma) + " " + Trim(rech->Rechnr)
         //Das Kreditorenkonto steht an der Rechnung, nicht am Lieferanten:
         //ein Lieferant kann je Waehrung ein eigenes Konto haben (siehe die
         //fibu-Tabelle in address_edit.prg), und welches gilt, entscheidet die
         //Rechnung. LexwareSync bucht ueber dasselbe Feld.
         hBeleg["_konto"] := _KontoStr(rech->Konto)
         hBeleg["_kontoname"] := cName
         hBeleg["_matchcode"] := Trim(rech->Liefma)
         AAdd(aBelege, hBeleg)

         //Offene Verbindlichkeiten. Payme traegt den Zahllauf; ist es leer,
         //ist die Rechnung noch nicht angewiesen - dieselbe Lesart wie im
         //Liquiditaetssammler.
         IF rech->Payme == 0
            nOffen += Round(rech->GrAmt, 2)
         ENDIF
      ENDIF

      rech->(dbSkip())
   ENDDO

   _Log("  ENGRECH gelesen: " + LTrim(Str(nScanned)) + ;
        ", ohne Kreditorenkonto uebergangen: " + LTrim(Str(nOhneKonto)))

RETURN aBelege

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
RETURN AllTrim(xKonto)

/**
  * Vorhandene Personenkonten der Gegenseite holen, geblaettert.
  *
  * cType ist "debtors" oder "creditors". Der Index bildet Kontonummer ->
  * Name; gebraucht wird nur, OB es das Konto gibt.
  **/
STATIC FUNCTION _BbbFetchAccounts(oRest, cType, hIndex)
   LOCAL hBody, hResponse
   LOCAL nOffset := 0
   LOCAL aData, hRow, cKonto
   LOCAL cResponse, nStatus := 0

   DO WHILE .T.
      hBody := {=>}
      hBody["api_key"] := "$APIKEY$"
      hBody["limit"] := BBB_GET_LIMIT
      hBody["offset"] := nOffset

      cResponse := oRest:Execute("settings/get/" + cType, "POST", hBody, _BbbHeader(), .T., @nStatus)

      IF Empty(cResponse)
         _Log("*** settings/get/" + cType + ": keine Antwort (HTTP " + LTrim(Str(nStatus)) + ")")
         RETURN .F.
      ENDIF

      hResponse := HB_JsonDecode(cResponse)
      IF ValType(hResponse) != "H" .OR. ! HHasKey(hResponse, "success") .OR. ! hResponse["success"]
         _Log("*** settings/get/" + cType + " fehlgeschlagen (HTTP " + LTrim(Str(nStatus)) + "): " + Left(cResponse, 300))
         RETURN .F.
      ENDIF

      aData := IF(HHasKey(hResponse, "data"), hResponse["data"], {})
      IF ValType(aData) != "A"
         aData := {}
      ENDIF

      FOR EACH hRow IN aData
         IF ValType(hRow) != "H"
            LOOP
         ENDIF
         cKonto := _RowStr(hRow, "postingaccount_number")
         IF ! Empty(cKonto)
            hIndex[cKonto] := _RowStr(hRow, "name")
         ENDIF
      NEXT

      IF Len(aData) < BBB_GET_LIMIT
         EXIT
      ENDIF
      nOffset += BBB_GET_LIMIT
   ENDDO

   _Log("settings/get/" + cType + ": " + LTrim(Str(Len(hIndex))) + " Konten vorhanden")

RETURN .T.

/**
  * Fehlende Personenkonten anlegen.
  *
  * Warum ueberhaupt Personenkonten? Ohne sie bucht BuchhaltungsButler jeden
  * Beleg auf das Sammelkonto. Damit gibt es keine offenen Posten je Kunde
  * oder Lieferant - und genau die sind der Grund, warum die Belege ueberhaupt
  * hinuebergehen.
  *
  * Die Kontonummer kommt aus Trader und wird ausdruecklich mitgegeben. BBB
  * wuerde sonst selbst durchnummerieren, und dann traegt dieselbe Firma in
  * Lexware eine andere Nummer als hier - beim Vergleichen der beiden Systeme
  * waere das die erste Fehlerquelle.
  *
  * Gesendet werden nur Name, Kontonummer und Matchcode. Anschrift, IBAN und
  * Umsatzsteuer-Id laesst die API pruefen und weist den ganzen Stammsatz mit
  * eigenen Fehlercodes zurueck, wenn ihr eine Angabe nicht gefaellt. Ein
  * Konto mit Namen ist fuer die Kontierung ausreichend; die Anschrift kann
  * spaeter nachziehen, wenn die Felder getestet sind.
  **/
STATIC FUNCTION _EnsureAccounts(oRest, aNeu, cType, cReceiptType, hBestand, lLive, nAngelegt, nFehler)
   LOCAL hFehlend := {=>}
   LOCAL hBeleg, cKonto, cName
   LOCAL aListe := {}, aBatches, aBatch
   LOCAL hBody, hResponse, hEintrag, hError
   LOCAL cResponse, nStatus := 0

   FOR EACH hBeleg IN aNeu
      IF hBeleg["type"] != cReceiptType
         LOOP
      ENDIF
      cKonto := hBeleg["_konto"]
      IF Empty(cKonto) .OR. HHasKey(hBestand, cKonto) .OR. HHasKey(hFehlend, cKonto)
         LOOP
      ENDIF
      hFehlend[cKonto] := hBeleg["_kontoname"]
   NEXT

   IF Len(hFehlend) == 0
      RETURN NIL
   ENDIF

   FOR EACH cName IN hFehlend
      hEintrag := {=>}
      hEintrag["postingaccount_number"] := cName:__eNumKey()
      hEintrag["name"] := cName
      AAdd(aListe, hEintrag)
   NEXT

   _Log("Fehlende " + cType + ": " + LTrim(Str(Len(aListe))))

   IF ! lLive
      FOR EACH hEintrag IN aListe
         _Log("  wuerde anlegen: " + PadR(hEintrag["postingaccount_number"], 10) + hEintrag["name"])
         //Fuer die Vorschau als vorhanden fuehren - sonst meldete die
         //Zuordnung gleich darauf lauter Belege ohne Personenkonto, die im
         //Echtlauf sehr wohl eines bekaemen. Eine Vorschau, die etwas anderes
         //zeigt als der Lauf tut, ist schlimmer als gar keine.
         hBestand[hEintrag["postingaccount_number"]] := hEintrag["name"]
      NEXT
      RETURN NIL
   ENDIF

   aBatches := _SplitIntoBatches(aListe, BBB_BATCH_SIZE)

   FOR EACH aBatch IN aBatches
      hBody := {=>}
      hBody["api_key"] := "$APIKEY$"
      hBody[cType] := aBatch

      cResponse := oRest:Execute("settings/add-batch/" + cType, "POST", hBody, _BbbHeader(), .T., @nStatus)

      IF Empty(cResponse)
         _Log("*** settings/add-batch/" + cType + ": keine Antwort (HTTP " + LTrim(Str(nStatus)) + ")")
         nFehler += Len(aBatch)
         LOOP
      ENDIF

      hResponse := HB_JsonDecode(cResponse)
      IF ValType(hResponse) != "H"
         _Log("*** settings/add-batch/" + cType + ": unlesbare Antwort: " + Left(cResponse, 300))
         nFehler += Len(aBatch)
         LOOP
      ENDIF

      IF HHasKey(hResponse, cType) .AND. ValType(hResponse[cType]) == "A"
         FOR EACH hEintrag IN hResponse[cType]
            IF ValType(hEintrag) == "H" .AND. HHasKey(hEintrag, "postingaccount_number")
               hBestand[_RowStr(hEintrag, "postingaccount_number")] := ""
               nAngelegt++
            ENDIF
         NEXT
      ENDIF

      IF HHasKey(hResponse, "errors") .AND. ValType(hResponse["errors"]) == "A"
         FOR EACH hError IN hResponse["errors"]
            nFehler++
            _Log("*** " + cType + " abgelehnt: " + ;
                 IF(ValType(hError) == "H" .AND. HHasKey(hError, "message"), hError["message"], HB_JsonEncode(hError)))
         NEXT
      ENDIF
   NEXT

RETURN NIL

/**
  * creditor_debtor an die Belege haengen, deren Konto es jetzt gibt.
  *
  * Fehlt das Konto, geht der Beleg trotzdem raus - ohne Kontobezug landet er
  * auf dem Sammelkonto. Das ist keine schoene, aber eine sichtbare Loesung:
  * die Buchhaltung findet den Beleg und kann ihn umkontieren. Ihn deswegen
  * zurueckzuhalten hiesse, ihn verschwinden zu lassen.
  **/
STATIC FUNCTION _AssignAccounts(aNeu, hDebitoren, hKreditoren)
   LOCAL hBeleg, hBestand, cKonto
   LOCAL nMit := 0, nOhne := 0

   FOR EACH hBeleg IN aNeu
      hBestand := IF(hBeleg["type"] == "invoice outbound", hDebitoren, hKreditoren)
      cKonto := hBeleg["_konto"]

      IF ! Empty(cKonto) .AND. HHasKey(hBestand, cKonto)
         hBeleg["creditor_debtor"] := Val(cKonto)
         nMit++
      ELSE
         nOhne++
         IF nOhne <= 50
            _Log("  ohne Personenkonto: " + hBeleg["_quelle"] + " (" + hBeleg["counterparty"] + ")")
         ELSEIF nOhne == 51
            _Log("  ... weitere werden nicht einzeln aufgefuehrt")
         ENDIF
      ENDIF
   NEXT

   _Log("Belege mit Personenkonto: " + LTrim(Str(nMit)) + ", ohne: " + LTrim(Str(nOhne)))

RETURN NIL

/**
  * Kontrollrechnung ueber die Betraege.
  *
  * Das ist der Rueckkanal, um den es bei der ganzen Uebung geht: nicht "wie
  * viele Belege", sondern "stimmt die Summe". Eine Stueckzahl verdeckt den
  * einen fehlenden Beleg ueber 40.000 Euro zwischen dreihundert kleinen.
  *
  * Und er kostet keinen einzigen zusaetzlichen Aufruf - beide Seiten liegen
  * nach dem Abgleich ohnehin im Speicher.
  *
  * Die Rechnung geht so:
  *
  *   Trader                    was ab dem Stichtag da ist
  * - BuchhaltungsButler        was dort schon liegt
  * = Luecke
  *   davon wird gesendet       Summe der fehlenden Belege
  *   davon bleibt offen        Klaerungsfaelle und alles Uebrige
  *
  * Bleibt nach dem Senden eine Differenz, hat das genau drei moegliche
  * Gruende, und alle drei gehoeren gesehen: ein Klaerungsfall, ein Beleg in
  * BuchhaltungsButler, den Trader nicht kennt (von Hand erfasst, aus einer
  * anderen Quelle, doppelt), oder ein Betrag, der auf einer Seite anders
  * steht. Nichts davon faellt bei einer Stueckzahlkontrolle auf.
  **/
STATIC FUNCTION _Kontrollrechnung(aAus, aEin, hBestandAus, hBestandEin, aNeu, aKlaerung)
   LOCAL nTraderAus := _SummeBelege(aAus)
   LOCAL nTraderEin := _SummeBelege(aEin)
   LOCAL nBbbAus := _SummeBestand(hBestandAus)
   LOCAL nBbbEin := _SummeBestand(hBestandEin)
   LOCAL nNeuAus := _SummeTyp(aNeu, "invoice outbound")
   LOCAL nNeuEin := _SummeTyp(aNeu, "invoice inbound")
   LOCAL nKlaerAus := _SummeTyp(aKlaerung, "invoice outbound")
   LOCAL nKlaerEin := _SummeTyp(aKlaerung, "invoice inbound")

   _Log("KONTROLLRECHNUNG (Betraege, nicht Stueck)")
   _Log("                          Ausgangsbelege   Eingangsbelege")
   _Log("  Trader gesamt        " + _Geld(nTraderAus) + _Geld(nTraderEin))
   _Log("  BuchhaltungsButler   " + _Geld(nBbbAus) + _Geld(nBbbEin))
   _Log("  Luecke               " + _Geld(nTraderAus - nBbbAus) + _Geld(nTraderEin - nBbbEin))
   _Log("  davon wird gesendet  " + _Geld(nNeuAus) + _Geld(nNeuEin))
   _Log("  davon zur Klaerung   " + _Geld(nKlaerAus) + _Geld(nKlaerEin))
   _Log("  bleibt danach offen  " + ;
        _Geld(nTraderAus - nBbbAus - nNeuAus) + _Geld(nTraderEin - nBbbEin - nNeuEin))
   _Log("")
   _Log("  Ein Rest ungleich null heisst: Klaerungsfall, ein Beleg in")
   _Log("  BuchhaltungsButler ohne Gegenstueck in Trader, oder ein Betrag,")
   _Log("  der auf einer Seite anders steht. Alle drei gehoeren angesehen.")
   _Log("")

RETURN NIL

STATIC FUNCTION _SummeBelege(aBelege)
   LOCAL nSumme := 0
   LOCAL hBeleg

   FOR EACH hBeleg IN aBelege
      nSumme += hBeleg["amount"]
   NEXT

RETURN Round(nSumme, 2)

STATIC FUNCTION _SummeTyp(aBelege, cType)
   LOCAL nSumme := 0
   LOCAL hBeleg

   FOR EACH hBeleg IN aBelege
      IF hBeleg["type"] == cType
         nSumme += hBeleg["amount"]
      ENDIF
   NEXT

RETURN Round(nSumme, 2)

STATIC FUNCTION _SummeBestand(hBestand)
   LOCAL nSumme := 0
   LOCAL aTreffer, hVorhanden

   FOR EACH aTreffer IN hBestand
      FOR EACH hVorhanden IN aTreffer
         nSumme += hVorhanden["betrag"]
      NEXT
   NEXT

RETURN Round(nSumme, 2)

STATIC FUNCTION _Geld(nBetrag)
RETURN PadL(LTrim(Str(nBetrag, 16, 2)), 17)

/**
  * Summen- und Saldenliste holen und gegen die offenen Posten aus Trader
  * halten.
  *
  * WANN DAS TRAEGT - bitte lesen, bevor jemand die Zahlen ernst nimmt:
  *
  * Ein Beleg ist noch keine Buchung. Solange dieser Abgleich nur Belege
  * liefert und in BuchhaltungsButler niemand bucht, stehen die Personenkonten
  * auf null, und die Liste zeigt eine Differenz in voller Hoehe der offenen
  * Posten. Das ist dann kein Fehler, sondern der Normalzustand.
  *
  * Aussagekraeftig wird die Gegenueberstellung erst, wenn die Belege drueben
  * auch verbucht sind. Bis dahin ist die Kontrollrechnung ueber die
  * Belegbetraege (siehe _Kontrollrechnung) der belastbare Wert.
  *
  * Zwei Nebenwirkungen, deshalb nur auf ausdrueckliche Anforderung:
  * der Bericht wird asynchron erzeugt und muss abgewartet werden, und ein
  * neuer Bericht ERSETZT den zuletzt erzeugten - wer in BuchhaltungsButler
  * gerade selbst einen gezogen hat, verlore ihn.
  **/
STATIC FUNCTION _BbbSumsReport(oRest, dFrom, hDebitoren, hKreditoren, nOffenDeb, nOffenKred)
   LOCAL hBody, hResponse, hReport
   LOCAL cResponse, nStatus := 0
   LOCAL cReportId
   LOCAL nTry
   LOCAL nSaldoDeb, nSaldoKred

   _Log("SUMMEN- UND SALDENLISTE")

   hBody := {=>}
   hBody["api_key"] := "$APIKEY$"
   hBody["date_from"] := _IsoDate(dFrom)
   hBody["date_to"] := _IsoDate(Date())
   hBody["base"] := "date"

   cResponse := oRest:Execute("reports/create/sums", "POST", hBody, _BbbHeader(), .T., @nStatus)
   hResponse := IF(Empty(cResponse), NIL, HB_JsonDecode(cResponse))

   IF ValType(hResponse) != "H" .OR. ! HHasKey(hResponse, "success") .OR. ! hResponse["success"] .OR. ;
      ! HHasKey(hResponse, "id_by_customer")
      //Haeufigster Fall: es laeuft noch ein Bericht. Kein Grund, den Lauf
      //abzubrechen - die Belege sind wichtiger als die Kennzahl.
      _Log("*** reports/create/sums fehlgeschlagen (HTTP " + LTrim(Str(nStatus)) + "): " + ;
           Left(IF(Empty(cResponse), "keine Antwort", cResponse), 300))
      RETURN NIL
   ENDIF

   cReportId := _RowStr(hResponse, "id_by_customer")
   _Log("  Bericht " + cReportId + " angefordert, wird erzeugt ...")

   hReport := NIL
   FOR nTry := 1 TO 10
      hb_idleSleep(6)

      hBody := {=>}
      hBody["api_key"] := "$APIKEY$"
      hBody["report_id_by_customer"] := Val(cReportId)

      cResponse := oRest:Execute("reports/get/sums", "POST", hBody, _BbbHeader(), .T., @nStatus)
      hResponse := IF(Empty(cResponse), NIL, HB_JsonDecode(cResponse))

      IF ValType(hResponse) == "H" .AND. HHasKey(hResponse, "success") .AND. hResponse["success"] .AND. ;
         HHasKey(hResponse, "report") .AND. ValType(hResponse["report"]) == "H"
         hReport := hResponse["report"]
         EXIT
      ENDIF
   NEXT

   IF hReport == NIL
      _Log("*** Bericht nach 60 Sekunden nicht abrufbar - uebersprungen")
      RETURN NIL
   ENDIF

   IF HHasKey(hReport, "integrityError") .AND. ! Empty(hReport["integrityError"])
      _Log("*** BuchhaltungsButler meldet integrityError: " + HB_JsonEncode(hReport["integrityError"]))
   ENDIF

   //Debitoren stehen natuerlicherweise im Soll, Kreditoren im Haben. Damit
   //eine Summe entsteht, die sich mit den offenen Posten vergleichen laesst,
   //zaehlt die jeweils natuerliche Seite positiv.
   nSaldoDeb := _SaldoSumme(hReport, hDebitoren, .T.)
   nSaldoKred := _SaldoSumme(hReport, hKreditoren, .F.)

   _Log("                          Debitoren        Kreditoren")
   _Log("  Trader offene Posten " + _Geld(nOffenDeb) + _Geld(nOffenKred))
   _Log("  BuchhaltungsButler   " + _Geld(nSaldoDeb) + _Geld(nSaldoKred))
   _Log("  Differenz            " + _Geld(nOffenDeb - nSaldoDeb) + _Geld(nOffenKred - nSaldoKred))
   _Log("")
   _Log("  ACHTUNG: ein Beleg ist noch keine Buchung. Solange drueben niemand")
   _Log("  bucht, stehen die Personenkonten auf null und die Differenz ist so")
   _Log("  gross wie die offenen Posten - das ist dann kein Fehler.")

RETURN NIL

/**
  * Salden der uebergebenen Personenkonten aufaddieren.
  *
  * lSollNatuerlich sagt, welche Seite positiv zaehlt. Wie die Gegenseite die
  * Seite benennt, ist nicht dokumentiert - die Feldnamen sprechen von Debit
  * und Credit, deutsche Systeme schreiben gern "S" und "H". Beides wird
  * akzeptiert, statt sich auf eine Schreibweise zu verlassen, die erst im
  * Echtbetrieb auffiele.
  **/
STATIC FUNCTION _SaldoSumme(hReport, hKonten, lSollNatuerlich)
   LOCAL hSums
   LOCAL nSumme := 0
   LOCAL hEintrag, cKonto, cSeite
   LOCAL nBetrag
   LOCAL lSoll

   IF ! HHasKey(hReport, "sums") .OR. ValType(hReport["sums"]) != "H"
      RETURN 0
   ENDIF
   hSums := hReport["sums"]

   FOR EACH hEintrag IN hSums
      cKonto := hEintrag:__eNumKey()
      IF ! HHasKey(hKonten, cKonto) .OR. ValType(hEintrag) != "H"
         LOOP
      ENDIF
      nBetrag := Val(_RowStr(hEintrag, "balanceAfterAbsolute"))
      cSeite := Upper(Left(_RowStr(hEintrag, "balanceAfterSide"), 1))
      lSoll := (cSeite == "D" .OR. cSeite == "S")
      nSumme += IF(lSoll == lSollNatuerlich, nBetrag, -nBetrag)
   NEXT

RETURN Round(nSumme, 2)

/**
  * Fehlende Belege senden, in Stapeln zu hoechstens BBB_BATCH_SIZE.
  *
  * addBatch meldet Erfolg und Fehler getrennt zurueck. Ein fehlerhafter
  * Beleg bricht den Stapel nicht ab - er kommt mit seiner Meldung ins
  * Protokoll, damit beim naechsten Lauf klar ist, woran es lag.
  **/
STATIC FUNCTION _BbbSend(oRest, aNeu, nGesendet, nFehler)
   LOCAL aBatches := _SplitIntoBatches(aNeu, BBB_BATCH_SIZE)
   LOCAL aBatch, hBeleg, hSenden, xWert
   LOCAL hBody, hResponse
   LOCAL cResponse, nStatus := 0
   LOCAL nBatch := 0
   LOCAL aReceipts
   LOCAL hError

   FOR EACH aBatch IN aBatches
      nBatch++

      aReceipts := {}
      FOR EACH hBeleg IN aBatch
         //Alles mit fuehrendem Unterstrich ist intern und gehoert nicht in
         //den Rumpf. Ueber das Praefix statt ueber eine Liste, damit ein
         //spaeter ergaenztes Feld nicht versehentlich mitgesendet wird.
         hSenden := {=>}
         FOR EACH xWert IN hBeleg
            IF Left(xWert:__eNumKey(), 1) != "_"
               hSenden[xWert:__eNumKey()] := xWert
            ENDIF
         NEXT
         AAdd(aReceipts, hSenden)
      NEXT

      hBody := {=>}
      hBody["api_key"] := "$APIKEY$"
      hBody["receipts"] := aReceipts

      _Log("Sende Stapel " + LTrim(Str(nBatch)) + " von " + LTrim(Str(Len(aBatches))) + ;
           " (" + LTrim(Str(Len(aReceipts))) + " Belege)")

      cResponse := oRest:Execute("receipts/addBatch", "POST", hBody, _BbbHeader(), .T., @nStatus)

      IF Empty(cResponse)
         _Log("*** Stapel " + LTrim(Str(nBatch)) + ": keine Antwort (HTTP " + LTrim(Str(nStatus)) + ")")
         nFehler += Len(aReceipts)
         LOOP
      ENDIF

      hResponse := HB_JsonDecode(cResponse)
      IF ValType(hResponse) != "H"
         _Log("*** Stapel " + LTrim(Str(nBatch)) + ": unlesbare Antwort: " + Left(cResponse, 300))
         nFehler += Len(aReceipts)
         LOOP
      ENDIF

      IF HHasKey(hResponse, "receipts") .AND. ValType(hResponse["receipts"]) == "A"
         nGesendet += Len(hResponse["receipts"])
      ENDIF

      IF HHasKey(hResponse, "errors") .AND. ValType(hResponse["errors"]) == "A"
         FOR EACH hError IN hResponse["errors"]
            nFehler++
            _Log("*** abgelehnt: " + IF(ValType(hError) == "H" .AND. HHasKey(hError, "message"), ;
                 hError["message"], HB_JsonEncode(hError)))
         NEXT
      ENDIF
   NEXT

RETURN NIL

STATIC FUNCTION _LogVorschau(aNeu)
   LOCAL hBeleg
   LOCAL nZeile := 0

   _Log("Trockenlauf - diese Belege wuerden angelegt:")
   FOR EACH hBeleg IN aNeu
      nZeile++
      IF nZeile > 200
         _Log("  ... und " + LTrim(Str(Len(aNeu) - 200)) + " weitere")
         EXIT
      ENDIF
      _Log("  " + PadR(hBeleg["_quelle"], 28) + PadR(hBeleg["date"], 12) + ;
           PadL(LTrim(Str(hBeleg["amount"], 14, 2)), 14) + " " + hBeleg["currency"] + "  " + ;
           PadR(Left(hBeleg["counterparty"], 30), 32) + ;
           "Konto " + IF(Empty(hBeleg["_konto"]), "-", hBeleg["_konto"]))
   NEXT

RETURN NIL

STATIC FUNCTION _LogKlaerung(aKlaerung)
   LOCAL hBeleg, hVorhanden
   LOCAL cBetraege

   IF Len(aKlaerung) == 0
      RETURN NIL
   ENDIF

   _Log("ZUR KLAERUNG - Belegnummer vorhanden, Betrag weicht ab. Nicht gesendet:")
   FOR EACH hBeleg IN aKlaerung
      cBetraege := ""
      FOR EACH hVorhanden IN hBeleg["_bbb_betraege"]
         cBetraege += IF(Empty(cBetraege), "", ", ") + LTrim(Str(hVorhanden["betrag"], 14, 2)) + ;
                      " (" + Left(hVorhanden["gegenpartei"], 20) + ")"
      NEXT
      _Log("  " + PadR(hBeleg["_quelle"], 28) + "Trader: " + LTrim(Str(hBeleg["amount"], 14, 2)) + ;
           "  BuchhaltungsButler: " + cBetraege)
   NEXT
   _Log("")

RETURN NIL

STATIC FUNCTION _Log(cText)
   ? cText
   IF snProtokoll > 0
      FWrite(snProtokoll, cText + CRLF)
   ENDIF
   IF Left(cText, 3) == "***"
      scFehlerText += cText + CRLF
   ENDIF

RETURN NIL

STATIC FUNCTION _Finish(cProtokoll)
   LOCAL cMail

   IF snProtokoll > 0
      FClose(snProtokoll)
      snProtokoll := 0
   ENDIF

   IF ! GetConfigValue("BATCHMODE")
      WAPI_ShellExecute(NIL, "open", cProtokoll, "", "")
      Sinkey(0)
   ENDIF

   //GetConfigValue wirft bei einem unbekannten Schluessel - die Adresse steht
   //deshalb im allgemeinen Wertespeicher, nicht in der Konfiguration.
   cMail := GetValue("BBB_ERRORMAIL", "")
   IF ! Empty(scFehlerText) .AND. ValType(cMail) == "C" .AND. ! Empty(cMail)
      SendMail({{Trim(cMail), ""}}, "Fehler beim BuchhaltungsButler-Abgleich", scFehlerText)
   ENDIF

RETURN NIL

STATIC FUNCTION _GetCustomerName(cKundma, hNamen)
   LOCAL cName

   IF HHasKey(hNamen, cKundma)
      RETURN hNamen[cKundma]
   ENDIF

   cName := Trim(cKundma)
   ku->(dbSetOrder(1))
   IF ku->(dbSeek(Pad(cKundma, 8) + "K"))
      cName := IF(! Empty(Trim(ku->Name1)), Trim(ku->Name1), Trim(ku->Kunde))
   ENDIF
   hNamen[cKundma] := hb_StrToUTF8(cName)

RETURN hNamen[cKundma]

STATIC FUNCTION _GetSupplierName(cLiefma, hNamen)
   LOCAL cName

   IF HHasKey(hNamen, cLiefma)
      RETURN hNamen[cLiefma]
   ENDIF

   cName := Trim(cLiefma)
   ku->(dbSetOrder(1))
   IF ku->(dbSeek(cLiefma + "L"))
      cName := IF(! Empty(Trim(ku->Name1)), Trim(ku->Name1), Trim(ku->Kunde))
   ENDIF
   hNamen[cLiefma] := hb_StrToUTF8(cName)

RETURN hNamen[cLiefma]

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
