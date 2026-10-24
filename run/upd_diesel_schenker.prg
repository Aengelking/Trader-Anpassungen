#include 'y:\hb34\contrib\hbcurl\hbcurl.ch'

PROCEDURE RUN_UPD_DIESEL_SCHENKER
   LOCAL cUrl := "https://www.dbschenker.com/de-de/produkte/landverkehre/system-freight/diesel-floating"   
   LOCAL cData,aMatches
   LOCAL dDate,nPer,nX
   LOCAL pCurl := Curl_Easy_Init()
   LOCAL lUpdated := .F.,cRow,aRows
   
   //cUrl := "https://www.dbschenker.com/de-de/produkte/landverkehre/stueckgut-international/diesel-floating"   
   //cUrl := "https://www.logistics.dbschenker.de/log-de-de/produkte-services/landverkehre/dieselzuschlag_floating/1978120/dieselzuschlag.html"
   //cUrl := "https://www.logistics.dbschenker.de/log-de-de/produkte-services/landverkehre/nebengebuehren/dieselzuschlag_floating/1978120/dieselzuschlag.html"
   //cUrl := "https://www.dbschenker.de/log-de-de/produkte-services/landverkehre/nebengebuehren/dieselzuschlag_floating/1978120/dieselzuschlag.html"

   curl_easy_setopt(pCurl, HB_CURLOPT_SSL_VERIFYPEER,0)
   curl_easy_setopt(pCurl, HB_CURLOPT_DL_BUFF_SETUP )
   curl_easy_setopt(pCurl, HB_CURLOPT_URL, cUrl )
   Curl_Easy_Perform(pCurl)
   curl_easy_setopt(pCurl, HB_CURLOPT_DL_BUFF_GET, @cData )
   
   Curl_Easy_CleanUp(pCurl)  
   
   aMatches := HB_Regex('<table>(.*)</table',cData)
   IF Len(aMatches) < 2
      _Schenker_Error("Keine Daten erhalten<br>"+cData)
   ELSE
      cData := aMatches[2]
      aRows := HB_RegexSplit("<tr>",cData)
      NetUse("diesel_schenker","ds_sch")
      
      FOR EACH cRow IN aRows
         aMatches := HB_Regex("([-0-9,]*)%.*([0-9]{2}\.[0-9]{2}\.[0-9]{4})",cRow)
         IF Len(aMatches) >= 2            
            dDate := CToD(aMatches[3])
            nPer  := Val(StrTran(aMatches[2],",","."))
            ? dDate,Str(nPer,6,2)+"%",aMatches[2],aMatches[3]
            IF ! ds_sch->(dbSeek( DToS(dDate) ))               
               ds_sch->(Add_Rec())
               ds_sch->From := dDate
               ds_sch->Percent := nPer
               ds_sch->(dbUnLock())
            ENDIF
            lUpdated := .T.
         ENDIF
      NEXT
      IF ! lUpdated
         _Schenker_Error("Keine Daten eingelesen<br>"+cData)
      ENDIF
   ENDIF
   IF ! GetConfigValue("BATCHMODE")
      //Sinkey(0)
   ENDIF
RETURN

STATIC Function _Schenker_Error(cError)
   IF GetConfigValue("BATCHMODE")
      SendMail({{"amos.engelking@engelking.de","Amos"}},"Dieselzuschläge konnten bei Schenker nicht abgerufen werden",HB_OemToAnsi(cError),,,,.T.)
   ELSE
      Tr_MsgBox(cError,"Abruf fehlgeschlagen")
   ENDIF
RETURN NIL

