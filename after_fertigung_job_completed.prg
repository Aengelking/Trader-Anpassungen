//David entfernt beim Versand jedes Chr(10) (siehe SendMail), ein CRLF wuerde also
//verschwinden und die Mail als ein Block ankommen - daher <br>
#define BR "<br>"
FUNCTION HOOK_after_fertigung_job_completed(nAufno,nCompleted,nNext)
   LOCAL cText := "Auftrag: "+LTrim(Str(nAufno))+BR
   LOCAL cCompleted,oFrepple,hResult
   LOCAL lOK := .F.
   LOCAL cFreppleId,nX,lOkResult
   
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
         //resources/materials muessen mitgeschickt werden, sonst antwortet Frepple mit
         //"This field is required". Leere Listen werden von Frepples update() uebersprungen
         //(if opplanreslist:), Belegungen und Materialbewegungen bleiben unangetastet.
         hResult := oFrepple:patchWorkOrder(StrTran(tip_urlEncode(hb_strtoutf8(cFreppleId)),"+","%20"),;
                                            {"status"=>"completed","resources"=>{},"materials"=>{}})
         cText += BR+"Frepple Auftrag: "+cFreppleId
         cText += BR+"Fertigungsauftrag in Frepple "
         IF ValType(hResult) == "C"
            hResult := hb_jsondecode(hResult)
         ENDIF
         lOkResult := .F.
         IF ValType(hResult) == "H"
            //Detail-Endpunkt antwortet mit dem gepatchten Objekt ...
            IF HHasKey(hResult,"status") .AND. hResult["status"] == "completed"
               lOkResult := .T.
            //... der Bulk-Endpunkt mit einer Zusammenfassung (created/updated/deleted/failed)
            ELSEIF HHasKey(hResult,"failed") .AND. HHasKey(hResult,"updated")
               lOkResult := Val(cStr(hResult["failed"])) == 0 .AND. Val(cStr(hResult["updated"])) > 0
            ENDIF
         ENDIF
         IF lOkResult
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
      //cText += BR+ValToPrg(hResult)
   ENDIF
   IF ! lOK
      MailConnect()
      SendMail({{"amos.engelking@engelking.de","Amos"}},"Fertigungsauftrag "+LTrim(Str(nAufno))+" "+Trim(cCompleted)+" abgeschlossen - FEHLER",cText)
   ENDIF
RETURN .T.

//#include '..\run\frepple_curl.prg'