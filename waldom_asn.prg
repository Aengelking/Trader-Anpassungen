//----------------------------------------------------------------------------//
// waldom_asn.prg
//
// RUN_WALDOM_ASN - Download and process the Waldom "Advance Ship Notice" (ASN).
//
// Extends the existing Waldom API integration (waldom_order_status.prg). For
// every open Waldom purchase order it pulls the ASN from the Waldom REST API
//
//      GET /api/v1/<ApiKey>/AsnAPI/<PONumber>
//
// and writes ONLY the actual shipping information back onto the matching engbes
// (bes) purchase-order line (position level):
//
//      bes->Tracking   carrier tracking id
//      bes->Shipped    ship date
//      bes->Carrier    carrier type            (only if the field exists)
//
// It deliberately does NOT touch AbNr, Confirmed, LTerm or GelQty - the delivery
// week / order confirmation is the job of RUN_WALDOM_ORDER_STATUS, and the goods
// receipt (GelQty) stays a manual booking.
//
// Schedule-level writes (besdel/bdel, when a Liefereinteilung exists) mirror the
// mcp_stdio confirm_shipment flow and are a documented extension point, not yet
// wired up here.
//
// ASN RESPONSE SCHEMA (Waldom Swagger, text/plain JSON body)
//   { "orders": [ {                       one entry per packing list / shipment
//        "packingListNumber","orderNumber","partnerOrderNumber",
//        "deliveryDate","shipDate","customerRequestedDate","orderDate",
//        "carrier": { "carrierType","carrierTrackingId","carrierRouting" },
//        "weight":  { "grossWeight","weightUom" },
//        "lineItems": [ {
//           "shipmentLineNumber","orderLineNumber","buyerPartNumber",
//           "supplierPartNumber","manufacturerName","countryOrigin","uom",
//           "shipmentQuantity","customerOrderQty" } ] } ],
//     "addresses": { "shipTo": {...}, "shipFrom": {...} } }
//
// SAFETY / STATUS
//   Like RUN_WALDOM_ORDER_STATUS, this script defaults to a DRY RUN
//   (lApply := .F.): it prints every match and what it WOULD write, but does not
//   touch the database. Set lApply := .T. once the mapping has been verified
//   against real ASN responses.
//
//   All database writes and the LetoDBF/curl calls are only really exercised by
//   the Windows build - they are not verifiable on the Linux syntax-check box.
//----------------------------------------------------------------------------//

#define WALD_DATE_FORMAT "yyyy-mm-dd"

FUNCTION RUN_WALDOM_ASN()
   LOCAL cSupplier := Pad("WALDOM",8)

   LOCAL cMethod   := "GET"
   LOCAL cEndpoint := "AsnAPI/"                   // ASN endpoint prefix, + PONumber
   LOCAL aHeaders  := {"Accept: text/plain"}
   LOCAL lVerifySsl := .T.
   LOCAL cApiKey   := "f6699e54-8f8d-4989-a039-5b6d663bea06"  // sent in the URL, not a secret

   LOCAL lApply := .F.   // .F. = dry run (report only), .T. = write to DB

   LOCAL oApi := RestAPI():New()
   LOCAL aPOs,nPO
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

      cData := oApi:Execute(cEndpoint+LTrim(Str(nPO)),cMethod,{=>},aHeaders,.F.,@nResponse,@cResponse)

      // 404 just means "no ASN for this PO yet" - not an error worth counting
      IF nResponse == 404
         LOOP
      ENDIF
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

      aRows := _AsnExtractRows(xParsed)
      nRows += Len(aRows)
      nUpdated += _AsnApplyRows(nPO,cSupplier,aRows,lApply)

   NEXT

   ? "Waldom ASN sync finished."+IF(lApply,""," (nothing written - DRY RUN)")
   ? "Updated:",nUpdated,"Shipment lines:",nRows,"Errors:",nErrors

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
// Flatten the ASN into one row per shipped line item, carrying the shipment
// header (tracking, ship date, carrier) down onto every line.
//----------------------------------------------------------------------------//
STATIC FUNCTION _AsnExtractRows(xData)
   LOCAL aRows := {}
   LOCAL xOrders := _AsnGetAny(xData,{"orders","Orders"})
   LOCAL xOrder,xLines,xLine,hRow

   IF ValType(xOrders) != "A"
      RETURN aRows
   ENDIF

   FOR EACH xOrder IN xOrders
      IF ValType(xOrder) != "H"
         LOOP
      ENDIF
      xLines := _AsnGetAny(xOrder,{"lineItems","LineItems"})
      IF ValType(xLines) != "A"
         LOOP
      ENDIF
      FOR EACH xLine IN xLines
         hRow := _AsnMapLine(xOrder,xLine)
         IF ! Empty(hRow)
            Aadd(aRows,hRow)
         ENDIF
      NEXT
   NEXT

RETURN aRows


//----------------------------------------------------------------------------//
// Map one (shipment header + line item) pair to the fields we care about.
// Only lines that actually carry shipment info (tracking or ship date) are kept.
//----------------------------------------------------------------------------//
STATIC FUNCTION _AsnMapLine(xOrder,xLine)
   LOCAL xCarrier := _AsnGetAny(xOrder,{"carrier","Carrier"})
   LOCAL cTracking := AllTrim(_AsnToStr(_AsnGetAny(xCarrier,{"carrierTrackingId"})))
   LOCAL cCarrier  := AllTrim(_AsnToStr(_AsnGetAny(xCarrier,{"carrierType"})))
   LOCAL dShipped  := _AsnToDate(_AsnGetAny(xOrder,{"shipDate"}))
   LOCAL cPacking  := AllTrim(_AsnToStr(_AsnGetAny(xOrder,{"packingListNumber"})))
   LOCAL cBuyer    := _AsnNorm(_AsnGetAny(xLine,{"buyerPartNumber"}))
   LOCAL cSupplier := _AsnNorm(_AsnGetAny(xLine,{"supplierPartNumber"}))
   LOCAL nQty      := _AsnToNum(_AsnGetAny(xLine,{"shipmentQuantity"}))
   LOCAL hRow := {=>}

   IF Empty(cBuyer) .AND. Empty(cSupplier)
      RETURN {=>}
   ENDIF
   // nothing shipped yet -> not an ASN line, skip
   IF Empty(cTracking) .AND. Empty(dShipped)
      RETURN {=>}
   ENDIF

   hRow["BUYERPART"] := cBuyer
   hRow["SUPPART"]   := cSupplier
   hRow["TRACKING"]  := cTracking
   hRow["CARRIER"]   := cCarrier
   hRow["SHIPPED"]   := dShipped
   hRow["PACKING"]   := cPacking
   hRow["QTY"]       := nQty

RETURN hRow


//----------------------------------------------------------------------------//
// Match the shipment rows to bes lines and (optionally) write them.
//----------------------------------------------------------------------------//
STATIC FUNCTION _AsnApplyRows(nPO,cSupplier,aRows,lApply)
   LOCAL hUsed := {=>}
   LOCAL hRow,nRec,nUpdated := 0

   IF Len(aRows) == 0
      RETURN 0
   ENDIF

   ? "PO",nPO
   FOR EACH hRow IN aRows
      nRec := _AsnFindBesRec(nPO,cSupplier,hRow,hUsed)
      IF nRec != 0
         ? "  Match:",ValToPrg(hRow)
         IF _AsnUpdateRec(nRec,hRow,lApply)
            hUsed[Str(nRec,10)] := .T.
            nUpdated++
         ENDIF
      ELSE
         ? "  No match for:",ValToPrg(hRow)
      ENDIF
   NEXT

RETURN nUpdated


//----------------------------------------------------------------------------//
// Find the open bes line for this PO whose part matches the shipment. The ASN
// carries both the buyer part and the supplier part; match either against the
// internal matchcode or the supplier part (artlief). Unlike the order-status
// matcher we do NOT require an exact ordered-quantity match, because a shipment
// may deliver a partial quantity.
//----------------------------------------------------------------------------//
STATIC FUNCTION _AsnFindBesRec(nPO,cSupplier,hRow,hUsed)
   LOCAL cBuyer := _AsnNorm(hRow["BUYERPART"])
   LOCAL cSupPart := _AsnNorm(hRow["SUPPART"])
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

               IF _AsnPartMatch(cBuyer,cMatch,cAliPart) .OR. _AsnPartMatch(cSupPart,cMatch,cAliPart)
                  RETURN bes->(RecNo())
               ENDIF
            ENDIF
         ENDIF
         bes->(dbSkip())
      ENDDO
   ENDIF

RETURN 0


STATIC FUNCTION _AsnPartMatch(cPart,cMatch,cAliPart)
   IF Empty(cPart)
      RETURN .F.
   ENDIF
RETURN cPart == cMatch .OR. cPart == cAliPart


//----------------------------------------------------------------------------//
// Write the shipment data onto the bes line (and its Folge lines). In dry-run
// mode nothing is written; the caller has already printed the match.
//
// Writes ONLY Tracking / Shipped / Carrier - by design nothing else (no AbNr,
// no Confirmed, no LTerm, no GelQty).
//----------------------------------------------------------------------------//
STATIC FUNCTION _AsnUpdateRec(nRec,hRow,lApply)
   LOCAL cTracking := hRow["TRACKING"]
   LOCAL dShipped  := hRow["SHIPPED"]
   LOCAL cCarrier  := hRow["CARRIER"]
   LOCAL nPO,nPos

   bes->(dbGoto(nRec))

   IF bes->Bestat >= 3 .OR. bes->GelQty >= bes->BeQty
      ? "    already completed, skip PO",Str(bes->Besnr,6),"Pos",Str(bes->Posnr,3)
      RETURN .F.
   ENDIF

   IF ! lApply
      ? "    DRY RUN - would set Tracking/Shipped"+IF(!Empty(cCarrier),"/Carrier","")
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
   _AsnWriteFields(cTracking,dShipped,cCarrier)
   bes->(dbUnlock())

   // apply to the Folge lines of this position, like the confirmation mask
   bes->(dbSkip())
   DO WHILE bes->Besnr == nPO .AND. (bes->Posnr == nPos .OR. bes->FolgeTo == nPos) .AND. ! bes->(EOF())
      IF bes->(Rec_Lock(0))
         _AsnWriteFields(cTracking,dShipped,cCarrier)
         bes->(dbUnlock())
      ENDIF
      bes->(dbSkip())
   ENDDO

RETURN .T.


//----------------------------------------------------------------------------//
// Write the shipment fields onto the current bes record. Carrier is guarded so
// the script also runs against an older schema without the CARRIER column.
//----------------------------------------------------------------------------//
STATIC FUNCTION _AsnWriteFields(cTracking,dShipped,cCarrier)

   IF ! Empty(cTracking)
      bes->Tracking := cTracking
   ENDIF
   IF ! Empty(dShipped)
      bes->Shipped := dShipped
   ENDIF
   IF ! Empty(cCarrier) .AND. bes->(FieldPos("CARRIER")) > 0
      bes->Carrier := cCarrier
   ENDIF

RETURN NIL


//----------------------------------------------------------------------------//
// Helpers (self-contained: each run-script is its own .hrb).
//----------------------------------------------------------------------------//
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
