/*
 * crm_figures_sync.prg  -  Finanzzahlen der Geschaeftsbeziehung ins NexusCRM
 * uebertragen.
 * -----------------------------------------------------------------------
 * Der Kundenbericht (bericht.prg) beantwortet die Fragen, die im Vertrieb
 * zaehlen: was haben wir mit dem Kunden umgesetzt, was ist offen, wie zahlt
 * er. Bisher nur als PDF. Dieses Run-Script schickt dieselben Zahlen ins CRM,
 * wo sie im Unternehmensprofil unter "Kundenbericht" stehen.
 *
 * Uebertragen wird je aktivem Kunden:
 *   Umsatz         current / last / last3 / total und die Jahresreihe
 *                  (GetCustomerTurnOver - dieselbe Quelle wie im Bericht)
 *   Auftragsbestand GetCustomerOpenOrders
 *   Offene Posten  Summe, ueberfaelliger Anteil, Anzahl, aeltestes Faelligdatum
 *   Zahlungsverhalten der letzten 12 Monate: Anzahl und Summe der Rechnungen,
 *                  Zahltage im Schnitt und maximal, Anzahl Mahnungen
 *   Konditionen    Zahlungsbedingung als Text, Zahlungsziel, Vorkasse
 *   Erstauftrag    Datum des ersten Auftrags
 *   Gekaufte Artikel je Artikel Menge UND Umsatz, jeweils gesamt und in den
 *                  letzten vier Zwoelfmonatszeitraeumen (Abschnitt "Bisher
 *                  gekaufte Artikel" des Berichts), dazu Anzahl der
 *                  Auftragspositionen und erstes/letztes Bestelldatum
 *
 * Der Artikelumsatz kommt aus den Auftragspositionen: Nettopreis nach Rabatt,
 * geteilt durch die Preiseinheit, mal Menge, Fremdwaehrung mit dem
 * Verkaufskurs. Er ist damit NICHT deckungsgleich mit turnover_total aus
 * GetCustomerTurnOver - die Summe ueber die Artikel weicht ab, weil dort der
 * Rabatt anders behandelt wird und Frachtpositionen mitzaehlen. Fuer die Frage
 * "was kauft dieser Kunde nicht" ist die Positionsrechnung die richtige, fuer
 * "was hat er insgesamt gebracht" turnover_total.
 *
 * Die Auswahl der Kunden folgt derselben Definition wie crm_company_sync.prg
 * (Umsatz im laufenden oder Vorjahr, oder Neukunde) und nutzt dieselben
 * Config-Werte NEXUSCRM_COMPANY_NEWDAYS und NEXUSCRM_COMPANY_SKIP. Wird die
 * Definition dort geaendert, gehoert sie hier nachgezogen - sonst hat das CRM
 * Firmen ohne Zahlen oder Zahlen ohne Firma.
 *
 * Betraege gehen in Euro raus: Fremdwaehrungsrechnungen werden mit dem Kurs
 * des Belegs umgerechnet, sonst mit dem Tageskurs (dasselbe Muster wie
 * supabase\supabase_kpi.prg). Zahlen gehen als Text raus, geprueft und
 * gewandelt wird im CRM (_shared/erpFigures.ts).
 *
 * Der Lauf ist rechenintensiv: je Kunde einmal Umsatz ermitteln und je einmal
 * ueber seine Rechnungen und seine Auftragspositionen laufen. Fuer einen
 * Nachtlauf gedacht, nicht fuer zwischendurch.
 *
 * Mehrfirmenbetrieb: Kundennummern gelten nur innerhalb ihrer Trader-Firma.
 * Der Lauf schickt deshalb die Firmennummer aus der Konfiguration (FIRMNO) als
 * `erp_company` mit und laeuft je Firma einmal - Firma umschalten, Lauf
 * wiederholen. Ist FIRMNO nicht gesetzt, bricht der Lauf ab: das CRM wuerde
 * die Daten sonst stillschweigend Firma 1 zuschlagen. Naeheres in
 * engelking-crm/docs/trader-multi-company.md.
 *
 * Aufruf (Run-Script):
 *   trader:-R&crm_figures_sync                  alle aktiven Kunden
 *   trader:-R&crm_figures_sync&{"0","J"}        Testlauf, das CRM schreibt nichts
 *   trader:-R&crm_figures_sync&{"25"}           nur die ersten 25 (zum Pruefen)
 *
 * Config (GetValue, siehe CRM_FiguresSync_Setup):
 *   NEXUSCRM               Keychain-Eintrag mit dem Bearer Token
 *   NEXUSCRM_FIGURES_URL   Endpunkt der Uebertragung
 *   NEXUSCRM_FIGURES_BATCH Kunden je Uebertragung (Server-Grenze: 250)
 *   NEXUSCRM_FIGURES_ARTICLES  Gekaufte Artikel je Kunde (0 = alle)
 *
 * Protokoll: X:\run\supabase\logs\crm_figures_sync_<Datum>_<Zeit>.log
 *
 * Feldabbildung und Betrieb im Detail:
 * engelking-crm/docs/trader-figures-sync.md
 */

#define CFS_MAXBATCH  250
#define CFS_LOGDIR    "X:\run\supabase\logs\"


// Firmennummer des laufenden Trader-Mandanten. Einmal je Lauf gesetzt,
// weil sie fuer jedes Paket dieselbe ist.
STATIC s_cFirm := ""


PROCEDURE RUN_CRM_FIGURES_SYNC(cLimit, cDryRun)
   LOCAL lDry     := CFS_IsYes(cDryRun)
   LOCAL nLimit   := Val(CFS_Str(cLimit))
   LOCAL lBatch   := GetConfigValue("BATCHMODE")
   LOCAL cLogFile := CFS_LogFile()
   LOCAL hTotals  := {=>}
   LOCAL aErrors  := {}
   LOCAL aFigures, aBatch
   LOCAL cUrl, nBatchSize, nFrom, nTo, nX

   CRM_FiguresSync_Setup()

   cUrl       := AllTrim(CFS_Str(GetValue("NEXUSCRM_FIGURES_URL")))
   nBatchSize := Int(Val(CFS_Str(GetValue("NEXUSCRM_FIGURES_BATCH"))))
   IF nBatchSize < 1 .OR. nBatchSize > CFS_MAXBATCH
      nBatchSize := 50
   ENDIF

   IF Empty(cUrl)
      CFS_Log(cLogFile, "ERROR", "NEXUSCRM_FIGURES_URL ist nicht gesetzt.")
      IF ! lBatch
         Tr_MsgBox("NEXUSCRM_FIGURES_URL ist nicht gesetzt.")
      ENDIF
      RETURN
   ENDIF

   // Ohne Firmennummer schlaegt das CRM die Daten Firma 1 zu. In einem Lauf
   // aus Automotive haengen sie damit an fremden Firmen - unbemerkt.
   s_cFirm := CFS_FirmNo()
   IF Empty(s_cFirm)
      CFS_Log(cLogFile, "ERROR", "FIRMNO ist in dieser Firma nicht gesetzt.")
      IF ! lBatch
         Tr_MsgBox({"Die Firmennummer (FIRMNO) ist nicht gesetzt.", ;
                    "Ohne sie wuerde das CRM die Daten Firma 1 zuschlagen."})
      ENDIF
      RETURN
   ENDIF

   IF ! lBatch
      Head("NexusCRM - Finanzzahlen uebertragen" + IF(lDry, " (Testlauf)", ""))
   ENDIF
   CFS_Log(cLogFile, "INFO", "Start" + IF(lDry, " als Testlauf", "") + ;
           ", Firma " + s_cFirm + ", Paketgroesse " + LTrim(Str(nBatchSize)) + ;
           IF(nLimit > 0, ", begrenzt auf " + LTrim(Str(nLimit)) + " Kunden", ""))

   aFigures := CFS_CollectFigures(nLimit, lBatch, cLogFile)
   IF Len(aFigures) == 0
      CFS_Log(cLogFile, "WARNING", "Keine aktiven Kunden gefunden.")
      IF ! lBatch
         Tr_MsgBox("Keine aktiven Kunden gefunden.")
      ENDIF
      RETURN
   ENDIF

   FOR nFrom := 1 TO Len(aFigures) STEP nBatchSize
      nTo    := Min(nFrom + nBatchSize - 1, Len(aFigures))
      aBatch := {}
      FOR nX := nFrom TO nTo
         AAdd(aBatch, aFigures[nX])
      NEXT

      IF ! lBatch
         @ 22,00 SAY "Uebertrage " + LTrim(Str(nFrom)) + "-" + LTrim(Str(nTo)) + ;
                     " von " + LTrim(Str(Len(aFigures))) + "    "
      ENDIF

      CFS_PushBatch(cUrl, aBatch, lDry, hTotals, aErrors, cLogFile)
   NEXT

   CFS_Report(hTotals, aErrors, lDry, lBatch, cLogFile)
RETURN


FUNCTION CRM_FiguresSync_Setup()
   GetValue("NEXUSCRM_FIGURES_URL", ;
            "https://rxaltcsbhcxlczjjczxs.supabase.co/functions/v1/api-companies/figures", ;
            "URL der NexusCRM Finanzzahlen-Uebertragung")
   GetValue("NEXUSCRM_FIGURES_BATCH", 50, "Kunden je Uebertragung (max. 250)")
   GetValue("NEXUSCRM_FIGURES_ARTICLES", 100, ;
            "Gekaufte Artikel je Kunde, die groessten Mengen zuerst (0 = alle)")
   // Auswahl der Kunden: dieselben Werte wie crm_company_sync.prg
   GetValue("NEXUSCRM_COMPANY_NEWDAYS", 365, ;
            "Neukunden ohne Umsatz: Tage seit 'Kunde seit'")
   GetValue("NEXUSCRM_COMPANY_SKIP", "SELF TEST GEKOA PGPOWER", ;
            "Matchcodes, die nicht ins CRM uebertragen werden")
RETURN NIL


// Zahlen aller aktiven Kunden einsammeln.
STATIC FUNCTION CFS_CollectFigures(nLimit, lBatch, cLogFile)
   LOCAL aFigures := {}
   LOCAL aSkip    := CFS_SkipList()
   LOCAL nNewDays := Int(Val(CFS_Str(GetValue("NEXUSCRM_COMPANY_NEWDAYS"))))
   LOCAL nMaxArt  := Int(Val(CFS_Str(GetValue("NEXUSCRM_FIGURES_ARTICLES"))))
   LOCAL nSeen := 0, nSkipped := 0
   LOCAL dNew

   IF nMaxArt < 0
      nMaxArt := 0
   ENDIF

   IF nNewDays < 0
      nNewDays := 0
   ENDIF
   dNew := Date() - nNewDays

   NetUse("engkund", "ku")
   NetUse("englsre", "re")
   NetUse("engauf", "auf")
   NetUse("skontoa", "sk")
   NetUse("artikel", "art")

   re->(dbSetOrder(1))                          // Kunde + ...
   auf->(dbSetOrder(2))                         // Kundenmatchcode
   ku->(dbSetOrder(2))                          // Group + Matchcode
   ku->(dbSeek("K"))

   DO WHILE ! ku->(EOF()) .AND. ku->Group == "K"
      nSeen++
      IF CFS_IsActive(dNew, aSkip)
         AAdd(aFigures, CFS_Payload(nMaxArt, cLogFile))
         IF ! lBatch .AND. Len(aFigures) % 10 == 0
            @ 21,00 SAY "Gelesen: " + LTrim(Str(Len(aFigures))) + " aktive von " + ;
                        LTrim(Str(nSeen)) + " geprueften    "
         ENDIF
         IF nLimit > 0 .AND. Len(aFigures) >= nLimit
            EXIT
         ENDIF
      ELSE
         nSkipped++
      ENDIF
      ku->(dbSkip())
   ENDDO

   CFS_Log(cLogFile, "INFO", LTrim(Str(nSeen)) + " Kunden geprueft, " + ;
           LTrim(Str(Len(aFigures))) + " aktiv, " + LTrim(Str(nSkipped)) + " uebersprungen")
RETURN aFigures


// Aktiver Kunde - dieselbe Definition wie in crm_company_sync.prg.
STATIC FUNCTION CFS_IsActive(dNew, aSkip)
   LOCAL cMatch := Upper(AllTrim(ku->Kunde))
   LOCAL xLocked

   IF Empty(cMatch) .OR. Empty(AllTrim(ku->Name1))
      RETURN .F.
   ENDIF
   IF AScan(aSkip, {|c| c == cMatch}) > 0
      RETURN .F.
   ENDIF
   xLocked := CFS_Field("ku", "KSperren", "")
   IF (ValType(xLocked) == "C" .AND. Upper(AllTrim(xLocked)) == "Y") .OR. ;
      (ValType(xLocked) == "L" .AND. xLocked)
      RETURN .F.
   ENDIF
   IF "[SIEHE:" $ Upper(ku->Name1)
      RETURN .F.
   ENDIF
   IF ku->Turnover + ku->Turnoverol > 0
      RETURN .T.
   ENDIF
RETURN ValType(ku->K_Seit) == "D" .AND. ! Empty(ku->K_Seit) .AND. ku->K_Seit >= dNew


// Nutzdaten eines Kunden. Der Satzzeiger von ku steht auf dem Kunden.
STATIC FUNCTION CFS_Payload(nMaxArt, cLogFile)
   LOCAL hFig := {=>}
   LOCAL cKunde := ku->Kunde
   LOCAL hOpen
   LOCAL nX

   hFig["erp_customer_number"] := LTrim(Str(ku->Nummer))
   hFig["matchcode"]           := hb_strToUtf8(Upper(AllTrim(cKunde)))
   hFig["source"]              := "trader"
   hFig["currency"]            := "EUR"
   hFig["figures_date"]        := CFS_IsoDate(Date())

   CFS_AddTurnover(hFig, cKunde)

   hFig["open_orders_value"] := CFS_Num(CFS_OpenOrders(cKunde))

   // Konditionen zuerst: damit steht der Satzzeiger von sk auf der
   // Zahlungsbedingung des Kunden, bevor die Rechnungen gelesen werden -
   // dieselbe Reihenfolge wie in bericht.prg.
   CFS_AddTerms(hFig)

   // Offene Posten und Zahlungsverhalten in einem Durchlauf ueber die
   // Rechnungen des Kunden.
   hOpen := CFS_Invoices(cKunde)
   FOR nX := 1 TO Len(hOpen)
      hFig[HGetKeyAt(hOpen, nX)] := HGetValueAt(hOpen, nX)
   NEXT

   hFig["first_order_date"] := CFS_FirstOrder(cKunde)

   // Bisher gekaufte Artikel. Der Durchlauf ueber die Auftragspositionen
   // kommt zum Schluss, weil er den Satzzeiger von auf weit bewegt.
   hFig["articles"] := CFS_Articles(cKunde, nMaxArt, cLogFile)
RETURN hFig


// Umsatzzahlen und Jahresreihe - dieselbe Quelle wie der Kundenbericht.
STATIC FUNCTION CFS_AddTurnover(hFig, cKunde)
   LOCAL hTurn
   LOCAL aYears := {}
   LOCAL nX, hYear

   BEGIN SEQUENCE
      hTurn := GetCustomerTurnOver(cKunde)
   RECOVER
      hTurn := NIL
   END SEQUENCE

   IF ValType(hTurn) != "H"
      RETURN .F.
   ENDIF

   hFig["turnover_current"]   := CFS_Num(CFS_HDef(hTurn, "current", 0))
   hFig["turnover_last_year"] := CFS_Num(CFS_HDef(hTurn, "last", 0))
   hFig["turnover_last3"]     := CFS_Num(CFS_HDef(hTurn, "last3", 0))
   hFig["turnover_total"]     := CFS_Num(CFS_HDef(hTurn, "total", 0))

   // Fuer Kunden liefert GetCustomerTurnOver die Jahresreihe mit; sie ist ein
   // Hash Jahr -> Betrag.
   IF HHasKey(hTurn, "years") .AND. ValType(hTurn["years"]) == "H"
      hYear := hTurn["years"]
      FOR nX := 1 TO Len(hYear)
         AAdd(aYears, {"year"   => CFS_Str(HGetKeyAt(hYear, nX)), ;
                       "amount" => CFS_Num(HGetValueAt(hYear, nX))})
      NEXT
   ENDIF
   hFig["turnover_years"] := aYears
RETURN .T.


// Auftragsbestand. Eigene Funktion, weil sie fehlen kann.
STATIC FUNCTION CFS_OpenOrders(cKunde)
   LOCAL nValue := 0

   BEGIN SEQUENCE
      nValue := GetCustomerOpenOrders(cKunde)
   RECOVER
      nValue := 0
   END SEQUENCE
   IF ValType(nValue) != "N"
      nValue := 0
   ENDIF
RETURN nValue


// Ein Durchlauf ueber die Rechnungen des Kunden: offene Posten und
// Zahlungsverhalten der letzten zwoelf Monate. Die Bedingungen sind aus
// bericht.prg uebernommen - code 2 offen, code 3 abgeschlossen, reposnr 0 ist
// der Kopfsatz.
STATIC FUNCTION CFS_Invoices(cKunde)
   LOCAL hRes := {=>}
   LOCAL nOpen := 0, nOverdue := 0, nCount := 0
   LOCAL dOldestDue := CToD(""), dDue
   LOCAL nInvCount := 0, nInvTotal := 0, nReminders := 0
   LOCAL nPayDays := 0, nPayCount := 0, nMaxDays := 0, nDays
   LOCAL dLastInv := CToD(""), nLastAmount := 0
   LOCAL dFrom := Date() - 365
   LOCAL nRate

   IF Select("re") == 0
      RETURN hRes
   ENDIF

   re->(dbSetOrder(1))
   re->(dbSeek(cKunde + "0", .T.))

   DO WHILE ! re->(EOF()) .AND. re->Kunde == cKunde
      IF re->Reposnr == 0
         nRate := CFS_Rate()

         // Offene Posten
         IF re->Status == 0 .AND. re->Code == 2 .AND. re->Packed
            nOpen += (re->Poswt - re->AoQty) * nRate
            nCount++
            dDue := re->Rechdat + sk->(GetSkontoWait(re->Skonto, re->Rechdat))
            IF Date() >= dDue
               nOverdue += (re->Poswt - re->AoQty) * nRate
            ENDIF
            IF Empty(dOldestDue) .OR. dDue < dOldestDue
               dOldestDue := dDue
            ENDIF
         ENDIF

         // Zahlungsverhalten der letzten zwoelf Monate
         IF re->Code == 3 .AND. re->Rechdat >= dFrom
            nInvCount++
            nInvTotal += re->Poswt * nRate
            IF re->Rem > 0
               nReminders++
            ENDIF
            IF ValType(re->PayDate) == "D" .AND. ! Empty(re->PayDate)
               nDays := re->PayDate - re->Rechdat
               IF nDays >= 0
                  nPayDays += nDays
                  nPayCount++
                  nMaxDays := Max(nMaxDays, nDays)
               ENDIF
            ENDIF
         ENDIF

         // Letzte Rechnung, unabhaengig vom Status
         IF re->Code >= 2 .AND. (Empty(dLastInv) .OR. re->Rechdat > dLastInv)
            dLastInv    := re->Rechdat
            nLastAmount := re->Poswt * nRate
         ENDIF
      ENDIF
      re->(dbSkip())
   ENDDO

   hRes["open_items_total"]    := CFS_Num(nOpen)
   hRes["open_items_overdue"]  := CFS_Num(nOverdue)
   hRes["open_items_count"]    := LTrim(Str(nCount))
   hRes["invoices_12m_count"]  := LTrim(Str(nInvCount))
   hRes["invoices_12m_total"]  := CFS_Num(nInvTotal)
   hRes["reminders_12m"]       := LTrim(Str(nReminders))
   hRes["max_payment_days"]    := LTrim(Str(nMaxDays))
   IF nPayCount > 0
      hRes["avg_payment_days"] := CFS_Num(nPayDays / nPayCount)
   ENDIF
   IF ! Empty(dOldestDue)
      hRes["open_items_oldest_due_date"] := CFS_IsoDate(dOldestDue)
   ENDIF
   IF ! Empty(dLastInv)
      hRes["last_invoice_date"]   := CFS_IsoDate(dLastInv)
      hRes["last_invoice_amount"] := CFS_Num(nLastAmount)
   ENDIF
RETURN hRes


// Kurs des aktuellen Rechnungssatzes nach Euro. Der im Beleg festgehaltene
// Kurs geht vor - so bleibt eine alte Rechnung bei ihrem damaligen Wert
// (dasselbe Muster wie supabase\supabase_kpi.prg).
STATIC FUNCTION CFS_Rate()
   LOCAL nRate := 1

   BEGIN SEQUENCE
      IF re->Rate != 0
         nRate := re->Rate
      ELSEIF ! Empty(re->Money)
         nRate := Currate(re->Money, "V")
      ENDIF
   RECOVER
      nRate := 1
   END SEQUENCE
   IF ValType(nRate) != "N" .OR. nRate <= 0
      nRate := 1
   ENDIF
RETURN nRate


// Zahlungsbedingung als Text, Zahlungsziel und Vorkasse.
STATIC FUNCTION CFS_AddTerms(hFig)
   LOCAL cTerms := ""
   LOCAL nDays := 0

   MEMVAR SYS_LAN

   IF Select("sk") == 0
      RETURN .F.
   ENDIF

   BEGIN SEQUENCE
      sk->(dbGoto(ku->Skonto + 1))
      cTerms := AllTrim(skont(, , sk->Ziel1, sk->Ziel2, sk->Ziel3, ;
                              sk->Rate1, sk->Rate2, sk->Rate3, SYS_LAN, .F.))
      nDays  := Max(Max(sk->Ziel1, sk->Ziel2), sk->Ziel3)
      hFig["prepay"] := IF(sk->(IsPrePay(ku->Skonto)), ".T.", ".F.")
   RECOVER
      cTerms := ""
      nDays  := 0
   END SEQUENCE

   IF ! Empty(cTerms)
      hFig["payment_terms"] := hb_strToUtf8(cTerms)
   ENDIF
   IF nDays > 0
      hFig["payment_terms_days"] := LTrim(Str(nDays))
   ENDIF
RETURN .T.


// Datum des ersten Auftrags - im Bericht die Zeile "Kunde seit".
STATIC FUNCTION CFS_FirstOrder(cKunde)
   IF Select("auf") == 0
      RETURN ""
   ENDIF
   auf->(dbSetOrder(2))
   IF auf->(dbSeek(cKunde, .T.)) .AND. auf->Kundma == cKunde
      RETURN CFS_IsoDate(auf->Besda)
   ENDIF
RETURN ""



// Bisher gekaufte Artikel - der gleichnamige Abschnitt aus bericht.prg, um den
// Umsatz erweitert. Je Artikel Menge UND Umsatz, jeweils gesamt und in den
// letzten vier rollierenden Zwoelfmonatszeitraeumen, dazu Anzahl und Zeitraum
// der Auftragspositionen.
//
// Sortiert und gekappt wird nach UMSATZ, nicht nach Menge: Stueck, Meter und
// Kilo lassen sich nicht gegeneinander vergleichen, Euro schon. Nur damit
// laesst sich die Frage beantworten, was ein Kunde noch nicht kauft.
STATIC FUNCTION CFS_Articles(cKunde, nMax, cLogFile)
   LOCAL hBought := {=>}
   LOCAL aSorted := {}
   LOCAL aArt    := {}
   LOCAL lArt    := Select("art") > 0
   LOCAL cMatch, hRow, nQty, nValue, nRate, nX, dOrder
   LOCAL cDesc, cUnit, aYears, aVals
   LOCAL nNoRate := 0

   IF Select("auf") == 0
      RETURN aArt
   ENDIF

   auf->(dbSetOrder(2))                         // Kundenmatchcode
   auf->(dbSeek(cKunde, .T.))

   DO WHILE ! auf->(EOF()) .AND. auf->Kundma == cKunde
      cMatch := auf->Matchcode
      // Frachtpositionen und Folgeauftraege bleiben aussen vor - dieselbe
      // Bedingung wie der Filter in bericht.prg. Leere Matchcodes fallen
      // ueber den Teilstringtest ebenfalls heraus.
      IF ! Trim(cMatch) $ "PORTO PORTOPAUSCHALE FRAIGHT" .AND. auf->FolgeTo == 0
         IF ! HHasKey(hBought, cMatch)
            hBought[cMatch] := {"total"  => 0, ;
                                "years"  => {0, 0, 0, 0}, ;
                                "val"    => 0, ;
                                "vyears" => {0, 0, 0, 0}, ;
                                "orders" => 0, ;
                                "first"  => CToD(""), ;
                                "last"   => CToD("")}
         ENDIF
         hRow := hBought[cMatch]

         // Solange der Auftrag laeuft zaehlt die bestellte Menge, ist er
         // abgeschlossen die tatsaechlich gelieferte.
         nQty := IF(auf->Bestat < 3, Max(auf->VkQty, auf->GelQty), auf->GelQty)

         // Positionswert in Euro. Nettopreis nach Rabatt, geteilt durch die
         // Preiseinheit - dieselbe Rechnung wie QuoteLinePrice() in
         // mcp_stdio.prg, samt Schutz vor Pe == 0. Fremdwaehrungen mit dem
         // Verkaufskurs, wie supabase\supabase_kpi.prg und custturn.prg.
         nRate := CFS_OrderRate(@nNoRate)
         IF nRate == 0
            nValue := 0                        // Kurs unbekannt: Menge ja, Umsatz nein
         ELSE
            nValue := nQty * (auf->VkPr - auf->VkPr * auf->Rabatt / 100) / ;
                      IF(auf->Pe == 0, 1, auf->Pe) * nRate
         ENDIF

         hRow["total"]  := hRow["total"] + nQty
         hRow["val"]    := hRow["val"] + nValue
         hRow["orders"] := hRow["orders"] + 1

         // Vier Zwoelfmonatsscheiben rueckwaerts ab heute. Massgeblich ist
         // der Wunschtermin, sonst der Liefertermin.
         FOR nX := 1 TO 4
            IF (auf->Wterm != 0 .AND. CalWd(auf->Wterm) >= Date() - 365 * nX - 1 .AND. ;
                CalWd(auf->Wterm) <= Date() - 365 * (nX - 1)) .OR. ;
               (auf->Wterm == 0 .AND. CalWd(auf->Dterm) >= Date() - 365 * nX - 1 .AND. ;
                CalWd(auf->Dterm) <= Date() - 365 * (nX - 1))
               hRow["years"][nX]  := hRow["years"][nX] + nQty
               hRow["vyears"][nX] := hRow["vyears"][nX] + nValue
            ENDIF
         NEXT

         dOrder := auf->Besda
         IF ValType(dOrder) == "D" .AND. ! Empty(dOrder)
            IF Empty(hRow["first"]) .OR. dOrder < hRow["first"]
               hRow["first"] := dOrder
            ENDIF
            IF Empty(hRow["last"]) .OR. dOrder > hRow["last"]
               hRow["last"] := dOrder
            ENDIF
         ENDIF
      ENDIF
      auf->(dbSkip())
   ENDDO

   FOR nX := 1 TO Len(hBought)
      AAdd(aSorted, {HGetKeyAt(hBought, nX), HGetValueAt(hBought, nX)})
   NEXT
   ASort(aSorted, , , {|x, y| x[2]["val"] > y[2]["val"]})

   IF nMax > 0 .AND. Len(aSorted) > nMax
      CFS_Log(cLogFile, "INFO", "Kunde " + AllTrim(cKunde) + ": " + ;
              LTrim(Str(Len(aSorted))) + " Artikel, uebertragen werden die " + ;
              LTrim(Str(nMax)) + " mit dem groessten Umsatz")
      aSorted := ASize(aSorted, nMax)
   ENDIF

   IF lArt
      art->(dbSetOrder(1))                      // Matchcode
   ENDIF

   FOR nX := 1 TO Len(aSorted)
      cMatch := aSorted[nX][1]
      hRow   := aSorted[nX][2]
      aYears := hRow["years"]
      aVals  := hRow["vyears"]
      cDesc  := ""
      cUnit  := ""
      IF lArt .AND. art->(dbSeek(cMatch))
         cDesc := AllTrim(art->Artikel)
         cUnit := AllTrim(art->Me)
      ENDIF

      AAdd(aArt, {"article_matchcode"   => hb_strToUtf8(Upper(AllTrim(cMatch))), ;
                  "article_description" => hb_strToUtf8(cDesc), ;
                  "unit"                => hb_strToUtf8(cUnit), ;
                  "qty_total"           => CFS_Num(hRow["total"]), ;
                  "qty_last_12m"        => CFS_Num(aYears[1]), ;
                  "qty_12_24m"          => CFS_Num(aYears[2]), ;
                  "qty_24_36m"          => CFS_Num(aYears[3]), ;
                  "qty_36_48m"          => CFS_Num(aYears[4]), ;
                  "revenue_total"       => CFS_Num(hRow["val"]), ;
                  "revenue_last_12m"    => CFS_Num(aVals[1]), ;
                  "revenue_12_24m"      => CFS_Num(aVals[2]), ;
                  "revenue_24_36m"      => CFS_Num(aVals[3]), ;
                  "revenue_36_48m"      => CFS_Num(aVals[4]), ;
                  "orders_count"        => LTrim(Str(hRow["orders"])), ;
                  "first_order_date"    => CFS_IsoDate(hRow["first"]), ;
                  "last_order_date"     => CFS_IsoDate(hRow["last"])})
   NEXT

   IF nNoRate > 0
      CFS_Log(cLogFile, "WARNING", "Kunde " + AllTrim(cKunde) + ": " + ;
              LTrim(Str(nNoRate)) + " Auftragspositionen ohne Waehrungskurs - " + ;
              "Mengen sind vollstaendig, Umsaetze nicht.")
   ENDIF
RETURN aArt


// Kurs der aktuellen Auftragsposition nach Euro. Euro-Auftraege haben kein
// Money-Kennzeichen und damit Kurs 1. Fehlt der Kurs einer Fremdwaehrung,
// kommt 0 zurueck - dann bleibt der Umsatz dieser Position leer, statt Zloty
// als Euro zu buchen. Der Zaehler wandert nach oben ins Protokoll.
STATIC FUNCTION CFS_OrderRate(nNoRate)
   LOCAL nRate := 1

   IF Empty(auf->Money)
      RETURN 1
   ENDIF
   BEGIN SEQUENCE
      nRate := Currate(auf->Money, "V")
   RECOVER
      nRate := 0
   END SEQUENCE
   IF ValType(nRate) != "N" .OR. nRate <= 0
      nNoRate++
      RETURN 0
   ENDIF
RETURN nRate


// Ein Paket uebertragen und die Rueckmeldungen verbuchen.
STATIC FUNCTION CFS_PushBatch(cUrl, aBatch, lDry, hTotals, aErrors, cLogFile)
   LOCAL oRest   := RestApi():New()
   LOCAL hBody   := {=>}
   LOCAL aHeader := {"Authorization: Bearer $APIKEY$", ;
                     "Content-Type: application/json", ;
                     "Accept: application/json"}
   LOCAL nStatus := 0
   LOCAL cResponse, xAnswer, aResults, hItem
   LOCAL cAction, cNumber, nX

   hBody["source"]      := "trader"
   hBody["dry_run"]     := lDry
   hBody["erp_company"] := s_cFirm
   hBody["figures"]     := aBatch

   oRest:cBaseUrl    := ""
   oRest:cApiKeyName := "NEXUSCRM"               // Bearer = TRADER_API_KEY
   cResponse := oRest:Execute(cUrl, "POST", hBody, aHeader, .T., @nStatus)

   IF nStatus < 200 .OR. nStatus >= 300 .OR. Empty(cResponse)
      CFS_Count(hTotals, "failed", Len(aBatch))
      AAdd(aErrors, "HTTP " + LTrim(Str(nStatus)) + ": " + Left(CFS_Str(cResponse), 200))
      CFS_Log(cLogFile, "ERROR", "Paket fehlgeschlagen, HTTP " + LTrim(Str(nStatus)) + ;
              ": " + Left(CFS_Str(cResponse), 500))
      RETURN .F.
   ENDIF

   xAnswer := HB_JsonDecode(cResponse)
   IF ValType(xAnswer) != "H" .OR. ! HHasKey(xAnswer, "results")
      CFS_Count(hTotals, "failed", Len(aBatch))
      AAdd(aErrors, "Unerwartete Antwort: " + Left(CFS_Str(cResponse), 200))
      CFS_Log(cLogFile, "ERROR", "Unerwartete Antwort: " + Left(CFS_Str(cResponse), 500))
      RETURN .F.
   ENDIF

   aResults := xAnswer["results"]
   IF ValType(aResults) != "A"
      aResults := {}
   ENDIF

   FOR nX := 1 TO Len(aResults)
      hItem   := aResults[nX]
      cAction := Lower(CFS_Str(CFS_HDef(hItem, "action", "failed")))
      cNumber := CFS_Str(CFS_HDef(hItem, "erp_customer_number", ""))

      CFS_Count(hTotals, cAction, 1)

      IF cAction == "updated"
         CFS_Log(cLogFile, "DEBUG", "uebernommen " + cNumber + " -> " + ;
                 CFS_Str(CFS_HDef(hItem, "company_id", "")))
      ELSE
         AAdd(aErrors, cAction + " " + cNumber + " " + ;
              hb_utf8ToStr(CFS_Str(CFS_HDef(hItem, "reason", ""))))
         CFS_Log(cLogFile, "WARNING", cAction + " " + cNumber + ": " + ;
                 hb_utf8ToStr(CFS_Str(CFS_HDef(hItem, "reason", ""))))
      ENDIF
   NEXT
RETURN .T.


STATIC FUNCTION CFS_Report(hTotals, aErrors, lDry, lBatch, cLogFile)
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

   CFS_Log(cLogFile, "INFO", "Ergebnis" + IF(lDry, " (Testlauf)", "") + ": " + cLine)

   IF lBatch
      RETURN NIL
   ENDIF

   AAdd(aMsg, IF(lDry, "Testlauf - im CRM wurde nichts geaendert.", ;
                       "Finanzzahlen uebertragen."))
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
// Kleine Helfer (wie in crm_company_sync.prg / crm_credit_sync.prg)
//---------------------------------------------------------------------------

STATIC FUNCTION CFS_SkipList()
   LOCAL aSkip := {}
   LOCAL aParts, nX

   aParts := hb_ATokens(Upper(AllTrim(CFS_Str(GetValue("NEXUSCRM_COMPANY_SKIP")))), " ")
   FOR nX := 1 TO Len(aParts)
      IF ! Empty(AllTrim(aParts[nX]))
         AAdd(aSkip, AllTrim(aParts[nX]))
      ENDIF
   NEXT
RETURN aSkip


// Betrag als Text mit Punkt als Dezimaltrenner - das CRM wandelt.
STATIC FUNCTION CFS_Num(nValue)
   IF ValType(nValue) != "N"
      RETURN ""
   ENDIF
RETURN LTrim(Str(nValue, 20, 2))


STATIC FUNCTION CFS_Count(hTotals, cKey, nCount)
   IF Empty(cKey)
      cKey := "unknown"
   ENDIF
   IF ! HHasKey(hTotals, cKey)
      hTotals[cKey] := 0
   ENDIF
   hTotals[cKey] += nCount
RETURN hTotals[cKey]


STATIC FUNCTION CFS_HDef(hHash, cKey, xDef)
   IF ValType(hHash) == "H" .AND. HHasKey(hHash, cKey)
      RETURN hHash[cKey]
   ENDIF
RETURN xDef


STATIC FUNCTION CFS_Str(xVal)
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


STATIC FUNCTION CFS_IsoDate(dDate)
   LOCAL cDate

   IF ValType(dDate) != "D" .OR. Empty(dDate)
      RETURN ""
   ENDIF
   cDate := DToS(dDate)
RETURN SubStr(cDate, 1, 4) + "-" + SubStr(cDate, 5, 2) + "-" + SubStr(cDate, 7, 2)


STATIC FUNCTION CFS_IsYes(xVal)
   LOCAL cVal := Upper(AllTrim(CFS_Str(xVal)))
RETURN cVal == "1" .OR. cVal == "J" .OR. cVal == "JA" .OR. cVal == "Y" .OR. ;
       cVal == "YES" .OR. cVal == ".T." .OR. cVal == "DRY"


// Feld defensiv lesen - KSperren fehlt in aelteren engkund-Strukturen.
STATIC FUNCTION CFS_Field(cAlias, cField, xDef)
   LOCAL nPos := (cAlias)->(FieldPos(cField))

   IF nPos > 0
      RETURN (cAlias)->(FieldGet(nPos))
   ENDIF
RETURN xDef


STATIC FUNCTION CFS_LogFile()
   LOCAL cFile

   IF ! File(CFS_LOGDIR)
      MakeDir(CFS_LOGDIR)
   ENDIF
   cFile := CFS_LOGDIR + "crm_figures_sync_" + DToS(Date()) + "_" + ;
            StrTran(Time(), ":", "") + ".log"
   CFS_Log(cFile, "INFO", "Protokoll gestartet: " + DToC(Date()) + " " + Time())
RETURN cFile


STATIC FUNCTION CFS_Log(cLogFile, cLevel, cMessage)
   LOCAL nHandle
   LOCAL cLine := "[" + DToC(Date()) + " " + Time() + "] [" + cLevel + "] " + ;
                  cMessage + Chr(13) + Chr(10)

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


// Nummer der Trader-Firma, aus der dieser Lauf stammt. Kundennummern gelten
// nur innerhalb ihrer Firma - dieselbe Nummer meint bei Elektronik und bei
// Automotive zwei verschiedene Betriebe. Leerstring, wenn FIRMNO nicht
// gesetzt ist; dann bricht der Lauf ab, statt zu raten.
STATIC FUNCTION CFS_FirmNo()
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
