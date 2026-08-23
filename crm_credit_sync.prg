/*
 * crm_credit_sync.prg  -  Bonitaets- und Strukturdaten aus den Creditsafe-
 * Reports ins NexusCRM uebertragen.
 * -----------------------------------------------------------------------
 * Der Stammdaten-Abgleich (crm_company_sync.prg) bringt Adresse und
 * Kundennummer ins CRM. Dieses Run-Script legt die Bewertungsgrundlage
 * daneben: zu jedem Kunden mit einer Creditsafe-Auskunft im Archiv wandern
 * Rating, Kreditlimit, Bilanzkennzahlen (mehrjaehrig), Mitarbeiterzahlen,
 * Geschaeftsfuehrung, Gesellschafter, Konzernstruktur und der Branchen-
 * vergleich in die Tabelle company_credit_reports des CRM.
 *
 * Grundlage ist ausschliesslich das Archiv - es wird keine Auskunft neu
 * eingeholt und nichts bezahlt. Gelesen wird der jeweils letzte Report je
 * Kunde ueber CS_GetCompanyReportFromArchive(), das Reports aelter als
 * 12 Monate von sich aus verwirft.
 *
 * Gelaufen wird ueber die Tabelle creditsafe (cs), nicht ueber alle Kunden:
 * dort steht, zu welchem Kunden es ueberhaupt eine Auskunft gibt.
 *
 * Zahlen gehen als Text raus. Das CRM prueft und wandelt sie (siehe
 * _shared/creditReport.ts) - so entscheidet eine Stelle ueber Dezimaltrenner
 * und unlesbare Werte, und nicht zwei.
 *
 * Die Betraege stehen in der Waehrung des Reports. Mitgeschickt wird deshalb
 * der Kurs nach Euro aus der ERP-Waehrungstabelle - derselbe, mit dem
 * fakturiert wird (Currate(code,"E")). Kennt das ERP die Waehrung nicht, geht
 * kein Kurs mit: das CRM laesst die Euro-Betraege dann leer, statt Franken
 * gegen Zloty zu vergleichen.
 *
 * Aufruf (Run-Script):
 *   trader:-R&crm_credit_sync                   alle Kunden mit Auskunft
 *   trader:-R&crm_credit_sync&{"0","J"}         Testlauf, das CRM schreibt nichts
 *   trader:-R&crm_credit_sync&{"20"}            nur die ersten 20 (zum Pruefen)
 *
 * Config (GetValue, siehe CRM_CreditSync_Setup):
 *   NEXUSCRM              Keychain-Eintrag mit dem Bearer Token (TRADER_API_KEY
 *                         des CRM), eingesetzt fuer $APIKEY$ im Header
 *   NEXUSCRM_CREDIT_URL   Endpunkt der Bonitaets-Uebertragung
 *   NEXUSCRM_CREDIT_BATCH Reports je Uebertragung (Server-Grenze: 100)
 *
 * Protokoll: X:\run\supabase\logs\crm_credit_sync_<Datum>_<Zeit>.log
 *
 * Feldabbildung und Betrieb im Detail:
 * engelking-crm/docs/trader-credit-sync.md
 */

#define CCR_MAXBATCH  100
#define CCR_LOGDIR    "X:\run\supabase\logs\"


PROCEDURE RUN_CRM_CREDIT_SYNC(cLimit, cDryRun)
   LOCAL lDry     := CCR_IsYes(cDryRun)
   LOCAL nLimit   := Val(CCR_Str(cLimit))
   LOCAL lBatch   := GetConfigValue("BATCHMODE")
   LOCAL cLogFile := CCR_LogFile()
   LOCAL hTotals  := {=>}
   LOCAL aErrors  := {}
   LOCAL aReports, aBatch
   LOCAL cUrl, nBatchSize, nFrom, nTo, nX

   CRM_CreditSync_Setup()

   cUrl       := AllTrim(CCR_Str(GetValue("NEXUSCRM_CREDIT_URL")))
   nBatchSize := Int(Val(CCR_Str(GetValue("NEXUSCRM_CREDIT_BATCH"))))
   IF nBatchSize < 1 .OR. nBatchSize > CCR_MAXBATCH
      nBatchSize := 25
   ENDIF

   IF Empty(cUrl)
      CCR_Log(cLogFile, "ERROR", "NEXUSCRM_CREDIT_URL ist nicht gesetzt.")
      IF ! lBatch
         Tr_MsgBox("NEXUSCRM_CREDIT_URL ist nicht gesetzt.")
      ENDIF
      RETURN
   ENDIF

   IF ! lBatch
      Head("NexusCRM - Creditsafe-Daten uebertragen" + IF(lDry, " (Testlauf)", ""))
   ENDIF
   CCR_Log(cLogFile, "INFO", "Start" + IF(lDry, " als Testlauf", "") + ;
           ", Paketgroesse " + LTrim(Str(nBatchSize)) + ;
           IF(nLimit > 0, ", begrenzt auf " + LTrim(Str(nLimit)) + " Reports", ""))

   aReports := CCR_CollectReports(nLimit, lBatch, cLogFile)
   IF Len(aReports) == 0
      CCR_Log(cLogFile, "WARNING", "Keine verwertbaren Reports im Archiv gefunden.")
      IF ! lBatch
         Tr_MsgBox("Keine verwertbaren Creditsafe-Reports im Archiv gefunden.")
      ENDIF
      RETURN
   ENDIF

   FOR nFrom := 1 TO Len(aReports) STEP nBatchSize
      nTo    := Min(nFrom + nBatchSize - 1, Len(aReports))
      aBatch := {}
      FOR nX := nFrom TO nTo
         AAdd(aBatch, aReports[nX])
      NEXT

      IF ! lBatch
         @ 22,00 SAY "Uebertrage " + LTrim(Str(nFrom)) + "-" + LTrim(Str(nTo)) + ;
                     " von " + LTrim(Str(Len(aReports))) + "    "
      ENDIF

      CCR_PushBatch(cUrl, aBatch, lDry, hTotals, aErrors, cLogFile)
   NEXT

   CCR_Report(hTotals, aErrors, lDry, lBatch, cLogFile)
RETURN


// Konfigurationswerte anlegen bzw. lesbar machen.
FUNCTION CRM_CreditSync_Setup()
   GetValue("NEXUSCRM_CREDIT_URL", ;
            "https://rxaltcsbhcxlczjjczxs.supabase.co/functions/v1/api-companies/credit", ;
            "URL der NexusCRM Bonitaets-Uebertragung")
   GetValue("NEXUSCRM_CREDIT_BATCH", 25, "Reports je Uebertragung (max. 100)")
RETURN NIL


// Alle Kunden mit einer Auskunft im Archiv einsammeln.
STATIC FUNCTION CCR_CollectReports(nLimit, lBatch, cLogFile)
   LOCAL aReports := {}
   LOCAL nSeen := 0, nNoCustomer := 0, nNoReport := 0
   LOCAL oXml, hReport

   NetUse("creditsafe", "cs")
   NetUse("engkund", "ku")
   NetUse("currency", "cur")

   cur->(dbSetOrder(2))                         // Waehrungssymbol (ISO-Code)
   ku->(dbSetOrder(8))                          // Kundennummer
   cs->(dbSetOrder(1))
   cs->(dbGoTop())

   DO WHILE ! cs->(EOF())
      nSeen++

      IF ! ku->(dbSeek(Str(cs->Kunde, 6)))
         nNoCustomer++
      ELSE
         // Liefert NIL, wenn nichts archiviert ist oder der letzte Report
         // aelter als 12 Monate ist.
         oXml := CS_GetCompanyReportFromArchive(cs->Kunde)
         IF oXml == NIL
            nNoReport++
         ELSE
            hReport := CCR_Payload(oXml, cLogFile)
            IF Empty(hReport)
               nNoReport++
               CCR_Log(cLogFile, "WARNING", "Report von Kunde " + ;
                       LTrim(Str(cs->Kunde)) + " nicht lesbar")
            ELSE
               AAdd(aReports, hReport)
            ENDIF
         ENDIF
      ENDIF

      IF ! lBatch .AND. nSeen % 10 == 0
         @ 21,00 SAY "Gelesen: " + LTrim(Str(Len(aReports))) + " Reports von " + ;
                     LTrim(Str(nSeen)) + " Auskuenften    "
      ENDIF
      IF nLimit > 0 .AND. Len(aReports) >= nLimit
         EXIT
      ENDIF

      cs->(dbSkip())
   ENDDO

   CCR_Log(cLogFile, "INFO", LTrim(Str(nSeen)) + " Auskuenfte geprueft, " + ;
           LTrim(Str(Len(aReports))) + " Reports gelesen, " + ;
           LTrim(Str(nNoReport)) + " ohne aktuellen Report, " + ;
           LTrim(Str(nNoCustomer)) + " ohne Kunden")
RETURN aReports


// Nutzdaten eines Reports. Der Satzzeiger von ku steht auf dem Kunden, cs auf
// seiner Auskunft. Leeres Ergebnis heisst: der Report ist nicht verwertbar.
STATIC FUNCTION CCR_Payload(oXml, cLogFile)
   LOCAL hRep := {=>}
   LOCAL oReport, oSummary, oIdent, oBasic, oScore, oRating, oContact
   LOCAL oGroup, oParent, oFinancials, oAdd

   oReport := CCR_Node(oXml:oRoot, "Reports")
   IF oReport == NIL
      RETURN NIL
   ENDIF
   oReport := oReport:oChild
   IF oReport == NIL
      RETURN NIL
   ENDIF

   oSummary    := CCR_Node(oReport, "CompanySummary")
   oIdent      := CCR_Node(oReport, "CompanyIdentification")
   oBasic      := CCR_Node(oIdent, "BasicInformation")
   oScore      := CCR_Node(oReport, "CreditScore")
   oRating     := CCR_Node(oScore, "CurrentCreditRating")
   IF oRating == NIL
      oRating := CCR_Node(oSummary, "CreditRating")    // Kurzfassung im Summary
   ENDIF
   oContact    := CCR_Node(oReport, "ContactInformation")
   oGroup      := CCR_Node(oReport, "GroupStructure")
   oFinancials := CCR_Node(oReport, "FinancialStatements")
   oAdd        := CCR_Node(oReport, "AdditionalInformation")

   // Zuordnung im CRM
   hRep["erp_customer_number"] := LTrim(Str(ku->Nummer))
   hRep["matchcode"]           := hb_strToUtf8(Upper(AllTrim(ku->Kunde)))
   hRep["source"]              := "creditsafe"
   hRep["report_date"]         := CCR_IsoDate(cs->LastCheck)

   // Identitaet
   hRep["provider_company_id"]  := CCR_Attr(oReport, "CompanyId")
   hRep["safe_number"]          := CCR_Text(oSummary, "Number")
   hRep["registration_number"]  := CCR_Text(oSummary, "CompanyRegistrationNumber")
   hRep["vat_number"]           := CCR_Text(oBasic, "VatRegistrationNumber")
   hRep["national_number"]      := CCR_Text(CCR_Node(oAdd, "Misc"), "NationalNumber")
   hRep["legal_form"]           := CCR_Utf8(CCR_Text(oBasic, "LegalForm"))
   hRep["company_status"]       := CCR_Text(oSummary, "CompanyStatus")
   hRep["company_status_code"]  := CCR_Attr(CCR_Node(oSummary, "CompanyStatus"), "Code")
   hRep["incorporation_date"]   := CCR_XmlDate(oBasic, "DateofCompanyRegistration")
   hRep["country"]              := CCR_Text(oSummary, "Country")
   hRep["industry_code"]        := CCR_Text(CCR_Node(oSummary, "MainActivity"), "ActivityCode")
   hRep["industry_description"] := CCR_Utf8(CCR_Text(CCR_Node(oSummary, "MainActivity"), ;
                                                     "ActivityDescription"))
   hRep["website"]              := CCR_Text(CCR_Node(oContact, "Websites"), "Website")
   hRep["phone"]                := CCR_Text(CCR_Node(oContact, "MainAddress"), "Telephone")

   // Bonitaet
   hRep["currency"]             := CCR_Attr(oReport, "ReportCurrency")
   IF ! CCR_AddRate(hRep, hRep["currency"])
      // Sichtbar machen: ohne Kurs bleiben Kreditlimit und Umsatz dieser Firma
      // im CRM als "nicht vergleichbar" stehen.
      CCR_Log(cLogFile, "WARNING", "Kein ERP-Kurs fuer " + hRep["currency"] + ;
              " (Kunde " + LTrim(Str(ku->Nummer)) + "), Betraege gehen ohne Umrechnung")
   ENDIF
   hRep["rating_value"]         := CCR_Text(oRating, "CommonValue")
   hRep["rating_description"]   := CCR_Utf8(CCR_Text(oRating, "CommonDescription"))
   hRep["credit_limit"]         := CCR_Text(oRating, "CreditLimit")
   hRep["provider_score"]       := CCR_Text(oRating, "ProviderValue")
   hRep["provider_score_max"]   := CCR_Attr(CCR_Node(oRating, "ProviderValue"), "MaxValue")
   hRep["provider_description"] := CCR_Utf8(CCR_Text(oRating, "ProviderDescription"))
   // Creditsafe nennt in der Zusammenfassung eigene Zahlen, die vom letzten
   // Jahresabschluss abweichen koennen. Beide gehen mit, damit im CRM klar ist,
   // welche Zahl man sieht.
   hRep["latest_turnover"]            := CCR_Text(oSummary, "LatestTurnoverFigure")
   hRep["latest_shareholders_equity"] := CCR_Text(oSummary, "LatestShareholdersEquityFigure")
   hRep["rating_changed_on"]    := CCR_XmlDate(oReport, "DateOfLatestRatingChange")

   // Reihen
   hRep["financials"]        := CCR_Financials(oFinancials)
   hRep["employees_history"] := CCR_Employees(CCR_Node(oReport, "EmployeesInformation"))
   hRep["directors"]         := CCR_Directors(CCR_Node(oReport, "CurrentDirectors"))
   hRep["shareholders"]      := CCR_ShareHolders(CCR_Node(oReport, "ShareHolders"))

   // Konzern
   oParent := CCR_Node(oGroup, "UltimateParent")
   IF oParent == NIL
      oParent := CCR_Node(oGroup, "ImmediateParent")
   ENDIF
   IF oParent != NIL
      hRep["parent_name"]        := CCR_Utf8(CCR_ChildText(oParent, "Name"))
      hRep["parent_safe_number"] := CCR_Attr(oParent, "SafeNumber")
   ENDIF
   hRep["group_company_count"] := LTrim(Str(CCR_CountChildren(CCR_Node(oAdd, ;
                                                "ExtendedGroupStructure"), "CompanyName")))

   // Branchenvergleich (Quartile) als Ganzes, damit die Bewertung im CRM
   // "besser/schlechter als die Branche" rechnen kann.
   hRep["industry_benchmark"] := CCR_Quartiles(CCR_Node(oAdd, "IndustryQuartiles"))

   IF Empty(hRep["safe_number"]) .AND. Empty(hRep["rating_value"]) .AND. ;
      Len(hRep["financials"]) == 0
      RETURN NIL                                // kein verwertbarer Inhalt
   ENDIF
RETURN hRep


// Umrechnungskurs nach Euro beilegen. Fuer Euro-Reports ist er 1, sonst kommt
// er aus der ERP-Waehrungstabelle. Kennt das ERP die Waehrung nicht oder ist
// der Kurs 0, geht kein Kurs mit - das CRM behandelt die Betraege dann als
// nicht vergleichbar. Lieber eine Luecke als ein falscher Betrag.
STATIC FUNCTION CCR_AddRate(hRep, cIso)
   LOCAL nRate := 0

   cIso := Upper(AllTrim(CCR_Str(cIso)))
   IF Empty(cIso) .OR. cIso == "EUR"
      hRep["fx_rate_to_eur"] := "1"
      hRep["fx_rate_date"]   := CCR_IsoDate(Date())
      hRep["fx_rate_source"] := "trader (EUR)"
      RETURN .T.
   ENDIF

   IF Select("cur") == 0
      RETURN .F.
   ENDIF

   BEGIN SEQUENCE
      IF cur->(dbSeek(cIso))
         nRate := Currate(cur->Code, "E")       // Multiplikator nach Euro
      ENDIF
   RECOVER
      nRate := 0
   END SEQUENCE

   IF ValType(nRate) != "N" .OR. nRate <= 0
      RETURN .F.
   ENDIF

   hRep["fx_rate_to_eur"] := LTrim(Str(nRate, 18, 6))
   hRep["fx_rate_date"]   := CCR_IsoDate(Date())
   hRep["fx_rate_source"] := "trader"
RETURN .T.


// Kennzahlen aller Geschaeftsjahre, in der Reihenfolge des Reports (juengstes
// zuerst). Das CRM sortiert selbst nach Jahr, hier wird nur gesammelt.
STATIC FUNCTION CCR_Financials(oFinancials)
   LOCAL aYears := {}
   LOCAL oNode, oPL, oBS, oOther, oRatios, hYear

   IF oFinancials == NIL
      RETURN aYears
   ENDIF
   oNode := oFinancials:oChild
   DO WHILE oNode != NIL
      IF CCR_Child(oNode, "YearEndDate") != NIL
         oPL     := CCR_Child(oNode, "ProfitAndLoss")
         oBS     := CCR_Child(oNode, "BalanceSheet")
         oOther  := CCR_Child(oNode, "OtherFinancials")
         oRatios := CCR_Child(oNode, "Ratios")

         hYear := {=>}
         hYear["year_end"]              := CCR_XmlChildDate(oNode, "YearEndDate")
         hYear["currency"]              := CCR_ChildText(oNode, "Currency")
         hYear["revenue"]               := CCR_ChildText(oPL, "Revenue")
         hYear["operating_profit"]      := CCR_ChildText(oPL, "OperatingProfit")
         hYear["profit_after_tax"]      := CCR_ChildText(oPL, "ProfitAfterTax")
         hYear["total_assets"]          := CCR_ChildText(oBS, "TotalAssets")
         hYear["shareholders_equity"]   := CCR_ChildText(oBS, "TotalShareholdersEquity")
         hYear["net_worth"]             := CCR_ChildText(oOther, "NetWorth")
         hYear["working_capital"]       := CCR_ChildText(oOther, "WorkingCapital")
         hYear["equity_percentage"]     := CCR_ChildText(oRatios, "EquityInPercentage")
         hYear["current_ratio"]         := CCR_ChildText(oRatios, "CurrentRatio")
         hYear["debtor_days"]           := CCR_ChildText(oRatios, "DebtorDays")
         hYear["pre_tax_profit_margin"] := CCR_ChildText(oRatios, "PreTaxProfitMargin")
         hYear["gearing"]               := CCR_ChildText(oRatios, "Gearing")
         AAdd(aYears, hYear)
      ENDIF
      oNode := oNode:oNext
   ENDDO
RETURN aYears


// Mitarbeiterzahlen je Jahr, juengstes zuerst.
STATIC FUNCTION CCR_Employees(oEmployees)
   LOCAL aYears := {}
   LOCAL oNode, hYear

   IF oEmployees == NIL
      RETURN aYears
   ENDIF
   oNode := oEmployees:oChild
   DO WHILE oNode != NIL
      IF CCR_Child(oNode, "Year") != NIL
         hYear := {=>}
         hYear["year"]      := CCR_ChildText(oNode, "Year")
         hYear["employees"] := CCR_ChildText(oNode, "NumberOfEmployees")
         AAdd(aYears, hYear)
      ENDIF
      oNode := oNode:oNext
   ENDDO
RETURN aYears


// Geschaeftsfuehrung / Prokura.
STATIC FUNCTION CCR_Directors(oDirectors)
   LOCAL aPersons := {}
   LOCAL oNode, hPerson

   IF oDirectors == NIL
      RETURN aPersons
   ENDIF
   oNode := oDirectors:oChild
   DO WHILE oNode != NIL
      IF CCR_Child(oNode, "Name") != NIL
         hPerson := {=>}
         hPerson["name"]     := CCR_Utf8(CCR_ChildText(oNode, "Name"))
         hPerson["position"] := CCR_Utf8(CCR_ChildText(oNode, "Position"))
         AAdd(aPersons, hPerson)
      ENDIF
      oNode := oNode:oNext
   ENDDO
RETURN aPersons


// Gesellschafter mit Anteil.
STATIC FUNCTION CCR_ShareHolders(oShareHolders)
   LOCAL aHolders := {}
   LOCAL oNode, hHolder

   IF oShareHolders == NIL
      RETURN aHolders
   ENDIF
   oNode := oShareHolders:oChild
   DO WHILE oNode != NIL
      IF CCR_Child(oNode, "Name") != NIL
         hHolder := {=>}
         hHolder["name"]          := CCR_Utf8(CCR_ChildText(oNode, "Name"))
         hHolder["share_percent"] := CCR_ChildText(oNode, "SharePercent")
         AAdd(aHolders, hHolder)
      ENDIF
      oNode := oNode:oNext
   ENDDO
RETURN aHolders


// Branchen-Quartile: je Kennzahl der eigene Wert gegen Branchen-Unter-,
// Mittel- und Oberwert. Die Kennzahlen stehen im Report als eigene Tags,
// deshalb eine feste Liste - so ist ohne Blick in den Report klar, was
// uebertragen wird, und ein neuer Tag im Report aendert nichts still.
STATIC FUNCTION CCR_Quartiles(oQuartiles)
   LOCAL hBench := {=>}
   LOCAL aMetrics := {}
   LOCAL aNames := {"CurrentRatio", "QuickRatio", "DebtRatio", "SolvencyRatio", ;
                    "ReceivablesTurnover", "BorrowingsTurnover", "InventoryTurnover", ;
                    "ReturnOnAssets", "ReturnOnEquity", "ReturnOnSales", ;
                    "ReturnOnEconomicActivity", "SolidEquityToSolidAssetsRatio", ;
                    "ShortTermLiabilitiesToCurrentAssetsRatio"}
   LOCAL oMetric, hMetric, nX

   IF oQuartiles == NIL
      RETURN hBench
   ENDIF

   hBench["industry_code"]        := CCR_Text(oQuartiles, "IndustryCode")
   hBench["industry_description"] := CCR_Utf8(CCR_Text(oQuartiles, "IndustryDescription"))
   hBench["year_end"]             := CCR_Text(oQuartiles, "YearEndDate")
   hBench["statement_count"]      := CCR_Text(oQuartiles, "NumberOfFinancialStatements")

   FOR nX := 1 TO Len(aNames)
      oMetric := CCR_Child(oQuartiles, aNames[nX])
      IF oMetric != NIL
         hMetric := {=>}
         hMetric["name"]   := aNames[nX]
         hMetric["value"]  := CCR_ChildText(oMetric, "Value")
         hMetric["lower"]  := CCR_ChildText(oMetric, "Lower")
         hMetric["median"] := CCR_ChildText(oMetric, "Median")
         hMetric["upper"]  := CCR_ChildText(oMetric, "Upper")
         AAdd(aMetrics, hMetric)
      ENDIF
   NEXT
   hBench["metrics"] := aMetrics
RETURN hBench


// Ein Paket uebertragen und die Rueckmeldungen verbuchen.
STATIC FUNCTION CCR_PushBatch(cUrl, aBatch, lDry, hTotals, aErrors, cLogFile)
   LOCAL oRest   := RestApi():New()
   LOCAL hBody   := {=>}
   LOCAL aHeader := {"Authorization: Bearer $APIKEY$", ;
                     "Content-Type: application/json", ;
                     "Accept: application/json"}
   LOCAL nStatus := 0
   LOCAL cResponse, xAnswer, aResults, hItem
   LOCAL cAction, cNumber, nX

   hBody["source"]  := "creditsafe"
   hBody["dry_run"] := lDry
   hBody["reports"] := aBatch

   oRest:cBaseUrl    := ""
   oRest:cApiKeyName := "NEXUSCRM"               // Bearer = TRADER_API_KEY
   cResponse := oRest:Execute(cUrl, "POST", hBody, aHeader, .T., @nStatus)

   IF nStatus < 200 .OR. nStatus >= 300 .OR. Empty(cResponse)
      CCR_Count(hTotals, "failed", Len(aBatch))
      AAdd(aErrors, "HTTP " + LTrim(Str(nStatus)) + ": " + Left(CCR_Str(cResponse), 200))
      CCR_Log(cLogFile, "ERROR", "Paket fehlgeschlagen, HTTP " + LTrim(Str(nStatus)) + ;
              ": " + Left(CCR_Str(cResponse), 500))
      RETURN .F.
   ENDIF

   xAnswer := HB_JsonDecode(cResponse)
   IF ValType(xAnswer) != "H" .OR. ! HHasKey(xAnswer, "results")
      CCR_Count(hTotals, "failed", Len(aBatch))
      AAdd(aErrors, "Unerwartete Antwort: " + Left(CCR_Str(cResponse), 200))
      CCR_Log(cLogFile, "ERROR", "Unerwartete Antwort: " + Left(CCR_Str(cResponse), 500))
      RETURN .F.
   ENDIF

   aResults := xAnswer["results"]
   IF ValType(aResults) != "A"
      aResults := {}
   ENDIF

   FOR nX := 1 TO Len(aResults)
      hItem   := aResults[nX]
      cAction := Lower(CCR_Str(CCR_HDef(hItem, "action", "failed")))
      cNumber := CCR_Str(CCR_HDef(hItem, "erp_customer_number", ""))

      CCR_Count(hTotals, cAction, 1)

      IF cAction == "updated"
         CCR_Log(cLogFile, "DEBUG", "uebernommen " + cNumber + " -> " + ;
                 CCR_Str(CCR_HDef(hItem, "company_id", "")))
      ELSE
         AAdd(aErrors, cAction + " " + cNumber + " " + ;
              hb_utf8ToStr(CCR_Str(CCR_HDef(hItem, "reason", ""))))
         CCR_Log(cLogFile, "WARNING", cAction + " " + cNumber + ": " + ;
                 hb_utf8ToStr(CCR_Str(CCR_HDef(hItem, "reason", ""))))
      ENDIF
   NEXT
RETURN .T.


// Ergebnis protokollieren und - ausserhalb des Batchbetriebs - anzeigen.
STATIC FUNCTION CCR_Report(hTotals, aErrors, lDry, lBatch, cLogFile)
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

   CCR_Log(cLogFile, "INFO", "Ergebnis" + IF(lDry, " (Testlauf)", "") + ": " + cLine)

   IF lBatch
      RETURN NIL
   ENDIF

   AAdd(aMsg, IF(lDry, "Testlauf - im CRM wurde nichts geaendert.", ;
                       "Creditsafe-Daten uebertragen."))
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
// XML-Helfer. Find() durchsucht den Teilbaum und liefert den ersten Treffer -
// deshalb wird immer erst der Abschnitt geholt und darin weitergesucht.
//---------------------------------------------------------------------------

STATIC FUNCTION CCR_Node(oNode, cTag)
   IF oNode == NIL
      RETURN NIL
   ENDIF
RETURN TXmlIteratorScan():New(oNode):Find(cTag)


STATIC FUNCTION CCR_Text(oNode, cTag)
   LOCAL oFound := CCR_Node(oNode, cTag)

   IF oFound != NIL .AND. ValType(oFound:cData) == "C"
      RETURN AllTrim(oFound:cData)
   ENDIF
RETURN ""


// Direktes Kind mit diesem Tag - ohne Teilbaum-Scan. Innerhalb sich
// wiederholender Bloecke (ein Geschaeftsjahr, ein Gesellschafter) ist das
// Pflicht: fehlt dort ein Feld, wuerde eine Suche im Teilbaum still den Wert
// des naechsten Blocks einsammeln und Zahlen dem falschen Jahr zuordnen.
STATIC FUNCTION CCR_Child(oNode, cTag)
   LOCAL oChild

   IF oNode == NIL
      RETURN NIL
   ENDIF
   oChild := oNode:oChild
   DO WHILE oChild != NIL
      IF ValType(oChild:cName) == "C" .AND. AllTrim(oChild:cName) == cTag
         RETURN oChild
      ENDIF
      oChild := oChild:oNext
   ENDDO
RETURN NIL


STATIC FUNCTION CCR_ChildText(oNode, cTag)
   LOCAL oFound := CCR_Child(oNode, cTag)

   IF oFound != NIL .AND. ValType(oFound:cData) == "C"
      RETURN AllTrim(oFound:cData)
   ENDIF
RETURN ""


STATIC FUNCTION CCR_Attr(oNode, cAttr)
   LOCAL xValue

   IF oNode == NIL
      RETURN ""
   ENDIF
   xValue := oNode:GetAttribute(cAttr)
   IF ValType(xValue) == "C"
      RETURN AllTrim(xValue)
   ENDIF
RETURN ""


// Zaehlt die Kinder eines Knotens, die cTag enthalten.
STATIC FUNCTION CCR_CountChildren(oNode, cTag)
   LOCAL nCount := 0
   LOCAL oChild

   IF oNode == NIL
      RETURN 0
   ENDIF
   oChild := oNode:oChild
   DO WHILE oChild != NIL
      IF CCR_Child(oChild, cTag) != NIL
         nCount++
      ENDIF
      oChild := oChild:oNext
   ENDDO
RETURN nCount


// Datum aus dem Report: "2010-01-01T00:00:00Z" -> "2010-01-01".
STATIC FUNCTION CCR_XmlDate(oNode, cTag)
RETURN CCR_DatePart(CCR_Text(oNode, cTag))


STATIC FUNCTION CCR_XmlChildDate(oNode, cTag)
RETURN CCR_DatePart(CCR_ChildText(oNode, cTag))


STATIC FUNCTION CCR_DatePart(cText)
   IF Len(cText) >= 10 .AND. SubStr(cText, 5, 1) == "-" .AND. SubStr(cText, 8, 1) == "-"
      RETURN Left(cText, 10)
   ENDIF
RETURN ""


//---------------------------------------------------------------------------
// Kleine Helfer (wie in crm_company_sync.prg)
//---------------------------------------------------------------------------

// Report-Texte sind Einzelbyte-Zeichen aus dem Archiv; JSON braucht UTF-8.
STATIC FUNCTION CCR_Utf8(cText)
   IF Empty(cText)
      RETURN ""
   ENDIF
RETURN hb_strToUtf8(cText)


STATIC FUNCTION CCR_Count(hTotals, cKey, nCount)
   IF Empty(cKey)
      cKey := "unknown"
   ENDIF
   IF ! HHasKey(hTotals, cKey)
      hTotals[cKey] := 0
   ENDIF
   hTotals[cKey] += nCount
RETURN hTotals[cKey]


STATIC FUNCTION CCR_HDef(hHash, cKey, xDef)
   IF ValType(hHash) == "H" .AND. HHasKey(hHash, cKey)
      RETURN hHash[cKey]
   ENDIF
RETURN xDef


STATIC FUNCTION CCR_Str(xVal)
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


STATIC FUNCTION CCR_IsoDate(dDate)
   LOCAL cDate

   IF ValType(dDate) != "D" .OR. Empty(dDate)
      RETURN ""
   ENDIF
   cDate := DToS(dDate)
RETURN SubStr(cDate, 1, 4) + "-" + SubStr(cDate, 5, 2) + "-" + SubStr(cDate, 7, 2)


STATIC FUNCTION CCR_IsYes(xVal)
   LOCAL cVal := Upper(AllTrim(CCR_Str(xVal)))
RETURN cVal == "1" .OR. cVal == "J" .OR. cVal == "JA" .OR. cVal == "Y" .OR. ;
       cVal == "YES" .OR. cVal == ".T." .OR. cVal == "DRY"


STATIC FUNCTION CCR_LogFile()
   LOCAL cFile

   IF ! File(CCR_LOGDIR)
      MakeDir(CCR_LOGDIR)
   ENDIF
   cFile := CCR_LOGDIR + "crm_credit_sync_" + DToS(Date()) + "_" + ;
            StrTran(Time(), ":", "") + ".log"
   CCR_Log(cFile, "INFO", "Protokoll gestartet: " + DToC(Date()) + " " + Time())
RETURN cFile


STATIC FUNCTION CCR_Log(cLogFile, cLevel, cMessage)
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

#include 'X:\run\creditsafe.prg'
