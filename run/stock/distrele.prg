FUNCTION RUN_PRICES_DISTRELE(nArtnr,cArtlief)
LOCAL lD := .F.
LOCAL hData
LOCAL lSuccess := .F.,nCount := 0
LOCAL cUrl
LOCAL oLogin,oHttp,cData

   HB_SYMBOL_UNUSED(nArtnr)

RETURN -1
   

   oLogin := TipClientHttp():New("https://www.distrelec.de")
   oLogin:open()
   Alert(oLogin:readAll()   )
   

   cUrl := "https://www.distrelec.de/availability?productCodes="+Trim(cArtlief)

   DO WHILE ! lSuccess .AND. nCount < 10
      oHttp := TIpClientHttp():new( cUrl )
      oHttp:nConnTimeout := 10000
      oHttp:hCookies := oLogin:hCookies
      oHttp:open()
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
   IF lSuccess
      IF Empty(cData)   
         RETURN -1
      ENDIF
      HB_JsonDeCode(cData,@hData)
      
//      MemoEdit(ValToPrg(hData))

      IF ValType(hData) != "H" .OR. ! HHasKey(hData,"availabilityData")
         //
         IF Tr_Getini(28) == 9
            Alert("Daten Fehler bei Distrelec")
            MemoEdit(cData)
         ENDIF
         RETURN -1
      ENDIF
      IF Len(hData["availabilityData"]["products"]) == 0
         RETURN 0
      ENDIF

      RETURN HGetValueAt(hData["availabilityData"]["products"][1],1)["stockLevelTotal"]

		//Return hData["availabilityData"]["products"][1][Trim(cArtLief)]["stockLevelTotal"] //Val(cData)
	Else
		Return -1
	Endif
