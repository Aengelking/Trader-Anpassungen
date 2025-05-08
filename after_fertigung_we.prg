#define CRLF Chr(13)+Chr(10)
FUNCTION HOOK_AFTER_FERTIGUNG_WE()
   LOCAL cText,aTo
   IF art->Charge
      //SendMail({{"amos.engelking@engelking.de","Amos"}},"Artikel mit Chargenverwaltung eingebucht "+Trim(art->Matchcode))
   ENDIF
   IF wer->Status == 4  //abgeschlossen
      IF wer->BadQty > wer->PlanBad
         cText := "Artikel: "+art->Matchcode+CRLF
         cText += "Ausschuss: "+LTrim(Transform(wer->BadQty,Me(art->Me)))+" "+art->Me+CRLF
         cText += "Geplant: "+LTrim(Transform(wer->PlanBad,Me(art->Me)))+" "+art->Me+CRLF      
         
         StickPrint("Sperrvermerk_Intern")
         

         cText += "Ausschuss bersteigt Planung"
         //aTo := {{"chris.chertes@engelking.de","Chris"}}
         aTo := {}
         Aadd(aTo,{"amos.engelking@engelking.de","Amos"})         
         SendMail(aTo,"Ausschuss bei FA "+LTrim(Str(wer->Aufno)),cText)
      ENDIF
   ENDIF
RETURN .T.