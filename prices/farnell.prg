#include 'y:\hb34\contrib\hbcurl\hbcurl.ch'

FUNCTION FARNELL(nArtnr,cArtlief)

LOCAL oHttp,hData,hPrices,hPrice
LOCAL lDbg := .F. //Tr_getini(28) == 9
LOCAL nPos 
LOCAL cUrl := "https://de.farnell.com/x/x/x/dp/"+Trim(cArtlief)
//LOCAL cUrl := "https://de.farnell.com/"
//LOCAL cUrl := "http://104.104.198.188/x/x/x/dp/3135822"
LOCAL lSuccess := .F.
LOCAL nCount := 1
LOCAL cLog := ""
LOCAL cData,cJsonData,aData,aPrice
LOCAL cPage
LOCAL pCurl

MEMVAR cPriceError 
PUBLIC cPriceError := ""


   HB_SYMBOL_UNUSED(nArtnr)

   //libcurl times out, the command line seems to work fine!
   cData := __DownLoadPage(cUrl)
   lSuccess := .T.

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
         cData := SubStr(cData,1,AT("</table",cData))
         aData := {}
         DO WHILE (nPos := AT("PriceBreakArray=",cData)) > 0 //find the last one
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