FUNCTION HOOK_AFTER_FERTIGUNG_WE
   IF art->Charge
      SendMail({{"amos.engelking@engelking.de","Amos"}},"Artikel mit Chargenverwaltung eingebucht "+Trim(art->Matchcode))
   ENDIF
RETURN .T.