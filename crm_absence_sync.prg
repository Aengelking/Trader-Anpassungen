/*
 * crm_absence_sync.prg  -  Abwesenheiten aus Timebutler ins NexusCRM spiegeln.
 * -----------------------------------------------------------------------
 * Das CRM kannte keine Abwesenheiten. Zwei Pain Points hingen daran: eine
 * Wiedervorlage, die in den Urlaub des Bearbeiters fiel, war nach der Rueckkehr
 * ueberfaellig (#63), und bei Krankheit sah niemand, was liegen bleibt (#26).
 *
 * Timebutler bleibt die Quelle. Dieser Lauf liest dort die Abwesenheiten des
 * laufenden und der folgenden Jahre - dieselbe API wie timebutler_sync.prg -
 * und schickt sie an die Edge Function `api-absences/sync` des CRM.
 *
 * Timebutler kennt unsere CRM-Benutzer nicht, der Trader schon: die
 * Personalnummer einer Abwesenheit ist die Satznummer im Bearbeiterstamm
 * (buyer), dort steht die E-Mail. Uebertragen werden deshalb E-Mails - das CRM
 * ordnet darueber seinen Benutzer zu und meldet zurueck, welche Adresse es
 * nicht kennt. Wer im CRM keinen Zugang hat (Lager, Fertigung), faellt dort
 * heraus, ohne den Lauf zu stoeren.
 *
 * EIN Aufruf je Lauf, keine Pakete: das CRM ersetzt das gemeldete Zeitfenster
 * vollstaendig (loeschen, dann schreiben, in einer Transaktion). Nur so
 * verschwindet ein gestrichener Urlaub auch dort. Ein zweites Paket wuerde
 * dasselbe Fenster erneut leeren und das erste mitnehmen - deshalb bricht der
 * Lauf ab, wenn mehr Abwesenheiten zusammenkommen als ein Aufruf traegt.
 *
 * Das Fenster beginnt heute: was gestern endete, braucht das CRM nicht. Eine
 * laufende Abwesenheit ragt ins Fenster und geht mit.
 *
 * Vertretung: uebertragen wird sie nur, wenn Timebutler sie als "Approved"
 * fuehrt - eine beantragte, aber nicht genehmigte Vertretung ist keine.
 *
 * Aufruf (Run-Script):
 *   trader:-R&crm_absence_sync                  laufendes + kommendes Jahr
 *   trader:-R&crm_absence_sync&{"J"}            Testlauf, das CRM schreibt nichts
 *
 * Config (GetValue, siehe CRM_AbsenceSync_Setup):
 *   NEXUSCRM              Keychain-Eintrag mit dem Bearer Token (TRADER_API_KEY
 *                         des CRM), eingesetzt fuer $APIKEY$ im Header
 *   TIMEBUTLER            Keychain-Eintrag fuer die Timebutler-API
 *   NEXUSCRM_URL          Adresse der NexusCRM-API (wie in nexuscrm.prg). Der
 *                         Endpunkt api-absences/sync wird daraus abgeleitet -
 *                         dasselbe Projekt, also keine eigene Einstellung.
 *   NEXUSCRM_ABSENCE_AHEAD  Jahre im Voraus (0 = nur laufendes Jahr)
 *
 * Protokoll: X:\run\supabase\logs\crm_absence_sync_<Datum>_<Zeit>.log
 *
 * Wirkung im CRM, Datenmodell und Kategorien je Timebutler-Typ:
 * engelking-crm/docs/abwesenheiten.md
 */

#define CAS_MAXROWS   5000                       // Server-Grenze je Aufruf
#define CAS_LOGDIR    "X:\run\supabase\logs\"


PROCEDURE RUN_CRM_ABSENCE_SYNC(cDryRun)
   LOCAL lDry     := CAS_IsYes(cDryRun)
   LOCAL lBatch   := GetConfigValue("BATCHMODE")
   LOCAL cLogFile := CAS_LogFile()
   LOCAL oAPI, aUsers, aAbsences, aRows
   LOCAL cUrl, nAhead, dFrom, dTo, nYear, nX
   LOCAL aData, hAbsence, hRow
   LOCAL nSkippedNoMail := 0, nSkippedPast := 0, nSkippedType := 0

   CRM_AbsenceSync_Setup()

   cUrl   := CAS_Endpoint("api-absences/sync")
   nAhead := Int(Val(CAS_Str(GetValue("NEXUSCRM_ABSENCE_AHEAD"))))
   IF nAhead < 0 .OR. nAhead > 3
      nAhead := 1
   ENDIF

   IF Empty(cUrl)
      CAS_Log(cLogFile, "ERROR", "NEXUSCRM_URL ist nicht gesetzt oder ohne /functions/v1/.")
      IF ! lBatch
         Tr_MsgBox("NEXUSCRM_URL ist nicht gesetzt oder ohne /functions/v1/.")
      ENDIF
      RETURN
   ENDIF

   NetUse("buyer", "buy")

   dFrom := Date()
   dTo   := StoD(LTrim(Str(Year(Date()) + nAhead)) + "1231")

   CAS_Log(cLogFile, "INFO", "Fenster " + CAS_IsoDate(dFrom) + " bis " + CAS_IsoDate(dTo) + ;
           IF(lDry, " (Testlauf)", ""))

   IF ! lBatch
      Head("NexusCRM - Abwesenheiten abgleichen")
      ? "Timebutler wird gelesen..."
   ENDIF

   oAPI   := TimeButlerAPI():New()
   aUsers := oAPI:Execute("users")
   IF ValType(aUsers) != "A"
      CAS_Log(cLogFile, "ERROR", "Timebutler: Benutzerliste nicht lesbar.")
      IF ! lBatch
         Tr_MsgBox("Timebutler antwortet nicht.")
      ENDIF
      RETURN
   ENDIF

   aAbsences := {}
   FOR nYear := Year(Date()) TO Year(Date()) + nAhead
      aData := oAPI:Execute("absences?year=" + LTrim(Str(nYear)))
      IF ValType(aData) != "A"
         CAS_Log(cLogFile, "ERROR", "Timebutler: Abwesenheiten " + LTrim(Str(nYear)) + ;
                 " nicht lesbar - Lauf abgebrochen, damit kein halbes Jahr das Fenster ersetzt.")
         IF ! lBatch
            Tr_MsgBox("Timebutler antwortet nicht.")
         ENDIF
         RETURN
      ENDIF
      FOR nX := 1 TO Len(aData)
         AAdd(aAbsences, aData[nX])
      NEXT
   NEXT

   CAS_Log(cLogFile, "INFO", "Timebutler meldet " + LTrim(Str(Len(aAbsences))) + " Abwesenheiten.")

   aRows := {}
   FOR EACH hAbsence IN aAbsences
      // Leerzeilen der API (kommen vor) und Saetze ohne Personalnummer
      IF ValType(hAbsence) != "H" .OR. Len(hAbsence) <= 1 .OR. ;
         ! HHasKey(hAbsence, "Employee number") .OR. ;
         ValType(hAbsence["Employee number"]) != "N"
         nSkippedType++
         LOOP
      ENDIF

      // Was vor heute endet, braucht das CRM nicht.
      IF ValType(hAbsence["To"]) != "D" .OR. hAbsence["To"] < dFrom
         nSkippedPast++
         LOOP
      ENDIF
      IF ValType(hAbsence["From"]) != "D" .OR. hAbsence["From"] > dTo
         nSkippedPast++
         LOOP
      ENDIF

      hRow := {=>}
      hRow["email"] := CAS_MailOf(hAbsence["Employee number"])
      IF Empty(hRow["email"])
         nSkippedNoMail++
         LOOP
      ENDIF

      hRow["from"]     := CAS_IsoDate(hAbsence["From"])
      hRow["to"]       := CAS_IsoDate(hAbsence["To"])
      hRow["type"]     := CAS_Str(CAS_HDef(hAbsence, "Type", ""))
      hRow["half_day"] := CAS_HDef(hAbsence, "Half a day", .F.) == .T.
      IF hRow["half_day"]
         hRow["morning"] := CAS_HDef(hAbsence, "Morning", .F.) == .T.
      ENDIF

      // Vertretung nur, wenn sie genehmigt ist.
      IF CAS_Str(CAS_HDef(hAbsence, "Substitute state", "")) == "Approved"
         hRow["substitute_email"] := CAS_SubstituteMail(aUsers, ;
            CAS_Str(CAS_HDef(hAbsence, "User ID of the substitute", "")))
      ENDIF

      AAdd(aRows, hRow)
   NEXT

   CAS_Log(cLogFile, "INFO", "Uebertragen werden " + LTrim(Str(Len(aRows))) + " Abwesenheiten " + ;
           "(ohne E-Mail: " + LTrim(Str(nSkippedNoMail)) + ", ausserhalb des Fensters: " + ;
           LTrim(Str(nSkippedPast)) + ", unbrauchbar: " + LTrim(Str(nSkippedType)) + ")")

   IF Len(aRows) > CAS_MAXROWS
      CAS_Log(cLogFile, "ERROR", "Zu viele Abwesenheiten fuer einen Aufruf (" + ;
              LTrim(Str(Len(aRows))) + " > " + LTrim(Str(CAS_MAXROWS)) + "). Der Lauf wuerde " + ;
              "das Fenster in Paketen ersetzen und sich dabei selbst leeren - " + ;
              "NEXUSCRM_ABSENCE_AHEAD verkleinern.")
      IF ! lBatch
         Tr_MsgBox("Zu viele Abwesenheiten fuer einen Aufruf.")
      ENDIF
      RETURN
   ENDIF

   IF Len(aRows) == 0
      // Kein Abbruch: niemand im Urlaub ist eine gueltige Aussage, und sie
      // gehoert ins CRM. Nur ein Timebutler-Ausfall darf leer melden - der ist
      // oben schon abgefangen.
      CAS_Log(cLogFile, "WARNING", "Keine Abwesenheiten im Fenster - das CRM wird geleert.")
   ENDIF

   CAS_Push(cUrl, aRows, dFrom, dTo, lDry, cLogFile, lBatch)

   CAS_Log(cLogFile, "INFO", "Lauf beendet.")
   IF ! lBatch
      ? "Fertig. Protokoll: " + cLogFile
      Sinkey(0)
   ENDIF
RETURN


FUNCTION CRM_AbsenceSync_Setup()
   GetValue("NEXUSCRM", "", "API Key fuer NexusCRM (Bearer Token)")
   GetValue("NEXUSCRM_URL", ;
      "https://rxaltcsbhcxlczjjczxs.supabase.co/functions/v1/api-opportunities", ;
      "URL der NexusCRM API")
   GetValue("NEXUSCRM_ABSENCE_AHEAD", 1, "Jahre im Voraus (0 = nur laufendes Jahr)")
RETURN NIL


// Das Paket uebertragen und die Rueckmeldung protokollieren.
STATIC FUNCTION CAS_Push(cUrl, aRows, dFrom, dTo, lDry, cLogFile, lBatch)
   LOCAL oRest   := RestApi():New()
   LOCAL hBody   := {=>}
   LOCAL aHeader := {"Authorization: Bearer $APIKEY$", ;
                     "Content-Type: application/json", ;
                     "Accept: application/json"}
   LOCAL nStatus := 0
   LOCAL cResponse, xAnswer, hSummary, aUnknown, nX

   hBody["source"]      := "timebutler"
   hBody["dry_run"]     := lDry
   hBody["window_from"] := CAS_IsoDate(dFrom)
   hBody["window_to"]   := CAS_IsoDate(dTo)
   hBody["absences"]    := aRows

   oRest:cBaseUrl    := ""
   oRest:cApiKeyName := "NEXUSCRM"               // Bearer = TRADER_API_KEY
   cResponse := oRest:Execute(cUrl, "POST", hBody, aHeader, .T., @nStatus)

   IF nStatus < 200 .OR. nStatus >= 300 .OR. Empty(cResponse)
      CAS_Log(cLogFile, "ERROR", "Uebertragung fehlgeschlagen, HTTP " + LTrim(Str(nStatus)) + ;
              ": " + Left(CAS_Str(cResponse), 500))
      IF ! lBatch
         Tr_MsgBox("Uebertragung fehlgeschlagen: HTTP " + LTrim(Str(nStatus)))
      ENDIF
      RETURN .F.
   ENDIF

   xAnswer := HB_JsonDecode(cResponse)
   IF ValType(xAnswer) != "H" .OR. ! HHasKey(xAnswer, "summary")
      CAS_Log(cLogFile, "ERROR", "Unerwartete Antwort: " + Left(CAS_Str(cResponse), 500))
      RETURN .F.
   ENDIF

   hSummary := xAnswer["summary"]
   CAS_Log(cLogFile, "INFO", "CRM: gemeldet " + CAS_Str(CAS_HDef(hSummary, "received", 0)) + ;
           ", gespeichert " + CAS_Str(CAS_HDef(hSummary, "stored", 0)) + ;
           ", geloescht " + CAS_Str(CAS_HDef(hSummary, "deleted", 0)) + ;
           ", geschrieben " + CAS_Str(CAS_HDef(hSummary, "inserted", 0)) + ;
           ", verworfen " + CAS_Str(CAS_HDef(hSummary, "rejected", 0)))

   // Unbekannte Adressen sind kein Fehler, aber ein Hinweis: entweder hat der
   // Kollege keinen CRM-Zugang oder im Bearbeiterstamm steht ein Tippfehler.
   aUnknown := CAS_HDef(hSummary, "unknown_users", NIL)
   IF ValType(aUnknown) == "A"
      FOR nX := 1 TO Len(aUnknown)
         CAS_Log(cLogFile, "WARNING", "CRM kennt diese Adresse nicht: " + ;
                 hb_utf8ToStr(CAS_Str(aUnknown[nX])))
      NEXT
   ENDIF

   CAS_LogRejected(xAnswer, cLogFile)
RETURN .T.


// Verworfene Datensaetze einzeln ins Protokoll - sonst sucht man sie in
// Timebutler blind.
STATIC FUNCTION CAS_LogRejected(xAnswer, cLogFile)
   LOCAL aRejected := CAS_HDef(xAnswer, "rejected", NIL)
   LOCAL hItem, nX

   IF ValType(aRejected) != "A"
      RETURN NIL
   ENDIF
   FOR nX := 1 TO Len(aRejected)
      hItem := aRejected[nX]
      CAS_Log(cLogFile, "WARNING", "verworfen: " + ;
              hb_utf8ToStr(CAS_Str(CAS_HDef(hItem, "reason", ""))) + " - " + ;
              hb_utf8ToStr(CAS_Str(CAS_HDef(hItem, "input", ""))))
   NEXT
RETURN NIL


// E-Mail zu einer Timebutler-Personalnummer. Die Nummer ist die Satznummer im
// Bearbeiterstamm - dieselbe Zuordnung wie in timebutler_sync.prg.
STATIC FUNCTION CAS_MailOf(nEmployee)
   LOCAL cMail := ""

   IF ValType(nEmployee) != "N" .OR. nEmployee < 1 .OR. nEmployee > buy->(LastRec())
      RETURN ""
   ENDIF
   buy->(dbGoto(Int(nEmployee)))
   IF buy->(Eof()) .OR. buy->(Deleted())
      RETURN ""
   ENDIF
   // Inaktive Bearbeiter bleiben draussen: im CRM haben sie keinen Benutzer
   // mehr, ihre Abwesenheit verschiebt also nichts.
   IF ! buy->Aktive
      RETURN ""
   ENDIF
   cMail := Lower(AllTrim(CAS_Str(buy->Email)))
   IF ! "@" $ cMail
      RETURN ""
   ENDIF
RETURN cMail


// E-Mail der Vertretung ueber ihre Timebutler-Benutzer-Id.
STATIC FUNCTION CAS_SubstituteMail(aUsers, cUserId)
   LOCAL hUser
   LOCAL nX

   IF Empty(cUserId) .OR. ValType(aUsers) != "A"
      RETURN ""
   ENDIF
   // Die API liefert auch leere Benutzer (bekannter Timebutler-Fehler,
   // vermerkt in timebutler_sync.prg) - deshalb Empty() vor dem Vergleich.
   FOR nX := 1 TO Len(aUsers)
      hUser := aUsers[nX]
      IF ValType(hUser) == "H" .AND. HHasKey(hUser, "User ID") .AND. ;
         ! Empty(hUser["User ID"]) .AND. CAS_Str(hUser["User ID"]) == cUserId .AND. ;
         HHasKey(hUser, "Employee number")
         RETURN CAS_MailOf(hUser["Employee number"])
      ENDIF
   NEXT
RETURN ""


// ---------------------------------------------------------------------------
// Helfer - bewusst dieselben Muster wie in crm_company_sync.prg
// ---------------------------------------------------------------------------

STATIC FUNCTION CAS_HDef(hHash, cKey, xDef)
   IF ValType(hHash) == "H" .AND. HHasKey(hHash, cKey)
      RETURN hHash[cKey]
   ENDIF
RETURN xDef


// Endpunkt im selben Supabase-Projekt wie NEXUSCRM_URL. Die Einstellung zeigt
// auf eine Function (api-opportunities), nicht auf die Basis - abgeschnitten
// wird deshalb hinter /functions/v1/. Leer, wenn das Muster fehlt.
STATIC FUNCTION CAS_Endpoint(cPath)
   LOCAL cBase := AllTrim(CAS_Str(GetValue("NEXUSCRM_URL")))
   LOCAL nPos  := At("/functions/v1/", cBase)

   IF nPos == 0
      RETURN ""
   ENDIF
RETURN Left(cBase, nPos + Len("/functions/v1/") - 1) + cPath


STATIC FUNCTION CAS_Str(xVal)
   DO CASE
   CASE ValType(xVal) == "C"
      RETURN xVal
   CASE ValType(xVal) == "N"
      RETURN LTrim(Str(xVal))
   CASE ValType(xVal) == "L"
      RETURN IF(xVal, ".T.", ".F.")
   CASE ValType(xVal) == "D"
      RETURN DToC(xVal)
   ENDCASE
RETURN ""


STATIC FUNCTION CAS_IsoDate(dDate)
   LOCAL cDate

   IF ValType(dDate) != "D" .OR. Empty(dDate)
      RETURN ""
   ENDIF
   cDate := DToS(dDate)
RETURN SubStr(cDate, 1, 4) + "-" + SubStr(cDate, 5, 2) + "-" + SubStr(cDate, 7, 2)


STATIC FUNCTION CAS_IsYes(xVal)
   LOCAL cVal := Upper(AllTrim(CAS_Str(xVal)))
RETURN cVal == "1" .OR. cVal == "J" .OR. cVal == "JA" .OR. cVal == "Y" .OR. ;
       cVal == "YES" .OR. cVal == ".T." .OR. cVal == "DRY"


STATIC FUNCTION CAS_LogFile()
   LOCAL cFile

   IF ! File(CAS_LOGDIR)
      MakeDir(CAS_LOGDIR)
   ENDIF
   cFile := CAS_LOGDIR + "crm_absence_sync_" + DToS(Date()) + "_" + ;
            StrTran(Time(), ":", "") + ".log"
   CAS_Log(cFile, "INFO", "Protokoll gestartet: " + DToC(Date()) + " " + Time())
RETURN cFile


STATIC FUNCTION CAS_Log(cLogFile, cLevel, cMessage)
   LOCAL nHandle
   LOCAL cLine := "[" + DToC(Date()) + " " + Time() + "] [" + cLevel + "] " + ;
                  cMessage + Chr(13) + Chr(10)

   IF Empty(cLogFile)
      RETURN NIL
   ENDIF
   nHandle := FOpen(cLogFile, 2)                 // FO_READWRITE
   IF nHandle == -1
      nHandle := FCreate(cLogFile)
   ENDIF
   IF nHandle != -1
      FSeek(nHandle, 0, 2)                       // FS_END
      FWrite(nHandle, cLine)
      FClose(nHandle)
   ENDIF
RETURN NIL


// Die Klasse TimeButlerAPI - jedes Run-Script wird einzeln uebersetzt, sie
// muss hier mit hinein (wie in timebutler_sync.prg).
#include "x:\run\timebutlerapi.prg"
