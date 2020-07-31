#include 'y:\hb34\contrib\hbcurl\hbcurl.ch'

FUNCTION Prices_Reichelt(nArtnr,cArtlief,cMatch)

LOCAL hPrices := {=>}
LOCAL cUrl
LOCAL cData
LOCAL aRegex
LOCAL lD := .F. //Tr_Getini(28) == 9
LOCAL pCurl,nErr
LOCAL nMwSt


   HB_SYMBOL_UNUSED(nArtnr)
   HB_SYMBOL_UNUSED(cMatch)

   cUrl := "https://www.reichelt.de/index.html?ACTION=3&ARTICLE="+cArtLief 

   pCurl := Curl_Easy_Init()
   curl_easy_setopt(pCurl, HB_CURLOPT_BUFFERSIZE, 102400)
   curl_easy_setopt(pCurl, HB_CURLOPT_URL, cUrl )
   curl_easy_setopt(pCurl, HB_CURLOPT_NOPROGRESS, 1)
   //curl_easy_setopt(pCurl, HB_CURLOPT_USERAGENT, "Mozilla/5.0 (Windows NT 6.2; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/63.0.3239.84 Safari/537.36")
   curl_easy_setopt(pCurl, HB_CURLOPT_MAXREDIRS, 50)
   curl_easy_setopt(pCurl, HB_CURLOPT_HTTP_VERSION, "URL_HTTP_VERSION_2TLS")
   curl_easy_setopt(pCurl, HB_CURLOPT_CAINFO, "Y:\Curl\curl-7.67.0-win32-mingw\bin\curl-ca-bundle.crt")
   curl_easy_setopt(pCurl, HB_CURLOPT_TCP_KEEPALIVE, 1)
   curl_easy_setopt(pCurl, HB_CURLOPT_FOLLOWLOCATION, 1)
   curl_easy_setopt(pCurl, HB_CURLOPT_DL_BUFF_SETUP )
   nErr := Curl_Easy_Perform(pCurl)
   curl_easy_setopt( pCurl, HB_CURLOPT_DL_BUFF_GET, @cData )
   IF lD
      Alert( "Curl: "+Str(nErr) )
      Alert( "HTTP Response: "+Str(curl_easy_getinfo(pCurl,HB_CURLINFO_RESPONSE_CODE)) )
      Alert(cData)
   ENDIF
   Curl_Easy_CleanUp(pCurl)   

   IF nErr != 0
      IF lD 
         Alert("Error receiving data")
      ENDIF
      RETURN {=>}
   ENDIF

   /*DO WHILE ! lSuccess .AND. nCount < 10
      oHttp := TIpClientHttp():new( cUrl )
      oHttp:nConnTimeout := 10000
      oHttp:open()

      cData := oHttp:readAll()
   
      IF oHttp:nReplyCode == 301
         nCount++         
         cUrl := oHttp:hHeaders["Location"]
         IF lD
            Alert("Redirect: "+cUrl)
         ENDIF
      ELSE
         lSuccess := .T.
      ENDIF
   ENDDO*/

   

//   oHttp:Post() //{"symbol"=>cMatch,"brutto"=>"","onlyPrices"=>1})
   //cData := oHttp:readAll()
   IF cData == NIl
      RETURN hPrices
   ENDIF

   aRegex := HB_Regex('id="av_price.*\>([0-9]*,).*<sup[^>]*>([0-9]*)',cData) //

   IF Len(aRegex) == 3
      Taxit(1,@nMwSt,Date())
      hPrices := {1=>Val(StrTran(aRegex[2],",",".")+aRegex[3])/(1+nMwSt/100) }
   ENDIF

RETURN hPrices