LOCAL cUrl,oHttp
LOCAL cDate,aMatches
LOCAL dDate,nPer

//cUrl := "https://www.logistics.dbschenker.de/log-de-de/produkte-services/landverkehre/dieselzuschlag_floating/1978120/dieselzuschlag.html"
//cUrl := "https://www.logistics.dbschenker.de/log-de-de/produkte-services/landverkehre/nebengebuehren/dieselzuschlag_floating/1978120/dieselzuschlag.html"
//cUrl := "https://www.dbschenker.de/log-de-de/produkte-services/landverkehre/nebengebuehren/dieselzuschlag_floating/1978120/dieselzuschlag.html"
cUrl := "https://www.dbschenker.com/de-de/produkte/landverkehre/stueckgut-international/diesel-floating"
oHttp := TIpClientHttp():new( cUrl )
oHttp:nConnTimeout := 10000
IF oHttp:open()
   cData := oHttp:ReadAll()
   aMatches := HB_Regex('<table>(.*)</table',cData)
   IF Len(aMatches) < 2
      _Schenker_Error("Keine Daten erhalten<br>"+cData)
   ELSE
      cData := aMatches[2]

      aMatches := HB_RegexAll("<tr[^<]*<td[^>]*>([^<]*)</td>[\s]*<td[^>]*>[^<]*</td>[\s]*<td[^>]*>[^<]*</td>[\s]*<td[^>]*>([0-9,]*)%</td>[\s]*<td[^>]*>([0-9.]*)</td>",cData)
      NetUse("diesel_schenker","ds_sch")
      FOR nX := 1 TO Len(aMatches)
         dDate := CToD(aMatches[nX,4])
         nPer  := Val(StrTran(aMatches[nX,3],",","."))
         IF ! ds_sch->(dbSeek( DToS(dDate) ))
            ds_sch->(Add_Rec())
            ds_sch->From := dDate
            ds_sch->Percent := nPer
            ds_sch->(dbUnLock())
         ENDIF
      NEXT
   ENDIF
ELSE
   _Schenker_Error("Keine Verbindung")
ENDIF
oHttp:close()

STATIC Function _Schenker_Error(cError)
   IF GetConfigValue("BATCHMODE")
      SendMail({{"amos.engelking@engelking.de","Amos"}},"Dieselzuschläge konnten bei Schenker nicht abgerufen werden",HB_OemToAnsi(cError),,,,.T.)
   ELSE
      Tr_MsgBox(cError,"Abruf fehlgeschlagen")
   ENDIF
RETURN NIL

