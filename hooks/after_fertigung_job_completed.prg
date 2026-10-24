//David entfernt beim Versand jedes Chr(10) (siehe SendMail), ein CRLF wuerde also
//verschwinden und die Mail als ein Block ankommen - daher <br>
#define BR "<br>"
FUNCTION HOOK_after_fertigung_job_completed(nAufno,nCompleted,nNext)
   LOCAL cText := "Auftrag: "+LTrim(Str(nAufno))+BR
   LOCAL cCompleted,oFrepple,hResult
   LOCAL lOK := .F.
   LOCAL cFreppleId,nX,lOkResult,cRaw
   
   NetUSe("artikel","art")
   NetUse( "jobs",   "job" )
   
   art->(dbSeek(wer->Matchcode))
   cText += "Artikel: "+wer->Matchcode+BR
   cText += "Menge: "+Transform(wer->Qty,Me(art->Me))+" "+art->Me+BR
   job->(dbSeek( Str(nCompleted,6) ))
   cText += "Abgeschlossen: "+job->Name+BR   
   cCompleted := job->Name
   job->(dbSeek( Str(nNext,6) ))
   cText += "N„chster Schritt: "+job->Name

   MailConnect()
   NetUse("frepjobs","fjob")
   IF fjob->(dbSeek( Str(rst->Id,12) ))      
      LoadModule("frepple")
      oFrepple := GetFreppleApi()
      cFreppleId := Trim(fjob->FreppleId)
      FOR nX := 1 TO 2
         //Statuswechsel ueber den Service-Endpunkt svc/<scenario>/operationplan/, den auch
         //Frepples Plan-Oberflaeche benutzt. Der REST-Input-Endpunkt ist fuer Work Orders
         //unbrauchbar: ohne resources/materials antwortet er "This field is required", mit
         //ihnen "Direct assignment to the reverse side of a related set is prohibited".
         //Die ID steht hier im JSON-Body, daher hb_strtoutf8() statt URL-Encoding.
         hResult := oFrepple:updateOperationPlan({{"id"=>hb_strtoutf8(cFreppleId),"status"=>"completed"}})
         cText += BR+"Frepple Auftrag: "+cFreppleId
         cText += BR+"Fertigungsauftrag in Frepple "
         cRaw := hResult   //Rohantwort behalten, damit auch nicht-JSON im Fehlertext landet
         IF ValType(hResult) == "C"
            hResult := hb_jsondecode(hResult)
         ENDIF
         //Der Service antwortet bei Erfolg mit {"OK": 1}, bei Fehlern mit {"errors": [...]}
         lOkResult := ValType(hResult) == "H" .AND. HHasKey(hResult,"OK")
         IF lOkResult
            cText += "erfolgreich abgeschlossen"
            oFrepple:LoadPlan()
            lOK := .T.
            EXIT
         ELSE
            cText += "nicht abgeschlossen: "+IF(ValType(hResult) == "H",ValToPrg(hResult),cStr(cRaw))
            
            IF LTrim(Str(Val(cFreppleId))) != cFreppleId //Not a numeric ID, then exit
               EXIT
            ELSE //build a new Frepple ID, we guess that the order has been updated 
               job->(dbSeek( Str(nCompleted,6) ))
               cFreppleId := "FA"+LTrim(Str(wer->Aufno))+"-"+Trim(job->Name)
            ENDIF
         ENDIF  
      NEXT    
      //cText += BR+ValToPrg(hResult)
   ENDIF
   IF ! lOK
      MailConnect()
      SendMail({{"amos.engelking@engelking.de","Amos"}},"Fertigungsauftrag "+LTrim(Str(nAufno))+" "+Trim(cCompleted)+" abgeschlossen - FEHLER",cText)
   ENDIF
RETURN .T.

//#include '..\run\frepple_curl.prg'