#include 'y:\hb34\contrib\hbcurl\hbcurl.ch'
FUNCTION RUN_PRICES_SCHUKAT(nArtnr,cArtlief,cMatch)

LOCAL nX,hPrices := {=>},aInfo
LOCAL cVal,nQty,aRegex,cVPE,nVpe
LOCAL nPos,cPrices
LOCAL lD := .F. //Tr_Getini(28) == 9
LOCAL pCurl,cData,nErr

   HB_SYMBOL_UNUSED(nArtnr)
   HB_SYMBOL_UNUSED(cArtlief)

   pCurl := Curl_Easy_Init()
   curl_easy_setopt(pCurl, HB_CURLOPT_BUFFERSIZE, 102400)
   curl_easy_setopt(pCurl, HB_CURLOPT_URL, "https://www.schukat.com/schukat/schukat_cms_de.nsf/index/suchergebnisse?OpenDocument&news=false&katalog=true&query="+cMatch )
   curl_easy_setopt(pCurl, HB_CURLOPT_NOPROGRESS, 1)
   curl_easy_setopt(pCurl, HB_CURLOPT_USERAGENT, "Mozilla/5.0 (Windows NT 6.2; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/63.0.3239.84 Safari/537.36")
   curl_easy_setopt(pCurl, HB_CURLOPT_MAXREDIRS, 50)
   curl_easy_setopt(pCurl, HB_CURLOPT_HTTP_VERSION, "URL_HTTP_VERSION_2TLS")
   curl_easy_setopt(pCurl, HB_CURLOPT_CAINFO, "Y:\Curl\curl-7.67.0-win32-mingw\bin\curl-ca-bundle.crt")
   curl_easy_setopt(pCurl, HB_CURLOPT_TCP_KEEPALIVE, 1)
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
      RETURN {=>}
   ENDIF

   /*oHttp := TIpClientHttp():new( "https://www.schukat.com/schukat/schukat_cms_de.nsf/index/suchergebnisse?OpenDocument&news=false&katalog=true&query="+cMatch )
   oHttp:nConnTimeout := 10000
   oHttp:open()

   oHttp:Post() //{"symbol"=>cMatch,"brutto"=>"","onlyPrices"=>1})
   cData := oHttp:readAll()
   IF cData == NIl
      RETURN hPrices
   ENDIF*/

   IF Empty(HB_ATX("<td[^>]*plCO.*>"+Trim(cMatch)+"\s*",cData,,@nPos))
      IF lD
         Alert("Matchcode not verified")
      ENDIF
      RETURN hPrices
   ELSEIF lD
      Alert("Pos: "+Str(nPos)+Str(Len(cData)))
   ENDIF

   aInfo := HB_RegexAll("<table[^>]*plWB",SubStr(cData,nPos),,,,,.F.)
   IF aInfo != NIL .AND. Len(aInfo) > 0
      nPos += ATail(aInfo)[1,2]
      IF nPos != 0
         cPrices := SubStr(cData,nPos)
         IF lD
            Alert(cPrices)
         ENDIF
         nPos := AT("</table",cPrices)
         cPrices := SubStr(cPrices,1,nPos-1)
         nX := 1
         DO WHILE (nPos := AT("<td",cPrices)) != 0
            cVal := SubStr(cPrices,nPos)
            cVal := SubStr(cVal,At(">",cVal)+1)
            cPrices := Substr(cPrices,nPos+3)
            IF nX == 4
               nX := 1
            ENDIF
            nPos := AT("</td>",cVal)
            cVal := StrTran(SubStr(cVal,1,nPos-1),",",".")
            IF lD
               Alert(Str(nX)+"-"+cVal+"-"+Str(Val(cVal)))
            ENDIF
            IF nX == 1
               nQty := Val(cVal)
            ELSEIF nX == 3
               hPrices[nQty] := Val(StrTran(cVal,",","."))
            ENDIF
            nX++
         ENDDO
      ENDIF
   ELSE
      IF lD
         Alert("No price table found")
      ENDIF
      RETURN hPrices
   ENDIF

   aRegex := HB_Regex('<td.*plWB[^>]*>.*>([HETpPkh])<.*</td',cData,,.F.) //   [HETpPkh]
   
   IF Len(aRegex) >= 2 //VPE gefunden
      nVPE := 0
      cVPE := Upper(aRegex[2])
      IF cVPE == "H"
         nVPE := 100
      ELSEIF cVPE == "E"  //1 Stück
      ELSEIF cVPE == "T"
         nVPE := 1000
      ELSEIF cVPE == "K"  //kilo
      ELSEIF cVPE == "P"  //pack
      ENDIF
      IF nVPE != 0
         FOR nX := 1 TO LEN(hPrices)
            hPrices[HGEtKeyAt(hPrices,nX)] := HGetValueAt(hPrices,nX)/nVPE
         NEXT
      ENDIF
   ENDIF

RETURN hPrices