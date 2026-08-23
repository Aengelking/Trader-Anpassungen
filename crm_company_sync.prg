/*
 * crm_company_sync.prg  -  Alle aktiven Kunden aus Trader mit den Firmen im
 * NexusCRM abgleichen.
 * -----------------------------------------------------------------------
 * Das CRM kennt viele Firmen nur mit Namen: Adresse, Telefon, Branche und die
 * ERP-Kundennummer fehlen. Dieses Run-Script laeuft ueber engkund (Gruppe "K"),
 * nimmt jeden aktiven Kunden und schickt ihn paketweise an die Edge Function
 * `api-companies/sync` des CRM. Die Function ordnet jeden Kunden einer Firma zu
 * (ERP-Kundennummer -> Matchcode -> Firmenname), aktualisiert sie oder legt sie
 * neu an und meldet je Kunde zurueck, was passiert ist.
 *
 * Aktiver Kunde = Umsatz im laufenden oder im Vorjahr (Turnover + Turnoverol,
 * dieselbe Definition wie in update_branch_ai.prg) oder Neukunde der letzten
 * NEXUSCRM_COMPANY_NEWDAYS Tage. Gesperrte (KSperren) und zusammengefuehrte
 * Adressen ("[SIEHE:...]") bleiben aussen vor.
 *
 * Die zusammengefuehrten Adressen werden aber gemeldet: changku.prg setzt beim
 * Verschmelzen KSperren und schreibt "[SIEHE:<Nummer des Siegers>]" vor Name1.
 * Genau diese Paare gehen als `merged_customers` ans CRM, damit es die beiden
 * Firmen dort ebenfalls zusammenlegt - sonst bleibt die Firma zur stillgelegten
 * Nummer mit ihren Kontakten, Leads und Opportunities fuer immer verwaist
 * stehen. Ketten (A -> B -> C) loest dieser Lauf auf und meldet C; das CRM
 * folgt keiner Kette. Die Meldungen gehen VOR den Kundenpaketen raus.
 *
 * Der Trader merkt sich zu einem Kunden nichts: die Verknuepfung von Kunde und
 * Firma haelt das CRM in companies.erp_customer_number. Die zurueckgemeldete
 * company_id steht nur im Protokoll, damit ein Lauf nachvollziehbar bleibt.
 *
 * Aufruf (Run-Script):
 *   trader:-R&crm_company_sync                  alle aktiven Kunden
 *   trader:-R&crm_company_sync&{"0","J"}        Testlauf, nichts wird geschrieben
 *   trader:-R&crm_company_sync&{"50"}           nur die ersten 50 (zum Pruefen)
 *
 * Config (GetValue, siehe CRM_CompanySync_Setup):
 *   NEXUSCRM              Keychain-Eintrag mit dem Bearer Token (TRADER_API_KEY
 *                         des CRM), eingesetzt fuer $APIKEY$ im Header
 *   NEXUSCRM_COMPANY_URL  Endpunkt der Synchronisation
 *   NEXUSCRM_COMPANY_BATCH    Kunden je Uebertragung (Server-Grenze: 500)
 *   NEXUSCRM_COMPANY_NEWDAYS  Neukunden ohne Umsatz: Tage seit "Kunde seit"
 *   NEXUSCRM_COMPANY_SKIP     Matchcodes, die nie uebertragen werden
 *   NEXUSCRM_COMPANY_MERGE    Zusammenfuehrungen melden (J/N) - Notbremse,
 *                             falls im CRM etwas schieflaeuft
 *
 * Protokoll: X:\run\supabase\logs\crm_company_sync_<Datum>_<Zeit>.log
 *
 * Zuordnung, Schreibregeln und Betrieb im Detail:
 * engelking-crm/docs/trader-company-sync.md
 */

#define CCS_MAXBATCH  500
#define CCS_MAXMERGE  200                        // Server-Grenze je Aufruf
#define CCS_SEEALSO   "[SIEHE:"                  // Marker aus changku.prg
#define CCS_LOGDIR    "X:\run\supabase\logs\"


PROCEDURE RUN_CRM_COMPANY_SYNC(cLimit, cDryRun)
   LOCAL lDry     := CCS_IsYes(cDryRun)
   LOCAL nLimit   := Val(CCS_Str(cLimit))
   LOCAL lBatch   := GetConfigValue("BATCHMODE")
   LOCAL cLogFile := CCS_LogFile()
   LOCAL hTotals  := {=>}
   LOCAL aErrors  := {}
   LOCAL aMerges  := {}
   LOCAL aCustomers, aBatch
   LOCAL cUrl, nBatchSize, nFrom, nTo, nX

   CRM_CompanySync_Setup()

   cUrl       := AllTrim(CCS_Str(GetValue("NEXUSCRM_COMPANY_URL")))
   nBatchSize := Int(Val(CCS_Str(GetValue("NEXUSCRM_COMPANY_BATCH"))))
   IF nBatchSize < 1 .OR. nBatchSize > CCS_MAXBATCH
      nBatchSize := 100
   ENDIF

   IF Empty(cUrl)
      CCS_Log(cLogFile, "ERROR", "NEXUSCRM_COMPANY_URL ist nicht gesetzt.")
      IF ! lBatch
         Tr_MsgBox("NEXUSCRM_COMPANY_URL ist nicht gesetzt.")
      ENDIF
      RETURN
   ENDIF

   IF ! lBatch
      Head("NexusCRM - aktive Kunden abgleichen" + IF(lDry, " (Testlauf)", ""))
   ENDIF
   CCS_Log(cLogFile, "INFO", "Start" + IF(lDry, " als Testlauf", "") + ;
           ", Paketgroesse " + LTrim(Str(nBatchSize)) + ;
           IF(nLimit > 0, ", begrenzt auf " + LTrim(Str(nLimit)) + " Kunden", ""))

   aCustomers := CCS_CollectCustomers(nLimit, lBatch, cLogFile, aMerges)

   // Erst die im ERP zusammengefuehrten Kunden melden: das CRM verarbeitet sie
   // vor den Stammdaten und findet die Firma danach ueber die Zielnummer.
   CCS_SyncMerges(cUrl, aMerges, lDry, hTotals, aErrors, cLogFile, lBatch)

   IF Len(aCustomers) == 0
      CCS_Log(cLogFile, "WARNING", "Keine aktiven Kunden gefunden.")
      IF Len(hTotals) > 0
         // Zusammenfuehrungen sind trotzdem gelaufen - Ergebnis nicht verschweigen.
         CCS_Report(hTotals, aErrors, lDry, lBatch, cLogFile)
      ELSEIF ! lBatch
         Tr_MsgBox("Keine aktiven Kunden gefunden.")
      ENDIF
      RETURN
   ENDIF

   FOR nFrom := 1 TO Len(aCustomers) STEP nBatchSize
      nTo    := Min(nFrom + nBatchSize - 1, Len(aCustomers))
      aBatch := {}
      FOR nX := nFrom TO nTo
         AAdd(aBatch, aCustomers[nX])
      NEXT

      IF ! lBatch
         @ 22,00 SAY "Uebertrage " + LTrim(Str(nFrom)) + "-" + LTrim(Str(nTo)) + ;
                     " von " + LTrim(Str(Len(aCustomers))) + "    "
      ENDIF

      CCS_PushBatch(cUrl, aBatch, lDry, hTotals, aErrors, cLogFile)
   NEXT

   CCS_Report(hTotals, aErrors, lDry, lBatch, cLogFile)
RETURN


// Konfigurationswerte anlegen bzw. lesbar machen.
FUNCTION CRM_CompanySync_Setup()
   GetValue("NEXUSCRM_COMPANY_URL", ;
            "https://rxaltcsbhcxlczjjczxs.supabase.co/functions/v1/api-companies/sync", ;
            "URL der NexusCRM Firmen-Synchronisation")
   GetValue("NEXUSCRM_COMPANY_BATCH", 100, "Kunden je Uebertragung (max. 500)")
   GetValue("NEXUSCRM_COMPANY_NEWDAYS", 365, ;
            "Neukunden ohne Umsatz: Tage seit 'Kunde seit'")
   GetValue("NEXUSCRM_COMPANY_SKIP", "SELF TEST GEKOA PGPOWER", ;
            "Matchcodes, die nicht ins CRM uebertragen werden")
   GetValue("NEXUSCRM_COMPANY_MERGE", "J", ;
            "Im ERP zusammengefuehrte Kunden ans CRM melden (J/N)")
RETURN NIL


// Alle aktiven Kunden einsammeln. Erst lesen, dann senden - danach steht der
// Satzzeiger frei fuer das Zurueckschreiben der company_id.
STATIC FUNCTION CCS_CollectCustomers(nLimit, lBatch, cLogFile, aMerges)
   LOCAL aCustomers := {}
   LOCAL aSkip      := CCS_SkipList()
   LOCAL nNewDays   := Int(Val(CCS_Str(GetValue("NEXUSCRM_COMPANY_NEWDAYS"))))
   LOCAL nSeen := 0, nSkipped := 0
   LOCAL dNew

   IF nNewDays < 0
      nNewDays := 0
   ENDIF
   dNew := Date() - nNewDays

   NetUse("engkund", "ku")
   NetUse("kuinfo", "kuinfo")
   NetUse("branch", "br")

   kuinfo->(dbSetOrder(1))
   br->(dbSetOrder(1))
   ku->(dbSetOrder(2))                          // Group + Matchcode
   ku->(dbSeek("K"))

   DO WHILE ! ku->(EOF()) .AND. ku->Group == "K"
      nSeen++
      IF CCS_IsActive(dNew, aSkip)
         AAdd(aCustomers, CCS_Payload())
         IF ! lBatch .AND. Len(aCustomers) % 25 == 0
            @ 21,00 SAY "Gelesen: " + LTrim(Str(Len(aCustomers))) + " aktive von " + ;
                        LTrim(Str(nSeen)) + " geprueften    "
         ENDIF
         IF nLimit > 0 .AND. Len(aCustomers) >= nLimit
            EXIT
         ENDIF
      ELSE
         nSkipped++
         // Nicht aktiv heisst nicht uninteressant: hier stehen die per
         // changku.prg verschmolzenen Adressen, die das CRM erfahren muss.
         CCS_CollectMerge(aMerges)
      ENDIF
      ku->(dbSkip())
   ENDDO

   CCS_Log(cLogFile, "INFO", LTrim(Str(nSeen)) + " Kunden geprueft, " + ;
           LTrim(Str(Len(aCustomers))) + " aktiv, " + LTrim(Str(nSkipped)) + " uebersprungen, " + ;
           LTrim(Str(Len(aMerges))) + " zusammengefuehrt")
   IF nLimit > 0
      CCS_Log(cLogFile, "INFO", "Begrenzter Lauf: Zusammenfuehrungen hinter dem " + ;
              LTrim(Str(nLimit)) + ". aktiven Kunden bleiben unentdeckt")
   ENDIF
RETURN aCustomers


// Ist der Kunde am aktuellen Satz per changku.prg auf eine andere Nummer
// verschmolzen? Dann Paar (stillgelegte Nummer, Zielnummer) merken.
STATIC FUNCTION CCS_CollectMerge(aMerges)
   LOCAL nInto := CCS_SeeAlso(ku->Name1)

   IF ValType(aMerges) != "A" .OR. nInto <= 0
      RETURN NIL
   ENDIF
   IF ku->Nummer <= 0 .OR. nInto == ku->Nummer
      RETURN NIL
   ENDIF
   AAdd(aMerges, {ku->Nummer, nInto})
RETURN NIL


// Zielnummer aus dem Marker lesen: changku.prg stellt Name1 ein
// "[SIEHE:<Nummer>]" voran. Wurde eine Adresse zweimal verschmolzen, stehen
// mehrere Marker davor; der vorderste ist der zuletzt geschriebene und damit
// der richtige. 0 = kein Marker.
STATIC FUNCTION CCS_SeeAlso(cName)
   LOCAL cText   := Upper(CCS_Str(cName))
   LOCAL nPos    := At(CCS_SEEALSO, cText)
   LOCAL cDigits := ""
   LOCAL cChar, nX

   IF nPos == 0
      RETURN 0
   ENDIF
   FOR nX := nPos + Len(CCS_SEEALSO) TO Len(cText)
      cChar := SubStr(cText, nX, 1)
      IF cChar >= "0" .AND. cChar <= "9"
         cDigits += cChar
      ELSE
         EXIT
      ENDIF
   NEXT
RETURN Val(cDigits)


// Ist der Kunde am aktuellen Satz ein aktiver Kunde?
STATIC FUNCTION CCS_IsActive(dNew, aSkip)
   LOCAL cMatch := Upper(AllTrim(ku->Kunde))
   LOCAL xLocked

   IF Empty(cMatch) .OR. Empty(AllTrim(ku->Name1))
      RETURN .F.
   ENDIF
   IF AScan(aSkip, {|c| c == cMatch}) > 0
      RETURN .F.
   ENDIF
   // Gesperrt oder per changku.prg auf eine andere Nummer zusammengefuehrt.
   // KSperren wird als "Y" gesetzt; ein logisches Feld waere auch denkbar.
   xLocked := CCS_Field("ku", "KSperren", "")
   IF (ValType(xLocked) == "C" .AND. Upper(AllTrim(xLocked)) == "Y") .OR. ;
      (ValType(xLocked) == "L" .AND. xLocked)
      RETURN .F.
   ENDIF
   IF "[SIEHE:" $ Upper(ku->Name1)
      RETURN .F.
   ENDIF
   // Umsatz im laufenden oder im Vorjahr.
   IF ku->Turnover + ku->Turnoverol > 0
      RETURN .T.
   ENDIF
RETURN ValType(ku->K_Seit) == "D" .AND. ! Empty(ku->K_Seit) .AND. ku->K_Seit >= dNew


// Nutzdaten eines Kunden fuer die Schnittstelle. Texte gehen als UTF-8 raus.
STATIC FUNCTION CCS_Payload()
   LOCAL hCust := {=>}
   LOCAL cName := AllTrim(AllTrim(ku->Name1) + " " + AllTrim(ku->Name2))
   LOCAL cSince := CCS_IsoDate(ku->K_Seit)

   hCust["erp_customer_number"] := LTrim(Str(ku->Nummer))
   hCust["matchcode"]           := hb_strToUtf8(Upper(AllTrim(ku->Kunde)))
   hCust["name"]                := hb_strToUtf8(cName)
   hCust["street"]              := hb_strToUtf8(AllTrim(ku->Street))
   hCust["postal_code"]         := hb_strToUtf8(AllTrim(ku->Plz))
   hCust["city"]                := hb_strToUtf8(AllTrim(ku->Town))
   hCust["country"]             := Upper(AllTrim(ku->CountryIso))
   hCust["phone"]               := hb_strToUtf8(AllTrim(ku->Telefon))
   hCust["email"]               := Lower(AllTrim(ku->Email))
   hCust["website"]             := hb_strToUtf8(CCS_Website())
   hCust["industry"]            := hb_strToUtf8(CCS_Industry())
   hCust["description"]         := hb_strToUtf8(CCS_Description())
   IF ! Empty(cSince)
      hCust["customer_since"] := cSince
   ENDIF
RETURN hCust


// Branche des Kunden als Klartext (branch-Tabelle).
STATIC FUNCTION CCS_Industry()
   LOCAL cCode := AllTrim(ku->Branch)

   IF Empty(cCode) .OR. Select("br") == 0
      RETURN ""
   ENDIF
   IF br->(dbSeek(cCode)) .AND. AllTrim(br->Branch) == cCode
      RETURN AllTrim(br->Name)
   ENDIF
RETURN ""


// Taetigkeitsbeschreibung aus kuinfo (von update_branch_ai.prg gepflegt).
STATIC FUNCTION CCS_Description()
   IF Select("kuinfo") == 0
      RETURN ""
   ENDIF
   IF kuinfo->(dbSeek(Str(ku->Nummer, 6)))
      RETURN AllTrim(kuinfo->Info)
   ENDIF
RETURN ""


// Website aus den Zusatzdaten des Kunden - nur wenn das Feld angelegt ist.
STATIC FUNCTION CCS_Website()
   LOCAL xWeb := CCS_ExtraGet(ku->Nummer, "WEBSITE")

   IF ValType(xWeb) == "C"
      RETURN AllTrim(xWeb)
   ENDIF
RETURN ""


// Zusatzfeld lesen, wenn es fuer Adressen ueberhaupt definiert ist. Nicht
// definierte Felder sind kein Ausnahmefall, sondern der Normalzustand: ohne
// HasField laeuft der Zugriff in BASE/1004 ("Message not found"). Idiom wie
// in ship\2.prg.
STATIC FUNCTION CCS_ExtraGet(nNumber, cField)
   LOCAL xValue := NIL
   LOCAL oExtra

   BEGIN SEQUENCE
      oExtra := ku->(ExtraData():New(nNumber))
      IF oExtra:HasField(cField)
         xValue := oExtra:Get(cField)
      ENDIF
   RECOVER
      xValue := NIL
   END SEQUENCE
RETURN xValue


// Ein Paket uebertragen und die Rueckmeldungen verbuchen.
STATIC FUNCTION CCS_PushBatch(cUrl, aBatch, lDry, hTotals, aErrors, cLogFile)
   LOCAL oRest   := RestApi():New()
   LOCAL hBody   := {=>}
   LOCAL aHeader := {"Authorization: Bearer $APIKEY$", ;
                     "Content-Type: application/json", ;
                     "Accept: application/json"}
   LOCAL nStatus := 0
   LOCAL cResponse, xAnswer, aResults, hItem
   LOCAL cAction, cCompanyId, cNumber, nX

   hBody["source"]     := "trader"
   hBody["dry_run"]    := lDry
   hBody["user_email"] := Lower(AllTrim(CCS_Str(SystemUser():Email)))
   hBody["customers"]  := aBatch

   oRest:cBaseUrl    := ""
   oRest:cApiKeyName := "NEXUSCRM"               // Bearer = TRADER_API_KEY
   cResponse := oRest:Execute(cUrl, "POST", hBody, aHeader, .T., @nStatus)

   IF nStatus < 200 .OR. nStatus >= 300 .OR. Empty(cResponse)
      CCS_Count(hTotals, "failed", Len(aBatch))
      AAdd(aErrors, "HTTP " + LTrim(Str(nStatus)) + ": " + Left(CCS_Str(cResponse), 200))
      CCS_Log(cLogFile, "ERROR", "Paket fehlgeschlagen, HTTP " + LTrim(Str(nStatus)) + ;
              ": " + Left(CCS_Str(cResponse), 500))
      RETURN .F.
   ENDIF

   xAnswer := HB_JsonDecode(cResponse)
   IF ValType(xAnswer) != "H" .OR. ! HHasKey(xAnswer, "results")
      CCS_Count(hTotals, "failed", Len(aBatch))
      AAdd(aErrors, "Unerwartete Antwort: " + Left(CCS_Str(cResponse), 200))
      CCS_Log(cLogFile, "ERROR", "Unerwartete Antwort: " + Left(CCS_Str(cResponse), 500))
      RETURN .F.
   ENDIF

   aResults := xAnswer["results"]
   IF ValType(aResults) != "A"
      aResults := {}
   ENDIF

   FOR nX := 1 TO Len(aResults)
      hItem      := aResults[nX]
      cAction    := Lower(CCS_Str(CCS_HDef(hItem, "action", "failed")))
      cNumber    := CCS_Str(CCS_HDef(hItem, "erp_customer_number", ""))
      cCompanyId := CCS_Str(CCS_HDef(hItem, "company_id", ""))

      CCS_Count(hTotals, cAction, 1)

      IF cAction == "created" .OR. cAction == "updated"
         CCS_Log(cLogFile, "DEBUG", cAction + " " + cNumber + " -> " + cCompanyId + ;
                 " " + CCS_List(CCS_HDef(hItem, "changed", NIL)))
      ELSEIF cAction != "unchanged"
         AAdd(aErrors, cAction + " " + cNumber + " " + ;
              hb_utf8ToStr(CCS_Str(CCS_HDef(hItem, "reason", ""))))
         CCS_Log(cLogFile, "WARNING", cAction + " " + cNumber + ": " + ;
                 hb_utf8ToStr(CCS_Str(CCS_HDef(hItem, "reason", ""))) + ;
                 " " + CCS_List(CCS_HDef(hItem, "candidates", NIL)))
      ENDIF
   NEXT
RETURN .T.


// Zusammenfuehrungen melden: aufloesen, senden, protokollieren. Laeuft vor den
// Kundenpaketen, damit das CRM die zusammengefuehrte Firma anschliessend ueber
// die Zielnummer findet statt eine zweite anzulegen.
STATIC FUNCTION CCS_SyncMerges(cUrl, aMerges, lDry, hTotals, aErrors, cLogFile, lBatch)
   LOCAL aBatch
   LOCAL nFrom, nTo, nX

   IF Len(aMerges) == 0
      RETURN .T.
   ENDIF
   IF ! CCS_IsYes(GetValue("NEXUSCRM_COMPANY_MERGE"))
      CCS_Log(cLogFile, "INFO", LTrim(Str(Len(aMerges))) + ;
              " Zusammenfuehrung(en) gefunden, aber NEXUSCRM_COMPANY_MERGE steht auf Nein")
      RETURN .F.
   ENDIF

   aMerges := CCS_ResolveChains(aMerges, cLogFile)
   IF Len(aMerges) == 0
      RETURN .T.
   ENDIF

   CCS_Log(cLogFile, "INFO", LTrim(Str(Len(aMerges))) + " Zusammenfuehrung(en) werden gemeldet")
   FOR nFrom := 1 TO Len(aMerges) STEP CCS_MAXMERGE
      nTo    := Min(nFrom + CCS_MAXMERGE - 1, Len(aMerges))
      aBatch := {}
      FOR nX := nFrom TO nTo
         AAdd(aBatch, CCS_MergePayload(aMerges[nX]))
      NEXT

      IF ! lBatch
         @ 22,00 SAY "Melde Zusammenfuehrungen " + LTrim(Str(nFrom)) + "-" + ;
                     LTrim(Str(nTo)) + " von " + LTrim(Str(Len(aMerges))) + "    "
      ENDIF

      CCS_PushMerges(cUrl, aBatch, lDry, hTotals, aErrors, cLogFile)
   NEXT
RETURN .T.


// Ketten aufloesen: ist B selbst auf C verschmolzen, wird aus A -> B ein
// A -> C. Das CRM folgt keiner Kette, es verarbeitet jede Meldung fuer sich.
// Ein Ringschluss (durch doppeltes Verschmelzen von Hand) wird gemeldet und
// die Meldung verworfen, statt endlos zu laufen.
STATIC FUNCTION CCS_ResolveChains(aMerges, cLogFile)
   LOCAL hInto := {=>}
   LOCAL aOut  := {}
   LOCAL hSeen, nFrom, nInto, nHops, nX

   FOR nX := 1 TO Len(aMerges)
      // Zweimal dieselbe stillgelegte Nummer kann es nicht geben; falls doch,
      // gewinnt der letzte Satz - beide zeigen ohnehin auf dasselbe Ziel.
      hInto[aMerges[nX][1]] := aMerges[nX][2]
   NEXT

   FOR nX := 1 TO Len(aMerges)
      nFrom := aMerges[nX][1]
      nInto := aMerges[nX][2]
      hSeen := {=>}
      hSeen[nFrom] := .T.
      nHops := 0

      DO WHILE HHasKey(hInto, nInto) .AND. nHops < 20
         IF HHasKey(hSeen, nInto)
            CCS_Log(cLogFile, "WARNING", "Ringschluss bei Kunde " + LTrim(Str(nFrom)) + ;
                    " (" + LTrim(Str(nInto)) + " zeigt zurueck) - nicht gemeldet")
            nInto := nFrom
            EXIT
         ENDIF
         hSeen[nInto] := .T.
         nInto := hInto[nInto]
         nHops++
      ENDDO

      IF nInto == nFrom .OR. nInto <= 0
         LOOP
      ENDIF
      IF HHasKey(hInto, nInto)
         // Nach 20 Spruengen immer noch kein Endpunkt: das ist keine Kette mehr,
         // sondern ein Datenfehler. Lieber nicht melden als falsch melden.
         CCS_Log(cLogFile, "WARNING", "Kette zu lang bei Kunde " + LTrim(Str(nFrom)) + ;
                 " - nicht gemeldet")
         LOOP
      ENDIF
      IF nHops > 0
         CCS_Log(cLogFile, "DEBUG", "Kette aufgeloest: " + LTrim(Str(nFrom)) + " -> " + ;
                 LTrim(Str(aMerges[nX][2])) + " -> ... -> " + LTrim(Str(nInto)))
      ENDIF
      AAdd(aOut, {nFrom, nInto})
   NEXT
RETURN aOut


// Nutzdaten einer Zusammenfuehrung: nur die beiden Nummern. Namen oder
// Matchcode braucht das CRM hier nicht - zugeordnet wird ueber die Nummer,
// alles andere waere geraten.
STATIC FUNCTION CCS_MergePayload(aPair)
   LOCAL hMerge := {=>}

   hMerge["erp_customer_number"]      := LTrim(Str(aPair[1]))
   hMerge["into_erp_customer_number"] := LTrim(Str(aPair[2]))
RETURN hMerge


// Ein Paket Zusammenfuehrungen uebertragen. `customers` bleibt leer, das Feld
// verlangt die Function aber.
STATIC FUNCTION CCS_PushMerges(cUrl, aBatch, lDry, hTotals, aErrors, cLogFile)
   LOCAL oRest   := RestApi():New()
   LOCAL hBody   := {=>}
   LOCAL aHeader := {"Authorization: Bearer $APIKEY$", ;
                     "Content-Type: application/json", ;
                     "Accept: application/json"}
   LOCAL nStatus := 0
   LOCAL cResponse, xAnswer, aResults, hItem
   LOCAL cAction, cFrom, cInto, cCompanyId, nX

   hBody["source"]           := "trader"
   hBody["dry_run"]          := lDry
   hBody["user_email"]       := Lower(AllTrim(CCS_Str(SystemUser():Email)))
   hBody["customers"]        := {}
   hBody["merged_customers"] := aBatch

   oRest:cBaseUrl    := ""
   oRest:cApiKeyName := "NEXUSCRM"               // Bearer = TRADER_API_KEY
   cResponse := oRest:Execute(cUrl, "POST", hBody, aHeader, .T., @nStatus)

   IF nStatus < 200 .OR. nStatus >= 300 .OR. Empty(cResponse)
      CCS_Count(hTotals, "merge_failed", Len(aBatch))
      AAdd(aErrors, "Zusammenfuehrungen HTTP " + LTrim(Str(nStatus)) + ": " + ;
           Left(CCS_Str(cResponse), 200))
      CCS_Log(cLogFile, "ERROR", "Zusammenfuehrungen fehlgeschlagen, HTTP " + ;
              LTrim(Str(nStatus)) + ": " + Left(CCS_Str(cResponse), 500))
      RETURN .F.
   ENDIF

   xAnswer := HB_JsonDecode(cResponse)
   IF ValType(xAnswer) != "H" .OR. ! HHasKey(xAnswer, "merges")
      CCS_Count(hTotals, "merge_failed", Len(aBatch))
      AAdd(aErrors, "Unerwartete Antwort auf Zusammenfuehrungen: " + Left(CCS_Str(cResponse), 200))
      CCS_Log(cLogFile, "ERROR", "Unerwartete Antwort auf Zusammenfuehrungen: " + ;
              Left(CCS_Str(cResponse), 500))
      RETURN .F.
   ENDIF

   aResults := xAnswer["merges"]
   IF ValType(aResults) != "A"
      aResults := {}
   ENDIF

   FOR nX := 1 TO Len(aResults)
      hItem      := aResults[nX]
      cAction    := Lower(CCS_Str(CCS_HDef(hItem, "action", "failed")))
      cFrom      := CCS_Str(CCS_HDef(hItem, "erp_customer_number", ""))
      cInto      := CCS_Str(CCS_HDef(hItem, "into_erp_customer_number", ""))
      cCompanyId := CCS_Str(CCS_HDef(hItem, "company_id", ""))

      CCS_Count(hTotals, "merge_" + cAction, 1)

      IF cAction == "merged" .OR. cAction == "relinked" .OR. cAction == "unchanged"
         CCS_Log(cLogFile, "DEBUG", cAction + " " + cFrom + " -> " + cInto + " = " + ;
                 cCompanyId + " " + CCS_List(CCS_HDef(hItem, "merged_company_ids", NIL)) + ;
                 " " + hb_utf8ToStr(CCS_Str(CCS_HDef(hItem, "reason", ""))))
      ELSE
         AAdd(aErrors, "Zusammenfuehrung " + cAction + " " + cFrom + " -> " + cInto + " " + ;
              hb_utf8ToStr(CCS_Str(CCS_HDef(hItem, "reason", ""))))
         CCS_Log(cLogFile, "WARNING", "Zusammenfuehrung " + cAction + " " + cFrom + " -> " + ;
                 cInto + ": " + hb_utf8ToStr(CCS_Str(CCS_HDef(hItem, "reason", ""))))
      ENDIF
   NEXT
RETURN .T.


// Ergebnis protokollieren und - ausserhalb des Batchbetriebs - anzeigen.
STATIC FUNCTION CCS_Report(hTotals, aErrors, lDry, lBatch, cLogFile)
   LOCAL aMsg := {}
   LOCAL cLine := ""
   LOCAL nX

   FOR nX := 1 TO Len(hTotals)
      cLine += IF(Empty(cLine), "", ", ") + HGetKeyAt(hTotals, nX) + ": " + ;
               LTrim(Str(HGetValueAt(hTotals, nX)))
   NEXT
   IF Empty(cLine)
      cLine := "keine Rueckmeldungen"
   ENDIF

   CCS_Log(cLogFile, "INFO", "Ergebnis" + IF(lDry, " (Testlauf)", "") + ": " + cLine)

   IF lBatch
      RETURN NIL
   ENDIF

   AAdd(aMsg, IF(lDry, "Testlauf - im CRM wurde nichts geaendert.", "Abgleich abgeschlossen."))
   AAdd(aMsg, cLine)
   IF Len(aErrors) > 0
      AAdd(aMsg, LTrim(Str(Len(aErrors))) + " Hinweis(e), siehe Protokoll:")
      FOR nX := 1 TO Min(Len(aErrors), 5)
         AAdd(aMsg, Left(aErrors[nX], 70))
      NEXT
   ENDIF
   AAdd(aMsg, "Protokoll: " + cLogFile)
   Tr_MsgBox(aMsg)
RETURN NIL


//---------------------------------------------------------------------------
// Kleine Helfer
//---------------------------------------------------------------------------

// Matchcodes, die nie uebertragen werden (eigene Firma, Testadressen).
STATIC FUNCTION CCS_SkipList()
   LOCAL aSkip := {}
   LOCAL aParts, nX

   aParts := hb_ATokens(Upper(AllTrim(CCS_Str(GetValue("NEXUSCRM_COMPANY_SKIP")))), " ")
   FOR nX := 1 TO Len(aParts)
      IF ! Empty(AllTrim(aParts[nX]))
         AAdd(aSkip, AllTrim(aParts[nX]))
      ENDIF
   NEXT
RETURN aSkip


// Zaehler je Rueckmeldung ("created", "updated", ...) hochzaehlen.
STATIC FUNCTION CCS_Count(hTotals, cKey, nCount)
   IF Empty(cKey)
      cKey := "unknown"
   ENDIF
   IF ! HHasKey(hTotals, cKey)
      hTotals[cKey] := 0
   ENDIF
   hTotals[cKey] += nCount
RETURN hTotals[cKey]


// Hashwert mit Standardwert (ohne hb_HGetDef, das nicht registriert sein muss).
STATIC FUNCTION CCS_HDef(hHash, cKey, xDef)
   IF ValType(hHash) == "H" .AND. HHasKey(hHash, cKey)
      RETURN hHash[cKey]
   ENDIF
RETURN xDef


// Sicheres Stringify - die Antwort kann Zahlen als JSON-Strings liefern.
STATIC FUNCTION CCS_Str(xVal)
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


// Array aus der Antwort als lesbare Liste.
STATIC FUNCTION CCS_List(xArray)
   LOCAL cList := ""
   LOCAL nX

   IF ValType(xArray) != "A"
      RETURN ""
   ENDIF
   FOR nX := 1 TO Len(xArray)
      cList += IF(Empty(cList), "", ",") + CCS_Str(xArray[nX])
   NEXT
RETURN IF(Empty(cList), "", "(" + cList + ")")


// Datum als ISO-Datum (das JSON der Schnittstelle erwartet YYYY-MM-DD).
STATIC FUNCTION CCS_IsoDate(dDate)
   LOCAL cDate

   IF ValType(dDate) != "D" .OR. Empty(dDate)
      RETURN ""
   ENDIF
   cDate := DToS(dDate)
RETURN SubStr(cDate, 1, 4) + "-" + SubStr(cDate, 5, 2) + "-" + SubStr(cDate, 7, 2)


// Run-Script-Parameter als Ja/Nein lesen.
STATIC FUNCTION CCS_IsYes(xVal)
   LOCAL cVal := Upper(AllTrim(CCS_Str(xVal)))
RETURN cVal == "1" .OR. cVal == "J" .OR. cVal == "JA" .OR. cVal == "Y" .OR. ;
       cVal == "YES" .OR. cVal == ".T." .OR. cVal == "DRY"


// Feld defensiv lesen - KSperren fehlt in aelteren engkund-Strukturen.
STATIC FUNCTION CCS_Field(cAlias, cField, xDef)
   LOCAL nPos := (cAlias)->(FieldPos(cField))

   IF nPos > 0
      RETURN (cAlias)->(FieldGet(nPos))
   ENDIF
RETURN xDef


// Protokolldatei anlegen (ein Lauf = eine Datei).
STATIC FUNCTION CCS_LogFile()
   LOCAL cFile

   IF ! File(CCS_LOGDIR)
      MakeDir(CCS_LOGDIR)
   ENDIF
   cFile := CCS_LOGDIR + "crm_company_sync_" + DToS(Date()) + "_" + ;
            StrTran(Time(), ":", "") + ".log"
   CCS_Log(cFile, "INFO", "Protokoll gestartet: " + DToC(Date()) + " " + Time())
RETURN cFile


STATIC FUNCTION CCS_Log(cLogFile, cLevel, cMessage)
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
