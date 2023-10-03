FUNCTION HOOK_AFTER_FERTIGUNG_WE()
   IF art->Charge
      //SendMail({{"amos.engelking@engelking.de","Amos"}},"Artikel mit Chargenverwaltung eingebucht "+Trim(art->Matchcode))
   ENDIF
   IF wer->Status == 4  //abgeschlossen
      IF wer->BadQty > wer->PlanBad
         SendMail({{"amos.engelking@engelking.de","Amos"}},"Ausschuss bei FA "+LTrim(Str(wer->Aufno))+" Åbersteigt Planung")
      ENDIF
   ENDIF
RETURN .T.