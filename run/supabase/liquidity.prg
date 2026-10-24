FUNCTION RUN_SYNC_SUPABASE_LIQUIDITY(cUserId)
   LOCAL oRest := RestApi():New()
   LOCAL aItems := {}
   LOCAL aItemBatches
   LOCAL aInvItems
   LOCAL aCustOrdItems
   LOCAL aCustInvItems
   LOCAL aPaidInvItems
   LOCAL aBookings
   LOCAL aBookingBatches
   LOCAL hBody
   LOCAL aHeader := {}
   LOCAL cResponse
   LOCAL hResponse
   LOCAL nBatchSize := 100
   LOCAL nBatchCount
   LOCAL nBatch
   LOCAL aBatchItems
   LOCAL aBatchBookings
   LOCAL nItemsSynced := 0
   LOCAL nBookingsSynced := 0
   LOCAL nErrors := 0
   LOCAL aFailed := {}
   LOCAL lComplete
   LOCAL cFailed := ""
   //Kennzeichnet diesen Lauf. erp-push schreibt sie an jeden gelieferten
   //Posten; im letzten Batch gilt als abgeschlossen, was sie nicht traegt.
   //Bewusst eine Kennung und kein Zeitstempel: ein Zeitstempel aus dieser
   //Zeitzone koennte auf dem Server in der Zukunft liegen, und dann waere
   //kein einziger Posten mehr "geliefert".
   LOCAL cSyncRun := DToS(Date()) + StrTran(Time(), ":", "")

   Default(@cUserId, "")

   Head("Daten an Liquidity Monitor senden")

   IF Empty(cUserId)
      cUserId := _GetLiquidityUserId()
   ENDIF

   IF Empty(cUserId)
      ? "ABBRUCH: Kein Liquidity user_id konfiguriert (LIQUIDITY_USER_ID)"
      //Tr_MsgBox blockiert im Nachtlauf auf einem Dialog, den niemand wegklickt
      IF ! GetConfigValue("BATCHMODE")
         Tr_MsgBox("Kein Liquidity user_id konfiguriert (LIQUIDITY_USER_ID)")
      ENDIF
      RETURN .F.
   ENDIF

   ? "----------------------------------------------"
   ? "Liquidity Sync gestartet:", DToC(Date()), Time()
   ? "User:", cUserId

   //Jeder Sammler laeuft abgesichert: faellt eine Quelle aus (typischer Fall
   //im Nachtlauf: die Lexware-ODBC-Verbindung steht unter dem Dienstkonto
   //nicht zur Verfuegung), wird sie uebersprungen statt den ganzen Lauf
   //abzubrechen. Ob eine Quelle gefehlt hat, steuert weiter unten, ob nicht
   //gelieferte Posten abgeschlossen werden.
   aItems := _CollectGuarded("Purchase Orders", {|| _CollectPurchaseOrderItems() }, @aFailed)
   ? "Purchase Orders gesammelt:", Len(aItems)

   aInvItems := _CollectGuarded("Purchase Invoices", {|| _CollectPurchaseInvoiceItems() }, @aFailed)
   ? "Purchase Invoices gesammelt:", Len(aInvItems)
   AEval(aInvItems, {|hItem| AAdd(aItems, hItem)})

   aCustOrdItems := _CollectGuarded("Customer Orders", {|| _CollectCustomerOrderItems() }, @aFailed)
   ? "Customer Orders gesammelt:", Len(aCustOrdItems)
   AEval(aCustOrdItems, {|hItem| AAdd(aItems, hItem)})

   aCustInvItems := _CollectGuarded("Customer Invoices", {|| _CollectCustomerInvoiceItems() }, @aFailed)
   ? "Customer Invoices gesammelt:", Len(aCustInvItems)
   AEval(aCustInvItems, {|hItem| AAdd(aItems, hItem)})

   //Bezahlte Rechnungen ab 2026: nicht fuer den Liquiditaetsplan, sondern
   //damit die Zahlungszuordnung ihren Gegenpart findet.
   aPaidInvItems := _CollectGuarded("Paid Customer Invoices", {|| _CollectPaidCustomerInvoiceItems() }, @aFailed)
   ? "Bezahlte Kundenrechnungen gesammelt:", Len(aPaidInvItems)
   AEval(aPaidInvItems, {|hItem| AAdd(aItems, hItem)})

   IF GetConfigValue("FIRMNO") == 1
      aBookings := _CollectGuarded("Lexware Buchungen", {|| _CollectLexwareBookings(Year(Date())) }, @aFailed)
      ? "Lexware Buchungen gesammelt:", Len(aBookings)
   ENDIF

   lComplete := Len(aFailed) == 0
   IF ! lComplete
      AEval(aFailed, {|c| cFailed += IF(Empty(cFailed), "", ", ") + c})
      ? "WARNUNG: Unvollstaendige Sammlung. Ausgefallen:", cFailed
      ? "WARNUNG: Posten werden nicht abgeschlossen - bestehende Eintraege"
      ? "         in Liquidity bleiben stehen und werden nur aktualisiert."
   ENDIF

   ? "Gesamt Items fÅr Upload:", Len(aItems)

   aItemBatches := _SplitIntoBatches(aItems, nBatchSize)
   aBookingBatches := _SplitIntoBatches(aBookings, nBatchSize)
   nBatchCount := Max(Len(aItemBatches), Len(aBookingBatches))

   IF nBatchCount == 0
      ? "Keine offenen Daten fÅr Liquidity gefunden"
      IF ! GetConfigValue("BATCHMODE")
         Sinkey(0)
      ENDIF
      RETURN .T.
   ENDIF

   //oRest:cBaseUrl := "https://fhyvjvjyszbqzefwvtpz.supabase.co/"
   oRest:cBaseUrl := "https://bjsocddqwaddzhybhixu.supabase.co"
   oRest:cApiKeyName := "LIQUIDITY"

   AAdd(aHeader, "x-api-key: $APIKEY$")
   AAdd(aHeader, "accept: application/json")
   AAdd(aHeader, "content-type: application/json")

   ? "Sende Daten an Supabase Funktion: functions/v1/erp-push"
   ? "Batching aktiv - Grî·e:", nBatchSize, "Items:", Len(aItemBatches), "Bookings:", Len(aBookingBatches), "Gesamt:", nBatchCount

   FOR nBatch := 1 TO nBatchCount
      aBatchItems := IF(nBatch <= Len(aItemBatches), aItemBatches[nBatch], {})
      aBatchBookings := IF(nBatch <= Len(aBookingBatches), aBookingBatches[nBatch], {})

      hBody := {=>}
      hBody["user_id"] := cUserId
      hBody["items"] := aBatchItems
      hBody["bookings"] := aBatchBookings
      //replace_all loeschte in erp-push ALLE erp_items und legte sie neu an -
      //mit neuen IDs und ohne Historie. Abgeloest durch close_missing:
      //erp-push schliesst ab, was dieser Lauf nicht geliefert hat. Die
      //Posten bleiben damit erhalten, und eine bezahlte Rechnung ist weiter
      //auffindbar, statt zu verschwinden.
      //
      //Nur nach vollstaendiger Sammlung: sonst gaelten die Posten der
      //ausgefallenen Quelle als "nicht mehr geliefert" und verschwaenden
      //aus dem Liquiditaetsbild.
      hBody["replace_all"] := .F.
      hBody["sync_run_id"] := cSyncRun
      hBody["close_missing"] := (nBatch == nBatchCount) .AND. lComplete
      hBody["replace_all_bookings"] := .F.
      hBody["sync_accounts"] := (nBatch == 1)  //trigger the syncing of bank accounts
      //Zahlungszuordnung zuletzt: bis zum letzten Batch ist das
      //Rechnungsbuch unvollstaendig, und der Matcher wuerde eine Zahlung
      //an den falschen Posten desselben Kunden haengen. Ohne lComplete
      //fehlt eine ganze Quelle - dasselbe Problem.
      hBody["run_matching"] := (nBatch == nBatchCount) .AND. lComplete

      ? "Sende Batch", nBatch, "von", nBatchCount, "(Items:", Len(aBatchItems), "Bookings:", Len(aBatchBookings), ")"

      cResponse := oRest:Execute("functions/v1/erp-push", "POST", hBody, aHeader, .T.)

      IF Empty(cResponse)
         ? "Liquidity Sync Batch fehlgeschlagen: keine Antwort (Batch", nBatch, ")"
         IF ! GetConfigValue("BATCHMODE")
            Sinkey(0)
         ENDIF
         RETURN .F.
      ENDIF

      hResponse := HB_JsonDecode(cResponse)
      IF ValType(hResponse) != "H" .OR. ! HHasKey(hResponse, "success") .OR. ! hResponse["success"]
         ? "Liquidity Sync Batch fehlgeschlagen:", nBatch
         ? "Batch Antwort:", cResponse
         IF ! GetConfigValue("BATCHMODE")
            Sinkey(0)
         ENDIF
         RETURN .F.
      ENDIF

      IF HHasKey(hResponse, "items_synced")
         nItemsSynced += hResponse["items_synced"]
      ENDIF
      IF HHasKey(hResponse, "bookings_synced")
         nBookingsSynced += hResponse["bookings_synced"]
      ENDIF
      IF HHasKey(hResponse, "errors")
         nErrors += Len(hResponse["errors"])
         IF Len(hResponse["errors"]) > 0
            ? "Batch", nBatch, "Fehler:", Len(hResponse["errors"])
            ? "Beispiel Fehler:", HB_JsonEncode(hResponse["errors"][1])
         ENDIF
      ENDIF
   NEXT

   IF lComplete
      ? "Liquidity Sync erfolgreich."
   ELSE
      ? "Liquidity Sync abgeschlossen - UNVOLLSTAENDIG:", cFailed
   ENDIF
   ? "ERP Elemente:", LTrim(Str(nItemsSynced))
   ? "Kostenbuchungen:", LTrim(Str(nBookingsSynced))
   ? "Fehler:", LTrim(Str(nErrors))

   IF ! GetConfigValue("BATCHMODE")
      Sinkey(0)
   ENDIF
RETURN .T.

STATIC FUNCTION _CollectGuarded(cLabel, bCollect, aFailed)
   //Ruft einen Sammler ab und faengt jeden Laufzeitfehler ab. Ohne diese
   //Klammer reisst z.B. eine nicht erreichbare Lexware-ODBC-Quelle den
   //kompletten Nachtlauf mit - dann wird gar nichts uebertragen.
   //Die ausgefallene Quelle landet in aFailed; der Aufrufer laesst daraufhin
   //replace_all weg, damit die bereits uebertragenen Posten dieser Quelle
   //nicht aus dem Liquiditaetsbild geloescht werden.
   LOCAL xResult
   LOCAL oErr

   BEGIN SEQUENCE WITH {|e| Break(e)}
      xResult := Eval(bCollect)
   RECOVER USING oErr
      xResult := {}
      AAdd(aFailed, cLabel)
      ? "FEHLER in Sammler '" + cLabel + "':"
      IF ValType(oErr) == "O"
         ? "   ", _ErrText(oErr)
      ENDIF
      ? "   Quelle wird uebersprungen, der Lauf geht weiter."
   END SEQUENCE

   IF ValType(xResult) != "A"
      xResult := {}
   ENDIF

RETURN xResult

STATIC FUNCTION _ErrText(oErr)
   //Fehlerobjekt in eine Protokollzeile. Jede Eigenschaft einzeln abgesichert:
   //ein Fehler beim Aufbereiten des Fehlers waere besonders aergerlich.
   LOCAL cText := ""

   BEGIN SEQUENCE WITH {|e| Break(e)}
      cText := AllTrim(oErr:Description)
      IF ! Empty(oErr:Operation)
         cText += " (" + AllTrim(oErr:Operation) + ")"
      ENDIF
      IF ValType(oErr:SubSystem) == "C" .AND. ! Empty(oErr:SubSystem)
         cText += " [" + AllTrim(oErr:SubSystem) + "]"
      ENDIF
   RECOVER
      cText := "Fehlerdetails nicht lesbar"
   END SEQUENCE

   IF Empty(cText)
      cText := "Unbekannter Fehler"
   ENDIF

RETURN cText

STATIC FUNCTION _CollectLexwareBookings(nYear)
   LOCAL aBookings := {}
   LOCAL aLxBookings
   LOCAL hCostCenters
   LOCAL hBooking
   LOCAL hItem
   
   LOCAL nScanned := 0
   LOCAL nRelevant := 0
   LOCAL hNummern := {=>}
   LOCAL xCostCenterName
   LOCAL cCostCenter

   Default(@nYear,Year(Date()))

   ? "[BU][LX] Sammle Buchungen mit Kostenstelle aus Lexware..."

   IF ! LX_Start()
      ? "[BU][LX] Lexware Start fehlgeschlagen"
      RETURN aBookings
   ENDIF

   hCostCenters := LX_GetCostCenters(.T., .T.)

   aLxBookings := LX_GetBookingsWithKSt(nYear, .F.)

   FOR EACH hBooking IN aLxBookings
      nScanned++

      IF HHasKey(hBooking, "KST") .AND. hBooking["KST"] != 0
         nRelevant++
         IF ! HHasKey(hNummern, hBooking["NR"])
            hNummern[hBooking["NR"]] := 0
         ELSE
            hNummern[hBooking["NR"]]++
         ENDIF
         hItem := {=>}
         hItem["erp_reference"] := "BU-" + StrZero(hBooking["JAHR"],4) + "-" + StrZero(hBooking["NR"],8)+"-"+StrZero(hNummern[hBooking["NR"]],2)
         hItem["booking_date"] := _IsoDate(hBooking["DATUM"])
         hItem["amount"] := Round(hBooking["NETTO"] + hBooking["UST"], 2)
         hItem["net_amount"] := Round(hBooking["NETTO"], 2)
         hItem["vat_amount"] := Round(hBooking["UST"], 2) 
         hItem["vat_handling"] := "standard"
         hItem["currency"] := "EUR"
         hItem["account_debit"] := LTrim(Str(hBooking["SOLL"]))
         hItem["account_credit"] := LTrim(Str(hBooking["HABEN"]))
         cCostCenter := "KST-" + LTrim(Str(hBooking["KST"]))
         IF HHasKey(hCostCenters, hBooking["KST"])
            xCostCenterName := hCostCenters[hBooking["KST"]]
            IF ValType(xCostCenterName) == "C" .AND. ! Empty(AllTrim(xCostCenterName))
               cCostCenter := hb_StrToUTF8(AllTrim(xCostCenterName))
            ENDIF
         ELSEIF HHasKey(hCostCenters, LTrim(Str(hBooking["KST"])))
            xCostCenterName := hCostCenters[LTrim(Str(hBooking["KST"]))]
            IF ValType(xCostCenterName) == "C" .AND. ! Empty(AllTrim(xCostCenterName))
               cCostCenter := hb_StrToUTF8(AllTrim(xCostCenterName))
            ENDIF
         ENDIF
         hItem["cost_center"] := cCostCenter
         hItem["description"] := hb_StrToUTF8(AllTrim(hBooking["TEXT"]))
         hItem["company_id"] := GetConfigValue("FIRMNO")
         AAdd(aBookings, hItem)
      ENDIF
   NEXT

   LX_Close()

   ? "[BU][LX] Gelesen:", nScanned, "Relevant:", nRelevant, "Items:", Len(aBookings)

RETURN aBookings

STATIC FUNCTION _CollectPurchaseOrderItems()
   LOCAL aItems := {}
   LOCAL hSupplierNames := {=>}
   LOCAL hItem
   LOCAL nScanned := 0
   LOCAL nRelevant := 0
   LOCAL nOpenQty
   LOCAL nShipQty
   LOCAL nZoQty
   LOCAL nAmount
   LOCAL nUnitPrice
   LOCAL nWait
   LOCAL dDelDate
   LOCAL dPayDate
   LOCAL cCurrency
   LOCAL cBaseRef
   LOCAL cRef
   LOCAL nItem
   LOCAL lSpread_over_period
   LOCAL lImport, nMwst, nVatRate
   LOCAL lPrePay   //war undeklariert: Zugriff lief ueber einen Memvar

   NetUse("engbes", "bes")
   NetUse("engkund", "ku")
   NetUse("skontob", "skb")

   bes->(dbSetOrder(1))
   ku->(dbSetOrder(1))
   bes->(dbGoTop())

   ? "[PO] Sammle offene Bestellungen aus ENGBES..."

   DO WHILE ! bes->(EOF())
      nScanned++
      nShipQty := bes->BeQty - bes->GelQty
      nZoQty := bes->zoQty
      nOpenQty := nShipQty + nZoQty

      IF nOpenQty > 0 .AND. (bes->Bestat < 3 .OR. (bes->Bestat > 5 .AND. bes->Bestat < 9)) //.AND. Val(Right(Str(bes->Lterm),2)) <= 52
         nRelevant++
         IF Right(Str(bes->Lterm),2) != "99"  //keine Rahmenpositionen
            dDelDate := CalWD(bes->LTerm) //+bes->ShipTime)
            lSpread_over_period := .F.
         ELSE
            dDelDate := Stod("20"+Left(Str(bes->Lterm,4),2)+"1231")
            lSpread_over_period := .T.
         ENDIF
         IF Empty(dDelDate) //.OR. dDelDate < Date()
            dDelDate := Date()
         ENDIF

         lPrePay := .F.
         nWait := 0
         IF ku->(dbSeek(bes->Liefma + "L")) 
            lPrePay := skb->(IsPrePay(ku->Skonto))
            IF ! lPrepay
               nWait := skb->(GetSkontoWait(ku->Skonto, dDelDate, Date()))
            ENDIF
         ENDIF
         dPayDate := dDelDate + nWait

         IF ! lPrePay
         nUnitPrice := bes->EkPr / Max(bes->Pe, 1) * (1 - bes->Rabatt / 100)
         cCurrency := _CurrencyISO(IF(Empty(bes->Money), "E", bes->Money))
         taxit(ku->TaxCode,@nMwst,dDelDate,.F.)
         lImport := ku->TaxCode == 0
         nVatRate := IF(lImport,19,nMwst)
         cBaseRef := "BE" + StrZero(bes->Besnr, 6) +"W"+ Str(bes->LTerm,4)

         IF nShipQty > 0
            nAmount := Round(nShipQty * nUnitPrice, 2)
            IF nAmount != 0
               cRef := cBaseRef 
               IF (nItem := AScan(aItems,{|x| x["erp_reference"] == cRef })) > 0
                  aItems[nItem]["amount"] += nAmount*(1+nMwst/100)
                  aItems[nItem]["vat_amount"] += Round(nAmount*nVatRate/100, 2)
               ELSE
                  //lEG := ! lImport .AND. Trim(Upper(v->text)) == "EG"
                  //lReverse := ! lImport .AND. Trim(Upper(v->text)) == "REVERSE"
                  hItem := {=>}
                  hItem["erp_reference"] := cRef
                  hItem["type"] := "supplier_order"
                  hItem["counterparty_name"] := _GetSupplierName(bes->Liefma, hSupplierNames)
                  hItem["amount"] := nAmount*(1+nMwst/100)  //wir rechnen immer mit 19%, da bei Einfuhr auch 19% MwSt. anfÑllt
                  hItem["vat_key"] := nMwst
                  hItem["vat_amount"] := Round(nAmount*nVatRate/100, 2)
                  hItem["vat_handling"] := IF(lImport,"import","standard")
                  hItem["currency"] := cCurrency
                  hItem["due_date"] := _IsoDate(IF(dDelDate<Date(),Date()+nWait,dPayDate))  //we have not received this yet, so we assume the payment date is the delivery date + skonto wait time
                  hItem["payment_probability"] := 1.0
                  
                  hItem["status"] := "open"
                  hItem["paid_amount"] := 0
                  hItem["spread_over_period"] := lSpread_over_period
                  IF lSpread_over_period
                     hItem["spread_start_date"] := _IsoDate(Date()+30) //Annahme: Verteilung startet in 30 Tagen, wenn Åber Zeitraum verteilt
                  ENDIF
                  hItem["company_id"] := GetConfigValue("FIRMNO")
                  AAdd(aItems, hItem)
               ENDIF
            ENDIF
         ENDIF

         IF nZoQty > 0
            nAmount := Round(nZoQty * nUnitPrice, 2)
            IF nAmount != 0
               cRef := cBaseRef + "-MI"
               IF (nItem := AScan(aItems,{|x| x["erp_reference"] == cRef })) > 0
                  aItems[nItem]["amount"] += nAmount*(1+nMwst/100)
                  aItems[nItem]["vat_amount"] += Round(nAmount*nVatRate/100, 2)
               ELSE
                  hItem := {=>}
                  hItem["erp_reference"] := cRef
                  hItem["type"] := "supplier_order"
                  hItem["counterparty_name"] := _GetSupplierName(bes->Liefma, hSupplierNames)
                  hItem["amount"] := nAmount*(1+nMwst/100)  //wir rechnen immer mit 19%, da bei Einfuhr auch 19% MwSt. anfÑllt
                  hItem["vat_key"] := nMwst
                  hItem["vat_amount"] := Round(nAmount*nVatRate/100, 2)
                  hItem["vat_handling"] := IF(lImport,"import","standard")
                  hItem["currency"] := cCurrency
                  hItem["due_date"] := _IsoDate(Min(Date()+nWait,dPayDate))
                  hItem["payment_probability"] := 1.0
                  
                  hItem["status"] := "open"
                  hItem["paid_amount"] := 0
                  hItem["spread_over_period"] := lSpread_over_period
                  IF lSpread_over_period
                     hItem["spread_start_date"] := _IsoDate(Date()+30) //Annahme: Verteilung startet in 30 Tagen, wenn Åber Zeitraum verteilt
                  ENDIF
                  hItem["company_id"] := GetConfigValue("FIRMNO")
                  AAdd(aItems, hItem)
               ENDIF
            ENDIF
         ENDIF

         ENDIF
      ENDIF

      bes->(dbSkip())
   ENDDO

   ? "[PO] Gelesen:", nScanned, "Relevant:", nRelevant, "Items:", Len(aItems)

RETURN aItems

STATIC FUNCTION _CollectCustomerOrderItems()
   LOCAL aItems := {}
   LOCAL hCustomerNames := {=>}
   LOCAL hItem
   LOCAL nScanned := 0
   LOCAL nRelevant := 0
   LOCAL nOpenQty
   LOCAL nAmount
   LOCAL nUnitPrice
   LOCAL nWait
   LOCAL dDelDate
   LOCAL dDueDate
   LOCAL nMwSt
   LOCAL cCurrency
   LOCAL nItem
   LOCAL lSpread_over_period

   NetUse("engauf", "auf")
   NetUse("engkund", "ku")
   NetUse("skontoa", "sk")

   auf->(dbSetOrder(14))
   ku->(dbSetOrder(1))
   auf->(dbGoTop())

   ? "[SO] Sammle offene KundenauftrÑge aus ENGAUF..."

   DO WHILE ! auf->(EOF()) .AND. auf->Bestat < 3
      nScanned++
      nOpenQty := auf->VkQty - auf->GelQty
    
      IF nOpenQty > 0 
         ku->(dbSeek(auf->Kundma + "K"))
         nRelevant++
         

         nUnitPrice := auf->VkPr / Max(auf->Pe, 1) * (1 - auf->Rabatt / 100)
         nAmount := Round(nOpenQty * nUnitPrice, 2)


         IF nAmount != 0 //.AND. Val(Right(Str(auf->Dterm),2)) <= 52
            IF (nItem := AScan(aItems,{|x| x["erp_reference"] == "AB" + StrZero(auf->Abnr, 6)+"W"+Str(auf->Dterm,4) })) > 0
               aItems[nItem]["amount"] += nAmount*(1+aItems[nItem]["vat_key"]/100)
            ELSE
               hItem := {=>}
               IF Right(Str(auf->Dterm),2) $ {"97","98"}
                  dDelDate := Date() + 90
                  lSpread_over_period := .F.
                  hItem["payment_probability"] := 0.5
               ELSEIF Right(Str(auf->Dterm),2) != "99"  //keine Rahmenpositionen
                  dDelDate := IF(ku->JustInTime,auf->BDatum, CalWD(auf->DTerm))
                  lSpread_over_period := .F.       
                  hItem["payment_probability"] := 0.9        
               ELSE
                  dDelDate := CalWD(auf->wTerm)
                  lSpread_over_period := .T.
                  hItem["payment_probability"] := 0.9
               ENDIF
               IF Empty(dDelDate) .OR. dDelDate < Date()
                  dDelDate := EoY(Date())
               ENDIF

               taxit(ku->TaxCode,@nMwst,dDelDate,.F.)

               nWait := sk->(GetSkontoWait(ku->Skonto, dDelDate, Date()))     
               //nWait := GetCustomerPayTime(ku->Kunde) 
               dDueDate := dDelDate + nWait

               cCurrency := _CurrencyISO(IF(Empty(auf->Money), "E", auf->Money))
               
               hItem["erp_reference"] := "AB" + StrZero(auf->Abnr, 6)+"W"+Str(auf->Dterm,4)
               hItem["type"] := "customer_order"
               hItem["counterparty_name"] := _GetCustomerName(auf->Kundma, hCustomerNames)
               hItem["amount"] := nAmount*(1+nMwst/100)
               hItem["net_amount"] := nAmount
               hItem["vat_key"] := nMwSt
               hItem["vat_amount"] := Round(nAmount*nMwst/100, 2)
               hItem["vat_handling"] := "standard"
               hItem["currency"] := cCurrency
               hItem["due_date"] := _IsoDate(dDueDate)
               
               hItem["status"] := "open"
               hItem["paid_amount"] := 0
               hItem["spread_over_period"] := lSpread_over_period
               IF lSpread_over_period
                  hItem["spread_start_date"] := _IsoDate(Max(auf->Sdatum,Date()+30)) //Annahme: Verteilung startet in 30 Tagen, wenn Åber Zeitraum verteilt
               ENDIF
               hItem["company_id"] := GetConfigValue("FIRMNO")
               AAdd(aItems, hItem)
            ENDIF
         ENDIF
      ENDIF

      auf->(dbSkip())
   ENDDO

   ? "[SO] Gelesen:", nScanned, "Relevant:", nRelevant, "Items:", Len(aItems)

RETURN aItems

STATIC FUNCTION _CollectCustomerInvoiceItems()
   LOCAL aItems := {}
   LOCAL hCustomerNames := {=>}
   LOCAL nScanned := 0
   LOCAL nRelevant := 0
   LOCAL hItem
   LOCAL cKundma
   LOCAL cCurrency
   LOCAL cCustomerName
   LOCAL cRef
   LOCAL oRechnung
   
   LOCAL nAmount
   LOCAL nWait
   LOCAL dDueDate
   LOCAL nKuNummer
   LOCAL nRechnr

   NetUse("rechnung", "reh")
   NetUse("englsre","re")
   NetUse("engkund", "ku")
   NetUse("skontoa", "sk")

   ku->(dbSetOrder(8))
   re->(dbSetOrder(5))
   re->(dbSetFilter({|| re->Code < 3 .AND. re->Status <= 1 .AND. Year(re->Rechdat) > 2020} ,"code<3 .AND. Status<=1 .AND. Year(Rechdat) > 2020"))
   re->(dbGoTop())

   ? "[CI][RH] Sammle Kundenrechnungen aus RECHNUNG ..."

   DO WHILE ! re->(EOF()) .AND. re->Reposnr == 0
      nScanned++
      reh->(dbSeek(Str(re->Rechnr,6)))

      oRechnung := Rechnung():New()
      oRechnung:Load(re->Rechnr)

      nAmount := Round(oRechnung:Brutto - oRechnung:Zahlbetrag, 2)

      IF nAmount != 0 .AND. ! _FieldValue("reh", "BEZAHLT", .F.)
         nRelevant++

         cCurrency := _CurrencyISO(_FieldValue("reh", "MONEY", "E"))
         nRechnr := _FieldValue("reh", "RECHNR", 0)
         nKuNummer := _FieldValue("reh", "KUNUMMER", 0)
         cKundma := _FieldValue("reh", "KUNDE", "")

         IF nKuNummer != 0 .AND. ku->(dbSeek(Str(nKuNummer, 6)))
            cKundma := ku->Kunde
         ELSEIF ! Empty(cKundma)
            ku->(dbSetOrder(1))
            IF ku->(dbSeek(Pad(cKundma, 8) + "K"))
               nKuNummer := ku->Nummer
            ENDIF
            ku->(dbSetOrder(8))
         ENDIF

         cCustomerName := IF(! Empty(cKundma), _GetCustomerName(cKundma, hCustomerNames), "Debitor " + LTrim(Str(nKuNummer)))

         nWait := 0
         IF ! Empty(cKundma) .AND. ku->(dbSetOrder(1), dbSeek(Pad(cKundma,8)+"K"))
            nWait := sk->(GetSkontoWait(ku->Skonto, _FieldValue("reh", "RECHDAT", Date()), Date()))
            ku->(dbSetOrder(8))
         ENDIF
         //nWait := GetCustomerPayTime(ku->Kunde)
         dDueDate := oRechnung:Rechdat + nWait
         
         hItem := {=>}
         cRef := "RE" + StrZero(nRechnr,6)
         hItem["erp_reference"] := cRef
         hItem["type"] := "customer_invoice"
         hItem["counterparty_name"] := hb_StrToUTF8(Trim(cCustomerName))
         hItem["amount"] := oRechnung:Brutto
         hItem["net_amount"] := oRechnung:Brutto - oRechnung:Mwst
         hItem["vat_key"] := oRechnung:MwstRate
         hItem["vat_amount"] := oRechnung:Mwst
         hItem["vat_handling"] := "standard"
         hItem["currency"] := cCurrency
         hItem["due_date"] := _IsoDate(dDueDate)
         //Rechnungsdatum. Die Faelligkeit allein reicht der Zahlungs-
         //zuordnung nicht: an ihr faellt nicht auf, wenn eine Zahlung
         //aelter ist als die Rechnung, die ihr zugeordnet werden soll.
         hItem["document_date"] := _IsoDate(oRechnung:Rechdat)
         IF Date()-365 > oRechnung:Rechdat //alte Gutschriften eher unwahrscheinlich
            hItem["payment_probability"] := Max(0.8-(Year(Date())-Year(oRechnung:Rechdat))*0.2,0)
         ELSEIF Abs(oRechnung:Brutto-oRechnung:Zahlbetrag) < Abs(oRechnung:Brutto * 0.05) //fast vollstÑndig bezahlt
            hItem["payment_probability"] := 0.01
         ELSE
            hItem["payment_probability"] := 0.95
         ENDIF
         hItem["status"] := "open"
         hItem["paid_amount"] := Max(0, Round(oRechnung:Zahlbetrag, 2))
         hItem["company_id"] := GetConfigValue("FIRMNO")
         AAdd(aItems, hItem)
      ENDIF

      re->(dbSkip())
   ENDDO

   ? "[CI][RH] Gelesen:", nScanned, "Relevant:", nRelevant, "Items:", Len(aItems)

RETURN aItems

STATIC FUNCTION _CollectPaidCustomerInvoiceItems()
   //Bezahlte Kundenrechnungen ab 2026.
   //
   //Finova braucht das ganze Rechnungsbuch, nicht nur den heute offenen
   //Ausschnitt: eine Zahlung gehoert fast immer zu einer Rechnung, die die
   //Buchhaltung laengst gebucht hat. Ohne sie findet die Zuordnung ihren
   //Gegenpart nicht - 654 der 763 ungeklaerten Zahlungseingaenge nennen
   //eine Rechnungsnummer, zu der es in Finova keinen Posten mehr gibt.
   //
   //Bewusst ein eigener Durchlauf statt einer Erweiterung von
   //_CollectCustomerInvoiceItems: dessen Filter laesst bezahlte Rechnungen
   //gar nicht erst durch (Code < 3 .AND. Status <= 1), und an diesem Filter
   //haengt der Liquiditaetsplan. Ihn zu weiten hiesse, die Kernaufgabe der
   //App anzufassen, um eine Nebenaufgabe zu bedienen.
   //
   //Bezahlt ist laut model/rechnung.prg: Code >= 3 .AND. Status == 3.
   //
   //Die Schleife laeuft bis EOF und filtert Positionszeilen ueber den
   //Filter statt ueber eine Abbruchbedingung. Damit haengt sie an keiner
   //Indexreihenfolge - anders als der offene Sammler, der bei der ersten
   //Positionszeile stehenbleibt.
   LOCAL aItems := {}
   LOCAL hCustomerNames := {=>}
   LOCAL nScanned := 0
   LOCAL nRelevant := 0
   LOCAL hItem
   LOCAL cKundma
   LOCAL cCurrency
   LOCAL cCustomerName
   LOCAL cRef
   LOCAL oRechnung
   LOCAL nWait
   LOCAL nKuNummer
   LOCAL nRechnr

   NetUse("rechnung", "reh")
   NetUse("englsre","re")
   NetUse("engkund", "ku")
   NetUse("skontoa", "sk")

   ku->(dbSetOrder(8))
   re->(dbSetOrder(5))
   re->(dbSetFilter({|| re->Reposnr == 0 .AND. re->Code >= 3 .AND. ;
                        re->Status == 3 .AND. Year(re->Rechdat) >= 2026}, ;
                    "Reposnr == 0 .AND. Code >= 3 .AND. Status == 3 .AND. Year(Rechdat) >= 2026"))
   re->(dbGoTop())

   ? "[CIP][RH] Sammle bezahlte Kundenrechnungen ab 2026 ..."

   DO WHILE ! re->(EOF())
      nScanned++
      reh->(dbSeek(Str(re->Rechnr,6)))

      oRechnung := Rechnung():New()
      oRechnung:Load(re->Rechnr)

      nRelevant++
      cCurrency := _CurrencyISO(_FieldValue("reh", "MONEY", "E"))
      nRechnr := _FieldValue("reh", "RECHNR", 0)
      nKuNummer := _FieldValue("reh", "KUNUMMER", 0)
      cKundma := _FieldValue("reh", "KUNDE", "")

      IF nKuNummer != 0 .AND. ku->(dbSeek(Str(nKuNummer, 6)))
         cKundma := ku->Kunde
      ELSEIF ! Empty(cKundma)
         ku->(dbSetOrder(1))
         IF ku->(dbSeek(Pad(cKundma, 8) + "K"))
            nKuNummer := ku->Nummer
         ENDIF
         ku->(dbSetOrder(8))
      ENDIF

      cCustomerName := IF(! Empty(cKundma), _GetCustomerName(cKundma, hCustomerNames), "Debitor " + LTrim(Str(nKuNummer)))

      nWait := 0
      IF ! Empty(cKundma) .AND. ku->(dbSetOrder(1), dbSeek(Pad(cKundma,8)+"K"))
         nWait := sk->(GetSkontoWait(ku->Skonto, _FieldValue("reh", "RECHDAT", Date()), Date()))
         ku->(dbSetOrder(8))
      ENDIF

      hItem := {=>}
      cRef := "RE" + StrZero(nRechnr,6)
      hItem["erp_reference"] := cRef
      hItem["type"] := "customer_invoice"
      hItem["counterparty_name"] := hb_StrToUTF8(Trim(cCustomerName))
      hItem["amount"] := oRechnung:Brutto
      hItem["net_amount"] := oRechnung:Brutto - oRechnung:Mwst
      hItem["vat_key"] := oRechnung:MwstRate
      hItem["vat_amount"] := oRechnung:Mwst
      hItem["vat_handling"] := "standard"
      hItem["currency"] := cCurrency
      hItem["due_date"] := _IsoDate(oRechnung:Rechdat + nWait)
      hItem["document_date"] := _IsoDate(oRechnung:Rechdat)
      //Bezahlt - faellt in keine Vorschau mehr.
      hItem["payment_probability"] := 0
      hItem["status"] := "paid"
      hItem["paid_amount"] := Max(0, Round(oRechnung:Zahlbetrag, 2))
      hItem["company_id"] := GetConfigValue("FIRMNO")
      AAdd(aItems, hItem)

      re->(dbSkip())
   ENDDO

   re->(dbClearFilter())

   ? "[CIP][RH] Gelesen:", nScanned, "Relevant:", nRelevant, "Items:", Len(aItems)

RETURN aItems

STATIC FUNCTION _CollectPurchaseInvoiceItems()
   LOCAL aItems, aEngRech

   ? "[PI] Sammle offene Eingangsrechnungen (Lexware + ENGRECH)..."
   aItems := _CollectPurchaseInvoiceItemsFromLexware()
   ? "[PI] Lexware Items:", Len(aItems)
   aEngRech := _CollectPurchaseInvoiceItemsFromEngRech()
   ? "[PI] ENGRECH (noch nicht uebertragen) Items:", Len(aEngRech)
   AEval(aEngRech, {|hItem| AAdd(aItems, hItem)})
   ? "[PI] Gesamt Items:", Len(aItems)

RETURN aItems

STATIC FUNCTION _CollectPurchaseInvoiceItemsFromLexware()
   LOCAL aItems := {}
   LOCAL hSupplierNames := {=>}
   LOCAL hOpSummen
   LOCAL nKonto
   LOCAL nAccounts := 0
   LOCAL nOps := 0
   LOCAL aOps
   LOCAL nX
   LOCAL hOp
   LOCAL hItem
   LOCAL cLiefma
   LOCAL cCurrency
   LOCAL cSupplierName
   LOCAL cRef
   LOCAL nAmount
   LOCAL nPaidAmount
   LOCAL lStarted
   LOCAL cBeleg
   LOCAL lPrePay   //war undeklariert: Zugriff lief ueber einen Memvar

   NetUse("fibu", "fibu")
   NetUse("engkund", "ku")
   Netuse("skontob", "skb")

   
   ku->(dbSetOrder(8))

   ? "[PI][LX] Starte Lexware Verbindung..."
   lStarted := LX_Start()
   IF ! lStarted
      ? "[PI][LX] Lexware Start fehlgeschlagen"
      RETURN aItems
   ENDIF
   ? "[PI][LX] Lexware verbunden"

   hOpSummen := LX_GetOffenePostenSummen(.F.)
   ? "[PI][LX] Kreditoren mit OP:", Len(hOpSummen)
   FOR EACH nKonto IN hOpSummen      
      nAccounts++
      cCurrency := "E"
      cLiefma := ""
      cSupplierName := ""
      lPrePay := .F.

      fibu->(dbSetOrder(2))
      ku->(dbSetOrder(8))
      //? nKonto:__eNumKey()
      IF fibu->(dbSeek(Str(nKonto:__eNumKey(), 6)))         
         cCurrency := IF(Empty(fibu->Currency), "E", fibu->Currency)
         IF fibu->Adresse != 0 .AND. ku->(dbSeek(Str(fibu->Adresse, 6)))            
            cLiefma := ku->Kunde
            lPrePay := skb->(IsPrePay(ku->Skonto)) //PrePay prÅfen
            cSupplierName := _GetSupplierName(cLiefma, hSupplierNames)
            //?? "",cSupplierName
         ELSE
            //?? " kein Lieferant",fibu->Adresse
         ENDIF
      ELSE         
         fibu->(dbSetOrder(3))
         IF fibu->(dbSeek(Str(nKonto:__eNumKey(), 6)))  //WD Konto, kann ignoriert werden
            //?? " WÑhrungsdifferenz Konto",fibu->Konto
            LOOP
         ENDIF
         //?? " kein Fibu"
      ENDIF
      IF ! lPrePay
         IF Empty(cSupplierName)
            cSupplierName := "Kreditor " + LTrim(Str(nKonto:__eNumKey()))
         ENDIF

         aOps := LX_GetOffenePosten(nKonto:__eNumKey(), .F.)
         nOps += Len(aOps)
         FOR nX := 1 TO Len(aOps)
            hOp := aOps[nX]
            nAmount := Round(hOp["BETRAG"], 2)

            IF nAmount != 0  .AND. hOp["FAELLIG"] >= Date()-30 
               nPaidAmount := Round(hOp["BETRAG"] - hOp["REST"], 2)

               hItem := {=>}
               cBeleg := Trim(hOp["BELEGNR"])
               IF Empty(cBeleg)
                  cBeleg := "OP"+Ltrim(Str(hOP["NR"]))
               ENDIF
               IF ! Empty(cLiefma)
                  cRef := "ER-" + Trim(cLiefma) + "-" + cBeleg
               ELSE
                  cRef := "ER-KONTO-" + LTrim(Str(nKonto:__eNumKey())) + "-" + cBeleg
               ENDIF
               hItem["erp_reference"] := cRef
               hItem["type"] := "supplier_invoice"
               hItem["counterparty_name"] := hb_StrToUTF8(Trim(cSupplierName))
               hItem["amount"] := nAmount
               hItem["net_amount"] := Round(nAmount - hOp["STEUER"]/100, 2)
               hItem["vat_amount"] := Round(hOp["STEUER"], 2)
               hItem["vat_handling"] := "standard"
               hItem["currency"] := _CurrencyISO(cCurrency)
               hItem["due_date"] := _IsoDate(hOp["FAELLIG"])
               
               IF nAmount < 0 .AND. hOp["FAELLIG"] < Date()-10 //vermutlich Gutschrift, die ÅberfÑllig ist
                  hItem["payment_probability"] := 0.01
               ELSE
                  hItem["payment_probability"] := 1.0
               ENDIF
               hItem["status"] := "open"
               hItem["paid_amount"] := nPaidAmount
               hItem["company_id"] := GetConfigValue("FIRMNO")
               AAdd(aItems, hItem)
            ENDIF
         NEXT
      ENDIF
   NEXT

   LX_Close()
   ? "[PI][LX] Konten:", nAccounts, "OP Positionen:", nOps, "Items:", Len(aItems)

RETURN aItems

STATIC FUNCTION _CollectPurchaseInvoiceItemsFromEngRech()
   //Eingangsrechnungen, die noch NICHT nach Lexware uebertragen wurden
   //(! Transfer) - diese fehlen in den Lexware-OPs. Sobald eine Position
   //erfasst wird, ist sie zudem aus bes->ZoQty heraus (siehe PO-Sync), taucht
   //also sonst nirgends auf.
   //  - gebucht (Booked):       Bruttobetrag der Rechnung (Kopf massgeblich)
   //  - nur teilweise erfasst:  nur die erfassten Positionen, da nur diese
   //                            schon aus ZoQty entfernt wurden.
   //Transfer wurde erst ab 2016 gepflegt -> Datumsuntergrenze.
   LOCAL aItems := {}
   LOCAL hSupplierNames := {=>}
   LOCAL hItem
   LOCAL nScanned := 0, nRelevant := 0
   LOCAL nNet, nGross, nMwst, nVatRate, nVatAmount
   LOCAL lImport
   LOCAL dDueDate
   LOCAL cCurrency, cRef

   NetUse("engrech", "rech")
   NetUse("rechpos", "rpos")
   NetUse("engkund", "ku")

   ku->(dbSetOrder(1))
   rech->(dbSetOrder(0))
   rech->(dbGoTop())

   ? "[PI][ENGRECH] Sammle noch nicht uebertragene Eingangsrechnungen..."

   DO WHILE ! rech->(EOF())
      nScanned++
      IF ! rech->Transfer .AND. rech->Status == 0 .AND. rech->Payme == 0 .AND. rech->Rechdat >= SToD("20160101") .AND. ! Empty(rech->Liefma) .AND. ! Empty(rech->Rechnr)

         IF rech->Booked
            nNet   := rech->Netamt
            nGross := rech->GrAmt
         ELSE
            nNet   := _ErfassteRePosNet(rech->Liefma, rech->Rechnr)
            nGross := nNet  //MwSt wird unten wie beim Bestell-Sync ergaenzt
         ENDIF

         IF nNet != 0 .OR. nGross != 0
            nRelevant++

            ku->(dbSetOrder(1))
            ku->(dbSeek(rech->Liefma + "L"))  //fuer TaxCode; wenn nicht gefunden -> Standard
            taxit(ku->TaxCode, @nMwst, rech->Rechdat, .F.)
            lImport  := ku->TaxCode == 0
            nVatRate := IF(lImport, 19, nMwst)

            IF rech->Booked
               //echte Kopfwerte (inkl. Porto, tatsaechliche MwSt)
               nVatAmount := Round(nGross - nNet, 2)
            ELSE
               //erfasste Positionen wie ZoQty-Items bewerten (Import: 19% Annahme)
               nGross     := Round(nNet * (1 + nVatRate/100), 2)
               nVatAmount := Round(nNet * nVatRate/100, 2)
            ENDIF

            dDueDate := rech->Rechdat + Max(rech->Wait, rech->WAITSkonto)
            IF Empty(dDueDate)
               dDueDate := rech->Rechdat
            ENDIF
            IF Empty(dDueDate)
               dDueDate := Date()
            ENDIF

            cCurrency := _CurrencyISO(IF(Empty(rech->Money), "E", rech->Money))
            cRef := "ER-NT-" + Trim(rech->Liefma) + "-" + Trim(rech->Rechnr)

            hItem := {=>}
            hItem["erp_reference"]       := cRef
            hItem["type"]                := "supplier_invoice"
            hItem["counterparty_name"]   := _GetSupplierName(rech->Liefma, hSupplierNames)
            hItem["amount"]              := Round(nGross, 2)
            hItem["net_amount"]          := Round(nNet, 2)
            hItem["vat_key"]             := nVatRate
            hItem["vat_amount"]          := nVatAmount
            hItem["vat_handling"]        := IF(lImport, "import", "standard")
            hItem["currency"]            := cCurrency
            hItem["due_date"]            := _IsoDate(dDueDate)
            hItem["payment_probability"] := 1.0
            hItem["status"]              := "open"
            hItem["paid_amount"]         := 0
            hItem["company_id"]          := GetConfigValue("FIRMNO")
            AAdd(aItems, hItem)
         ENDIF
      ENDIF

      rech->(dbSkip())
   ENDDO

   ? "[PI][ENGRECH] Gelesen:", nScanned, "Relevant:", nRelevant, "Items:", Len(aItems)

RETURN aItems

STATIC FUNCTION _ErfassteRePosNet(cLiefma, cReNr)
   //Summe der bereits erfassten Rechnungspositionen (Nettowert) einer
   //Eingangsrechnung - analog zur Bewertung "WE ohne Rechnung" (ZoQty).
   LOCAL nSum := 0
   LOCAL nOrder := rpos->(IndexOrd())
   rpos->(dbSetOrder(1)) //liefma+beleg+belegpos
   IF rpos->(dbSeek(cLiefma + cReNr))
      DO WHILE ! rpos->(EOF()) .AND. rpos->Liefma == cLiefma .AND. rpos->Beleg == cReNr
         nSum += rpos->Menge * rpos->EkPr / Max(rpos->Pe, 1) * (1 - rpos->Rabatt/100)
         rpos->(dbSkip())
      ENDDO
   ENDIF
   rpos->(dbSetOrder(nOrder))
RETURN nSum


STATIC FUNCTION _GetSupplierName(cLiefma, hSupplierNames)
   LOCAL cName

   IF HHasKey(hSupplierNames, cLiefma)
      RETURN hSupplierNames[cLiefma]
   ENDIF

   cName := Trim(cLiefma)
   ku->(dbSetOrder(1))
   IF ku->(dbSeek(cLiefma + "L"))
      cName := IF(! Empty(Trim(ku->Name1)), Trim(ku->Name1), Trim(ku->Kunde))
   ENDIF
   hSupplierNames[cLiefma] := hb_StrToUTF8(cName)

RETURN hSupplierNames[cLiefma]

STATIC FUNCTION _GetCustomerName(cKundma, hCustomerNames)
   LOCAL cName

   IF HHasKey(hCustomerNames, cKundma)
      RETURN hCustomerNames[cKundma]
   ENDIF

   cName := Trim(cKundma)
   IF ku->(dbSeek(cKundma + "K"))
      cName := IF(! Empty(Trim(ku->Name1)), Trim(ku->Name1), Trim(ku->Kunde))
   ENDIF
   hCustomerNames[cKundma] := hb_StrToUTF8(cName)

RETURN hCustomerNames[cKundma]

STATIC FUNCTION _CurrencyISO(cCurrency)
   LOCAL hMap := {"E" => "EUR", "U" => "USD", "P" => "GBP","Y"=>"JPY"}
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

STATIC FUNCTION _FieldValue(cAlias, cField, xDefault)
   LOCAL nPos

   nPos := (cAlias)->(FieldPos(cField))
   IF nPos > 0
      RETURN (cAlias)->(FieldGet(nPos))
   ENDIF

RETURN xDefault

STATIC FUNCTION _SplitIntoBatches(aSource, nBatchSize)
   LOCAL aBatches := {}
   LOCAL aBatch
   LOCAL nFrom
   LOCAL nTo
   LOCAL nIdx

   Default(@aSource, {})
   Default(@nBatchSize, 250)

   IF ValType(aSource) != "A" .OR. Len(aSource) == 0
      RETURN aBatches
   ENDIF

   IF nBatchSize <= 0
      nBatchSize := 250
   ENDIF

   FOR nFrom := 1 TO Len(aSource) STEP nBatchSize
      nTo := Min(nFrom + nBatchSize - 1, Len(aSource))
      aBatch := {}
      FOR nIdx := nFrom TO nTo
         AAdd(aBatch, aSource[nIdx])
      NEXT
      AAdd(aBatches, aBatch)
   NEXT

RETURN aBatches

STATIC FUNCTION _GetLiquidityUserId()
   /*LOCAL cUserId := GetConfigValue("LIQUIDITY_USER_ID")

  IF Empty(cUserId)
    cUserId := GetValue("LIQUIDITY_USER_ID", "")
  ENDIF

RETURN Trim(cUserId)*/
RETURN "6efd3371-fc1a-4883-a0ad-cf540a3f84ee"  //amos



