#include 'y:\hb34\contrib\hbcurl\hbcurl.ch'
FUNCTION RUN_PRICES_ETTINGER(nArtnr,cArtlief)

   LOCAL hPrices := {=>}
   LOCAL cUrl,cSearch,cPreis,nAt,cVpe
   LOCAL lDbg := .F. //Tr_GetIni(28) == 9
   LOCAL pCurl,nErr,cData

   HB_SYMBOL_UNUSED(nArtnr)

	cSearch := "Preis:"

	cUrl := "https://www.ettinger.de/de/product/"+cArtLief
   
   pCurl := Curl_Easy_Init()
   curl_easy_setopt(pCurl, HB_CURLOPT_BUFFERSIZE, 102400)
   curl_easy_setopt(pCurl, HB_CURLOPT_URL, cUrl )
   curl_easy_setopt(pCurl, HB_CURLOPT_NOPROGRESS, 1)
   curl_easy_setopt(pCurl, HB_CURLOPT_USERAGENT, "Mozilla/5.0 (Windows NT 6.2; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/63.0.3239.84 Safari/537.36")
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
      RETURN {=>}
   ENDIF

   /*oHttp := TIpClientHttp():new( cUrl )
   If oHttp:open()
      cData := oHttp:readAll()
      IF cData == NIL //no data returned
         RETURN {=>}
      ENDIF*/
      IF lDbg
         //Alert(cData)
      ENDIF
      nAT := AT(cSearch,cData)
      IF nAT == 0
         RETURN {=>}
      ENDIF
      cPreis := SubStr(cData,nAt+Len(cSearch))
      cPreis := SubStr(cPreis,AT("<span>",cPreis)+6)
      cPreis := StrTran(Substr(cPreis,1,At(" ",cPreis)),",",".")

      cVpe := LTrim(SubStr(cData,At("Verpackungseinheit:",cData)+19))
      cVpe := SubStr(cVpe,1,AT(" ",cVPE))

      hPrices[Val(cVpe)] := Val(cPreis)

      /*oLogin := TIpClientHttp():new("https://www.ettinger.de/de/login")
	   IF oLogin:open()
         oLogin:Post({"redirect"=>"product/"+cArtLief,"form_build_id"=>"form-1D5PSnZe5TV1bDIcMz__tp1i7mL79YcdZbVnLdTukrc","op"=>"Login","ADR_STMNUM"=>"615318","ADR_PASSWORT"=>"V4A1YIZ5","form_id"=>"ettinger_customer_form" })
         cData := oLogin:readAll()
         IF oLogin:nReplyCode == 302 //login succesfull
            //MemoEdit(ValToPrg(oLogin:hHeaders))
            oHttp := TIpClientHttp():new( oLogin:hHeaders["Location"] )
            //oHttp:hCookies := oLogin:hCookies
            hCookies := HGetValueAt(HGetValueAt(oLogin:hCookies,1),1)
            cValue := ""
            FOR EACH cValue IN hCookies
               oHttp:setCookie(cValue:__enumKey()+"="+cValue)
            NEXT
            oHttp:open()

            cData := oHttp:ReadAll()
            DO WHILE (nPos := AT("ScaleItem",cData)) != 0
               cData := SubStr(cData,nPos+9)
               cMenge := Ltrim(SubStr(cData,AT("Amount",cData)+8))
//               cMenge := LTrim(StrTran(cMenge,"ab",""))
               cMenge := SubStr(cMenge,At(" ",cMenge)+1)
               cPrice := SubStr(cData,AT("Price",cData)+7)
               cPrice := SubStr(cPrice,AT("<span>",cPrice)+6)
               cPe := SubStr(cPrice,AT("</span>",cPrice)+2)
               cPe := LTrim(SubStr(cPe,AT("/",cPe)+1))
               cPrice := StrTran( StrTran( SubStr(cPrice,1,AT(" ",cPrice)),".","") ,",",".")
               IF Tr_Getini(28) == 9
                  //Alert(Str(Val(cMenge),6,2)+";"+cPrice+";"+cPe)
               ENDIF
               hPrices[Val(cMenge)] := Val(cPrice)/Val(cPe)
            ENDDO
         ENDIF
      ENDIF*/
      RETURN hPrices
   /*ELSE
      RETURN {=>}
   ENDIF*/
