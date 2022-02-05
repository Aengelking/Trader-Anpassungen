PROCEDURE RUN_WALDOM
   LOCAL cUrl := "http://www.waldomemea.com/dailyfeed/Engelking_Feed.xml"
   LOCAL cLief := Pad("WALDOM",8)
   LOCAL aArtikel := {},aParts := {},cChr
   LOCAL cArtlief
   LOCAL cList := ""
   LOCAL cData,oHttp,oXml,cQty,nArtnr,cPrice,nX,oNode,oChildren,oIter,cMatch,nTry
   LOCAL cTempFile

   CLS

   NetUse("artikel","art")
   NetUse("artlief","ali")
   NetUse("buyprice","bpr")
   NetUse("liefstock","lsto")
   NetUse("waldom","wald")
    
   //SendMail({{"amos.engelking@engelking.de","AMOS"}},"Waldom started")

   FOR nTry := 1 TO 3 //3 tries
      ? "Downloading data..."
      oHttp := TIpClientHttp():new( cUrl )
   
      //oHttp:nConnTimeout := 10000
      IF ! oHttp:open()
         SendMail({{"amos.engelking@engelking.de","AMOS"}},"No data received from Waldom")
         ? "NO DATA RETRIEVED"
         Inkey(5)
         RETURN
      ENDIF
      cData := oHttp:ReadAll()

      IF cData == NIL       
         SendMail({{"amos.engelking@engelking.de","Amos"}},"Waldom: No Data received. "+LTrim(Str(oHttp:nReplyCode))+" "+oHttp:cReplyDescr)
         RETURN
      ENDIF

      ?? " complete",Len(cData)

      //remove junk from stream data (please do not ask why this is in there, I guess it is information for the CIA :-))
      FOR EACH cChr IN {Chr(0),Chr(255),Chr(254)}
         cData := StrTran(cData,cChr,"")
      NEXT

      oXml := TXmlDocument():New()
      oXml:Read(hb_utf8tostr(cData))

      oIter := TXmlIteratorScan():New(oXml:oRoot)
      oNode := oIter:Find("row")

      IF oNode != NIL
         EXIT
      ELSE
         //Wait before re-trying
         Inkey(60,128)
      ENDIF
   NEXT
   IF oNode == NIL       
      cTempFile := GetEnv("TEMP")+"\waldom_"+TtoS(DateTime())+".xml"
      MemoWrit(cTempFile,cData)
      SendMail({{"amos.engelking@engelking.de","Amos"}},"Waldom: NO XML Data",,{cTempFile})
      RETURN
   ENDIF

   ? "Updating stock/prices"
   nR := Row()
   DO WHILE oNode != NIL
      oChildren := TXmlIteratorScan():New(oNode)
      cMatch := oChildren:Find("PartNumber"):cData
      cArtlief := ""
      
      @ nR,30 SAY cMatch

      ali->(dbSetOrder( 3 ))
      art->(dbSetOrder( 1 ))
      IF art->(dbSeek( cMatch ))
         nArtnr := art->Artikelnr
         @ nR+1,30 SAY Pad("Match: "+art->Matchcode,50)
      ELSEIF ali->(dbSeek(Pad("BULGIN",8)+cMatch)) .OR. ali->(dbSeek(Pad("BULGIN",8)+StrTran(cMatch,"/SP","")))
         @ nR+1,30 SAY Pad("Artlief: "+ali->Matchcode,50)
         cMatch := ali->Matchcode
         cArtlief := ali->Artlief
         nArtnr := ali->Artikelnr  
      ELSE
         IF  AT("/",oChildren:Find("ShipsNow"):cData) == 0
            Select("wald")
            wald->(dbGoTop())
            LOCATE FOR Trim(wald->PART) == Trim(cMatch)
            IF ! wald->(Found())
               wald->(Add_Rec(0))
            ELSE
               wald->(Rec_Lock(0))
            ENDIF
            wald->Part := cMatch
            wald->Stock := Val(oChildren:Find("ShipsNow"):cData)
            wald->(dbUnLock())
            cList += Chr(13)+Chr(10)+cMatch+" "+oChildren:Find("ShipsNow"):cData
            IF oChildren:Find("ShipsIn7Days"):cData != NIL
               cList += " "+oChildren:Find("ShipsIn7Days"):cData
            ENDIF
            Aadd(aParts,Trim(cMatch))
         ENDIF
         oNode := oIter:Next()
         LOOP
         //RETURN
      ENDIF

      Aadd(aArtikel,nArtnr)

      oChildren:Rewind()
      IF lsto->(dbSeek( cLief+Str(nArtnr,6) ))
         lsto->(Rec_Lock())
      ELSE
         lsto->(Add_Rec())
         lsto->Liefma    := cLief
         lsto->Artikelnr := nArtnr
      ENDIF

      IF Empty(oChildren:Find("ShipsNow"):cData)         
         SendMail({{"amos.engelking@engelking.de","AMOS"}},"Waldom Import No SHIPSNOW found for "+cMatch)
         lsto->Stock := 0
      ELSEIF AT("/",oChildren:Find("ShipsNow"):cData) == 0
         lsto->Stock := Val(oChildren:Find("ShipsNow"):cData)
      ELSE
         lsto->Stock := 0
      ENDIF
      lsto->DelTime := 7
      IF oChildren:Find("ShipsIn7Days"):cData != NIL .AND. AT("/",oChildren:Find("ShipsIn7Days"):cData) == 0
         lsto->DelQty  := Val(oChildren:Find("ShipsIn7Days"):cData)-1
      ELSE
         lsto->DelQty  := 0
      ENDIF
      lsto->(dbUnLock())
      
      //lWaldomDelivers := .F.
      /*IF lsto->Stock > 0
         hReqInc := GetProductRequirementAndIncoming(nArtnr)
         IF lsto->Stock > hReqInc["forecast"]*2 //stock for two months
            //compare pricing
            hWaldomPrice := GetBuyPrice( Pad("WALDOM",8), nArtnr, hReqInc["forecast"]*2 )
            hBulginPrice := GetBuyPrice( Pad("BULGIN",8), nArtnr, hReqInc["forecast"]*2 )
            IF hWaldomPrice["price"]/hWaldomPrice["unit"] < hBulginPrice["price"]/hBulginPrice["unit"]
               lWaldomDelivers := .T.
               ali->(dbSetOrder( 1 ))
               IF ali->(dbSeek( Pad("BULGIN",8)+Str(nArtnr,6) )) .AND. ali->LZ == 0 .AND. art->LZ > 1 //save bulgin delivery time
                  ali->(Rec_Lock())
                  ali->LZ := art->LZ
                  ali->(dbUnLock())
               ENDIF
               art->(dbSetOrder( 2 ))
               IF art->(dbSeek( Str(nArtnr,6) ))
                  art->(Rec_Lock())
                  art->LZ := 1
                  art->(dbUnLock())
               ENDIF
            ENDIF
         ENDIF
      ENDIF
      IF ! lWaldomDelivers
         ali->(dbSetOrder( 1 ))
         art->(dbSetOrder( 2 ))
         IF ali->(dbSeek( Pad("BULGIN",8)+Str(nArtnr,6) )) .AND. art->(dbSeek( Str(nArtnr,6) )) .AND. (ali->LZ > art->LZ .OR. ali->LZ <= 1)
            art->(Rec_Lock())
            art->LZ :=  IF(ali->LZ==1,0,ali->LZ) //waldom LZ was saved to ali if it is 1
            art->(dbUnLock())
         ENDIF
      ENDIF */
      
      /*IF nArtnr == 1779 .AND. ! GetConfigValue("BATCHMODE")
         ? "We buy from: ",IF(lWaldomDelivers,"WALDOM","BULGIN")

         Inkey(0,128)
      ENDIF*/

      ali->(dbSetOrder( 1 ))
      IF ! ali->(dbSeek( cLief+Str(nArtnr,6) ))
         ali->(Add_Rec())
         ali->Matchcode := cMatch
         ali->Artikelnr := nArtnr
         ali->Kunde     := cLief
      ELSE
         ali->(Rec_Lock())
      ENDIF
      oChildren:Rewind()
      ali->Min       := Val(oChildren:Find("MOQ"):cData)-1
      ali->VPE       := 1 
      IF ! Empty(cArtlief) .AND. ali->Artlief != cArtlief
         ali->Artlief := cArtlief
      ENDIF
      ali->(dbUnLock())

      bpr->(dbSeek( cLief+Str(nArtnr,6) ))

      FOR nX := 1 TO 8
         cQty := oChildren:Find("PriceBreakQty"+Str(nX,1)):cData
         cPrice := oChildren:Find("PriceBreak"+Str(nX,1)):cData
         IF Empty(cQty)
            EXIT
         ENDIF

         IF bpr->Liefma == cLief .AND. bpr->Artikelnr == nArtnr
            bpr->(Rec_Lock(0))
         ELSE
            bpr->(Add_Rec(0))
            bpr->Liefma := cLief
            bpr->Artikelnr := nArtnr
         ENDIF
         bpr->Qty       := Val(cQty)-IF(nX>1,1,0)
         bpr->Price     := Val(cPrice)
         bpr->Pe        := 1
         bpr->StartDate := Date()
         bpr->EndDate   := Date()+7
         bpr->Type      := "LIST"

         bpr->(dbUnLock())

         bpr->(dbSkip())

      NEXT

      //delete the remaining entries if there where more price breakes before
      DO WHILE bpr->Liefma == cLief .AND. bpr->Artikelnr == nArtnr
         bpr->(Rec_Lock())
         bpr->(dbDelete())
         bpr->(dbUnLock())
         bpr->(dbSkip())
      ENDDO

      oNode := oIter:Next()

   ENDDO

   IF Len(aParts) == 0
      cTempFile := GetEnv("TEMP")+"\waldom_"+TtoS(DateTime())+".xml"
      MemoWrit(cTempFile,cData)
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

//SendMail({{"amos.engelking@engelking.de","AMOS"}},"Waldom import completed.","Tries: "+LTrim(Str(nTry)))

//MemoEdit(cList)
//Inkey(0,128)


FUNCTION type_cb()
RETURN 0



