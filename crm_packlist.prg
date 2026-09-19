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
 *   NEXUSCRM_LABELS_PRINTCMD (optional) eigener Druckbefehl; {file} und
 *                            {printer} werden ersetzt. Gesetzt, gilt nur er.
 *
 * Gedruckt wird ueber Ghostscript, das hier ohnehin an mehreren Stellen laeuft
 * (invoice_beleg, david, auto_beleg). Der Weg ueber die Windows-Druckverben
 * "print"/"printto" waere kuerzer, haengt aber daran, dass ein PDF-Programm sie
 * anmeldet: Adobe Reader tut das, Edge - auf neueren Windows der Standard fuer
 * PDF - nicht. Dann passiert schlicht nichts, ohne Fehler und ohne Papier.
 * Ghostscript druckt selbst und braucht kein registriertes Programm.
 *
 * Reihenfolge: eigener Befehl aus der Konfiguration, sonst Ghostscript, sonst
 * das Druckverb als letzter Versuch. Klappt keines davon, sagt das Script es -
 * ein stiller Fehlschlag waere hier das Schlimmste, weil danach die Frage nach
 * dem gelungenen Druck kommt.
 *
 * Wirkung im CRM: engelking-crm/docs/deutsche-post-versand.md
 */

//#include 'trader.ch'

PROCEDURE RUN_CRM_PACKLIST(cMode, xArg)
   LOCAL cUpper := Upper(CPL_Str(cMode))
   CRM_PackList_Setup()
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
           If(nStatus == -1, "CRM antwortet unverst„ndlich", ;
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
   LOCAL cActionId, cBase64, nAnswer, lPrinted

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

   lPrinted := CPL_Print(cFile)

   // Gefragt wird nach dem Druck, nicht davor: Was nicht auf Papier ist, ist
   // nicht versendet. Bei "Nein" bleibt die Zeile stehen und kann erneut.
   // Ist schon der Druckauftrag gescheitert, steht das in der Frage - sonst
   // bestaetigt jemand einen Druck, den es nie gab.
   nAnswer := Tr_MsgBox(If(lPrinted, "Etikett gedruckt und Sendung fertig?", ;
                           "Druck konnte nicht ausgeloest werden. Trotzdem als versendet melden?"), ;
                        , {"Nein", "Versendet"})
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
 * Etikett auf Papier bringen.
 *
 * Drei Wege, in dieser Reihenfolge:
 *
 *   1. Eigener Befehl aus der Konfiguration (NEXUSCRM_LABELS_PRINTCMD).
 *   2. Ghostscript auf den eingestellten Drucker - der verlaessliche Weg,
 *      weil er kein registriertes PDF-Programm braucht.
 *   3. Das Windows-Druckverb als letzter Versuch.
 *
 * Rueckgabe .F., wenn keiner gegriffen hat. Das muss der Aufrufer wissen:
 * Gleich danach wird gefragt, ob der Druck gelungen ist, und diese Frage waere
 * sinnlos, wenn nie ein Druckauftrag entstanden ist.
 */
STATIC FUNCTION CPL_Print(cFile)
   LOCAL cPrinter := AllTrim(CPL_Str(GetValue("NEXUSCRM_LABELS_PRINTER")))
   LOCAL cCmd     := AllTrim(CPL_Str(GetValue("NEXUSCRM_LABELS_PRINTCMD")))
   LOCAL cGS

#ifndef __XHARBOUR__
   #xtranslate ShellExecute([<x,...>])        => Wapi_ShellExecute(<x>)
#endif

   // 1. Eigener Befehl: Wer einen Etikettendrucker mit eigenem Werkzeug
   //    ansteuert, kommt hier durch, ohne dass das Script davon wissen muss.
   IF ! Empty(cCmd)
      cCmd := StrTran(cCmd, "{file}", '"' + cFile + '"')
      cCmd := StrTran(cCmd, "{printer}", cPrinter)
      RETURN HB_ProcessRun(cCmd) == 0
   ENDIF

   // 2. Ghostscript: druckt selbst auf den Windows-Druckertreiber. Ohne
   //    Druckernamen zeigte mswinpr2 einen Auswahldialog - am Packplatz waere
   //    das ein Klick zu viel, deshalb nur mit eingestelltem Drucker.
   cGS := CPL_Ghostscript()
   IF ! Empty(cGS) .AND. ! Empty(cPrinter)
      cCmd := '"' + cGS + '"' + ;
              ' -dPrinted -dBATCH -dNOPAUSE -dNOSAFER -dNoCancel -q' + ;
              ' -sDEVICE=mswinpr2 -sOutputFile="%printer%' + cPrinter + '"' + ;
              ' "' + cFile + '"'
      IF HB_ProcessRun(cCmd) == 0
         RETURN .T.
      ENDIF
   ENDIF

   // 3. Druckverb: kurz, aber es haengt daran, dass ein PDF-Programm es
   //    anmeldet. Edge tut das nicht.
   IF Empty(cPrinter)
      ShellExecute(NIL, "print", cFile, "", "", 0)
   ELSE
      ShellExecute(NIL, "printto", cFile, '"' + cPrinter + '"', "", 0)
   ENDIF

   IF Empty(cGS)
      Tr_MsgBox("Ghostscript nicht gefunden - es wurde das Windows-Druckverb " + ;
                "versucht. Bleibt der Drucker still, bitte NEXUSCRM_LABELS_PRINTCMD setzen.")
   ELSEIF Empty(cPrinter)
      Tr_MsgBox("Kein Drucker eingestellt - es wurde der Standarddrucker ueber das " + ;
                "Windows-Druckverb versucht (NEXUSCRM_LABELS_PRINTER).")
   ENDIF
RETURN .F.


/*
 * Ghostscript finden.
 *
 * Dieselben Orte, die auch david.prg und invoice_beleg.prg absuchen - der Pfad
 * traegt die Versionsnummer, und die ist je Server eine andere. Gefunden wird
 * hier, damit eine neue Ghostscript-Version an einer Stelle nachgetragen wird
 * und nicht in jedem Script einzeln.
 */
STATIC FUNCTION CPL_Ghostscript()
   LOCAL aCandidates := { ;
      "C:\Program Files\gs\gs10.08.0\bin\gswin64c.exe", ;
    }
   LOCAL cExtra := AllTrim(CPL_Str(GetValue("GHOSTSCRIPT_EXE")))
   LOCAL nX

   IF ! Empty(cExtra) .AND. File(cExtra)
      RETURN cExtra
   ENDIF
   FOR nX := 1 TO Len(aCandidates)
      IF File(aCandidates[nX])
         RETURN aCandidates[nX]
      ENDIF
   NEXT
RETURN ""


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
   //GetValue("NEXUSCRM", "", "API Key fuer NexusCRM (Bearer Token)")
   GetValue("NEXUSCRM_LABELS_URL", ;
      "https://rxaltcsbhcxlczjjczxs.supabase.co/functions/v1/api-labels", ;
      "Basis der Etiketten-Schnittstelle im NexusCRM (ohne /open)")
   GetValue("NEXUSCRM_LABELS_PRINTER", "", ;
      "Drucker fuer die Frankier-Etiketten (leer = Standarddrucker)")
   GetValue("NEXUSCRM_LABELS_PRINTCMD", "", ;
      "Eigener Druckbefehl, {file} und {printer} werden ersetzt (leer = Ghostscript)")
RETURN NIL


// --- Kleinkram -----------------------------------------------------------

STATIC FUNCTION CPL_BaseUrl()
   LOCAL cUrl := AllTrim(CPL_Str(GetValue("NEXUSCRM_LABELS_URL","https://rxaltcsbhcxlczjjczxs.supabase.co/functions/v1/api-labels", ;
      "Basis der Etiketten-Schnittstelle im NexusCRM (ohne /open)")))
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
