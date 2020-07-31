PARAMETERS nArtnr,cArtlief,cMatch

LOCAL nX,hData,hPrice,hPrices := {=>},oHttp,oHttp2
LOCAL nPos,cPrices,cDomain := "https://www.buerklin.com"
LOCAL lDbg := .F. //Tr_Getini(28) == 9 .AND. ! GetConfigValue("BATCHMODE")
LOCAL hCookies := {=>},cValue
   
   cUrl :=  cDomain+"/de/x/x/p/"+StrTran(cArtLief," ","")
   cData := __DownLoadPage(cUrl) //oHttp:readAll()

   IF ValType(cData) == "C"       
      IF lDbg
         MemoEdit(cData)
      ENDIF
      IF (nP := AT("crossselling",cData)) != 0
         cData := SubStr(cData,1,nP)  //cut off all crossselling products to avoid wrong information
      ENDIF            
      IF AT("Dieser Artikel ist ein Auslaufartikel",cData) != 0  //keine Preise mehr verfgbar         
         IF lDbg
            Alert("Auslauf")
         ENDIF
         SendMail({{"amos.engelking@engelking.de","Amos"}},"Artikel nicht mehr bei Brklin erh„tlich "+Trim(art->Matchcode),"")
         RETURN hPrices
      ENDIF
      cData := SubStr(cData,AT("scale-table",cData)+11)
      IF AT("Staffelpreise",cData) > 0 //es gibt staffelpreise
         //Alert(SubStr(cData,1,AT("Staffelpreise",cData)))
         IF lDbg; Alert("Staffel"); ENDIF
         cData := SubStr(cData,1,AT("</table",cData))
         cData := SubStr(cData,AT("</thead",cData))
         IF lDbg
            Alert(cData)
         ENDIF
         aBreaks := HB_RegexAll('<td[^0-9,]*([0-9,]*)',cData)
         IF lDbg
            Alert(ValToPrg(aBreaks))
         ENDIF
         FOR nX := 1 TO Len(aBreaks) STEP 3        
            hPrices[Val(aBreaks[nX,2])] := Val(StrTran(aBreaks[nX+2,2],",","."))
         NEXT
      ELSE //es gibt nur einen Preis
         cData := SubStr(cData,AT('<p class="price">',cData)+17)
         cData := SuBStr(cData,1,AT("</p",cData))
         aBreaks := HB_Regex('[0-9,]+',cData)
         IF Len(aBreaks) > 0
           hPrices[1] := Val(StrTran(aBreaks[1],",","."))
         ENDIF
      ENDIF

   ELSEIF lDbg
      Alert("No data received")
   ENDIF

RETURN hPrices

#include '\\EK-SERVER2\trader\run\curl.prg'