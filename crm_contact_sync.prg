/*
 * crm_contact_sync.prg  -  Ansprechpartner aus Trader ins NexusCRM uebertragen.
 * -----------------------------------------------------------------------
 * Ergaenzung zu crm_company_sync.prg: Dieser Lauf geht ueber dieselben Kunden
 * (Gruppe "K"), liest zu jedem Kunden die Ansprechpartner (Tabelle contacts)
 * und schickt jeden mit E-Mail paketweise an die Edge Function
 * `api-companies/contacts` des CRM. Dort wird der Kontakt der Firma des Kunden
 * zugeordnet (ueber die ERP-Kundennummer), angelegt oder um Telefon und
 * Position ergaenzt. Die Firmenadresse selbst kommt aus crm_company_sync - der
 * Firmen-Abgleich muss deshalb zuerst gelaufen sein.
 *
 * Auswahl exakt wie in export_contacts_cleverreach.prg, damit das CRM nicht mehr
 * Ansprechpartner bekommt als CleverReach:
 *   - Kunden mit Auftrag (VkPr != 0), Musterversand oder Angebot seit 01.01.2021,
 *   - davon alle Ansprechpartner mit Anrede (allgemeine Adressen ohne Anrede
 *     fallen weg), mit E-Mail-Adresse, aktiv und nicht auf der Sperrliste.
 * Inaktive Ansprechpartner werden nicht uebertragen.
 *
 * Aufruf (Run-Script):
 *   trader:-R&crm_contact_sync                    alle Kunden nach obigem Filter
 *   trader:-R&crm_contact_sync&{"0","J"}          Testlauf, nichts wird geschrieben
 *   trader:-R&crm_contact_sync&{"50"}             nur die ersten 50 Kunden
 *
 * Config: wie crm_company_sync (NEXUSCRM, NEXUSCRM_URL, NEXUSCRM_COMPANY_SKIP).
 * Mehrfirmenbetrieb: FIRMNO muss gesetzt sein.
 *
 * Protokoll: X:\run\supabase\logs\crm_contact_sync_<Datum>_<Zeit>.log
 */

#define CCT_BATCH   100
#define CCT_SINCE   "20210101"                  // wie cStart im CleverReach-Export
#define CCT_LOGDIR  "X:\run\supabase\logs\"

STATIC s_cFirm := ""


PROCEDURE RUN_CRM_CONTACT_SYNC(cLimit, cDryRun)
   LOCAL lDry     := CCT_IsYes(cDryRun)
   LOCAL nLimit   := Val(CCT_Str(cLimit))
   LOCAL lBatch   := GetConfigValue("BATCHMODE")
   LOCAL cLogFile := CCT_LogFile()
   LOCAL hTotals  := {=>}
   LOCAL aErrors  := {}
   LOCAL aContacts, aPart, cUrl, nX

   cUrl := CCT_Endpoint("api-companies/contacts")
   IF Empty(cUrl)
      CCT_Log(cLogFile, "ERROR", "NEXUSCRM_URL ist nicht gesetzt oder ohne /functions/v1/.")
      IF ! lBatch
         Tr_MsgBox("NEXUSCRM_URL ist nicht gesetzt oder ohne /functions/v1/.")
      ENDIF
      RETURN
   ENDIF

   s_cFirm := CCT_FirmNo()
   IF Empty(s_cFirm)
      CCT_Log(cLogFile, "ERROR", "FIRMNO ist in dieser Firma nicht gesetzt.")
      IF ! lBatch
         Tr_MsgBox("Die Firmennummer (FIRMNO) ist nicht gesetzt.")
      ENDIF
      RETURN
   ENDIF

   IF ! lBatch
      Head("NexusCRM - Ansprechpartner abgleichen" + IF(lDry, " (Testlauf)", ""))
   ENDIF
   CCT_Log(cLogFile, "INFO", "Start" + IF(lDry, " als Testlauf", "") + ", Firma " + s_cFirm)

   aContacts := CCT_Collect(nLimit, lBatch, cLogFile)

   nX := 1
   DO WHILE nX <= Len(aContacts)
      aPart := {}
      DO WHILE nX <= Len(aContacts) .AND. Len(aPart) < CCT_BATCH
         AAdd(aPart, aContacts[nX])
         nX++
      ENDDO
      CCT_Push(cUrl, aPart, lDry, hTotals, aErrors, cLogFile)
   ENDDO

   CCT_Report(hTotals, aErrors, lDry, lBatch, cLogFile)
RETURN


// Kunden mit Auftrag, Muster oder Angebot seit CCT_SINCE - dieselben
// Schleifen wie am Anfang von export_contacts_cleverreach.prg.
STATIC FUNCTION CCT_Customers()
   LOCAL hCust  := {=>}
   LOCAL dStart := StoD(CCT_SINCE)
   LOCAL cWeek  := CalWeek(dStart)

   NetUse("engauf", "auf", .F., 0)
   auf->(dbSetOrder(10))
   auf->(dbSetFilter({|| auf->VkPr != 0}, "VkPr != 0"))
   auf->(dbSeek(cWeek))
   DO WHILE ! auf->(EOF()) .AND. auf->DTERM >= Val(cWeek) .AND. Left(Str(auf->Dterm, 4), 2) <= "52"
      hCust[auf->Kundma] := .T.
      auf->(dbSkip())
   ENDDO
   auf->(dbClearFilter())

   NetUse("lagerne", "lne", .F., 0)
   lne->(dbSetFilter({|| lne->Versand .AND. lne->Datum >= dStart .AND. lne->Gruppe == "K"}, ;
         "Versand .AND. Datum >= StoD('" + CCT_SINCE + "') .AND. Gruppe == 'K'"))
   lne->(dbGoTop())
   DO WHILE ! lne->(EOF())
      hCust[lne->Kunde] := .T.
      lne->(dbSkip())
   ENDDO
   lne->(dbClearFilter())

   NetUse("angebot", "ang")
   ang->(dbSetFilter({|| ang->Besda >= dStart}, "Besda >= StoD('" + CCT_SINCE + "')"))
   ang->(dbGoTop())
   DO WHILE ! ang->(EOF())
      hCust[ang->Kundma] := .T.
      ang->(dbSkip())
   ENDDO
   ang->(dbClearFilter())
RETURN hCust


// Ansprechpartner dieser Kunden einsammeln (Filter wie im CleverReach-Export).
STATIC FUNCTION CCT_Collect(nLimit, lBatch, cLogFile)
   LOCAL aOut  := {}
   LOCAL aSkip := CCT_SkipList()
   LOCAL hCust := CCT_Customers()
   LOCAL nCust := 0, nNoCust := 0, nNoMail := 0, nBlack := 0, nInactive := 0, nGeneral := 0
   LOCAL cKunde, cEmail, hC, nDept, nX

   NetUse("engkund", "ku", .F., 0)
   NetUse("contacts", "conts")
   ku->(dbSetOrder(1))
   conts->(dbSetOrder(2))                       // Address + Number
   nDept := conts->(FieldPos("DEPARTMENT"))

   FOR nX := 1 TO Len(hCust)
      cKunde := HGetKeyAt(hCust, nX)
      IF Trim(cKunde) $ "SELF TEST" .OR. AScan(aSkip, {|c| c == Upper(AllTrim(cKunde))}) > 0
         LOOP
      ENDIF
      IF ! ku->(dbSeek(cKunde + "K"))
         nNoCust++
         LOOP
      ENDIF
      nCust++

      conts->(dbSeek(Str(ku->Nummer, 6)))
      DO WHILE ! conts->(EOF()) .AND. conts->Address == ku->Nummer
         cEmail := Lower(AllTrim(conts->Email))
         IF conts->Anrede == 0
            nGeneral++                          // allgemeine Adresse
         ELSEIF ! conts->Active
            nInactive++
         ELSEIF Empty(cEmail) .OR. ! "@" $ cEmail
            nNoMail++
         ELSEIF IsBlacklisted(cEmail, "C")
            nBlack++
         ELSE
            hC := {=>}
            hC["erp_customer_number"] := LTrim(Str(ku->Nummer))
            hC["erp_contact_number"]  := LTrim(Str(conts->Number))
            hC["name"]                := hb_strToUtf8(AllTrim(conts->Name))
            hC["email"]               := cEmail
            hC["phone"]               := hb_strToUtf8(AllTrim(conts->Telephone))
            hC["position"]            := IF(nDept > 0, hb_strToUtf8(AllTrim(CCT_Str(conts->(FieldGet(nDept))))), "")
            hC["active"]              := .T.
            AAdd(aOut, hC)
         ENDIF
         conts->(dbSkip())
      ENDDO
      IF nLimit > 0 .AND. nCust >= nLimit
         EXIT
      ENDIF
   NEXT

   CCT_Log(cLogFile, "INFO", LTrim(Str(nCust)) + " Kunden, " + LTrim(Str(Len(aOut))) + ;
           " Ansprechpartner uebertragen; nicht uebertragen: " + LTrim(Str(nInactive)) + " inaktiv, " + ;
           LTrim(Str(nGeneral)) + " allgemeine Adressen, " + LTrim(Str(nNoMail)) + " ohne E-Mail, " + ;
           LTrim(Str(nBlack)) + " Sperrliste, " + LTrim(Str(nNoCust)) + " Kunden nicht in engkund")
RETURN aOut


STATIC FUNCTION CCT_Push(cUrl, aBatch, lDry, hTotals, aErrors, cLogFile)
   LOCAL oRest   := RestApi():New()
   LOCAL hBody   := {=>}
   LOCAL aHeader := {"Authorization: Bearer $APIKEY$", ;
                     "Content-Type: application/json", ;
                     "Accept: application/json"}
   LOCAL nStatus := 0
   LOCAL cResponse, xAnswer, aResults, hItem, cAction, nX

   hBody["source"]      := "trader"
   hBody["dry_run"]     := lDry
   hBody["erp_company"] := s_cFirm
   hBody["user_email"]  := Lower(AllTrim(CCT_Str(SystemUser():Email)))
   hBody["contacts"]    := aBatch

   oRest:cBaseUrl    := ""
   oRest:cApiKeyName := "NEXUSCRM"
   cResponse := oRest:Execute(cUrl, "POST", hBody, aHeader, .T., @nStatus)

   IF nStatus < 200 .OR. nStatus >= 300 .OR. Empty(cResponse)
      CCT_Count(hTotals, "failed", Len(aBatch))
      AAdd(aErrors, "HTTP " + LTrim(Str(nStatus)) + ": " + Left(CCT_Str(cResponse), 200))
      CCT_Log(cLogFile, "ERROR", "Paket fehlgeschlagen, HTTP " + LTrim(Str(nStatus)) + ": " + Left(CCT_Str(cResponse), 500))
      RETURN .F.
   ENDIF

   xAnswer := HB_JsonDecode(cResponse)
   IF ValType(xAnswer) != "H" .OR. ! HHasKey(xAnswer, "results") .OR. ValType(xAnswer["results"]) != "A"
      CCT_Count(hTotals, "failed", Len(aBatch))
      AAdd(aErrors, "Unerwartete Antwort: " + Left(CCT_Str(cResponse), 200))
      CCT_Log(cLogFile, "ERROR", "Unerwartete Antwort: " + Left(CCT_Str(cResponse), 500))
      RETURN .F.
   ENDIF

   aResults := xAnswer["results"]
   FOR nX := 1 TO Len(aResults)
      hItem   := aResults[nX]
      cAction := Lower(CCT_Str(IF(HHasKey(hItem, "action"), hItem["action"], "failed")))
      CCT_Count(hTotals, cAction, 1)
      IF cAction != "created" .AND. cAction != "updated" .AND. cAction != "unchanged"
         CCT_Log(cLogFile, "WARNING", cAction + " Kunde " + CCT_Str(IF(HHasKey(hItem, "erp_customer_number"), hItem["erp_customer_number"], "")) + ;
                 " " + CCT_Str(IF(HHasKey(hItem, "email"), hItem["email"], "")) + ": " + ;
                 hb_utf8ToStr(CCT_Str(IF(HHasKey(hItem, "reason"), hItem["reason"], ""))))
         IF cAction != "no_company"
            AAdd(aErrors, cAction + " " + CCT_Str(IF(HHasKey(hItem, "email"), hItem["email"], "")))
         ENDIF
      ENDIF
   NEXT
RETURN .T.


STATIC FUNCTION CCT_Report(hTotals, aErrors, lDry, lBatch, cLogFile)
   LOCAL cLine := ""
   LOCAL aMsg  := {}
   LOCAL nX

   FOR nX := 1 TO Len(hTotals)
      cLine += IF(Empty(cLine), "", ", ") + HGetKeyAt(hTotals, nX) + ": " + LTrim(Str(HGetValueAt(hTotals, nX)))
   NEXT
   IF Empty(cLine)
      cLine := "keine Rueckmeldungen"
   ENDIF
   CCT_Log(cLogFile, "INFO", "Ergebnis" + IF(lDry, " (Testlauf)", "") + ": " + cLine)
   IF lBatch
      RETURN NIL
   ENDIF
   AAdd(aMsg, IF(lDry, "Testlauf - im CRM wurde nichts geaendert.", "Abgleich abgeschlossen."))
   AAdd(aMsg, cLine)
   IF Len(aErrors) > 0
      AAdd(aMsg, LTrim(Str(Len(aErrors))) + " Fehler, siehe Protokoll.")
   ENDIF
   AAdd(aMsg, "Protokoll: " + cLogFile)
   Tr_MsgBox(aMsg)
RETURN NIL


//---------------------------------------------------------------------------
// Kleine Helfer (wie in crm_company_sync.prg)
//---------------------------------------------------------------------------

STATIC FUNCTION CCT_SkipList()
   LOCAL aSkip  := {}
   LOCAL aParts := hb_ATokens(Upper(AllTrim(CCT_Str(GetValue("NEXUSCRM_COMPANY_SKIP")))), " ")
   LOCAL nX

   FOR nX := 1 TO Len(aParts)
      IF ! Empty(AllTrim(aParts[nX]))
         AAdd(aSkip, AllTrim(aParts[nX]))
      ENDIF
   NEXT
RETURN aSkip


STATIC FUNCTION CCT_Count(hTotals, cKey, nCount)
   IF ! HHasKey(hTotals, cKey)
      hTotals[cKey] := 0
   ENDIF
   hTotals[cKey] += nCount
RETURN hTotals[cKey]


STATIC FUNCTION CCT_Endpoint(cPath)
   LOCAL cBase := AllTrim(CCT_Str(GetValue("NEXUSCRM_URL", "https://rxaltcsbhcxlczjjczxs.supabase.co/functions/v1/api-opportunities", "URL der NexusCRM API")))
   LOCAL nPos  := At("/functions/v1/", cBase)

   IF nPos == 0
      RETURN ""
   ENDIF
RETURN Left(cBase, nPos + Len("/functions/v1/") - 1) + cPath


STATIC FUNCTION CCT_Str(xVal)
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


STATIC FUNCTION CCT_IsYes(xVal)
   LOCAL cVal := Upper(AllTrim(CCT_Str(xVal)))
RETURN cVal == "1" .OR. cVal == "J" .OR. cVal == "JA" .OR. cVal == "Y" .OR. ;
       cVal == "YES" .OR. cVal == ".T." .OR. cVal == "DRY"


STATIC FUNCTION CCT_LogFile()
   LOCAL cFile

   IF ! File(CCT_LOGDIR)
      MakeDir(CCT_LOGDIR)
   ENDIF
   cFile := CCT_LOGDIR + "crm_contact_sync_" + DToS(Date()) + "_" + StrTran(Time(), ":", "") + ".log"
   CCT_Log(cFile, "INFO", "Protokoll gestartet: " + DToC(Date()) + " " + Time())
RETURN cFile


STATIC FUNCTION CCT_Log(cLogFile, cLevel, cMessage)
   LOCAL nHandle
   LOCAL cLine := "[" + DToC(Date()) + " " + Time() + "] [" + cLevel + "] " + cMessage + Chr(13) + Chr(10)

   IF Empty(cLogFile)
      RETURN NIL
   ENDIF
   nHandle := FOpen(cLogFile, 2)
   IF nHandle == -1
      nHandle := FCreate(cLogFile)
   ENDIF
   IF nHandle != -1
      FSeek(nHandle, 0, 2)
      FWrite(nHandle, cLine)
      FClose(nHandle)
   ENDIF
RETURN NIL


STATIC FUNCTION CCT_FirmNo()
   LOCAL xFirm := GetConfigValue("FIRMNO")
   LOCAL nFirm := 0

   IF ValType(xFirm) == "N"
      nFirm := Int(xFirm)
   ELSEIF ValType(xFirm) == "C"
      nFirm := Int(Val(AllTrim(xFirm)))
   ENDIF
   IF nFirm < 1
      RETURN ""
   ENDIF
RETURN LTrim(Str(nFirm))
