#define CRLF Chr(13)+Chr(10)
FUNCTION HOOK_AFTER_FERTIGUNG_WE()
   LOCAL cText,aTo
   IF art->Charge
      //SendMail({{"amos.engelking@engelking.de","Amos"}},"Artikel mit Chargenverwaltung eingebucht "+Trim(art->Matchcode))
   ENDIF
   IF wer->Status == 4  //abgeschlossen
      cText := "Artikel: "+art->Matchcode+CRLF
      cText += "Ausschuss: "+LTrim(Transform(wer->BadQty,Me(art->Me)))+" "+art->Me+CRLF
      cText += "Geplant: "+LTrim(Transform(wer->PlanBad,Me(art->Me)))+" "+art->Me+CRLF
      IF wer->BadQty > wer->PlanBad
         cText += "Ausschuss bersteigt Planung"
      ENDIF
      IF wer->BadQty > 0
         aTo := {{"chris.chertes@engelking.de","Chris"}}
         IF wer->BadQty > wer->PlanBad
            Aadd(aTo,{"amos.engelking@engelking.de","Amos","CC"})
         ENDIF
         SendMail(aTo,"Ausschuss bei FA "+LTrim(Str(wer->Aufno)),cText)
      ENDIF
   ENDIF
RETURN .T.