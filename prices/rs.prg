FUNCTION RUN_PRICES_RS(nArtnr,cArtlief,cMatch,lSub)

LOCAL nX
LOCAL lDbg := .F. //Tr_Getini(28) == 9 .AND. ! GetConfigValue("BATCHMODE")
LOCAL cChr
LOCAL hPrices,cUrl,nPe,aRegex
LOCAL hData,hSubData
LOCAL nBrake,nPrice,aBrakes
LOCAL oArtikel,cData,nAmount,nPos,cValue,hPrices2,nLow,nHigh
LOCAL aTexts,nT

MEMVAR cPriceError


   IF lSub != .T. .AND. Right(Trim(Upper(cArtLief)),1) $ "PA"
      cArtLief := SubStr(cArtLief,1,Len(Trim(cArtlief))-1)
   ENDIF

   cUrl := "https://de.rs-online.com/web/p/products/"+Trim(cArtlief)+"/"
   //cUrl := "https://de.rs-online.com/web/p/industrie-automation-steckverbinder/4260919/"

   cData := __DownLoadPage(cUrl,,.F.)
   
   IF lDbg
      gtSetClipboard(cData,,.F.)
   ENDIF

   If ValType(cData) != "C"
      IF lDbg
         Alert("No Data")         
      ENDIF
      cPriceError := "NO DATA"
      RETURN NIL
   ELSEIF lDbg .AND. "Leider konnten wir die von Ihnen gesuchte Seite nicht finden" $ cData
      Alert("Part not found;"+cArtlief)
   Endif

   aRegex := HB_Regex("Preis pro.*?([0-9]*) Stück([^\(][^0-9]*([0-9]+))?",cData) //
   nPe := 1

   oArtikel := Artikel():New(.F.)
   oArtikel:Load(nArtnr)

   IF oArtikel:Me == "STCK" .AND. Len(aRegex) >= 2 .AND. ! Empty(aRegex[2])
      nPe := Max(Val(aRegex[2]),1)
   ELSEIF oArtikel:Me == "PACK" .AND. Len(aRegex) >= 4
      nPe := 1/Max(Val(aRegex[4]),1)
      IF lDbg
         Alert("Pack, Preiseinheit: "+LTrim(Str(nPE)))
      ENDIF
   ENDIF

   aTexts := {{"breakRange","unitPrice"},{"price-breaks-quantity","price-breaks-price"}}
   FOR nT := 1 TO Len(aTexts)
      IF aTexts[nT,1] $ cData
         EXIT
      ENDIF
   NEXT
   
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

   IF ValType(lSub) != "L" .OR. lSub != .T.
      FOR EACH cChr IN {"P","A"}
         cArtLief := Trim(cArtlief)+cChr
         hPrices2 := MBaseRun(Trim(Tr_Getini(1))+"\run\prices\rs",{art->Artikelnr,cArtLief,art->Matchcode,.T.})
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
