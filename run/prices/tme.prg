#include 'y:\hb34\contrib\hbcurl\hbcurl.ch'
FUNCTION RUN_PRICES_TME(nArtnr,cArtlief,cMatch)

LOCAL nX,hData,hPrice,hPrices := {=>}
LOCAL cMe
LOCAL lDebug := .F. // Tr_getini(28) == 9
//LOCAL oHttp
LOCAL cData,aRegex,nPos,nAmount
LOCAL pCurl,aHeader := {},nErr

   HB_SYMBOL_UNUSED(nArtnr)
   

   IF Left(cMatch,7) $ {"PXP6010","PXP6011","PXM6010","PXM6011"}
      cMatch := SubStr(cMatch,1,RAt("/",cMatch)-1)+Right(Trim(cMatch),4)
   ENDIF
   pCurl := Curl_Easy_Init()
   
   curl_easy_setopt(pCurl, HB_CURLOPT_BUFFERSIZE, 102400)
   curl_easy_setopt(pCurl, HB_CURLOPT_URL, "https://www.tme.eu/_ajax/ProductInformationPage/_getStocks.html" )
   curl_easy_setopt(pCurl, HB_CURLOPT_NOPROGRESS, 1)
   curl_easy_setopt(pCurl, HB_CURLOPT_USERAGENT, "Mozilla/5.0 (Windows NT 6.2; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/63.0.3239.84 Safari/537.36")
   Aadd(aHeader,"X-Requested-With: XMLHttpRequest")
   Aadd(aHeader,"referer: https://www.tme.eu/en/details/px0931_04_p/px-connectors/bulgin/")
   Aadd(aHeader,"origin: https://www.tme.eu")
   Aadd(aHeader,":authority: www.tme.eu")
   curl_easy_setopt(pCurl, HB_CURLOPT_HEADER,aHeader)   
   curl_easy_setopt(pCurl, HB_CURLOPT_MAXREDIRS, 50)
   //curl_easy_setopt(pCurl, HB_CURLOPT_HTTP_VERSION, "URL_HTTP_VERSION_2TLS")
   curl_easy_setopt(pCurl, HB_CURLOPT_CAINFO, "Y:\Curl\curl-7.67.0-win32-mingw\bin\curl-ca-bundle.crt")
   curl_easy_setopt(pCurl, HB_CURLOPT_TCP_KEEPALIVE, 1)
   curl_easy_setopt(pCurl, HB_CURLOPT_DL_BUFF_SETUP )
   
   curl_easy_setopt(pCurl, HB_CURLOPT_POST, 1)
   curl_easy_setopt(pCurl, HB_CURLOPT_POSTFIELDS, BuildPostMessage({"symbol"=>Trim(IF(!Empty(cArtLief),cArtLief,cMatch)),"brutto"=>"","similars"=>{20523,188368,81144,92165,92145} }))

   nErr := Curl_Easy_Perform(pCurl)
   curl_easy_setopt( pCurl, HB_CURLOPT_DL_BUFF_GET, @cData )
   IF lDebug
      Alert( "Curl: "+Str(nErr) )
      Alert( "HTTP Response: "+Str(curl_easy_getinfo(pCurl,HB_CURLINFO_RESPONSE_CODE)) )
      Alert(cData)
   ENDIF
   Curl_Easy_CleanUp(pCurl)

   /*oHttp := TIpClientHttp():new( "https://www.tme.eu/_ajax/ProductInformationPage/_getStocks.html" )
   oHttp:open()
   oHttp:hFields["X-Requested-With"]:="XMLHttpRequest"
   //oHttp:hFields["Accept-Encoding"] := "gzip, deflate,br"
   oHttp:cUserAgent := "Mozilla/5.0 (Windows NT 6.2; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/56.0.2924.76 Safari/537.36"
   oHttp:hFields["referer"] := "https://www.tme.eu/en/details/px0931_04_p/px-connectors/bulgin/"
   oHttp:hFields["origin"]:= "https://www.tme.eu"
   oHttp:hFields[":authority"]:=  "www.tme.eu"

   oHttp:Post({"symbol"=>Trim(IF(!Empty(cArtLief),cArtLief,cMatch)),"brutto"=>"","similars"=>{20523,188368,81144,92165,92145} }) //,"onlyPrices"=>1})
   cData := oHttp:readAll()*/
   IF lDebug
      MemoEdit(cData)
   
      //GTSetClipBoard(cData)
      /*nH := FCreate("c:\Users\Amos\Desktop\tme.gz")
      FWrite(nH,cData)
      FClose(nH)*/
   ENDIF
   HB_JsonDeCode(cData,@hData)
/*   IF lDebug
      Alert(Str(oHttp:nReplyCode)) //+oHttp:hHeaders["Location"])
      IF ValType(hData) == "H"
         MemoEdit(ValToPrg(hData))
      //GTSetClipBoard(ValToPrg(hData))
      ELSE
         MemoEdit(cData)
      ENDIF
   ENDIF*/


   IF  ValType(hData) == "H" .AND. HHAsKey(hData,"Products") .AND. Len(hData["Products"]) >= 1 .AND. ValType(hData["Products"][1]) == "H"
     IF  HHasKey(hData["Products"][1],"Prices")
        FOR EACH hPrice IN hData["Products"][1]["Prices"]
           hPrices[ hPrice["Amount"] ] := Val(hPrice["Price"])
        NEXT
     ELSEIF HHasKey(hData["Products"][1],"PriceTpl")
         //GTSetClipBoard(hData["Products"][1]["PriceTpl"])
         aRegex := HB_RegEx("<td>Menge.*?\[([a-z]+)\]",hData["Products"][1]["PriceTpl"])
         IF Len(aRegex) > 1
            cMe := aRegex[2]
         ELSE
            cMe := "st"
         ENDIF
         cData := SubStr(hData["Products"][1]["PriceTpl"],At("prices_body",hData["Products"][1]["PriceTpl"]))
         nX := 1
         DO WHILE (nPos := At("<td",cData)) != 0
            cData := SubStr(cData,nPos)
            cData := SubStr(cData,AT(">",cData)+1)

            IF Tr_Getini(28) == 9
//               Alert(SubStr(cData,1,AT("</td",cData)-1))
//               GTSetClipBoard(SubStr(cData,1,AT("</td",cData)-1))
            ENDIF
            IF nX != 2
               aRegex := HB_RegEx(".*?([0-9.]+)",SubStr(cData,1,AT("</td",cData)-1))
               IF Len(aRegex) > 0
                  IF Tr_Getini(28) == 9
//                     Alert(aRegex[2])
                  ENDIF
                  IF nx == 3
                     hPrices[nAmount] := Val(aRegex[2])
                     IF art->Me == "PACK" .AND. cMe == "st"
                        hPrices[nAmount] *= 10
                     ENDIF
                     IF Tr_Getini(28) == 9
                        //Alert(Str(nAmount)+":"+Str(hPrices[nAmount]))
                     ENDIF
                  //ELSEIF nx % 2 == 0
                  ELSE
                     nAmount := Val(aRegex[2])
                     IF Tr_Getini(28) == 9
                        //Alert(Str(nAmount))
                     ENDIF
                  ENDIF
               ENDIF
            ENDIF
            IF nX == 3
               nX := 1
            ELSE
               nX++
            ENDIF
         ENDDO
     ENDIF
   ENDIF
RETURN hPrices

/*   oHttp := TIpClientHttp():new( "http:/"+"/www.tme.eu/de/details/"+cMatch+"/x/x/#" )
	If oHttp:open()
		cData := oHttp:readAll()
		IF Empty(cData)
		   IF oHttp:nReplyCode == 301 //moved
      	   oHttp:close()
      	   oHttp := TIpClientHttp():new( "http:/"+"/www.tme.eu"+oHttp:hHeaders["Location"] )
      	   IF ! oHttp:open()
      	        Return NIL
      	   ENDIF
      	   cData := oHttp:readAll()
      	ELSE
      	  RETURN NIL
			ENDIF
		Endif



      cData := SubStr(cData,AT("prices",cData))
      //cData := SubStr(cData,1,AT("/table",cData))
      //MemoEdit(cData)
      cData := SubStr(cData,AT("tbody",cData))

      aPrices := {}
      nX := 1
      DO WHILE (nPos := AT("<tr>",cData)) > 0
         cData := SubStr(cData,nPos+4)
         //Alert(cData)
         IF nX % 2 == 0
            cValue := SubStr(cData,1,AT("</",cData)-1)
            Aadd(aPrices,Val(StrTran(cValue,",",".")))
         ENDIF
         nX++
      ENDDO
      Return aPrices
	Else
		Return NIL //@ 06,22 SAY "fehlgeschlagen"
	Endif
*/

FUNCTION BuildPostMessage(hPost)
   LOCAL cMessage := ""
   LOCAL cData
   FOR EACH cData IN hPost
      cMessage += tip_URLEncode( AllTrim( hb_CStr( cData:__enumKey() ) ) ) + "=" 
      cMessage += tip_URLEncode( hb_CStr( cData ) )
      IF ! cData:__enumIsLast()
         cMessage += "&"
      ENDIF
   NEXT
RETURN cMessage