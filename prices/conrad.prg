FUNCTION RUN_PRICES_CONRAD(nArtnr,cArtlief,cMatch)

LOCAL nX,hPrices := {=>}
LOCAL nPos,cPrices
LOCAL lD := .F. //Tr_Getini(28) == 9
LOCAL lSuccess := .F.
LOCAL cProtDomain := "https://www.conrad.de"
LOCAL cUrl := cProtDomain+"/de/product-"+Trim(cArtLief)+".html"
LOCAL nCount := 0
LOCAL oHttp,cData,cVal,nQty,aMatches

RETURN {1=>999.99} //funktioniert gerade nicht


                  /*oApi := RestApi():New()
                  oApi:cBaseUrl := "https://api.browse.ai/v2/robots/"+Trim(oExtra:BrowseAI)+"/tasks"
                  cData := oApi:Execute("","POST",{"inputParameters"=>{"originUrl"=>cUrl}},aHeaders,.T.)
            
                  hData := HB_JsonDecode(cData)            
DO WHILE hData["result"]["status"] != "successful"               
                        @ MaxRow()/2+1,MaxCol()/2-5 SAY Replicate(".",nS)+Replicate(" ",11-nS)
                        Inkey(2,128)*/


   HB_SYMBOL_UNUSED(nArtnr)
   HB_SYMBOL_UNUSED(cMatch)
   //cMatch := StrTran(Trim(cMatch),"/","_")
   DO WHILE ! lSuccess .AND. nCount < 10
      
      IF AT("http",cUrl) != 1
         cUrl := cProtDomain+cUrl
      ENDIF
      
      oHttp := TIpClientHttp():new( cUrl )

      oHttp:hFields["Accept"] := "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8"
      oHttp:hFields["Accept-Language"] := "de-DE,de;q=0.9,en-US;q=0.8,en;q=0.7,nl;q=0.6"
      oHttp:cUserAgent := "Mozilla/5.0 (Windows NT 6.2; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/63.0.3239.84 Safari/537.36"

      oHttp:nConnTimeout := 10000
      oHttp:open()

      oHttp:Post() //{"symbol"=>cMatch,"brutto"=>"","onlyPrices"=>1})
      cData := oHttp:readAll()
      IF lD
         Alert( LTrim(Str( oHttp:nReplyCode ))+" "+oHttp:cReplyDescr)
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
   IF cData == NIl
      IF lD
         Alert("NO DATA")
      ENDIF
      RETURN hPrices
   ENDIF
   IF AT("Ausverkauft",cData) != 0
      RETURN {} //1=>999.99}
   ENDIF

   //HB_ATX("<table[^>]*qtydiscount__table",cData,,@nPos)
   HB_ATX("priceAvailability__block--borderless",cData,,@nPos)
//   HB_AtX("Mengenrabatt<\/strong",cData,,@nPos)

   nPos += AT('table',SubStr(cData,nPos))
   IF nPos != 0
      cPrices := SubStr(cData,nPos)
      IF lD
         Alert(cPrices)
      ENDIF
      nPos := AT("tbody",cPrices)
      cPrices := SubStr(cPrices,nPos+5)
      nPos := AT("</tbody",cPrices)
      cPrices := SubStr(cPrices,1,nPos-1)
      nX := 1
      DO WHILE (nPos := AT("<td>",cPrices)) != 0
         cVal := SubStr(cPrices,nPos+4)
         cPrices := Substr(cPrices,nPos+4)
         IF nX == 3
            nX := 1
         ELSE
            nPos := AT("</td>",cVal)
            cVal := StrTran(SubStr(cVal,1,nPos-1),",",".")
//            Alert(Str(nX)+"-"+cVal+"-"+Str(Val(cVal)))
            IF nX == 1
               nQty := Val(cVal)
            ELSE
               hPrices[nQty] := Val(StrTran(cVal,",","."))
            ENDIF
            nX++
         ENDIF
      ENDDO
   ELSEIF lD
      Alert("Keine Preistabelle gefunden")
      gtSetClipBoard(cData)
      MemoEdit(cData)
   ENDIF

   IF Len(hPrices) == 0 //no price breaks
      aMatches := HB_RegEx("<span[^>]*_produktpreis[^0-9]*([0-9,]*)",cData)
      IF Len(aMatches) == 0
         aMatches := HB_Regex("data-price-without-warranty[^>]*>\s*([0-9,\.]*)",cData) //Einzelpreis
         IF Len(aMatches) >= 2
            hPrices[1] := Val(StrTran(aMatches[2],",","."))
         ENDIF      
      ELSE
//      Alert( ValToPrg(aMatches) )
         hPrices[1] := Val(StrTran(aMatches[2],",","."))
      ENDIF
   ENDIF
   //Alert(cPrices)


RETURN hPrices