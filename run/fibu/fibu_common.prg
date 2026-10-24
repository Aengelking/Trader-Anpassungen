/**
  * fibu_common - gemeinsame Helfer der vorbereitenden Buchhaltung
  *
  * Wird von belege_push.prg und reb_push.prg unten eingebunden. Kein eigener
  * Einstiegspunkt: hb_hrbRun startet die erste oeffentliche Funktion der
  * einbindenden Datei, und hier ist alles STATIC.
  *
  * Warum gemeinsam und nicht je Sammler kopiert: _Quelle bildet den halben
  * Eindeutigkeitsschluessel, unter dem Finova eintraegt. Zweimal gepflegt
  * liefe er irgendwann auseinander, und dann ueberschriebe der eine Sammler
  * die Belege des anderen - ohne Fehler, ohne Meldung.
  *
  * DIE EINBINDENDE DATEI MUSS OBEN DEKLARIEREN:
  *
  *   STATIC snProtokoll := 0      //_Log/_Finish, aber auch der Aufrufer
  *   STATIC shWaehrungen := {=>}  //Zwischenspeicher von _CurrencyISO
  *
  * Am Dateianfang, nicht hier unten: ein STATIC nach ausfuehrbarem Code gibt
  * E0004, und weiter oben ist es ohnehin dateiweit sichtbar.
  **/

#define CRLF Chr(13)+Chr(10)

//Belege je Aufruf. erp-push schreibt sie in Bloecken zu 500; 100 je Anfrage
//haelt den Rumpf klein genug fuer eine Zeitueberschreitung.
#define PUSH_BATCH 100

#define FIBU_DEFAULT_YEAR 2026

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
