#include 'y:\hb34\contrib\hbcurl\hbcurl.ch'

#define WALD_STOCK_EMEA "Stock EMEA"
#define WALD_STOCK_USA "Stock USA"

PROCEDURE RUN_WALDOM
   LOCAL cUrl := "https://www.waldomemea.com/dailyFeed/Engelking%20Elektronik%20GmbH_InventoryFeed.csv"
                  //http://www.waldomemea.com/dailyFeed/Engelking%20Elektronik%20GmbH_InventoryFeed.csv
   LOCAL cLief := Pad("WALDOM",8)
   LOCAL cBulgin := Pad("BULGIN",8)
   LOCAL aArtikel := {},aParts := {}
   LOCAL cArtlief
   LOCAL cData,nQty,nArtnr,nX,nR,cMatch
   LOCAL cTempFile
   LOCAL hFieldMap := {=>},aData,nResponse,nD
   LOCAL nP,bBlock
   LOCAL pCurl := Curl_Easy_Init()
   
   CLS

   NetUse("artikel","art")
   NetUse("artlief","ali")
   NetUse("buyprice","bpr")
   NetUse("liefstock","lsto")
   NetUse("waldom","wald")
   NetUse("engkund","ku")

   ku->(dbSetOrder( 8 ))
   IF ! ku->(dbSeek( Str(29146,6) ))
      Alert("Waldom not found")
      RETURN   
   ENDIF
   cLief := ku->Kunde
   IF ! ku->(dbSeek( Str(4835,6) ))
      Alert("Bulgin not found")
      RETURN
   ENDIF
   cBulgin := ku->Kunde

   //FOR nTry := 1 TO 3 //3 tries
      ? "Downloading data..."
      curl_easy_setopt(pCurl, HB_CURLOPT_SSL_VERIFYPEER,0)
      curl_easy_setopt(pCurl, HB_CURLOPT_DL_BUFF_SETUP )
      curl_easy_setopt(pCurl, HB_CURLOPT_URL, cUrl )
      Curl_Easy_Perform(pCurl)
      curl_easy_setopt(pCurl, HB_CURLOPT_DL_BUFF_GET, @cData )
      
      Curl_Easy_CleanUp(pCurl)
      nResponse := curl_easy_getinfo(pCurl,HB_CURLINFO_RESPONSE_CODE)

   
      IF cData == NIL //.OR. nResponse != 200
         SendMail({{"amos.engelking@engelking.de","Amos"}},"Waldom: No Data received. "+LTrim(Str(nResponse)),cData)
         RETURN
      ENDIF

      //?? " complete",Len(cData)

/*      IF Len(aData) > 0
         EXIT
      ELSE
         //Wait before re-trying
         Inkey(60,128)
      ENDIF
   NEXT*/
   cTempFile := GetEnv("TEMP")+"\waldom_"+TtoS(DateTime())+".csv"
   MemoWrit(cTempFile,cData)

   aData := FParseEx(cTempFile,",")

   IF Len(aData) == 0       
      SendMail({{"amos.engelking@engelking.de","Amos"}},"Waldom: NO Data",,{cTempFile})
      RETURN
   ENDIF

   ?? "done. ",LTrim(Str(Len(aData)))," records"

   AEval(aData[1],{|cName,nI| hFieldMap[cName] := nI })

   IF ! HHasKey(hFieldMap,WALD_STOCK_EMEA) .OR. ! HHasKey(hFieldMap,WALD_STOCK_USA)      
      SendMail({{"amos.engelking@engelking.de","Amos"}},"Waldom: Field missing",ValToPrg(hFieldMap),{cTempFile})
      RETURN
   ENDIF

   

   ? "Updating stock/prices"
   nR := Row()   
   FOR nD := 2 TO Len(aData)
      
      cMatch := aData[nD][hFieldMap["Part Number"]]
      cArtlief := ""
      
     // @ nR,30 SAY Str(nD-1)+"/"+LTrim(Str(Len(aData)-1))+" "+Pad(cMatch,50)+Pad(aData[nD][hFieldMap["In Stock EMEA"]],12)//+"="+Str(Val(aData[nD][hFieldMap["In Stock EMEA"]]))
      @ Row(),00 SAY Space(MaxCol())
      @ Row(),00 SAY cMatch
      IF cMatch == "PXP4011/10P/5560"
         //SInkey(0)
      ENDIF

      //,aData[nD][hFieldMap["In Stock USA"]]
      IF Chr(Inkey()) $ "pP"
         Sinkey(0)
      ELSEIF LastKey() == 27
      RETURN
      ENDIF 

      ali->(dbSetOrder( 3 ))
      art->(dbSetOrder( 1 ))
      IF art->(dbSeek( cMatch ))
         ?? "Part found"
         nArtnr := art->Artikelnr
         @ nR+1,30 SAY Pad("Match: "+art->Matchcode,50)
      ELSEIF ali->(dbSeek(Pad("WALDOM",8)+cMatch)) .OR. ali->(dbSeek(Pad("BULGIN",8)+cMatch)) .OR. ali->(dbSeek(Pad("BULGIN",8)+StrTran(cMatch,"/SP","")))
         ?? "Artlief"
         @ nR+1,30 SAY Pad("Artlief: "+ali->Matchcode,50)
         cMatch := ali->Matchcode
         cArtlief := ali->Artlief
         nArtnr := ali->Artikelnr  
      ELSEIF Val(aData[nD][hFieldMap[WALD_STOCK_EMEA]])+Val(aData[nD][hFieldMap["Stock USA"]])+Val(aData[nD][hFieldMap["On Order Quantity"]]) > 0
         ?? "Stock saved",Val(aData[nD][hFieldMap[WALD_STOCK_EMEA]]) //,Val(aData[nD][hFieldMap["In Stock USA"]]),Val(aData[nD][hFieldMap["On Order Quantity"]]) 
         Select("wald")
         IF ! wald->(dbSeek(cMatch))
            wald->(Add_Rec(0))
         ELSE
            wald->(Rec_Lock(0))
         ENDIF
         wald->Part := cMatch
         wald->Stock := Val(aData[nD][hFieldMap[WALD_STOCK_EMEA]]) //Val(oChildren:Find("ShipsNow"):cData)
         wald->StockUs := Val(aData[nD][hFieldMap["Stock USA"]])
         wald->OnOrder := Val(aData[nD][hFieldMap["On Order Quantity"]])
         wald->PRC := aData[nD][hFieldMap["PRC"]]
         wald->MOQ := Val(aData[nD][hFieldMap["MOQ"]])
         wald->VPE := Val(aData[nD][hFieldMap["SPQ"]])
         FOR nP := 1 TO 9
            IF Len(aData[nD]) >= hFieldMap["Price Break Qty 1"] .AND. Len(aData[nD]) >= hFieldMap["Price Break 1"]
               bBlock := wald->(FieldBlock("Break"+LTrim(Str(nP))))
               Eval(bBlock, Val(aData[nD][hFieldMap["Price Break Qty "+LTrim(str(nP))]]) )
               bBlock := wald->(FieldBlock("Price"+LTrim(Str(nP))))
               Eval(bBlock, Val(aData[nD][hFieldMap["Price Break "+Ltrim(str(nP))]]) )               
            ENDIF
         NEXT
         wald->(dbUnLock())
         Aadd(aParts,Trim(cMatch))
         LOOP      
      ELSE

         LOOP   
      ENDIF


      Aadd(aArtikel,nArtnr)

      IF lsto->(dbSeek( cLief+Str(nArtnr,6) ))
         lsto->(Rec_Lock())
      ELSE
         lsto->(Add_Rec())
         lsto->Liefma    := cLief
         lsto->Artikelnr := nArtnr
      ENDIF
      lsto->Stock := Val(aData[nD][hFieldMap[WALD_STOCK_EMEA]])
      lsto->DelTime := 7
      lsto->DelQty  := Val(aData[nD][hFieldMap[WALD_STOCK_USA]])
      lsto->(dbUnLock())

      ali->(dbSetOrder( 1 ))
      IF ! ali->(dbSeek( cLief+Str(nArtnr,6) ))
         ali->(Add_Rec())
         ali->Matchcode := cMatch
         ali->Artikelnr := nArtnr
         ali->Kunde     := cLief
      ELSE
         ali->(Rec_Lock())
      ENDIF
      ali->Min       := Val(aData[nD][hFieldMap["MOQ"]])
      ali->VPE       := Val(aData[nD][hFieldMap["SPQ"]])
      IF Val(aData[nD][hFieldMap["Lead Time"]]) > 99         
         ali->LZ     := 99
      ELSE
         ?? Val(aData[nD][hFieldMap["Lead Time"]]) 
         ali->LZ     := Val(aData[nD][hFieldMap["Lead Time"]]) 
      ENDIF
      IF ! Empty(cArtlief) .AND. ali->Artlief != cArtlief
         ali->Artlief := cArtlief
      ENDIF
      ali->(dbUnLock())

      bpr->(dbSetFilter({|| ! Empty(bpr->EndDate) .OR. bpr->EndDate <= Date() },"! Empty(EndDate) .OR. EndDate <= Date()"))
      IF ! bpr->(dbSeek( cBulgin+Str(nArtnr,6))) //keine Bulgin Preise
         art->(dbSetOrder( 2 ))
         IF art->(dbSeek( Str(nArtnr,6) ))
            art->(Rec_Lock(0))
            IF Val(aData[nD][hFieldMap["Lead Time"]]) > 99         
               art->LZ := 99
            ELSE
               art->LZ := Val(aData[nD][hFieldMap["Lead Time"]]) 
            ENDIF
            art->(dbUnLock())
         ENDIF
      ENDIF
      bpr->(dbClearFilter())

      bpr->(dbSeek( cLief+Str(nArtnr,6) ))

      FOR nX := 1 TO 9
         nQTY := Val(aData[nD][hFieldMap["Price Break Qty "+Str(nX,1)]])
         nPrice := Val(aData[nD][hFieldMap["Price Break "+Str(nX,1)]])

         IF nQty != 0
            IF bpr->Liefma == cLief .AND. bpr->Artikelnr == nArtnr
               bpr->(Rec_Lock(0))
            ELSE
               bpr->(Add_Rec(0))
               bpr->Liefma := cLief
               bpr->Artikelnr := nArtnr
            ENDIF
            bpr->Qty       := nQty
            bpr->Price     := nPrice
            bpr->Pe        := 1
            bpr->StartDate := Date()
            bpr->EndDate   := Date()+7
            bpr->Type      := "LIST"

            bpr->(dbUnLock())

            bpr->(dbSkip())
         ENDIF

      NEXT

      //delete the remaining entries if there where more price breakes before
      DO WHILE bpr->Liefma == cLief .AND. bpr->Artikelnr == nArtnr
         bpr->(Rec_Lock())
         bpr->(dbDelete())
         bpr->(dbUnLock())
         bpr->(dbSkip())
      ENDDO

   NEXT

   IF Len(aParts) == 0
      SendMail({{"amos.engelking@engelking.de","Amos"}},"Waldom download failed",,{cTempfile})
   ENDIF
   
   //reset the quantities if they have not been listed
   ? "Removing not listed stock"   
   wald->(dbGoTop())
   DO WHILE ! wald->(EOF())
      IF ! Trim(wald->Part) $ aParts
         @ Row(),30 SAY wald->Part
         wald->(Rec_Lock(0))
         wald->Stock := 0
         FOR nP := 1 TO 9 //reset prices            
            bBlock := wald->(FieldBlock("Break"+LTrim(Str(nP))))
            Eval(bBlock, 0 )
            bBlock := wald->(FieldBlock("Price"+LTrim(Str(nP))))
            Eval(bBlock, 0 )
         NEXT
         wald->(dbUnLock())
      ENDIF
      wald->(dbSkip())
   ENDDO
   @ Row(),30 SAY Space(30)
   lsto->(dbSeek( cLief ))
   DO WHILE lsto->Liefma == cLief
      IF AScan(aArtikel,lsto->Artikelnr) == 0
         @ Row(),30 SAY lsto->Artikelnr
         lsto->(Rec_Lock())
         lsto->Stock  := 0
         lsto->DelQty := 0
         lsto->(dbUnLock())
      ENDIF
      lsto->(dbSkip())
   ENDDO
? "Finished"



