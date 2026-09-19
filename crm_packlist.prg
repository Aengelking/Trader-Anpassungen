/*
 * crm_packlist.prg  -  Frankier-Etiketten aus dem NexusCRM in der
 * Packzettel-Liste anbieten, drucken und den Versand zurueckmelden.
 * -----------------------------------------------------------------------
 * Das CRM kauft fuer seine Kampagnen-Stufen die Frankierung bei der Deutschen
 * Post (Internetmarke) und haelt das Etikett als PDF bereit. Gepackt und
 * gedruckt wird aber im Lager - und dort arbeitet niemand im CRM, sondern in
 * der Packzettel-Liste des Traders (tr_148, AListRech).
 *
 * Diese Sendungen sind kein Trader-Vorgang: keine Rechnung, keine Entnahme,
 * kein Lagerbezug. Sie stellen sich deshalb ueber den Hook `packlist_rows` in
 * dieselbe Liste, und beim Auswaehlen ruft `pack_extern` den Druck auf.
 *
 * Ablauf beim Packen:
 *   1. Etikett beim CRM holen (PDF, base64)
 *   2. In eine Datei schreiben und an den eingestellten Drucker schicken
 *   3. Nachfragen, ob der Druck brauchbar war
 *   4. Erst dann Versand melden - danach verschwindet die Zeile aus der Liste
 *
 * Die Reihenfolge ist Absicht. Ein Etikett, das nicht gedruckt hat, ist nicht
 * versendet; wer zuerst meldet und dann druckt, hat bei einem Papierstau eine
 * Sendung, die im CRM als raus gilt und im Lager liegt.
 *
 * Aufruf (ueber die Hooks, siehe trader-hooks/packlist_rows.prg und
 * trader-hooks/pack_extern.prg):
 *   MBaseRun(Path("run\crm_packlist"),{"ROWS",aRecs})
 *   MBaseRun(Path("run\crm_packlist"),{"PACK",hRow})
 *
 * Config (GetValue, siehe CRM_PackList_Setup):
 *   NEXUSCRM             Keychain-Eintrag mit dem Bearer Token (TRADER_API_KEY)
 *   NEXUSCRM_LABELS_URL  Basis der Etiketten-Schnittstelle (ohne /open)
 *   NEXUSCRM_LABELS_PRINTER  Drucker fuer die Etiketten. Leer = Standarddrucker
 *
 * Gedruckt wird ueber das Windows-Druckverb: mit Druckernamen "printto", ohne
 * "print". Beides setzt voraus, dass ein PDF-Betrachter fuer diese Verben
 * registriert ist (Adobe Reader, SumatraPDF) - ein eigener Druckfilter waere
 * ein zweiter Ort, an dem Papierformate falsch sein koennen.
 *
 * Wirkung im CRM: engelking-crm/docs/deutsche-post-versand.md
 */

#include 'trader.ch'

PROCEDURE RUN_CRM_PACKLIST(cMode, xArg)
   LOCAL cUpper := Upper(CPL_Str(cMode))

   DO CASE
   CASE cUpper == "ROWS"
      CPL_Rows(xArg)
   CASE cUpper == "PACK"
      CPL_Pack(xArg)
   OTHERWISE
      Tr_MsgBox("crm_packlist: unbekannter Modus " + cUpper)
   ENDCASE
RETURN


/*
 * Offene Etiketten holen und als Zeilen anhaengen.
 *
 * Laeuft bei jedem Neuaufbau der Liste, also alle paar Sekunden. Ein Fehler
 * darf die Liste deshalb nicht stoeren: Antwortet das CRM nicht, bleibt die
 * Packzettel-Liste eben ohne Etiketten - mit einem Hinweis in der Zeile, damit
 * niemand denkt, es gaebe gerade nichts zu packen.
 */
STATIC FUNCTION CPL_Rows(aRecs)
   LOCAL cUrl := CPL_BaseUrl()
   LOCAL hAnswer, aLabels, hItem, nX, hRow, nStatus := 0
   LOCAL cText, hRec

   IF ValType(aRecs) != "A" .OR. Empty(cUrl)
      RETURN .F.
   ENDIF

   hAnswer := CPL_Call(cUrl + "/open", {=>}, @nStatus)
   IF ValType(hAnswer) != "H"
      // Eine stille Liste waere die schlechtere Antwort: Sie saehe aus, als
      // gaebe es nichts zu packen.
      AAdd(aRecs, CPL_Row(0, ;
           If(nStatus == -1, "CRM antwortet unverstaendlich", ;
              "CRM nicht erreichbar (HTTP " + LTrim(Str(nStatus)) + ")"), .F., NIL))
      RETURN .F.
   ENDIF

   aLabels := CPL_HDef(hAnswer, "labels", {})
   IF ValType(aLabels) != "A"
      RETURN .F.
   ENDIF

   FOR nX := 1 TO Len(aLabels)
      hItem := aLabels[nX]
      IF ValType(hItem) != "H"
         LOOP
      ENDIF
      hRec := CPL_HDef(hItem, "recipient", {=>})

      // Eine Zeile, die sich in einer Zeile lesen laesst: Kampagne, an wen,
      // wohin. Die Sendungsnummer steht hinten - sie wird gebraucht, wenn
      // jemand spaeter nachfragt, nicht beim Packen.
      cText := "Etikett  "
      cText += Pad(hb_utf8ToStr(CPL_Str(CPL_HDef(hItem, "campaign", ""))), 18) + " "
      cText += Pad(hb_utf8ToStr(CPL_Str(CPL_HDef(hRec, "company", ""))), 24) + " "
      cText += Pad(hb_utf8ToStr(CPL_Str(CPL_HDef(hRec, "name", ""))), 20) + " "
      cText += Pad(hb_utf8ToStr(CPL_Str(CPL_HDef(hRec, "postal_code", ""))) + " " + ;
                   hb_utf8ToStr(CPL_Str(CPL_HDef(hRec, "city", ""))), 22)
      IF ! CPL_IsTrue(CPL_HDef(hItem, "has_label", .F.))
         cText += " OHNE PDF"
      ENDIF

      hRow := CPL_Row(nX, cText, CPL_IsTrue(CPL_HDef(hItem, "has_label", .F.)), hItem)
      hRow["date"] := CPL_Date(CPL_Str(CPL_HDef(hItem, "created_at", "")))
      AAdd(aRecs, hRow)
   NEXT
RETURN .T.


/*
 * Eine Zeile im Format der Packzettel-Liste.
 *
 * "type" darf weder "R" noch "L" sein - daran erkennt tr_148 einen fremden
 * Vorgang. "ready" entscheidet, ob sich die Zeile auswaehlen laesst: ein
 * Etikett ohne PDF gibt es zu sehen, aber nicht zu drucken.
 */
STATIC FUNCTION CPL_Row(nNr, cText, lReady, hItem)
   LOCAL hRow := {=>}
   hRow["type"]    := "P"           // Post
   hRow["nr"]      := nNr
   hRow["text"]    := cText
   hRow["ready"]   := lReady
   hRow["express"] := .F.
   hRow["date"]    := Date()
   hRow["kunde"]   := Space(8)
   hRow["person"]  := 0
   hRow["pos"]     := 0
   hRow["inuse"]   := .F.
   hRow["state"]   := ""
   hRow["pnum"]    := 0
   hRow["firm"]    := 0
   hRow["crm"]     := hItem          // die Antwort des CRM, unveraendert
RETURN hRow


/*
 * Etikett drucken und Versand melden.
 */
STATIC FUNCTION CPL_Pack(hRow)
   LOCAL hItem, cUrl := CPL_BaseUrl()
   LOCAL hLabel, cFile, nStatus := 0, hAnswer
   LOCAL cActionId, cBase64, nAnswer

   IF ValType(hRow) != "H" .OR. ! HB_HHasKey(hRow, "crm")
      RETURN .F.
   ENDIF
   hItem := hRow["crm"]
   IF ValType(hItem) != "H"
      RETURN .F.
   ENDIF
   cActionId := CPL_Str(CPL_HDef(hItem, "action_id", ""))
   IF Empty(cActionId) .OR. Empty(cUrl)
      Tr_MsgBox("Zu dieser Zeile fehlt die Kennung im CRM.")
      RETURN .F.
   ENDIF

   hLabel := CPL_Call(cUrl + "/label", {"action_id" => cActionId}, @nStatus)
   IF ValType(hLabel) != "H" .OR. ! HB_HHasKey(hLabel, "base64")
      Tr_MsgBox("Etikett konnte nicht geholt werden: " + ;
                If(ValType(hLabel) == "H", CPL_Str(CPL_HDef(hLabel, "error", "")), ;
                   "HTTP " + LTrim(Str(nStatus))))
      RETURN .F.
   ENDIF

   cBase64 := CPL_Str(hLabel["base64"])
   cFile   := CPL_TempFile(CPL_Str(CPL_HDef(hLabel, "filename", "Etikett.pdf")))
   IF ! HB_MemoWrit(cFile, HB_Base64Decode(cBase64))
      Tr_MsgBox("Etikett konnte nicht gespeichert werden: " + cFile)
      RETURN .F.
   ENDIF

   CPL_Print(cFile)

   // Gefragt wird nach dem Druck, nicht davor: Was nicht auf Papier ist, ist
   // nicht versendet. Bei "Nein" bleibt die Zeile stehen und kann erneut.
   nAnswer := Tr_MsgBox("Etikett gedruckt und Sendung fertig?", , {"Nein", "Versendet"})
   IF nAnswer != 2
      RETURN .F.
   ENDIF

   hAnswer := CPL_Call(cUrl + "/dispatched", ;
                       {"action_id" => cActionId, "printed_by" => CPL_UserName()}, @nStatus)
   IF ValType(hAnswer) != "H" .OR. ! CPL_IsTrue(CPL_HDef(hAnswer, "ok", .F.))
      // Gedruckt ist gedruckt - nur das CRM weiss es noch nicht. Die Zeile
      // bleibt stehen, der naechste Versuch meldet sie nach.
      Tr_MsgBox("Versand konnte im CRM nicht gemeldet werden (HTTP " + ;
                LTrim(Str(nStatus)) + "). Die Zeile bleibt in der Liste.")
      RETURN .F.
   ENDIF
RETURN .T.


/*
 * Drucken ueber das Windows-Druckverb.
 *
 * Mit eingestelltem Drucker "printto" (der Name wandert als Parameter mit),
 * ohne Angabe "print" auf den Standarddrucker.
 */
STATIC FUNCTION CPL_Print(cFile)
   LOCAL cPrinter := AllTrim(CPL_Str(GetValue("NEXUSCRM_LABELS_PRINTER")))

#ifndef __XHARBOUR__
   #xtranslate ShellExecute([<x,...>])        => Wapi_ShellExecute(<x>)
#endif

   IF Empty(cPrinter)
      ShellExecute(NIL, "print", cFile, "", "", 0)
   ELSE
      ShellExecute(NIL, "printto", cFile, '"' + cPrinter + '"', "", 0)
   ENDIF
RETURN .T.


/*
 * Ein Aufruf an die Etiketten-Schnittstelle des CRM.
 *
 * Gibt die dekodierte Antwort zurueck oder NIL. Der Status wandert nach
 * draussen, damit der Aufrufer zwischen "nichts da" und "nicht erreichbar"
 * unterscheiden kann.
 */
STATIC FUNCTION CPL_Call(cUrl, hBody, nStatus)
   LOCAL oRest   := RestApi():New()
   LOCAL aHeader := {"Authorization: Bearer $APIKEY$", ;
                     "Content-Type: application/json", ;
                     "Accept: application/json"}
   LOCAL cResponse, xAnswer

   oRest:cBaseUrl    := ""
   oRest:cApiKeyName := "NEXUSCRM"
   cResponse := oRest:Execute(cUrl, "POST", hBody, aHeader, .T., @nStatus)

   IF nStatus < 200 .OR. nStatus >= 300 .OR. Empty(cResponse)
      RETURN NIL
   ENDIF
   xAnswer := HB_JsonDecode(cResponse)
   IF ValType(xAnswer) != "H"
      // Erreicht, aber unverstaendlich - etwa die Fehlerseite eines Proxys.
      // Das ist ein anderer Fall als "keine Verbindung" und soll auch anders
      // dastehen, sonst sucht jemand am Netzwerk statt an der Antwort.
      nStatus := -1
      RETURN NIL
   ENDIF
RETURN xAnswer


FUNCTION CRM_PackList_Setup()
   GetValue("NEXUSCRM", "", "API Key fuer NexusCRM (Bearer Token)")
   GetValue("NEXUSCRM_LABELS_URL", ;
      "https://rxaltcsbhcxlczjjczxs.supabase.co/functions/v1/api-labels", ;
      "Basis der Etiketten-Schnittstelle im NexusCRM (ohne /open)")
   GetValue("NEXUSCRM_LABELS_PRINTER", "", ;
      "Drucker fuer die Frankier-Etiketten (leer = Standarddrucker)")
RETURN NIL


// --- Kleinkram -----------------------------------------------------------

STATIC FUNCTION CPL_BaseUrl()
   LOCAL cUrl := AllTrim(CPL_Str(GetValue("NEXUSCRM_LABELS_URL")))
   DO WHILE Right(cUrl, 1) == "/"
      cUrl := Left(cUrl, Len(cUrl) - 1)
   ENDDO
RETURN cUrl

/* Hashwert mit Standardwert (ohne hb_HGetDef, das nicht registriert sein muss). */
STATIC FUNCTION CPL_HDef(hHash, cKey, xDef)
   IF ValType(hHash) == "H" .AND. HB_HHasKey(hHash, cKey) .AND. ValType(hHash[cKey]) != "U"
      RETURN hHash[cKey]
   ENDIF
RETURN xDef

STATIC FUNCTION CPL_Str(xVal)
   DO CASE
   CASE ValType(xVal) == "C" ; RETURN xVal
   CASE ValType(xVal) == "N" ; RETURN AllTrim(Str(xVal))
   CASE ValType(xVal) == "D" ; RETURN DToC(xVal)
   CASE ValType(xVal) == "L" ; RETURN If(xVal, "J", "N")
   ENDCASE
RETURN ""

STATIC FUNCTION CPL_IsTrue(xVal)
   IF ValType(xVal) == "L"
      RETURN xVal
   ENDIF
RETURN Upper(CPL_Str(xVal)) $ "J,JA,Y,YES,TRUE,1"

/*
 * ISO-Datum aus dem CRM ("2026-09-18T07:12:00Z") in ein Trader-Datum.
 *
 * Ueber hb_SToD, nicht ueber CToD: CToD liest im eingestellten Datumsformat,
 * und das ist hier nicht unseres. Ein Datum, das dabei leer herauskommt, faellt
 * niemandem auf - es sortiert die Zeile nur an die falsche Stelle.
 */
STATIC FUNCTION CPL_Date(cIso)
   LOCAL dDate
   IF Len(cIso) >= 10
      dDate := HB_SToD(Left(cIso, 4) + SubStr(cIso, 6, 2) + SubStr(cIso, 9, 2))
      IF ! Empty(dDate)
         RETURN dDate
      ENDIF
   ENDIF
RETURN Date()

STATIC FUNCTION CPL_TempFile(cName)
   LOCAL cDir := AllTrim(CPL_Str(GetEnv("TEMP")))
   IF Empty(cDir)
      cDir := "C:\temp"
   ENDIF
   // Ein fester Name je Etikett: Wer zweimal druckt, fuellt nicht das
   // Temp-Verzeichnis mit Kopien derselben Datei.
   cName := StrTran(StrTran(cName, "/", "-"), "\", "-")
RETURN cDir + "\" + cName

STATIC FUNCTION CPL_UserName()
   LOCAL oUser := SystemUser()
   IF oUser != NIL
      RETURN AllTrim(CPL_Str(oUser:Name))
   ENDIF
RETURN ""
