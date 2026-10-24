PARAMETERS nArtnr,cArtlief,cMatch

LOCAL nX,hData,hPrice,hPrices := {=>},oArt := Artikel():New(),cManu := ""
LOCAL oHttp
LOCAL lDbg := Tr_getini(28)

   oArt:Load(nArtnr)


   oHttp := TIpClientHttp():new( "http://www.mouser.de/Search/ProductDetail.aspx?R="+If(Empty(cArtLief),Trim(cMatch),Trim(cArtLief)) )
   oHttp:hFields["Accept-Encoding"] := "deflate"
   oHttp:open()

   cData := oHttp:readAll()

   IF ValType(cData) != "C"
      RETURN 1
//      RETURN NIL
   ENDIF
   IF Tr_getini(28) == 9
      //Alert(cData)
      //Alert( ValToPrg(oHttp:hHeaders) )
   ENDIF
   IF AT("Sonderbestellung",cData) != 0
      RETURN  2
      //RETURN NIL
   ENDIF

   /*IF Empty(cArtLief)
      nPos := AT("divMouserPartNum",cData)
      IF nPos != 0
         cArtLief := SubStr(cData,nPos)
         cArtLief := SubStr(cData,AT(">",cArtLief)+1)
         cArtLief := SubStr(cData,1,AT("<",cArtLief)-1)
      ENDIF
      //Alert(cArtLief)
   ENDIF    */

   nPos := AT("PriceBreaks",cData)
   IF nPos == 0
      RETURN NIL
   ENDIF
   cData := SubStr(cData,nPos)

   nX := 1
   DO WHILE (nPos := AT('class="row"',cData)) > 0
         cData := SubStr(cData,nPos)
         cData := SubStr(cData,At(">",cData)+1)
         FOR nX := 1 TO 2
            nPos2 := AT("<div",cData)
            cLine := SubStr(cData,nPos2)
            cData := SubStr(cData,nPos2+4)
            cLine := SubStr(cLine,1,AT("/div>",cLine)+5)

           IF AT("PriceBreakQuantity",cLine) != 0
               aMatches := HB_Regex(">([0-9,.]*)</a",cLine)
               nAmount := Val(StrTran(StrTran(aMatches[2],".",""),",","."))
            ELSEIF AT("PriceBreakValue",cLine) != 0
               cLine := StrTran(cLine,Chr(13),"")
               cLine := StrTran(cLine,Chr(10),"")
               aMatches := HB_Regex(">([0-9,.]*)[\s]",cLine)
               IF Len(aMatches) >= 2
                  hPrices[nAmount] := Val(StrTran(StrTran(aMatches[2],".",""),",","."))
               ENDIF
           ENDIF
         NEXT
   ENDDO


RETURN hPrices