#define CRLF Chr(13)+Chr(10)
FUNCTION HOOK_after_fertigung_job_completed(nAufno,nCompleted,nNext)
   LOCAL cText := "Auftrag: "+LTrim(Str(nAufno))+CRLF
   LOCAL cCompleted,oFrepple,hResult
   LOCAL lOK := .F.
   LOCAL cFreppleId,nX
   
   NetUSe("artikel","art")
   NetUse( "jobs",   "job" )
   
   art->(dbSeek(wer->Matchcode))
   cText += "Artikel: "+wer->Matchcode+CRLF
   cText += "Menge: "+Transform(wer->Qty,Me(art->Me))+" "+art->Me+CRLF
   job->(dbSeek( Str(nCompleted,6) ))
   cText += "Abgeschlossen: "+job->Name+CRLF   
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
         hResult := oFrepple:patchWorkOrder(StrTran(tip_urlEncode(hb_strtoutf8(cFreppleId)),"+","%20"),{"status"=>"completed"})      
         cText += CRLF+"Frepple Auftrag: "+cFreppleId
         cText += CRLF+"Fertigungsauftrag in Frepple "
         IF ValType(hResult) == "C"
            hResult := hb_jsondecode(hResult)
         ENDIF
         IF ValType(hResult) == "H" .AND. HHasKey(hResult,"status") .AND. hResult["status"] == "completed"
            cText += "erfolgreich abgeschlossen"
            oFrepple:LoadPlan()
            lOK := .T.
            EXIT
         ELSE
            cText += "nicht abgeschlossen: "+ValToPrg(hResult)            
            
            IF LTrim(Str(Val(cFreppleId))) != cFreppleId //Not a numeric ID, then exit
               EXIT
            ELSE //build a new Frepple ID, we guess that the order has been updated 
               job->(dbSeek( Str(nCompleted,6) ))
               cFreppleId := "FA"+LTrim(Str(wer->Aufno))+"-"+Trim(job->Name)
            ENDIF
         ENDIF  
      NEXT    
      //cText += CRLF+ValToPrg(hResult)
   ENDIF
   IF ! lOK
      MailConnect()
      SendMail({{"amos.engelking@engelking.de","Amos"}},"Fertigungsauftrag "+LTrim(Str(nAufno))+" "+Trim(cCompleted)+" abgeschlossen - FEHLER",cText)
   ENDIF
RETURN .T.

//#include '..\run\frepple_curl.prg'