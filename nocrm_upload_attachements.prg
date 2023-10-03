FUNCTION noCRM_snapAddy(lComment)   
   LOCAL oNoCrm := NoCrmApi():New() //RestApi():New("https://engelking.nocrm.io/api/v2/","ff10f687005e643fc6a53f01cd06a646a5440986af412916")      
   LOCAL nPipeline := 1,aPipelines
   LOCAL getList := {}   
   LOCAL aPipelineNames := {}
   LOCAL aGetData,nOff := 0   
   LOCAL cDir := Pad("Y:\Dokumente und Einstellungen\All Users\Dokumente\Vertrieb\Electronica 2022\Reports PDF",255)
   LOCAL cCurl := "C:\Programme\Curl\bin\curl.exe"
   LOCAL nReportID,aMatches,aDir
   LOCAL cExe,nStdOUT,nProc,cLine,nBytes,cData
   LOCAL hUploadResponse,cRepl

   Default(@lComment,.T.)

   Head("Anh„nge aus snapAddy in noCRM hochladen")

   NetUse("nocrm","nocrm")
   NetUse("buyer","buy")
   
   //Check if connection is working   
   IF ! oNoCrm:Connect()      
      TR_MsgBox("Connection to nocrm.io failed")
      RETURN NIL
   ENDIF

   IF Empty(onoCrm:cUsrToken)
      TR_MsgBox("Unknown noCRM User")
      RETURN NIL
   ENDIF
   
   aPipeLines := oNoCrm:Execute("pipelines","GET")   
   
   AEval(aPipelines,{|x| Aadd(aPipelineNames,x["name"]) })
   
   @ 01,00 SAY "Pipeline"
   @ 01,10,10,50 GET nPipeLine LISTBOX aPipelineNames DROPDOWN
   @ 02,00 SAY "Verzeichnis"
   @ 02,10 GET cDir PICTURE "@S100" VALID {||
      IF Len(Directory(Trim(cDir)+"\*.pdf")) > 0
         RETURN .T.
      ENDIF
      Tr_MsgBox("Keine Dateien gefunden")
      RETURN .F.
   }
   READ   

   IF LastKey() == 27
      RETURN NIL
   ENDIF

   DO WHILE .T.
      aGetData := onoCRM:Execute("leads","GET",{"status"=>"todo,standby","include_unassigned"=>"true","limit"=>"100","offset"=>LTrim(Str(nOff))})
      AEval(aGetData,{|x|           
         IF x["pipeline"] == aPipeLines[nPipeline]["name"] //.AND. x["attachment_count"] == 0
            aMatches := HB_Regex("Report ID: ([0-9]{1,4})",x["description"])            
            nReportId := Val(aMatches[2])
            //? "Searching for: "+Trim(cDir)+"\"+StrZero(nReportId,4)+"*.pdf"
            aDir := Directory(Trim(cDir)+"\"+StrZero(nReportId,4)+"*.pdf")
            FOR nX := x["attachment_count"]+1 TO Len(aDir)
               ? aDir[nX][1]
               /*cUploadName := aDir[1,1]
               FOR EACH cRepl IN {""=>"ue","„"=>"ae","”"=>"oe","š"=>"UE","Ž"=>"AE","™"=>"OE","á"=>"ss","?"=>"_","&"=>"_",","=>"_"}
                  cUploadName := StrTran(cUploadName,cRepl:__eNumKey,cRepl)
               NEXT*/
               cExe := cCurl+' -XPOST -H "X-USER-TOKEN: '+oNoCrm:cUsrToken+'" -H "Content-Type: multipart/form-data" -F "attachment=@'+Trim(cDir)+"\"+aDir[nX][1]+';filename=Messebericht_'+LTrim(Str(nX))+'.pdf" "'+Trim(GetValue("NOCRM_URL"))+'/leads/'+LTrim(Str(x["id"]))+'/attachments"'               
               
               nProc := HB_OpenProcess(cExe,,@nStdOut,,.T.)
               cData := ""
               DO WHILE HB_ProcessValue(nProc,.F.) == -1
                  cLine := Space( 1000 )
                  nBytes := Fread( nStdOUT, @cLine, Len(cLine) )
                  cData += SubStr(cLine,1,nBytes)
               ENDDO            
               FClose(nStdOut)
               IF Empty(cData)
                  ?? " unbekannter Fehler"
                  gtSetClipboard(cExe)
                  Sinkey(0)
               ELSE
                  hUploadResponse := HB_JsonDecode(cData)               
                  
                  IF HHasKey(hUploadResponse,"error")
                     ?? hUploadResponse["message"]
                  ELSE
                     ?? " Upload abgeschlossen."
                  ENDIF
               ENDIF
               
            NEXT
         ENDIF
         RETURN NIL
      })
      nOff += Len(aGetData)
      IF Len(aGetData) < 100
         EXIT
      ENDIF
   ENDDO

   ? "Fertig. Weiter mit beliebiger Taste..."
   Sinkey(0)

   //curl -XPOST -H "X-USER-TOKEN: ITd-Jb3EC_nCXI2fez4hhg" -H "Content-Type: multipart/form-data" -F "attachment=@/path/to/your/file.txt" "https://YOUR_SUBDOMAIN_HERE.nocrm.io/api/v2/leads/9402/attachments"
  
   
RETURN NIL

#include 'x:\run\nocrm.prg'