FUNCTION RUN_SYNC_SUPABASE_LIQUIDITY(cUserId)
   LOCAL oRest := RestApi():New()
   LOCAL aItems := {}
   LOCAL aInvItems
   LOCAL aCustOrdItems
   LOCAL aCustInvItems
   LOCAL aBookings
   LOCAL hBody := {=>}
   LOCAL aHeader := {}
   LOCAL cResponse
   LOCAL hResponse

   Default(@cUserId, "")

   Head("Daten an Liquidity Monitor senden")

   IF Empty(cUserId)
      cUserId := _GetLiquidityUserId()
   ENDIF

   IF Empty(cUserId)
      Tr_MsgBox("Kein Liquidity user_id konfiguriert (LIQUIDITY_USER_ID)")
      RETURN .F.
   ENDIF

   ? "----------------------------------------------"
   ? "Liquidity Sync gestartet:", DToC(Date()), Time()
   ? "User:", cUserId

   aItems := _CollectPurchaseOrderItems()
   ? "Purchase Orders gesammelt:", Len(aItems)

  aInvItems := _CollectPurchaseInvoiceItems()
  ? "Purchase Invoices gesammelt:", Len(aInvItems)
  AEval(aInvItems, {|hItem| AAdd(aItems, hItem)})

  /*aCustOrdItems := _CollectCustomerOrderItems()
  ? "Customer Orders gesammelt:", Len(aCustOrdItems)
  AEval(aCustOrdItems, {|hItem| AAdd(aItems, hItem)})

  aCustInvItems := _CollectCustomerInvoiceItems()
  ? "Customer Invoices gesammelt:", Len(aCustInvItems)
  AEval(aCustInvItems, {|hItem| AAdd(aItems, hItem)})

  aBookings := _CollectLexwareBookings()
  ? "Lexware Buchungen gesammelt:", Len(aBookings)*/

   ? "Gesamt Items fr Upload:", Len(aItems)

   /*IF Len(aItems) == 0
      ? "Keine offenen Daten fr Liquidity gefunden"
      IF ! GetConfigValue("BATCHMODE")
         Sinkey(0)
      ENDIF
      RETURN .T.
   ENDIF*/

   hBody["user_id"] := cUserId
   hBody["items"] := aItems
   hBody["bookings"] := aBookings
   hBody["replace_all"] := .T.
   hBody["replace_all_bookings"] := .T.

   oRest:cBaseUrl := "https://fhyvjvjyszbqzefwvtpz.supabase.co/"
   oRest:cApiKeyName := "LIQUIDITY"

   AAdd(aHeader, "x-api-key: $APIKEY$")
   AAdd(aHeader, "accept: application/json")
   AAdd(aHeader, "content-type: application/json")

   ? "Sende Daten an Supabase Funktion: functions/v1/erp-push"

   cResponse := oRest:Execute("functions/v1/erp-push", "POST", hBody, aHeader, .T.)

   IF Empty(cResponse)
      ? "Liquidity Sync fehlgeschlagen: keine Antwort"
      IF ! GetConfigValue("BATCHMODE")
         Sinkey(0)
      ENDIF
      RETURN .F.
   ENDIF

   hResponse := HB_JsonDecode(cResponse)
   IF ValType(hResponse) == "H" .AND. HHasKey(hResponse, "success") .AND. hResponse["success"]
      ? "Liquidity Sync erfolgreich."
      IF HHasKey(hResponse, "items_synced")
         ? "ERP Elemente: "+LTrim(Str(hResponse["items_synced"]))
      ENDIF
      IF HHasKey(hResponse, "bookings_synced")
         ? "Kostenbuchungen: "+LTrim(Str(hResponse["bookings_synced"]))
      ENDIF
      //MemoEdit(cResponse)

      IF HHasKey(hResponse, "errors")     
         ? "Fehler: "+LTrim(Str(Len(hResponse["errors"])))
         IF Len(hResponse["errors"]) > 0
            //? "Error Details:", HB_JsonEncode(hResponse["errors"])
            ? "Beispiel Fehler:", HB_JsonEncode(hResponse["errors"][1])
         ENDIF    
      ENDIF
      IF ! GetConfigValue("BATCHMODE")
         Sinkey(0)
      ENDIF
      //? "Antwort:", cResponse
      RETURN .T.
   ENDIF

   ? "Liquidity Sync Antwort:", cResponse
   IF ! GetConfigValue("BATCHMODE")
      Sinkey(0)
   ENDIF  
RETURN .F.

STATIC FUNCTION _CollectLexwareBookings()
   LOCAL aBookings := {}
   LOCAL aLxBookings
   LOCAL hCostCenters
   LOCAL hBooking
   LOCAL hItem
   LOCAL nYear := Year(Date())
   LOCAL nScanned := 0
   LOCAL nRelevant := 0
   LOCAL hNummern := {=>}
   LOCAL xCostCenterName
   LOCAL cCostCenter

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
   LOCAL nAmount
   LOCAL nUnitPrice
   LOCAL nWait
   LOCAL dDelDate
   LOCAL dPayDate
   LOCAL cCurrency
   LOCAL nItem
   LOCAL lSpread_over_period

   NetUse("engbes", "bes")
   NetUse("engkund", "ku")
   NetUse("skontob", "skb")

   bes->(dbSetOrder(1))
   ku->(dbSetOrder(1))
   bes->(dbGoTop())

   ? "[PO] Sammle offene Bestellungen aus ENGBES..."

   DO WHILE ! bes->(EOF())
      nScanned++
      nOpenQty := bes->BeQty - bes->GelQty + bes->zoQty  //unerechnete Menge bercksichtigen

      IF nOpenQty > 0 .AND. (bes->Bestat < 3 .OR. (bes->Bestat > 5 .AND. bes->Bestat < 9)) .AND. Val(Right(Str(bes->Lterm),2)) <= 52
         nRelevant++
         IF Right(Str(bes->Lterm),2) != "99"  //keine Rahmenpositionen
            dDelDate := CalWD(bes->LTerm+bes->ShipTime)
            lSpread_over_period := .F.
         ELSE
            dDelDate := Stod("20"+Left(Str(bes->Lterm,4),2)+"1231")
            lSpread_over_period := .T.
         ENDIF
         IF Empty(dDelDate) .OR. dDelDate < Date()
            dDelDate := EoY(Date()) 
         ENDIF

         IF ku->(dbSeek(bes->Liefma + "L")) .AND. ! skb->(IsPrePay(ku->Skonto))
            nWait := skb->(GetSkontoWait(ku->Skonto, dDelDate, Date()))
         ELSE
            nWait := 0
         ENDIF
         dPayDate := dDelDate + nWait

         nUnitPrice := bes->EkPr / Max(bes->Pe, 1) * (1 - bes->Rabatt / 100)
         nAmount := Round(nOpenQty * nUnitPrice, 2)

         IF nAmount != 0
            IF (nItem := AScan(aItems,{|x| x["erp_reference"] == "BE" + StrZero(bes->Besnr, 6) +"W"+ Str(bes->LTerm,4) })) > 0
               aItems[nItem]["amount"] += nAmount
            ELSE
               cCurrency := _CurrencyISO(IF(Empty(bes->Money), "E", bes->Money))
               hItem := {=>}
               hItem["erp_reference"] := "BE" + StrZero(bes->Besnr, 6) +"W"+ Str(bes->LTerm,4)
               hItem["type"] := "supplier_order"
               hItem["counterparty_name"] := _GetSupplierName(bes->Liefma, hSupplierNames)
               hItem["amount"] := nAmount
               hItem["currency"] := cCurrency
               hItem["due_date"] := _IsoDate(dPayDate)
               hItem["payment_probability"] := 1.0
               
               hItem["status"] := "open"
               hItem["paid_amount"] := 0
               hItem["spread_over_period"] := lSpread_over_period
               IF lSpread_over_period
                  hItem["spread_start_date"] := _IsoDate(Date()+30) //Annahme: Verteilung startet in 30 Tagen, wenn ber Zeitraum verteilt
               ENDIF
               AAdd(aItems, hItem)
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
   LOCAL cCurrency
   LOCAL nItem
   LOCAL lSpread_over_period

   NetUse("engauf", "auf")
   NetUse("engkund", "ku")
   NetUse("skontoa", "sk")

   auf->(dbSetOrder(14))
   ku->(dbSetOrder(1))
   auf->(dbGoTop())

   ? "[SO] Sammle offene Kundenauftr„ge aus ENGAUF..."

   DO WHILE ! auf->(EOF()) .AND. auf->Bestat < 3
      nScanned++
      nOpenQty := auf->VkQty - auf->GelQty
    
      IF nOpenQty > 0 
         ku->(dbSeek(auf->Kundma + "K"))
         nRelevant++

         nUnitPrice := auf->VkPr / Max(auf->Pe, 1) * (1 - auf->Rabatt / 100)
         nAmount := Round(nOpenQty * nUnitPrice, 2)


         IF nAmount != 0 .AND. Val(Right(Str(auf->Dterm),2)) <= 52
            IF (nItem := AScan(aItems,{|x| x["erp_reference"] == "AB" + StrZero(auf->Abnr, 6)+"W"+Str(auf->Dterm,4) })) > 0
               aItems[nItem]["amount"] += nAmount
            ELSE
               IF Right(Str(auf->Dterm),2) != "99"  //keine Rahmenpositionen
                  dDelDate := IF(ku->JustInTime,auf->BDatum, CalWD(auf->DTerm))
                  lSpread_over_period := .F.
               ELSE
                  dDelDate := CalWD(auf->wTerm)
                  lSpread_over_period := .T.
               ENDIF
               IF Empty(dDelDate) //.OR. dDelDate < Date()
                  dDelDate := Date()
               ENDIF

               nWait := sk->(GetSkontoWait(ku->Skonto, dDelDate, Date()))      
               dDueDate := dDelDate + nWait

               cCurrency := _CurrencyISO(IF(Empty(auf->Money), "E", auf->Money))
               hItem := {=>}
               hItem["erp_reference"] := "AB" + StrZero(auf->Abnr, 6)+"W"+Str(auf->Dterm,4)
               hItem["type"] := "customer_order"
               hItem["counterparty_name"] := _GetCustomerName(auf->Kundma, hCustomerNames)
               hItem["amount"] := nAmount
               hItem["currency"] := cCurrency
               hItem["due_date"] := _IsoDate(dDueDate)
               hItem["payment_probability"] := 0.9
               hItem["status"] := "open"
               hItem["paid_amount"] := 0
               hItem["spread_over_period"] := lSpread_over_period
               IF lSpread_over_period
                  hItem["spread_start_date"] := _IsoDate(Date()+30) //Annahme: Verteilung startet in 30 Tagen, wenn ber Zeitraum verteilt
               ENDIF
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
         dDueDate := oRechnung:Rechdat + nWait
         
         hItem := {=>}
         cRef := "RE" + StrZero(nRechnr,6)
         hItem["erp_reference"] := cRef
         hItem["type"] := "customer_invoice"
         hItem["counterparty_name"] := hb_StrToUTF8(Trim(cCustomerName))
         hItem["amount"] := oRechnung:Brutto
         hItem["currency"] := cCurrency
         hItem["due_date"] := _IsoDate(dDueDate)
         IF Date()-365 > oRechnung:Rechdat //alte Gutschriften eher unwahrscheinlich
            hItem["payment_probability"] := Max(0.8-(Year(Date())-Year(oRechnung:Rechdat))*0.2,0)
         ELSEIF Abs(oRechnung:Brutto-oRechnung:Zahlbetrag) < Abs(oRechnung:Brutto * 0.05) //fast vollst„ndig bezahlt
            hItem["payment_probability"] := 0.01
         ELSE
            hItem["payment_probability"] := 0.95
         ENDIF
         hItem["status"] := "open"
         hItem["paid_amount"] := Max(0, Round(oRechnung:Zahlbetrag, 2))
         AAdd(aItems, hItem)
      ENDIF

      re->(dbSkip())
   ENDDO

   ? "[CI][RH] Gelesen:", nScanned, "Relevant:", nRelevant, "Items:", Len(aItems)

RETURN aItems

STATIC FUNCTION _CollectPurchaseInvoiceItems()
   LOCAL aItems

   ? "[PI] Sammle offene Eingangsrechnungen (Lexware + Fallback ENGRECH)..."
   aItems := _CollectPurchaseInvoiceItemsFromLexware()
   ? "[PI] Lexware Items:", Len(aItems)
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

   NetUse("fibu", "fibu")
   NetUse("engkund", "ku")

   
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

      fibu->(dbSetOrder(2))
      IF fibu->(dbSeek(Str(nKonto:__eNumKey(), 6)))
         cCurrency := IF(Empty(fibu->Currency), "E", fibu->Currency)
         IF fibu->Adresse != 0 .AND. ku->(dbSeek(Str(fibu->Adresse, 6)))
            cLiefma := ku->Kunde
            cSupplierName := _GetSupplierName(cLiefma, hSupplierNames)
         ENDIF
      ELSE
         fibu->(dbSetOrder(3))
         IF fibu->(dbSeek(Str(nKonto:__eNumKey(), 6)))  //WD Konto, kann ignoriert werden
            LOOP
         ENDIF
      ENDIF

      IF Empty(cSupplierName)
         cSupplierName := "Kreditor " + LTrim(Str(nKonto:__eNumKey()))
      ENDIF

      aOps := LX_GetOffenePosten(nKonto:__eNumKey(), .F.)
      nOps += Len(aOps)
      FOR nX := 1 TO Len(aOps)
         hOp := aOps[nX]
         nAmount := Round(hOp["BETRAG"], 2)

         IF nAmount != 0
            nPaidAmount := Max(0, Round(hOp["BETRAG"] - hOp["REST"], 2))

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
            hItem["currency"] := _CurrencyISO(cCurrency)
            hItem["due_date"] := _IsoDate(hOp["FAELLIG"])
            IF nAmount < 0 .AND. hOp["FAELLIG"] < Date()-365 //vermutlich Gutschrift, die schon lange berf„llig ist
               hItem["payment_probability"] := 0.01
            ELSE
               hItem["payment_probability"] := 1.0
            ENDIF
            hItem["status"] := "open"
            hItem["paid_amount"] := nPaidAmount
            AAdd(aItems, hItem)
         ENDIF
      NEXT
   NEXT

   LX_Close()
   ? "[PI][LX] Konten:", nAccounts, "OP Positionen:", nOps, "Items:", Len(aItems)

RETURN aItems

STATIC FUNCTION _CollectPurchaseInvoiceItemsFromEngRech()
   LOCAL aItems := {}
   LOCAL hSupplierNames := {=>}
   LOCAL hItem
   LOCAL nScanned := 0
   LOCAL nAmount
   LOCAL dDueDate
   LOCAL cCurrency

   NetUse("engrech", "rech")
   NetUse("engkund", "ku")

   rech->(dbSetOrder(2))
   ku->(dbSetOrder(1))
   rech->(dbGoTop())

   ? "[PI][ENGRECH] Prfe Fallback-Daten..."

   DO WHILE ! rech->(EOF())
      nScanned++
      IF rech->Status < 3 .AND. ! Empty(rech->Liefma) .AND. ! Empty(rech->Rechnr)
         nAmount := IF(rech->Pay != 0, rech->Pay, rech->GrAmt)
         IF nAmount != 0
            dDueDate := rech->Rechdat + IF(rech->Skonto == 0 .AND. rech->WAITSkonto > 0, rech->WAITSkonto, rech->Wait)
            IF Empty(dDueDate)
               dDueDate := rech->Rechdat
            ENDIF

            cCurrency := _CurrencyISO(IF(Empty(rech->Money), "E", rech->Money))

            hItem := {=>}
            hItem["erp_reference"] := "PI-" + Trim(rech->Liefma) + "-" + Trim(rech->Rechnr)
            hItem["type"] := "purchase_invoice"
            hItem["counterparty_name"] := _GetSupplierName(rech->Liefma, hSupplierNames)
            hItem["amount"] := Round(nAmount, 2)
            hItem["currency"] := cCurrency
            hItem["due_date"] := _IsoDate(dDueDate)
            hItem["payment_probability"] := 1.0
            hItem["status"] := "open"
            hItem["paid_amount"] := 0
            AAdd(aItems, hItem)
         ENDIF
      ENDIF

      rech->(dbSkip())
   ENDDO

   ? "[PI][ENGRECH] Gelesen:", nScanned, "Items:", Len(aItems)

RETURN aItems

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

STATIC FUNCTION _GetLiquidityUserId()
   /*LOCAL cUserId := GetConfigValue("LIQUIDITY_USER_ID")

  IF Empty(cUserId)
    cUserId := GetValue("LIQUIDITY_USER_ID", "")
  ENDIF

RETURN Trim(cUserId)*/
RETURN "6efd3371-fc1a-4883-a0ad-cf540a3f84ee"  //amos



