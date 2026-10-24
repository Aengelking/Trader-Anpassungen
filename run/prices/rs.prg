FUNCTION RUN_PRICES_RS(nArtnr,cArtlief,cMatch,lSub)

LOCAL nX
LOCAL lDbg := .F. //Tr_Getini(28) == 9 .AND. ! GetConfigValue("BATCHMODE")
LOCAL lPriceDbg := .T.
LOCAL cChr
LOCAL hPrices,cUrl,nPe,aRegex
LOCAL hData,hSubData
LOCAL nBrake,nPrice,aBrakes
LOCAL oArtikel,cData,nAmount,nPos,cValue,hPrices2,nLow,nHigh
LOCAL aTexts,nT,nSec,cProdType,cArtLief2
LOCAL hGroups := {;
   "STIE"=>"iec-steckverbinder",;
   "STWP"=>"industrie-automation-steckverbinder",;
   "SHST"=>"sicherungshalter";
   }

MEMVAR cPriceError


   IF (ValType(lSub) != "L" .OR. !lSub) .AND. Right(Trim(Upper(cArtLief)),1) $ "PA"
      cArtLief := SubStr(cArtLief,1,Len(Trim(cArtlief))-1)
   ENDIF

   cProdType := "products"
   
   IF HB_RegexMatch("PX.603[3-4].*",Trim(art->Matchcode))
      cProdType := "ethernet-steckverbinder"
   ELSEIF Trim(art->Matchcode) $ {"PXM6083","PX0810","PX0811","PX0733"}
      cProdType := "staubkappen-rundsteckverbinder"
   ELSEIF art->Gruppe $ hGroups
      cProdType := hGroups[art->Gruppe]
   ENDIF
   IF lDbg; Alert(art->Gruppe+";"+cProdType); ENDIF

   cUrl := "https://de.rs-online.com/web/p/"+cProdType+"/"+Trim(cArtlief) //+"/"
   //cUrl := "https://de.rs-online.com/web/p/industrie-automation-steckverbinder/4260919/"
   nSec := Seconds()
   cData := __DownLoadPage(cUrl,,.F.)
   
   IF lDbg
      //gtSetClipboard(cData,,.F.)
      gtSetClipboard(cUrl)
      Alert("Download from: "+cUrl+"; Took "+LTrim(Str(Seconds()-nSec))+"s")
      gtSetClipboard(cData)
   ENDIF

   If ValType(cData) != "C"
      IF lDbg
         Alert("No Data")         
      ENDIF
      cPriceError := "NO DATA"
      RETURN NIL
   ELSEIF lDbg .AND. "Leider konnten wir die von Ihnen gesuchte Seite nicht finden" $ cData
      Alert("Part not found;"+cArtlief)
   ELSEIF hb_strToUtf8("Nicht mehr im Sortiment") $ cData
      //SendMessage("PRODUKTMANAGEMENT | Artikel nicht mehr verfgbar","Artikel bei RS nicht mehr erh„tlich "+Trim(art->Matchcode),"RS wurde als Lieferant bei diesem Artikel entfernt<br>"+cUrl)      
      IF lDbg
         Alert("Part not available;"+cArtlief)
      ENDIF
      IF Trim(ali->Artlief) == Trim(cArtlief) .AND. Trim(ali->Kunde) == "RS"  //we are on the correct article
         ali->(Rec_Lock(0))
         ali->Artlief := ""  //avoid further updates
         ali->(dbUnlock())
      ENDIF
      cPriceError := "Part not available"
      RETURN NIL
   /*ELSEIF hb_strToUtf8("Derzeit nicht erh„ltlich") $ cData //text seems to be on every page
      SendMessage("PRODUKTMANAGEMENT | Artikel nicht verfgbar","Artikel bei RS derzeit nicht verfgbar "+Trim(art->Matchcode),"RS wurde als Lieferant bei diesem Artikel entfernt<br>"+cUrl)      
      IF lDbg
         Alert("Part currently not available;"+cArtlief)
      ENDIFn
      IF Trim(ali->Artlief) == Trim(cArtlief) .AND. Trim(ali->Kunde) == "RS"  //we are on the correct article
         //ali->(Rec_Lock(0))
         //ali->(dbDelete())
         //ali->(dbUnlock())
      ELSE         
         Alert("Part not available;"+cArtlief)
         
      ENDIF
      cPriceError := "Part not available"
      RETURN {=>}*/
   Endif

   aRegex := HB_Regex("Preis pro[\s:]*?([0-9]*) StÃ¼ck([^\(][^0-9]*([0-9]+))?",cData) //
   nPe := 1

   oArtikel := Artikel():New(.F.)
   oArtikel:Load(nArtnr)

   IF oArtikel:Me == "STCK" .AND. Len(aRegex) >= 2 .AND. ! Empty(aRegex[2])
      nPe := Max(Val(aRegex[2]),1)
   ELSEIF oArtikel:Me == "PACK" 
      IF Len(aRegex) >= 4
         nPe := 1/Max(Val(aRegex[4]),1)
         IF lDbg
            Alert("Pack, Preiseinheit: "+LTrim(Str(nPE))+";Regex: "+ValToPrg(aRegex))
         ENDIF
      ELSE
         oExtra := art->(ExtraData():New(art->Artikelnr))
         IF oExtra:VpePack != 0
            nPe := 1/oExtra:VpePack
         ELSE
            nPE := 1/10 //default to 10 if nothing else is known
         ENDIF
      ENDIF
   ENDIF

   aTexts := {{"breakRange","unitPrice"},{"price-breaks-quantity","price-breaks-price"}}
   FOR nT := 1 TO Len(aTexts)
      IF aTexts[nT,1] $ cData
         EXIT
      ENDIF
   NEXT
   
   IF lDbg .AND. ! lPriceDbg
      lDbg := .F.
   ENDIF

   hPrices := {=>}

   IF nT > Len(aTexts)
      IF lDbg
         Alert("No prices found for "+cArtLief)
      ENDIF
      Return hPrices 
   ENDIF

   
   nX := 1
   nAmount := 0
   DO WHILE (nPos := AT(aTexts[nT,1],cData)) > 0
      cData := SubStr(cData,nPos+Len(aTexts[nT,1]))
      cData := SubStr(cData,At(">",cData)+1)

      IF lDbg
         Alert("Data: "+cData)
      ENDIF         
      cValue := SubStr(cData,1,AT("-",cData)-1)

      IF lDbg
         //Alert("Qty: "+cValue+";"+Str(Val(cValue)))
      ENDIF

      nAmount := Val(cValue)
      IF nAmount != 0
         cValue := SubStr(cData,AT(aTexts[nT,2],cData)) //+Len(aTexts[nT,1])

         cValue := SubStr(cValue,AT(">",cValue)+1)
         
         cValue := SubStr(cValue,1,AT(Chr(226),cValue)-1)
         IF lDbg
            Alert("Price: "+cValue)
         ENDIF

         hPrices[nAmount*nPe] := Val(StrTran(cValue,",","."))/nPe
         
      ENDIF
      nX++
   ENDDO
   
   //15.08.23 deactivated as it takes very long
   IF .F. //ValType(lSub) != "L" .OR. lSub != .T.
      FOR EACH cChr IN {"P","A"}
         cArtLief2 := Trim(cArtlief)+cChr
         hPrices2 := MBaseRun(Trim(Tr_Getini(1))+"\run\prices\rs",{art->Artikelnr,cArtLief2,art->Matchcode,.T.})
         IF hPrices2 != NIL
            FOR EACH nPrice IN hPrices2
               nBrake := nPrice:__eNumkey()
               IF HHasKey(hPrices,nBrake)
                  IF hPrices[nBrake] > nPrice
                     hPrices[nBrake] := nPrice
                  ENDIF
               ELSE
                  aBrakes := HB_HKeys(hPrices)
                  nLow := AScan(aBrakes,{|x| x < nBrake })
                  nHigh := AScan(aBrakes,{|x| x > nBrake })
                  IF (nLow == 0 .OR. hPrices[aBrakes[nLow]] > nPrice) .AND. (nHigh == 0 .OR. hPrices[aBrakes[nHigh]] < nPrice)
                     hPrices[nBrake] := nPrice
                  ENDIF
               ENDIF
            NEXT
         ENDIF
      NEXT
   ENDIF

   cPriceError := "Url:"+cUrl+Chr(13)+Chr(10)+"Page dump: "+cData
   IF lDbg
      //Alert(ValToPrg(hPrices))
   ENDIF

Return hPrices   
   
#include '\\EK-SERVER2\trader\run\curl.prg'
