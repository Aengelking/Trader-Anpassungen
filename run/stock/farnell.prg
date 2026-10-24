#include 'hbcurl.ch'
FUNCTION RUN_STOCK_FARNELL(nArtnr,cArtlief)

   LOCAL cUrl
   LOCAL lDbg := .F. //Tr_Getini(28) == 9
   LOCAL lSuccess := .F.
   LOCAL nCount := 1
   LOCAL cSearch
   LOCAL pCurl,cData,nErr
   LOCAL aHeader

   HB_SYMBOL_UNUSED(nArtnr)

RETURN -1 //Does not work at the moment

   
	//cSearch := "PFProductInventoryStatus.jsp"
   cSearch := 'available">'

//   oHttp := TIpClientHttp():new( "http://de.farnell.com/jsp/commonfragments/productTotalWarehouseInventory.jsp?sku="+Trim(cArtlief) )
   cUrl :=  "http://de.farnell.com/x/x/x/dp/"+Trim(cArtlief)

   pCurl := Curl_Easy_Init()
   curl_easy_setopt(pCurl, HB_CURLOPT_BUFFERSIZE, 102400)
   curl_easy_setopt(pCurl, HB_CURLOPT_URL, cUrl )
   curl_easy_setopt(pCurl, HB_CURLOPT_NOPROGRESS, 1)
   curl_easy_setopt(pCurl, HB_CURLOPT_USERAGENT, "Mozilla/5.0 (Windows NT 6.2; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/63.0.3239.84 Safari/537.36")
   aHeader := {}
   Aadd(aHeader,"Connection: keep-alive")
   Aadd(aHeader,"Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8")
   Aadd(aHeader,"Accept-Language: de-DE,de;q=0.9,en-US;q=0.8,en;q=0.7,nl;q=0.6")
   curl_easy_setopt(pCurl, HB_CURLOPT_HEADER, aHeader )
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


   /*DO WHILE ! lSuccess .AND. nCount < 10
      oHttp := TIpClientHttp():new( cUrl )
      oHttp:lPersistent := .T.
      oHttp:hFields["Connection"] := "keep-alive"*/
      //oHttp:hFields["Accept"] := "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8"
/*      oHttp:hFields["Accept-Language"] := "de-DE,de;q=0.9,en-US;q=0.8,en;q=0.7,nl;q=0.6"
      oHttp:cUserAgent := "Mozilla/5.0 (Windows NT 6.2; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/63.0.3239.84 Safari/537.36"

      oHttp:nConnTimeout := 10000
      //oHttp:nConnTimeout := 1000
      IF ! oHttp:open() .AND. lDbg
         Alert("Could not open")
      ENDIF

      cData := oHttp:readAll()*/
      IF lDbg
         Alert("Headers: "+ValToPrg(oHttp:hHeaders))
         Alert(ValToPrg( oHttp:nReplyCode )+ValToPrg(cData))
         //MemoEdit(cLog)
      ENDIF
      IF oHttp:nReplyCode == 301
         nCount++
         cUrl := oHttp:hHeaders["Location"]
         IF lDbg
            Alert("Redirect: "+cUrl)
         ENDIF
      ELSEIF ! Empty(cData)
         lSuccess := .T.
      ENDIF
   //ENDDO




   If lSuccess .AND. ! Empty(cData)
/*      FOR nX := 1 TO 10
         oHttp:post()
         cData := oHttp:readAll()
         IF ! Empty(cData)
            EXIT
         ELSE
            hb_idleSleep(.1)
         ENDIF
      NEXT
		If Empty(cData)
			Return -1
		Endif       */


		cData := SubStr(cData,AT(cSearch,cData)+Len(cSearch))
      cData := LTrim(StrTran(cData,Chr(13),""))
      cData := StrTran(SubStr(cData,1,At('</span',cData)-1),".","")

		Return Val(cData)
	Else
		Return -1 //@ 06,22 SAY "fehlgeschlagen"
	Endif
