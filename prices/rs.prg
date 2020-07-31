FUNCTION RUN_PRICES_RS(nArtnr,cArtlief,cMatch,lSub)

LOCAL nX
LOCAL lDbg := .F. //Tr_Getini(28) == 9 .AND. ! GetConfigValue("BATCHMODE")
LOCAL cChr
LOCAL hPrices,cUrl,nPe,aRegex
LOCAL hData,hSubData
LOCAL nBrake,nPrice,aBrakes

MEMVAR cPriceError

   IF lSub != .T. .AND. Right(Trim(Upper(cArtLief)),1) $ "PA"
      cArtLief := SubStr(cArtLief,1,Len(Trim(cArtlief))-1)
   ENDIF

   cUrl := "https://de.rs-online.com/web/p/products/"+Trim(cArtlief)+"/"
//   cUrl := "http://de.rs-online.com/web/p/products/488208/"
   cData := __DownLoadPage(cUrl)
//   cData := ""
   /*oHttp := TIpClientHttp():new( cUrl )
   oHttp:nConnTimeout := 20000   */
//   oHttp:cUserAgent := "Mozilla/5.0 (Windows NT 6.2; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/56.0.2924.76 Safari/537.36"
//   oHttp:hFields["Accept"] := "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8"
/*   oHttp:hFields["Accept-Encoding"] := "deflate, sdch"
   oHttp:hFields["Accept-Language"] := "de-DE,de;q=0.8,en-US;q=0.6,en;q=0.4,nl;q=0.2"
   oHttp:hFields["Cache-Control"] := "max-age=0"
   //oHttp:hFields["Upgrade-Insecure-Requests"] := "1"
   oHttp:lPersistent := .T.
   IF lDbg
      //Alert(oHttp:cUserAgent)
      Alert("Starting request "+cUrl)
   ENDIF
   IF oHttp:open()
     cData := oHttp:ReadAll()*/
      If ValType(cData) != "C"
         IF lDbg
            Alert("No Data")         
         ENDIF
         cPriceError := "NO DATA"
         RETURN NIL
      ELSEIF lDbg
//         Alert(Str(oHttp:nReplyCode)+";"+oHttp:hHeaders["Location"])
         //MemoEdit(cData)
      Endif

      aRegex := HB_Regex("Preis pro.*?([0-9]*) StÃ¼ck([^\(][^0-9]*([0-9]+))?",cData) //
      nPe := 1

      oArtikel := Artikel():New(.F.)
      oArtikel:Load(nArtnr)

      IF oArtikel:Me == "STCK" .AND. Len(aRegex) >= 2 .AND. ! Empty(aRegex[2])
         nPe := Max(Val(aRegex[2]),1)
      ELSEIF oArtikel:Me == "PACK" .AND. Len(aRegex) >= 4
         //aRegex := HB_Regex("(In einer VPE ..|in einem Beutel mit) ([0-9]*)",cData)
          //IF Len(aRegex) == 2 .AND. ! Empty(aRegex[2])
            nPe := 1/Max(Val(aRegex[4]),1)
         //ENDIF
         IF lDbg
            Alert("Pack, Preiseinheit: "+LTrim(Str(nPE)))
         ENDIF
      ENDIF


//		renderPriceList({"breakPrices":[{"breakRangeWithoutUnit":"1 - 14","currencyCode":"EUR","maxRangeValue":14,"minRangeValue":1,"quantity":1,"unitPrice":"23,81 Gé¼","unitPriceWithoutCurrSymbol":"23,81 "},{"breakRangeWithoutUnit":"15 - 49","currencyCode":"EUR","maxRangeValue":49,"minRangeValue":15,"quantity":15,"unitPrice":"21,93 Gé¼","unitPriceWithoutCurrSymbol":"21,93 "},{"breakRangeWithoutUnit":"50 - 99","currencyCode":"EUR","maxRangeValue":99,"minRangeValue":50,"quantity":50,"unitPrice":"20,31 Gé¼","unitPriceWithoutCurrSymbol":"20,31 "},{"breakRangeWithoutUnit":"100 - 249","currencyCode":"EUR","maxRangeValue":249,"minRangeValue":100,"quantity":100,"unitPrice":"18,92 Gé¼","unitPriceWithoutCurrSymbol":"18,92 "},{"breakRangeWithoutUnit":"250 +","currencyCode":"EUR","minRangeValue":250,"quantity":250,"unitPrice":"17,71 Gé¼","unitPriceWithoutCurrSymbol":"17,71 "}],"columns":{"breakRangeWithoutUnit":"St++ck","unitPrice":"Preis"},"columnSize":2});

      /*nPos := AT('renderPriceList(',cData)

      IF nPos == 0
         IF lDbg
            gtSetClipboard(cData)
            Alert("NO renderPriceList found; "+cData)
         ENDIF
         RETURN NIL
      ENDIF


      cData := SubStr(cData,nPos)
      cData := SubStr(cData,AT("{",cData))
      cData := SubStr(cData,1,AT(");",cData)+2)
      cData := SubStr(cData,1,RAT("}",cData))

      HB_JSONDecode(cData,@hData)

      IF lDbg
         gtSetClipboard(cData)
//         Alert(cData)
         Alert(ValToPrg(hData))
      ENDIF

      IF ! HHasKey(hData,"breakPrices")
         IF lDbg
            Alert("breakPrices not found")
         ENDIF
         RETURN {=>}
      ENDIF


      hPrices := {=>}
      FOR EACH hSubData IN hData["breakPrices"]
         IF HHasKey(hSubData,"minRangeValue")
            hPrices[hSubData["minRangeValue"]] := Val(StrTran(hSubData["unitPriceWithoutCurrSymbol"],",","."))/nPe
         ELSE
            hPrices[Val(hSubData["breakRangeWithoutUnit"])] := Val(StrTran(hSubData["unitPrice"],",","."))/nPe
         ENDIF
      NEXT*/
      hPrices := {=>}
      nX := 1
      nAmount := 0
      DO WHILE (nPos := AT("breakRangeWithoutUnit",cData)) > 0
         cData := SubStr(cData,nPos+21)
         cData := SubStr(cData,At(">",cData)+1)

         IF lDbg
            Alert("Data: "+cData)
         ENDIF
         //cValue := SubStr(cData,AT('>',cData)+1)
         cValue := SubStr(cData,1,AT("-",cData)-1)

         IF lDbg
            Alert("Qty: "+cValue)
         ENDIF

         nAmount := Val(cValue)
         IF nAmount != 0
            cValue := SubStr(cData,AT("unitPrice",cData)+9)

            cValue := SubStr(cValue,AT(">",cValue)+1)
            
            cValue := SubStr(cValue,1,AT(Chr(226),cValue)-1)
            IF lDbg
               Alert("Price: "+cValue)
            ENDIF
   
            hPrices[nAmount*nPe] := Val(StrTran(cValue,",","."))/nPe
            
         ENDIF
         nX++
      ENDDO

      IF ValType(lSub) != "L" .OR. lSub != .T.
         FOR EACH cChr IN {"P","A"}
            cArtLief := Trim(cArtlief)+cChr
            hPrices2 := MBaseRun(Trim(Tr_Getini(1))+"\run\prices\rs",{art->Artikelnr,cArtLief,art->Matchcode,.T.})
            IF hPrices2 != NIL
               FOR EACH nPrice IN hPrices2
                  nBrake := nPrice:__eNumkey()
                  IF HHasKey(hPrices,nBrake)
                     IF hPrices[nBrake] > nPrice
                        hPrices[nBrake] := nPrice
                     ENDIF
                  ELSE
                     aBrakes := HB_HKeys(hPrices)
                     nLow := AScan(aBrakes,{|x| x < nBrake })
                     nHigh := AScan(aBrakes,{|x| x > nBrake })
                     IF (nLow == 0 .OR. hPrices[aBrakes[nLow]] > nPrice) .AND. (nHigh == 0 .OR. hPrices[aBrakes[nHigh]] < nPrice)
                        hPrices[nBrake] := nPrice
                     ENDIF
                  ENDIF
               NEXT
            ENDIF
         NEXT
      ENDIF

      cPriceError := "Page dump: "+cData
      IF lDbg
         Alert(ValToPrg(hPrices))
      ENDIF

      Return hPrices
   /*ELSE
      IF lDbg
         Alert("Connection timed out")
      ENDIF
      RETURN NIL
   ENDIF  */
   
#include '\\EK-SERVER2\trader\run\curl.prg'
