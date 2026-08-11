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
// (bes) purchase-order line:
//
//      Tracking   carrier tracking id
//      Shipped    ship date
//      Carrier    carrier type            (only if the field exists)
//
// PARTIAL DELIVERIES (Liefereinteilung / besdel)
//   Mirrors the mcp_stdio confirm_shipment flow: when the position has a
//   delivery schedule (besdel/bdel entries), the shipment is booked on the
//   matching schedule entry, NOT on the position - the same rule the
//   Bestellbestaetigung mask enforces (WHEN ! lHasPlan). The schedule entry for
//   a shipment is located by its delivery week (deliveryDate -> JJWW == bdel
//   Lterm), with the shipped quantity (bdel Qty == shipmentQuantity) as a
//   fallback. Each partial shipment consumes a distinct schedule entry, so two
//   ASN shipments of one position land on two different besdel weeks. Positions
//   without a schedule are booked at position level as before.
//
//   NB: deliveryDate is only READ to locate the right schedule entry - LTerm is
//   never written (the delivery week stays the job of RUN_WALDOM_ORDER_STATUS).
//
// It deliberately does NOT touch AbNr, Confirmed, LTerm or GelQty - the goods
// receipt (GelQty) stays a manual booking.
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
   NetUse("besdel","bdel")

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

   IF ! GetConfigValue("BATCHMODE")
      Sinkey(0)
   ENDIF
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
// header (tracking, ship date, delivery date, carrier) down onto every line.
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
// Only genuine shipment lines are kept: a positive shipped quantity AND a ship
// date. The tracking id lives on the packing list and may legitimately be empty
// (freight, carrier types without a trackable id), so it is NOT required.
//----------------------------------------------------------------------------//
STATIC FUNCTION _AsnMapLine(xOrder,xLine)
   LOCAL xCarrier := _AsnGetAny(xOrder,{"carrier","Carrier"})
   LOCAL cTracking := AllTrim(_AsnToStr(_AsnGetAny(xCarrier,{"carrierTrackingId"})))
   LOCAL cCarrier  := AllTrim(_AsnToStr(_AsnGetAny(xCarrier,{"carrierType"})))
   LOCAL dShipped  := _AsnToDate(_AsnGetAny(xOrder,{"shipDate"}))
   LOCAL cDelivery := AllTrim(_AsnToStr(_AsnGetAny(xOrder,{"deliveryDate"})))
   LOCAL cPacking  := AllTrim(_AsnToStr(_AsnGetAny(xOrder,{"packingListNumber"})))
   LOCAL cBuyer    := _AsnNorm(_AsnGetAny(xLine,{"buyerPartNumber"}))
   LOCAL cSupplier := _AsnNorm(_AsnGetAny(xLine,{"supplierPartNumber"}))
   LOCAL nQty      := _AsnToNum(_AsnGetAny(xLine,{"shipmentQuantity"}))
   LOCAL hRow := {=>}

   IF Empty(cBuyer) .AND. Empty(cSupplier)
      RETURN {=>}
   ENDIF
   IF nQty <= 0 .OR. Empty(dShipped)
      RETURN {=>}
   ENDIF

   hRow["BUYERPART"] := cBuyer
   hRow["SUPPART"]   := cSupplier
   hRow["TRACKING"]  := cTracking
   hRow["CARRIER"]   := cCarrier
   hRow["SHIPPED"]   := dShipped
   hRow["DELIVERY"]  := cDelivery
   hRow["PACKING"]   := cPacking
   hRow["QTY"]       := nQty

RETURN hRow


//----------------------------------------------------------------------------//
// Match the shipment rows to bes lines / besdel schedule entries and write them.
// hUsedDel dedups schedule entries, hUsedBes dedups position-level bookings -
// so several partial shipments of one position each consume their own besdel
// week instead of overwriting each other.
//----------------------------------------------------------------------------//
STATIC FUNCTION _AsnApplyRows(nPO,cSupplier,aRows,lApply)
   LOCAL hUsedBes := {=>}
   LOCAL hUsedDel := {=>}
   LOCAL hRow,nRec,nUpdated := 0

   IF Len(aRows) == 0
      RETURN 0
   ENDIF

   ? "PO",nPO
   FOR EACH hRow IN aRows
      nRec := _AsnFindBesRec(nPO,cSupplier,hRow)
      IF nRec == 0
         ? "  No matching position for:",ValToPrg(hRow)
         LOOP
      ENDIF
      ? "  Match:",ValToPrg(hRow)
      IF _AsnUpdateRec(nRec,hRow,lApply,hUsedBes,hUsedDel)
         nUpdated++
      ENDIF
   NEXT

RETURN nUpdated


//----------------------------------------------------------------------------//
// Find the open bes position for this PO whose part matches the shipment. The
// ASN carries both the buyer part and the supplier part; match either against
// the internal matchcode or the supplier part (artlief). No quantity match -
// a shipment may be partial. No dedup here: dedup happens at the booking target
// (position or schedule entry), so one position can serve several shipments.
//----------------------------------------------------------------------------//
STATIC FUNCTION _AsnFindBesRec(nPO,cSupplier,hRow)
   LOCAL cBuyer := _AsnNorm(hRow["BUYERPART"])
   LOCAL cSupPart := _AsnNorm(hRow["SUPPART"])
   LOCAL cAliPart,cMatch

   bes->(dbSetOrder(1))   // Str(Besnr,6)+Str(Posnr,3)
   IF bes->(dbSeek(Str(nPO,6)))
      DO WHILE bes->Besnr == nPO .AND. ! bes->(EOF())
         IF bes->Liefma == cSupplier .AND. bes->Bestat < 3 .AND. bes->BeQty-bes->GelQty > 0
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
// Book the shipment. If the position has a delivery schedule (Liefereinteilung)
// the write goes on the matching besdel entry; otherwise on the position (and
// its Folge lines). In dry-run mode nothing is written.
//
// Writes ONLY Tracking / Shipped / Carrier - by design nothing else.
//----------------------------------------------------------------------------//
STATIC FUNCTION _AsnUpdateRec(nBesRec,hRow,lApply,hUsedBes,hUsedDel)
   LOCAL cTracking := hRow["TRACKING"]
   LOCAL dShipped  := hRow["SHIPPED"]
   LOCAL cCarrier  := hRow["CARRIER"]
   LOCAL nKW       := _AsnDateToKW(hRow["DELIVERY"])
   LOCAL nQty      := hRow["QTY"]
   LOCAL nPO,nPos,nDelRec

   bes->(dbGoto(nBesRec))
   nPO  := bes->Besnr
   nPos := bes->Posnr

   IF bes->Bestat >= 3 .OR. bes->GelQty >= bes->BeQty
      ? "    already completed, skip PO",Str(nPO,6),"Pos",Str(nPos,3)
      RETURN .F.
   ENDIF

   // Position with a delivery schedule -> book on the matching schedule entry.
   IF _AsnHasPlan(nPO,nPos)
      nDelRec := _AsnFindDelRec(nPO,nPos,nKW,nQty,hUsedDel)
      IF nDelRec == 0
         ? "    Liefereinteilung, but no free schedule entry for KW",LTrim(Str(nKW)), ;
           "/ qty",LTrim(Str(nQty))+". Weeks:",_AsnDelWeeks(nPO,nPos)
         RETURN .F.
      ENDIF
      bdel->(dbGoto(nDelRec))

      IF ! lApply
         ? "    DRY RUN - would set schedule KW",LTrim(Str(bdel->Lterm))+ ;
           ": Tracking/Shipped"+IF(!Empty(cCarrier),"/Carrier","")
         hUsedDel[Str(nDelRec,10)] := .T.
         RETURN .T.
      ENDIF

      IF ! bdel->(Rec_Lock(0))
         ? "    could not lock schedule entry, PO",Str(nPO,6),"Pos",Str(nPos,3)
         RETURN .F.
      ENDIF
      _AsnWriteFieldsDel(cTracking,dShipped,cCarrier)
      bdel->(dbUnlock())
      hUsedDel[Str(nDelRec,10)] := .T.
      RETURN .T.
   ENDIF

   // No schedule -> position level (dedup so we don't overwrite an earlier one).
   IF HB_HHasKey(hUsedBes,Str(nBesRec,10))
      ? "    position already booked from another shipment (no schedule) - skip"
      RETURN .F.
   ENDIF

   IF ! lApply
      ? "    DRY RUN - would set Tracking/Shipped"+IF(!Empty(cCarrier),"/Carrier","")
      hUsedBes[Str(nBesRec,10)] := .T.
      RETURN .T.
   ENDIF

   IF ! LockEntity("BES",nPO)
      ? "    could not lock PO",Str(nPO,6)
      RETURN .F.
   ENDIF

   bes->(dbGoto(nBesRec))
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

   hUsedBes[Str(nBesRec,10)] := .T.

RETURN .T.


//----------------------------------------------------------------------------//
// Does the position have a delivery schedule (Liefereinteilung)?
//----------------------------------------------------------------------------//
STATIC FUNCTION _AsnHasPlan(nPO,nPos)
   bdel->(dbSetOrder(1))   // Str(Besnr,6)+Str(Posnr,3)
RETURN bdel->(dbSeek(Str(nPO,6)+Str(nPos,3)))


//----------------------------------------------------------------------------//
// Find the schedule entry (besdel) for a shipment: prefer the entry whose week
// matches the ASN delivery week (Lterm == nKW), else the entry whose planned
// quantity matches the shipped quantity (Qty == nQty). Skips entries already
// consumed by an earlier shipment in this run.
//----------------------------------------------------------------------------//
STATIC FUNCTION _AsnFindDelRec(nPO,nPos,nKW,nQty,hUsedDel)
   LOCAL nQtyRec := 0

   bdel->(dbSetOrder(1))
   IF bdel->(dbSeek(Str(nPO,6)+Str(nPos,3)))
      DO WHILE bdel->Besnr == nPO .AND. bdel->Posnr == nPos .AND. ! bdel->(EOF())
         IF ! HB_HHasKey(hUsedDel,Str(bdel->(RecNo()),10))
            IF nKW > 0 .AND. bdel->Lterm == nKW
               RETURN bdel->(RecNo())
            ENDIF
            IF nQtyRec == 0 .AND. nQty > 0 .AND. bdel->Qty == nQty
               nQtyRec := bdel->(RecNo())
            ENDIF
         ENDIF
         bdel->(dbSkip())
      ENDDO
   ENDIF

RETURN nQtyRec


//----------------------------------------------------------------------------//
// Comma-list of the schedule weeks of a position - for the no-match log.
//----------------------------------------------------------------------------//
STATIC FUNCTION _AsnDelWeeks(nPO,nPos)
   LOCAL cList := ""

   bdel->(dbSetOrder(1))
   IF bdel->(dbSeek(Str(nPO,6)+Str(nPos,3)))
      DO WHILE bdel->Besnr == nPO .AND. bdel->Posnr == nPos .AND. ! bdel->(EOF())
         cList += IF(Empty(cList),"",",")+StrZero(bdel->Lterm,4)
         bdel->(dbSkip())
      ENDDO
   ENDIF

RETURN cList


//----------------------------------------------------------------------------//
// Field writers. Carrier is guarded so the script also runs against an older
// schema without the CARRIER column.
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


STATIC FUNCTION _AsnWriteFieldsDel(cTracking,dShipped,cCarrier)

   IF ! Empty(cTracking)
      bdel->Tracking := cTracking
   ENDIF
   IF ! Empty(dShipped)
      bdel->Shipped := dShipped
   ENDIF
   IF ! Empty(cCarrier) .AND. bdel->(FieldPos("CARRIER")) > 0
      bdel->Carrier := cCarrier
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
