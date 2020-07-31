FUNCTION PriceLoadHttpData(cUrl,lSuccess,lD)
   LOCAL nCount := 1
   LOCAL oHttp
   
   Default(@lD,.F.)
   lSuccess := .F.

   DO WHILE ! lSuccess .AND. nCount < 10
      oHttp := TIpClientHttp():new( cUrl )
      oHttp:nConnTimeout := 10000
      oHttp:open()

      oHttp:Post() //{"symbol"=>cMatch,"brutto"=>"","onlyPrices"=>1})
      cData := oHttp:readAll()
      IF lD
         Alert(ValToPrg( oHttp:nReplyCode ))
      ENDIF
      IF oHttp:nReplyCode == 301
         nCount++
         cUrl := oHttp:hHeaders["Location"]
         IF lD
            Alert("Redirect: "+cUrl)
         ENDIF
      ELSE
         lSuccess := .T.
      ENDIF
   ENDDO
RETURN cData
