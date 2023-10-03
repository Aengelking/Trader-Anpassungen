PARAMETERS nArtnr,cArtlief,cMatch

LOCAL nX,hData,hPrice,hPrices := {=>},oHttp,oHttp2
LOCAL nPos,cPrices,cDomain := "https://www.buerklin.com"
LOCAL lDbg := .F. // Tr_Getini(28) == 9 .AND. ! GetConfigValue("BATCHMODE")
LOCAL hCookies := {=>},cValue
LOCAL cScreen
   
   cUrl :=  cDomain+"/de/p/x/x/"+Lower(Trim(StrTran(cMatch,"/","-")))+"/"+StrTran(cArtLief," ","")+"/"
   IF lDBg
      gtSetClipboard(cUrl)
      Alert(cUrl)
   ENDIF
   cData := __DownLoadPage(cUrl) //oHttp:readAll()

   IF ValType(cData) == "C"       
      IF lDbg
         /*cScreen := SaveScreen()
         MemoEdit(cData)*/
         gtSetClipboard(cData)
         //RestScreen(,,,,cScreen)
      ENDIF
      IF (nP := AT("crossselling",cData)) != 0
         cData := SubStr(cData,1,nP)  //cut off all crossselling products to avoid wrong information
      ENDIF            
      IF AT("Dieser Artikel ist ein Auslaufartikel",cData) != 0  //keine Preise mehr verfgbar         
         IF lDbg
            Alert("Auslauf")
         ENDIF
         SendMail({{"amos.engelking@engelking.de","Amos"}},"Artikel nicht mehr bei Brklin erh„tlich "+Trim(art->Matchcode),"")
         RETURN hPrices
      ENDIF
      cData := SubStr(cData,AT("ScaleOfPricesComponent",cData)+22)
      IF AT('data-scale-of-price-sku="'+StrTran(cArtLief," ","")+'"',cData) > 0 //es gibt staffelpreise
         //Alert(SubStr(cData,1,AT("Staffelpreise",cData)))
         IF lDbg; Alert("Staffel"); ENDIF
         //cData := SubStr(cData,AT("ScaleOfPricesItemComponent",cData)+26)
         IF AT("ScaleOfPricesComponent",cData) != 0//remove any further tables, e.g. accessories
            cData := SubStr(cData,1,AT("ScaleOfPricesComponent",cData))
         ENDIF
         //cData := SubStr(cData,AT("</thead",cData))
         IF lDbg
            Alert(cData)
         ENDIF
         aBreaks := HB_RegexAll('data-scale-of-prices-item-quantity="([0-9\.]*)',cData)
         aPrices := HB_RegexAll('data-scale-of-prices-item-price="([0-9\.]*)',cData)
         IF lDbg
            Alert(ValToPrg(aBreaks)+ValToPrg(aPrices))
         ENDIF
         FOR nX := 1 TO Len(aBreaks) //STEP 3 
            IF nX <= Len(aPrices)       
               hPrices[Val(aBreaks[nX,2])] := Val(aPrices[nX,2])/1.19 //Val(aBreaks[nX+2,2])
            ENDIF
         NEXT
      ELSE //es gibt nur einen Preis
         cData := SubStr(cData,AT('data-price="',cData)+12)
         cData := SuBStr(cData,1,AT('"',cData)-1)
         IF lDbg
            Alert(cData)
         ENDIF
         aBreaks := HB_Regex('[0-9\.]+',cData)
         IF Len(aBreaks) > 0
           hPrices[1] := Val(aBreaks[1])/1.19
         ENDIF
      ENDIF

   ELSEIF lDbg
      Alert("No data received")
   ENDIF
   IF lDbg
      Alert(ValToPrg(hPrices))
   ENDIF

RETURN hPrices

#include '\\EK-SERVER2\trader\run\curl.prg'