PARAMETERS nArtnr,cArtlief,cMatch

LOCAL nX,hData,hPrice,hPrices := {=>},oHttp,oHttp2
LOCAL nPos,cPrices,cDomain := "https://www.buerklin.com"
LOCAL lDbg := .F.  //Tr_Getini(28) == 9 .AND. ! GetConfigValue("BATCHMODE")
LOCAL hCookies := {=>},cValue
LOCAL cScreen
   
   cUrl :=  cDomain+"/de/p/x/x/"+Lower(Trim(StrTran(StrTran(cMatch,"/","-"),"#MT","")))+"/"+StrTran(cArtLief," ","")+"/"
   IF lDBg
      //gtSetClipboard(cUrl)
      Alert(cUrl)
   ENDIF
   cData := __DownLoadPage(cUrl) //oHttp:readAll()

   IF ValType(cData) == "C"       
      IF lDbg
         cScreen := SaveScreen()
         MemoEdit(cData)
         //gtSetClipboard(cData)
         RestScreen(,,,,cScreen)
      ENDIF
      IF (nP := AT("crossselling",cData)) != 0
         cData := SubStr(cData,1,nP)  //cut off all crossselling products to avoid wrong information
      ENDIF            
      IF AT("Dieser Artikel ist ein Auslaufartikel",cData) != 0 .OR. AT("Entschuldigung, die Seite wurde nicht gefunden",cData) != 0 //keine Preise mehr verfgbar         
         IF lDbg
            Alert("Auslauf")            
         ENDIF
         IF ! GetConfigValue("BATCHMODE")
            IF Tr_MsgBox({"Artikel nicht mehr bei Brklin erh„ltlich.","Bitte Lieferant l”schen - vorher ber Seite ”ffnen nochmals prfen"},,{"OK","Seite ”ffnen"}) == 2
               WAPI_ShellExecute(,"open",cUrl)
            ENDIF
         ELSE
            SendMessage("PRODUKTMANAGEMENT | Artikel nicht mehr verfgbar","Artikel nicht mehr bei Brklin erh„tlich "+Trim(art->Matchcode),cUrl)
         ENDIF
         RETURN NIL //hPrices
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
      IF Len(hPrices) == 0
         SendMail({{"amos.engelking@engelking.de","Amos"}},"Keine Preise bei Brklin gefunden fr: "+Trim(art->Matchcode),cData)
      ENDIF
   ELSE
      IF lDbg
         Alert("No data received")
      ENDIF
      SendMail({{"amos.engelking@engelking.de","Amos"}},"Preise von Brklin konnten fuer "+Trim(art->Matchcode)+" nicht geladen werden",cData)
   ENDIF
   IF lDbg
      Alert(ValToPrg(hPrices))
   ENDIF

RETURN hPrices

#include '\\EK-SERVER2\trader\run\curl.prg'