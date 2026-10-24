#include 'y:\hb34\contrib\hbcurl\hbcurl.ch'

FUNCTION FARNELL(nArtnr,cArtlief)

LOCAL oHttp,hData,hPrices,hPrice
LOCAL lDbg :=  Tr_getini(28) == 9 .AND. ! GetConfigValue("BATCHMODE")
LOCAL nPos 
LOCAL cUrl := "https://de.farnell.com/x/x/x/dp/"+Trim(cArtlief)
//LOCAL cUrl := "https://de.farnell.com/"
//LOCAL cUrl := "http://104.104.198.188/x/x/x/dp/3135822"
LOCAL lSuccess := .F.
LOCAL nCount := 1
LOCAL cLog := ""
LOCAL cData,cJsonData,aData,aPrice
LOCAL cPage
LOCAL pCurl,oFarnell

MEMVAR cPriceError 
PUBLIC cPriceError := ""

//RETURN NIL  //08.10.21 disabled, Farnell is returning access denied

   HB_SYMBOL_UNUSED(nArtnr)

   IF .F. //lDbg
      nSecs := Seconds()
      cData := NIL
      //HB_UnCompress(,cData,Len(cData),@cNewData)
      oFarnell := RestApi():New()
      oFarnell:cBaseUrl := "https://api.browse.ai/v2/robots/9bc466e8-2aab-43dc-9c7b-715ec4bf4aea/tasks"
      
      cData := oFarnell:Execute("","POST",{"inputParameters"=>{"originUrl"=>cUrl}},{"Authorization: Bearer 9ba19df2-a263-4251-8022-9d70ab149610:993b190c-2209-414c-8698-c50c50adbed7"},.T.)
      
      hData := HB_JsonDecode(cData)            
      
      IF ! HHasKey(hData,"result") .OR. ! HHasKey(hData["result"],"status")
         IF HHasKey(hData,"statusCode") .AND. hData["statusCode"] == 403
            SendMail({{"amos.engelking@engelking.de","Amos"}},"BrowseAI Abfrage Limit erreicht",cData)
         ENDIF
         RETURN {=>}
      ELSE
         DO WHILE hData["result"]["status"] != "successful"
            Inkey(2,128)
            cData := oFarnell:Execute("/"+hData["result"]["id"],"GET",{=>},{"Authorization: Bearer 9ba19df2-a263-4251-8022-9d70ab149610:993b190c-2209-414c-8698-c50c50adbed7"})
            IF cData == NIL
               EXIT
            ELSE
               hData := HB_JsonDecode(cData)
            ENDIF
            
         ENDDO
      ENDIF

      IF lDbg
         Alert("BrowseAI took: "+Str(Seconds()-nSecs)+"s")
      ENDIF
      
      hPrices := {=>}
      IF HHasKey(hData["result"]["capturedLists"],"Preise")           
         FOR EACH hPrice IN hData["result"]["capturedLists"]["Preise"]
            hPrices[Val(hPrice["Menge"])] := Val(StrTran(hPrice["Preis"],",","."))
         NEXT
         RETURN hPrices         
      ENDIF
   ENDIF


   //libcurl times out, the command line seems to work fine!
   IF .F. //lDbg
      oFarnell := RestApi():New()
      oFarnell:cBaseUrl := "https://app.zenscrape.com/api/v1/get"
      hParams := {"apikey"=>"41a78750-aa55-11ee-abc7-6960be9094de",;
                  "url"=>"https://www.google.de",; //cUrl,;
                  "location"=>"eu",;
                     "render"=>.T.,"premium"=>.T.}
                  //"url"=>"https%3A%2F%2Fde.farnell.com%2Fx%2Fx%2Fx%2Fdp%2F3841479",;
      cData := oFarnell:Execute("","GET",hParams)
      Alert(cData)
      lSuccess := .T.
   ELSE
      cData := __DownLoadPage(cUrl)
      lSuccess := .T.
   ENDIF

   IF lDbg
      gtSetClipboard(cData)
   ENDIF

   /*DO WHILE ! lSuccess .AND. nCount < 10
      oHttp := TIpClientHttp():new( cUrl )
      oHttp:lPersistent := .T.
      oHttp:hFields["Connection"] := "keep-alive"*/
      //oHttp:hFields["Accept"] := "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8"
      /*oHttp:hFields["Accept-Language"] := "de-DE,de;q=0.9,en-US;q=0.8,en;q=0.7,nl;q=0.6"
      oHttp:cUserAgent := "Mozilla/5.0 (Windows NT 6.2; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/63.0.3239.84 Safari/537.36"

      oHttp:nConnTimeout := 10000


      IF ! oHttp:open() .AND. lDbg
         Alert("Could not open")
      ENDIF
      cData := cPage := oHttp:readAll()

      IF Empty(cData) .AND. oHttp:nReplyCode == 200
         IF lDbg 
            CLS
            ? "Retry"
         ENDIF
         cData := oHttp:readAll()
      ENDIF
      IF lDbg
         Alert("Headers: "+ValToPrg(oHttp:hHeaders))

         Alert(ValToPrg( oHttp:nReplyCode )+ValToPrg(cData))
      ENDIF
      IF oHttp:nReplyCode == 301
         nCount++
         cUrl := oHttp:hHeaders["Location"]
         IF lDbg
            Alert("Redirect: "+cUrl)
         ENDIF
      ELSE
         lSuccess := .T.
      ENDIF
   ENDDO*/

   IF lDbg
      //MemoEdit(cLog)
   ENDIF

   If lSuccess

      IF Empty(cData)
         IF lDbg
            Alert("NO DATA")
         ENDIF
         cPriceError := "Blank page received."
         //Alert(ValToPrg(oHttp:hHeaders))
         //Alert(ValToPrg(oHttp:getCookies()))
         Return NIL
      ELSE
         IF lDbg
            gtSetClipboard(cData)
         ENDIF   
         IF AT("gesuchte Seite nicht gefunden",cData) != 0
            IF lDbg
               Alert("Produkt nicht gefunden")
            ENDIF
            RETURN NIL
         ENDIF
         IF AT("Access Denied",cData) != 0
            IF lDbg
               Alert("Access denied")
            ENDIF
            RETURN NIL
         ENDIF
      ENDIF

      
      nPos := AT('tableProductDetailPrice',cData )
      IF nPos == 0
         IF lDbg
            Alert("NO TABLE FOUND")
         ENDIF
         nPos := AT('jsonProductData">',cData )+17
         IF nPos != 0
            IF lDbg
               Alert("JSON")
            ENDIF   
            cJsonData := SubStr(cData,nPos)
            
            cjSonData := AllTrim(SubStr(cData,1,AT("</script",cjSonData)))

            IF lDbg
               Alert(cJsonData)
            ENDIF

            hData := NIL
            HB_JsonDecode(cJsOnData,@hData)

            IF lDbg
               Alert(ValToPrg(hData))
               IF  ValType(hData) == "H" 
                  Alert(ValToPrg(hData["productList"]["main"][1]["price"]["priceList"]))
               ENDIF
            ENDIF

            hPrices := {=>}
            IF ValType(hData) == "H" .AND. HHasKey(hData,"productList")
               FOR EACH hPrice IN hData["productList"]["main"][1]["price"]["priceList"]         
                  hPrices[Val(hPrice["minQty"])] := hPrice["price"]
               NEXT
            ENDIF
         ENDIF
      ELSE
         IF lDbg
            Alert("TABLE")
         ENDIF
         hPrices := {=>}
         
         cData := SubStr(cData,nPos)
         //cData := SubStr(cData,1,AT("</table",cData))
         aData := {}
         DO WHILE (nPos := AT("PriceBreakArray=",cData)) > 0 //get Price data, contained in a script
            cData := SubStr(cData,nPos+16)   
            IF lDbg 
               Alert(SubStr(cData,1,AT(Chr(13),cData)-1))
            ENDIF         
            HB_JsonDecode(SubStr(cData,1,AT(Chr(13),cData)-1),@aData)            
         ENDDO
         FOR EACH aPrice IN aData
            hPrices[aPrice[1]] := aPrice[2]
         NEXT

      ENDIF
      IF Empty(hPrices) //no success
         cPriceError := "No prices found." // Page dump: "+cPage
      ENDIF
         //nX := 1
      /*nAmount := 0
      DO WHILE (nPos := AT("<td",cData)) > 0
         cData := SubStr(cData,nPos)
         cData := SubStr(cData,At(">",cData)+1)
         cLine := LTrim(StrTran(SubStr(cData,1,At("/td>",cData)-4),Chr(13),""))

         IF nX % 2 == 0
            cLine := SubStr(cLine,AT(">",cLine)+1)

            cValue := SubStr(cLine,1,AT("&e",cData)-1)
            //Aadd(aPrices,Val(StrTran(cValue,",",".")))
            hPrices[nAmount] := Val(StrTran(cValue,",","."))
         ELSE
            nAmount := Val(Left(cLine,6))
//            Alert(Left(cLine,6)+";"+Str(nAmount))
         ENDIF
         nX++
      ENDDO*/

      Return hPrices
   ELSE
      cPriceError := "Data not retrieved"
   ENDIF

RETURN NIL

#include '\\EK-SERVER2\trader\run\curl.prg'