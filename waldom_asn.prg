//----------------------------------------------------------------------------//
// waldom_asn.prg
//
// RUN_WALDOM_ASN - Download and process the Waldom "Advance Ship Notice" (ASN).
//
// Extends the existing Waldom API integration (waldom_order_status.prg). For
// every open Waldom purchase order it pulls the shipment/ASN data from the
// Waldom REST API and writes the actual shipping information back onto the
// matching engbes (bes) purchase-order line (position level):
//
//      bes->Tracking   tracking number
//      bes->Shipped    ship date
//      bes->Carrier    carrier / forwarder      (only if the field exists)
//
// Schedule-level writes (besdel/bdel, when a Liefereinteilung exists) mirror the
// mcp_stdio confirm_shipment flow and are a documented extension point, not yet
// wired up here.
//
// Optionally (lApplyReceipt) it also advances the delivered quantity (GelQty)
// from the shipped quantity - OFF by default, because booking a goods receipt
// is a bigger intervention into stock.
//
// SAFETY / STATUS
//   Like RUN_WALDOM_ORDER_STATUS, this script defaults to a DRY RUN
//   (lApply := .F.): it prints every match and what it WOULD write, but does
//   not touch the database. Set lApply := .T. once the field mapping has been
//   verified against real ASN responses.
//
// ENDPOINT / FIELD NAMES
//   The Waldom API docs are not reachable from the build box, so the exact ASN
//   endpoint path and the shipment field names could not be confirmed here.
//   Everything that depends on the Waldom response contract is isolated at the
//   top of RUN_WALDOM_ASN (cEndpoint) and in _AsnMapShipment (the candidate
//   key lists passed to _AsnGetAny). The default endpoint reuses the known-good
//   "OrderAPI/<PoNumber>" call, whose OrderItems[].Shipments[] nodes already
//   carry the shipment data. On the first run the script logs the raw keys of
//   the first shipment node it sees ("ASN shipment keys:") so the real field
//   names can be read off a live response and pinned down without guessing.
//
// All database writes and the LetoDBF/curl calls are only really exercised by
// the Windows build - they are not verifiable on the Linux syntax-check box.
//----------------------------------------------------------------------------//

#define WALD_DATE_FORMAT "yyyy-mm-dd"

FUNCTION RUN_WALDOM_ASN()
   LOCAL cSupplier := Pad("WALDOM",8)

   LOCAL cMethod   := "GET"
   LOCAL cEndpoint := "OrderAPI/"                 // ASN endpoint prefix, + PoNumber
   LOCAL aHeaders  := {"Accept: text/plain"}
   LOCAL lVerifySsl := .T.
   LOCAL cApiKey   := "f6699e54-8f8d-4989-a039-5b6d663bea06"  // sent in the URL, not a secret

   LOCAL lApply        := .F.   // .F. = dry run (report only), .T. = write to DB
   LOCAL lApplyReceipt := .F.   // .T. = also advance GelQty from shipped quantity
   LOCAL lKeysLogged   := .F.   // log the shipment keys once, on the first node

   LOCAL oApi := RestAPI():New()
   LOCAL aPOs,nPO,hReq
   LOCAL cData,nResponse := 0,cResponse := ""
   LOCAL xParsed,aRows
   LOCAL nUpdated := 0,nRows := 0,nErrors := 0

   NetUse("engbes","bes")
   NetUse("artlief","ali")

   oApi:cBaseUrl  := "https://api.waldomemea.com/api/v1/"+cApiKey+"/"
   oApi:lVerifySSL := lVerifySsl

   aPOs := _AsnOpenPOs(cSupplier)
   ? "Waldom ASN sync"+IF(lApply,""," (DRY RUN)")+": open POs",Len(aPOs)

   FOR EACH nPO IN aPOs

      hReq := {=>}
      hReq["PoNumber"] := LTrim(Str(nPO))

      cData := oApi:Execute(cEndpoint+LTrim(Str(nPO)),cMethod,hReq,aHeaders,.F.,@nResponse,@cResponse)
      IF nResponse < 200 .OR. nResponse >= 300
         ? "PO",LTrim(Str(nPO)),"HTTP",nResponse,cResponse
         nErrors++
         LOOP
      ENDIF

      xParsed := HB_JsonDecode(cData)
      IF ValType(xParsed) != "H"
         ? "PO",LTrim(Str(nPO)),"invalid JSON response"
         ? cResponse
         nErrors++
         LOOP
      ENDIF

      aRows := _AsnExtractRows(xParsed,@lKeysLogged)
      nRows += Len(aRows)
      nUpdated += _AsnApplyRows(nPO,cSupplier,aRows,_AsnGetAny(xParsed,{"OrderId","OrderID"}),;
                                lApply,lApplyReceipt)

   NEXT

   ? "Waldom ASN sync finished."+IF(lApply,""," (nothing written - DRY RUN)")
   ? "Updated:",nUpdated,"Shipment rows:",nRows,"Errors:",nErrors

RETURN nErrors == 0


//----------------------------------------------------------------------------//
// Open Waldom purchase orders (same rule as RUN_WALDOM_ORDER_STATUS).
//----------------------------------------------------------------------------//
STATIC FUNCTION _AsnOpenPOs(cSupplier)
   LOCAL aPOs := {}

   bes->(dbSetOrder(2))   // Liefma
   IF bes->(dbSeek(cSupplier))
      DO WHILE bes->Liefma == cSupplier .AND. ! bes->(EOF())
         IF bes->Bestat < 3 .AND. bes->BeQty-bes->GelQty > 0 .AND. bes->Besnr != -1
            IF AScan(aPOs,bes->Besnr) == 0
               Aadd(aPOs,bes->Besnr)
            ENDIF
         ENDIF
         bes->(dbSkip())
      ENDDO
   ENDIF

RETURN aPOs


//----------------------------------------------------------------------------//
// Flatten the response into one row per shipped line.
//----------------------------------------------------------------------------//
STATIC FUNCTION _AsnExtractRows(xData,lKeysLogged)
   LOCAL aRows := {}
   LOCAL xItems := _AsnGetAny(xData,{"OrderItems","Items","Lines"})
   LOCAL xItem,xShipments,xShip,hRow

   IF ValType(xItems) != "A"
      RETURN aRows
   ENDIF

   FOR EACH xItem IN xItems
      xShipments := _AsnGetAny(xItem,{"Shipments","Shipment","ShipNotices","ASN"})
      IF ValType(xShipments) != "A"
         LOOP
      ENDIF
      FOR EACH xShip IN xShipments
         IF ! lKeysLogged .AND. ValType(xShip) == "H"
            ? "ASN shipment keys:",_AsnKeyList(xShip)
            lKeysLogged := .T.
         ENDIF
         hRow := _AsnMapShipment(xItem,xShip)
         IF ! Empty(hRow)
            Aadd(aRows,hRow)
         ENDIF
      NEXT
   NEXT

RETURN aRows


//----------------------------------------------------------------------------//
// Map one shipment node to the fields we care about. All key names are
// candidate lists so the mapping tolerates naming variants (see header note).
// Only rows that actually carry shipment info (tracking or ship date) are kept.
//----------------------------------------------------------------------------//
STATIC FUNCTION _AsnMapShipment(xItem,xShip)
   LOCAL cPart := _AsnNorm(_AsnToStr(_AsnGetAny(xItem,{"PartNumber","Part","ItemNumber"})))
   LOCAL cTracking := AllTrim(_AsnToStr(_AsnGetAny(xShip,{"TrackingNumber","Tracking","TrackingNo","Waybill","AWB"})))
   LOCAL dShipped  := _AsnToDate(_AsnGetAny(xShip,{"ShipDate","ShippedDate","ShipmentDate","ActualShipDate"}))
   LOCAL cCarrier  := AllTrim(_AsnToStr(_AsnGetAny(xShip,{"Carrier","CarrierName","ShipVia","Forwarder"})))
   LOCAL nQty      := _AsnToNum(_AsnGetAny(xShip,{"ShippedQuantity","ShippedQty","Quantity","Qty"}))
   LOCAL cPromise  := AllTrim(_AsnToStr(_AsnGetAny(xShip,{"PromiseDate","EstimatedDeliveryDate","DeliveryDate"})))
   LOCAL cAsnNo    := AllTrim(_AsnToStr(_AsnGetAny(xShip,{"AsnNumber","ASNNumber","ShipNoticeNumber","PackingSlip"})))
   LOCAL hRow := {=>}

   IF Empty(cPart)
      RETURN {=>}
   ENDIF
   // nothing shipped yet -> not an ASN line, skip
   IF Empty(cTracking) .AND. Empty(dShipped)
      RETURN {=>}
   ENDIF

   hRow["PART"]     := cPart
   hRow["TRACKING"] := cTracking
   hRow["SHIPPED"]  := dShipped
   hRow["CARRIER"]  := cCarrier
   hRow["QTY"]      := nQty
   hRow["PROMISE"]  := cPromise
   hRow["ASNNO"]    := cAsnNo

RETURN hRow


//----------------------------------------------------------------------------//
// Match the shipment rows to bes lines and (optionally) write them.
//----------------------------------------------------------------------------//
STATIC FUNCTION _AsnApplyRows(nPO,cSupplier,aRows,cOrderId,lApply,lApplyReceipt)
   LOCAL hUsed := {=>}
   LOCAL hRow,nRec,nUpdated := 0

   IF Len(aRows) == 0
      RETURN 0
   ENDIF

   ? "PO",nPO,"AB",_AsnToStr(cOrderId)
   FOR EACH hRow IN aRows
      nRec := _AsnFindBesRec(nPO,cSupplier,hRow,hUsed)
      IF nRec != 0
         ? "  Match:",ValToPrg(hRow)
         IF _AsnUpdateRec(nRec,hRow,cOrderId,lApply,lApplyReceipt)
            hUsed[Str(nRec,10)] := .T.
            nUpdated++
         ENDIF
      ELSE
         ? "  No match for:",ValToPrg(hRow)
      ENDIF
   NEXT

RETURN nUpdated


//----------------------------------------------------------------------------//
// Find the open bes line for this PO whose part matches the shipment. Matches
// on the supplier part (artlief) or the internal matchcode. Unlike the order-
// status matcher we do NOT require an exact ordered-quantity match, because a
// shipment may deliver a partial quantity.
//----------------------------------------------------------------------------//
STATIC FUNCTION _AsnFindBesRec(nPO,cSupplier,hRow,hUsed)
   LOCAL cPart := _AsnNorm(hRow["PART"])
   LOCAL cAliPart,cMatch

   bes->(dbSetOrder(1))   // Str(Besnr,6)+Str(Posnr,3)
   IF bes->(dbSeek(Str(nPO,6)))
      DO WHILE bes->Besnr == nPO .AND. ! bes->(EOF())
         IF bes->Liefma == cSupplier .AND. ! HB_HHasKey(hUsed,Str(bes->(RecNo()),10))
            IF bes->Bestat < 3 .AND. bes->BeQty-bes->GelQty > 0
               ali->(dbSetOrder(1))
               IF ali->(dbSeek(cSupplier+Str(bes->Artikelnr,6)))
                  cAliPart := _AsnNorm(ali->Artlief)
               ELSE
                  cAliPart := ""
               ENDIF
               cMatch := _AsnNorm(bes->Matchcode)

               IF cPart == cAliPart .OR. cPart == cMatch
                  RETURN bes->(RecNo())
               ENDIF
            ENDIF
         ENDIF
         bes->(dbSkip())
      ENDDO
   ENDIF

RETURN 0


//----------------------------------------------------------------------------//
// Write the shipment data onto the bes line (and its Folge lines). In dry-run
// mode nothing is written; the caller has already printed the match.
//----------------------------------------------------------------------------//
STATIC FUNCTION _AsnUpdateRec(nRec,hRow,cAB,lApply,lApplyReceipt)
   LOCAL cTracking := hRow["TRACKING"]
   LOCAL dShipped  := hRow["SHIPPED"]
   LOCAL cCarrier  := hRow["CARRIER"]
   LOCAL nKW       := _AsnDateToKW(hRow["PROMISE"])
   LOCAL nPO,nPos

   bes->(dbGoto(nRec))

   IF bes->Bestat >= 3 .OR. bes->GelQty >= bes->BeQty
      ? "    already completed, skip PO",Str(bes->Besnr,6),"Pos",Str(bes->Posnr,3)
      RETURN .F.
   ENDIF

   IF ! lApply
      ? "    DRY RUN - would set Tracking/Shipped"+IF(!Empty(cCarrier),"/Carrier","")+ ;
        IF(nKW>0," and LTerm "+LTrim(Str(nKW)),"")
      RETURN .T.
   ENDIF

   IF ! LockEntity("BES",bes->Besnr)
      ? "    could not lock PO",Str(bes->Besnr,6)
      RETURN .F.
   ENDIF

   nPO  := bes->Besnr
   nPos := bes->Posnr

   IF ! bes->(Rec_Lock(0))
      RETURN .F.
   ENDIF
   _AsnWriteFields(cTracking,dShipped,cCarrier,cAB,nKW,lApplyReceipt,hRow["QTY"])
   bes->(dbUnlock())

   // apply to the Folge lines of this position, like the confirmation mask
   bes->(dbSkip())
   DO WHILE bes->Besnr == nPO .AND. (bes->Posnr == nPos .OR. bes->FolgeTo == nPos) .AND. ! bes->(EOF())
      IF bes->(Rec_Lock(0))
         _AsnWriteFields(cTracking,dShipped,cCarrier,cAB,nKW,.F.,0)
         bes->(dbUnlock())
      ENDIF
      bes->(dbSkip())
   ENDDO

RETURN .T.


//----------------------------------------------------------------------------//
// Write the shipment fields onto the current bes record. Carrier and any
// goods-receipt advance are guarded so the script also runs against an older
// schema.
//----------------------------------------------------------------------------//
STATIC FUNCTION _AsnWriteFields(cTracking,dShipped,cCarrier,cAB,nKW,lApplyReceipt,nQty)

   IF ! Empty(cTracking)
      bes->Tracking := cTracking
   ENDIF
   IF ! Empty(dShipped)
      bes->Shipped := dShipped
   ENDIF
   IF ! Empty(cCarrier) .AND. bes->(FieldPos("CARRIER")) > 0
      bes->Carrier := cCarrier
   ENDIF
   IF ! Empty(cAB)
      bes->AbNr := Pad(_AsnToStr(cAB),10)
   ENDIF
   bes->Confirmed := "Y"
   IF nKW > 0
      bes->LTerm := nKW
   ENDIF

   IF lApplyReceipt .AND. nQty > 0 .AND. bes->GelQty+nQty <= bes->BeQty
      bes->GelQty := bes->GelQty+nQty
   ENDIF

RETURN NIL


//----------------------------------------------------------------------------//
// Helpers (self-contained: each run-script is its own .hrb).
//----------------------------------------------------------------------------//
STATIC FUNCTION _AsnDateToKW(cDate)
   LOCAL cOldFmt := Set(4)
   LOCAL dDate,nKW := 0

   cDate := AllTrim(_AsnToStr(cDate))
   IF Empty(cDate)
      RETURN 0
   ENDIF
   IF "T" $ cDate
      cDate := SubStr(cDate,1,AT("T",cDate)-1)
   ENDIF

   Set(4,WALD_DATE_FORMAT)
   dDate := CToD(cDate)
   Set(4,cOldFmt)

   IF ! Empty(dDate)
      nKW := Val(Right(Str(KWYear(dDate),4),2)+StrZero(DToKW(dDate),2))
   ENDIF

RETURN nKW


STATIC FUNCTION _AsnGetAny(hData,aKeys)
   LOCAL cKey

   IF ValType(hData) != "H"
      RETURN NIL
   ENDIF
   FOR EACH cKey IN aKeys
      IF HB_HHasKey(hData,cKey)
         RETURN hData[cKey]
      ELSEIF HB_HHasKey(hData,Upper(cKey))
         RETURN hData[Upper(cKey)]
      ELSEIF HB_HHasKey(hData,Lower(cKey))
         RETURN hData[Lower(cKey)]
      ENDIF
   NEXT

RETURN NIL


STATIC FUNCTION _AsnKeyList(hData)
   LOCAL cList := "",cKey

   IF ValType(hData) != "H"
      RETURN ""
   ENDIF
   FOR EACH cKey IN hb_HKeys(hData)
      cList += IF(Empty(cList),"",", ")+cKey
   NEXT

RETURN cList


STATIC FUNCTION _AsnNorm(cVal)
RETURN Upper(AllTrim(_AsnToStr(cVal)))


STATIC FUNCTION _AsnToStr(xVal)
   DO CASE
      CASE ValType(xVal) == "C"
         RETURN xVal
      CASE ValType(xVal) == "N"
         RETURN LTrim(Str(xVal))
      CASE ValType(xVal) == "D"
         RETURN DToC(xVal)
      CASE ValType(xVal) == "L"
         RETURN IF(xVal,".T.",".F.")
   ENDCASE
RETURN ""


STATIC FUNCTION _AsnToNum(xVal)
   LOCAL cVal
   IF ValType(xVal) == "N"
      RETURN xVal
   ENDIF
   cVal := AllTrim(_AsnToStr(xVal))
   cVal := StrTran(cVal,",","")
RETURN Val(cVal)


STATIC FUNCTION _AsnToDate(xVal)
   LOCAL cOldFmt,cDate,dDate

   IF ValType(xVal) == "D"
      RETURN xVal
   ENDIF
   cDate := AllTrim(_AsnToStr(xVal))
   IF Empty(cDate)
      RETURN CToD("")
   ENDIF
   IF "T" $ cDate
      cDate := SubStr(cDate,1,AT("T",cDate)-1)
   ENDIF
   cOldFmt := Set(4)
   Set(4,WALD_DATE_FORMAT)
   dDate := CToD(cDate)
   Set(4,cOldFmt)

RETURN dDate
