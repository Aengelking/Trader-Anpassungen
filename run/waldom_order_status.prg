//#include "xhb_dyn.ch"

#define WALD_DATE_FORMAT "yyyy-mm-dd"

FUNCTION RUN_WALDOM_ORDER_STATUS()
   LOCAL cSupplier := Pad("WALDOM",8)
   
   LOCAL cMethod := "GET" //"Waldom OrderRetrieve API method"))
   LOCAL cPoParam := "PoNumber" //"Request parameter name for customer PO number"
   LOCAL aHeaders := {"Accept: text/plain"} //,"X-API-USER: $USERNAME$","X-API-KEY: $APIKEY$"} //"HTTP headers for Waldom API"
   //LOCAL cUserKey := "WALD-LOGIN" //"Keychain key for Waldom API username/password"
   //LOCAL cApiKey := "WALDAPIKEY" //"Keychain key for Waldom API key/token"
   LOCAL lVerifySsl := .T. //"Enable SSL verification for Waldom API"
   
   LOCAL aPOs,nPO
   LOCAL oApi := RestAPI():New()
   LOCAL hReq
   LOCAL cData,nResponse := 0,cResponse := ""
   LOCAL xParsed,aRows
   LOCAL nUpdated := 0,nRows := 0,nErrors := 0
   LOCAL cApiKey := "f6699e54-8f8d-4989-a039-5b6d663bea06"  //the api key is sent in the URL so we do not need to protect it in any way!

   NetUse("engbes","bes")
   NetUse("artlief","ali")
   NetUse("werkauf","wer")

   oApi:cBaseUrl := "https://api.waldomemea.com/api/v1/"+cApiKey+"/"
   oApi:lVerifySSL := lVerifySsl

   aPOs := _WaldomOpenPOs(cSupplier)
   ? "Waldom status sync: open POs",Len(aPOs)

   FOR EACH nPO IN aPOs
      
      hReq := {=>}
      hReq[cPoParam] := LTrim(Str(nPO))

      cData := oApi:Execute("OrderAPI/"+LTrim(Str(nPO)),cMethod,hReq,aHeaders,.F.,@nResponse,@cResponse)
      IF nResponse < 200 .OR. nResponse >= 300
         ? "PO",LTrim(Str(nPO)),"HTTP",nResponse,cResponse
         nErrors++            
      ENDIF

      xParsed := HB_JsonDecode(cData)
      IF ValType(xParsed) == "U"
         ? "PO",LTrim(Str(nPO)),"invalid JSON response"
         ? cResponse
         ? cData
         nErrors++            
      ENDIF

      aRows := _WaldomExtractRows(xParsed)
      nRows += Len(aRows)
      nUpdated += _WaldomApplyRows(nPO,cSupplier,aRows,xParsed["OrderId"])
      
   NEXT

   ? "Waldom status sync finished. Updated:",nUpdated,"Rows:",nRows,"Errors:",nErrors
  
RETURN nErrors == 0

STATIC FUNCTION _WaldomOpenPOs(cSupplier)
   LOCAL aPOs := {}

   bes->(dbSetOrder(2))
   IF bes->(dbSeek(cSupplier))
      DO WHILE bes->Liefma == cSupplier .AND. ! bes->(EOF())
         IF bes->Bestat < 3 .AND. bes->BeQty-bes->GelQty > 0 .AND. bes->confirmed != "Y" .AND. bes->Besnr != -1
            IF AScan(aPOs,bes->Besnr) == 0
               Aadd(aPOs,bes->Besnr)
            ENDIF
         ENDIF
         bes->(dbSkip())
      ENDDO
   ENDIF

RETURN aPOs


STATIC FUNCTION _WaldomExtractRows(xData)
   LOCAL aRows := {}
   LOCAL xVal
   //_WaldomExtractRowsRec(xData["OrderItems"],@aRows)
   FOR EACH xVal IN xData["OrderItems"]
      _WaldomExtractRowsRec(xVal,@aRows)
   NEXT
RETURN aRows


STATIC FUNCTION _WaldomExtractRowsRec(xNode,aRows)
   
   LOCAL hRow

   
   hRow := _WaldomMapRow(xNode)
   IF ! Empty(hRow)
      Aadd(aRows,hRow)
      RETURN NIL
   ENDIF

RETURN NIL


STATIC FUNCTION _WaldomMapRow(hData)
   LOCAL cPart := hData["PartNumber"]
   LOCAL cDate := hData["Shipments"][1]["PromiseDate"]
   LOCAL xQty := hData["Shipments"][1]["Quantity"]
   LOCAL hRow := {=>}

   cPart := _WaldomNorm(cPart)
   IF Empty(cPart)
      RETURN {=>}
   ENDIF

   hRow["PART"] := cPart
   hRow["DATE"] := AllTrim(_WaldomToStr(cDate))
   hRow["QTY"] := _WaldomToNum(xQty)

RETURN hRow


STATIC FUNCTION _WaldomApplyRows(nPO,cSupplier,aRows,cOrderId)
   LOCAL hUsed := {=>}
   LOCAL hRow
   LOCAL nUpdated := 0
   LOCAL nRec

   ? "PO",nPO
   ? "AB",cOrderId
   FOR EACH hRow IN aRows
      nRec := _WaldomFindBesRec(nPO,cSupplier,hRow,hUsed)
      IF nRec != 0
         ? "Update:",ValToPrg(hRow)
         _WaldomUpdateRec(nRec,hRow,cOrderId)
         hUsed[Str(nRec,10)] := .T.
         nUpdated++
      ELSE
         ? "No match for:",ValToPrg(hRow)
      ENDIF
   NEXT

RETURN nUpdated


STATIC FUNCTION _WaldomFindBesRec(nPO,cSupplier,hRow,hUsed)
   LOCAL cPart := _WaldomNorm(hRow["PART"])
   LOCAL nWantedQty := hRow["QTY"]
   LOCAL cAliPart
   LOCAL cMatch
   LOCAL nCandidate := 0

   bes->(dbSetOrder(1))
   IF bes->(dbSeek(Str(nPO,6)))
      DO WHILE bes->Besnr == nPO .AND. ! bes->(EOF())
         IF bes->Liefma == cSupplier //.AND. bes->Bestat < 3 .AND. bes->BeQty-bes->GelQty > 0
            IF ! HB_HHasKey(hUsed,Str(bes->(RecNo()),10)) .AND. bes->BeQty == nWantedQty
               ali->(dbSetOrder(1))
               IF ali->(dbSeek(cSupplier+Str(bes->Artikelnr,6)))
                  cAliPart := _WaldomNorm(ali->Artlief)
               ELSE
                  cAliPart := ""
               ENDIF
               cMatch := _WaldomNorm(bes->Matchcode)

               IF cPart == cAliPart .OR. cPart == cMatch
                  
                   RETURN bes->(RecNo())
                  
               ELSE
                 // ? "No match for part. Wanted:",cPart,"Ali:",cAliPart,"Matchcode:",cMatch
               ENDIF
            ENDIF
         ENDIF
         bes->(dbSkip())
      ENDDO
   ENDIF

RETURN nCandidate


STATIC FUNCTION _WaldomUpdateRec(nRec,hRow,cAB)
   LOCAL nKW := _WaldomDateToKW(hRow["DATE"])

   LOCAL nPos
   LOCAL nPO

   bes->(dbGoto(nRec))

   IF bes->Bestat >= 3 .OR. bes->GelQty >= bes->BeQty
      ?? "Record already completed, cannot update. PO:",Str(bes->Besnr,6),"Pos:",Str(bes->Posnr,3)
      RETURN NIL
   ELSEIF bes->Confirmed == "Y"
      ?? "Record already confirmed, cannot update. PO:",Str(bes->Besnr,6),"Pos:",Str(bes->Posnr,3)
      RETURN NIL
   ELSEIF LockEntity("BES",bes->Besnr) == .F.
      ?? "Could not lock record for update. PO:",Str(bes->Besnr,6),"Pos:",Str(bes->Posnr,3)
      RETURN NIL
   ENDIF
   ?? "UPDATE"
RETURN NIL
   nPO := bes->Besnr
   IF ! bes->(Rec_Lock(0))
      RETURN NIL
   ENDIF
   
   IF ! Empty(cAb)
      bes->AbNr := Pad(cAb,10)
   ENDIF
   bes->Confirmed := "Y"
   IF nKW > 0
      bes->LTerm := nKW
   ENDIF
   bes->(dbUnlock())

   wer->(dbSetOrder(6))
   IF wer->(dbSeek(Str(bes->Besnr,6)+Str(bes->Posnr,3))) .AND. Right(Str(wer->End,4),2) != "99" .AND. nKW > 0
      wer->(Rec_Lock(0))
      wer->End := IF(Val(Right(Str(nKW,4),2)) <= 52,nKW+bes->ShipTime,nKW)
      wer->(dbUnlock())
   ENDIF

   nPos := bes->Posnr
   bes->(dbSkip())
   DO WHILE bes->Besnr == nPO .AND. (bes->Posnr == nPos .OR. bes->Folgeto == nPos)
      IF bes->(Rec_Lock(0))
         IF ! Empty(cAb)
            bes->AbNr := Pad(cAb,10)
         ENDIF
         bes->Confirmed := "Y"
         IF nKW > 0
            bes->LTerm := nKW
         ENDIF
         bes->(dbUnlock())
      ENDIF
      bes->(dbSkip())
   ENDDO

RETURN NIL


STATIC FUNCTION _WaldomDateToKW(cDate)
   LOCAL cOldFmt := Set(4)
   LOCAL dDate 
   LOCAL cFmt := WALD_DATE_FORMAT
   LOCAL nKW := 0

   cDate := AllTrim(_WaldomToStr(cDate))
   IF Empty(cDate)
      RETURN 0
   ENDIF

   IF "T" $ cDate
      cDate := SubStr(cDate,1,AT("T",cDate)-1)
   ENDIF

   
   Set(4,cFmt)
   dDate := CToD(cDate)
   
   Set(4,cOldFmt)

   IF ! Empty(dDate)
      nKW := Val(Right(Str(KWYear(dDate),4),2)+StrZero(DToKW(dDate),2))
   ENDIF

RETURN nKW


STATIC FUNCTION _WaldomGetAny(hData,aKeys)
   LOCAL cKey
   LOCAL cAlt

   FOR EACH cKey IN aKeys
      IF HB_HHasKey(hData,cKey)
         RETURN hData[cKey]
      ENDIF
      cAlt := Upper(cKey)
      IF HB_HHasKey(hData,cAlt)
         RETURN hData[cAlt]
      ENDIF
      cAlt := Lower(cKey)
      IF HB_HHasKey(hData,cAlt)
         RETURN hData[cAlt]
      ENDIF
   NEXT

RETURN NIL


STATIC FUNCTION _WaldomNorm(cVal)
RETURN Upper(AllTrim(cVal))


STATIC FUNCTION _WaldomToStr(xVal)
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


STATIC FUNCTION _WaldomToNum(xVal)
   LOCAL cVal
   IF ValType(xVal) == "N"
      RETURN xVal
   ENDIF
   cVal := AllTrim(_WaldomToStr(xVal))
   cVal := StrTran(cVal,",", "")

RETURN Val(cVal)
