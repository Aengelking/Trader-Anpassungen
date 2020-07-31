//#include 'hbcurl.ch'
FUNCTION RUN_PRICES_ARROW(nArtnr,cArtlief)
   LOCAL lDbg := .F. //Tr_Getini(28) == 9
   LOCAL cPr,cQty
   LOCAL cData,hPrices,nNext,cSub
   LOCAL pCurl,nErr
   //LOCAL cUrl := "https://components.arrow.com/part/detail/0323_"+PadL(Trim(cArtlief),8,"0")+"?region=arrowce"
   LOCAL cUrl,cManu
   LOCAL aRegex

   HB_SYMBOL_UNUSED(nArtnr)

   IF art->Manufactur == 1
      cManu := "bulgin-components-plc"
   ELSEIF art->Manufactur == 3
      cManu := "illinois-tool-works"
   ELSE
      RETURN {=>}
   ENDIF

   cUrl := "https://www.arrow.de/products/"+Trim(art->Matchcode)+"/"+cManu

   /*pCurl := Curl_Easy_Init()
   curl_easy_setopt(pCurl, HB_CURLOPT_BUFFERSIZE, 102400)
   curl_easy_setopt(pCurl, HB_CURLOPT_URL, cUrl )
   curl_easy_setopt(pCurl, HB_CURLOPT_NOPROGRESS, 1)
   //curl_easy_setopt(pCurl, HB_CURLOPT_USERAGENT, "Mozilla/5.0 (Windows NT 6.2; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/63.0.3239.84 Safari/537.36")
   curl_easy_setopt(pCurl, HB_CURLOPT_MAXREDIRS, 50)
   curl_easy_setopt(pCurl, HB_CURLOPT_HTTP_VERSION, "URL_HTTP_VERSION_2TLS")
   curl_easy_setopt(pCurl, HB_CURLOPT_CAINFO, "Y:\Curl\curl-7.67.0-win32-mingw\bin\curl-ca-bundle.crt")
   curl_easy_setopt(pCurl, HB_CURLOPT_TCP_KEEPALIVE, 1)
   curl_easy_setopt(pCurl, HB_CURLOPT_DL_BUFF_SETUP )
   nErr := Curl_Easy_Perform(pCurl)
   curl_easy_setopt( pCurl, HB_CURLOPT_DL_BUFF_GET, @cData )
   IF lDbg
      Alert( "Curl: "+Str(nErr) )
      Alert( "HTTP Response: "+Str(curl_easy_getinfo(pCurl,HB_CURLINFO_RESPONSE_CODE)) )
      Alert(cData)
   ENDIF
   Curl_Easy_CleanUp(pCurl)   

   IF nErr != 0
      IF lDbg 
         Alert("Error receiving data")
      ENDIF
      RETURN {=>}
   ENDIF*/
   cData := __DownLoadPage(cUrl,,.F.)

   /*oHttp := TIpClientHttp():new( cUrl )
   oHttp:nConnTimeout := 10000
   IF oHttp:open()
     cData := oHttp:ReadAll()
      If ValType(cData) != "C"
         IF lDbg
            Alert("No Data")
         ENDIF
         RETURN NIL
      Endif*/
      
      IF lDbg
         memoEdit(cData)
         gtSetClipboard(cData)
      ENDIF

      IF AT("This product is not available",cData) != 0
         IF lDbg
            Alert("Product not available")
         ENDIF
         RETURN {1=>99999}
      ENDIF

      cData := SubStr(cData,AT('class="BuyingOptions-priceTiers d-none d-sm-block ng-star-inserted">',cData))
      cData := SubStr(cData,1,AT("</ol",cData)-1)

      hPrices := {=>}

      DO WHILE (nNext := AT("</li",cData)) != 0
         cSub := SubStr(cData,1,nNext-1)

         aRegex := HB_Regex(">([0-9]*)\+",cData)
         IF Len(aRegex) > 2
            cQty := aRegex[2] //SubStr(cSub,1,AT("+:",cSub)-1)
            aRegex := HB_Regex(">([0-9,]*)\s€",cData)
            cPr := aRegex[2] //SubStr(cSub,AT("&euro;",cSub)+6)

            hPrices[Val(StrTran(cQty,",",""))] := Val(StrTran(cPr,",","."))
         ENDIF
         cData := SubStr(cData,nNext+4)
      ENDDO
      
      IF Len(hPrices) == 0
         //SendMail({{"amos.engelking@engelking.de","Amos"}},"Abruf Preise Arrow "+Trim(art->Matchcode),"Geht nicht!")
      ENDIF

      Return hPrices
   /*ELSE
      RETURN NIL
   ENDIF*/

   #include '\\EK-SERVER2\trader\run\curl.prg'
