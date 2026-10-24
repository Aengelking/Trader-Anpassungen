FUNCTION HOOK_BEFORE_FERTIGUNG_WE
   IF HB_regexMatch(".*\.LP\.BS\.[0-9]+",art->Matchcode) .AND. Tr_MsgBox("LeiterplattenprÅfprotokoll vorhanden?",,{"Nein","Ja"}) != 2
      RETURN .F.
   ENDIF
RETURN .T.