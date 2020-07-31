FUNCTION HOOK_before_print_angebot(nAngnr,hSettings)
   //Alert(hSettings["email_type"])
   LOCAL oExtra
   IF ku->Skonto == 8
      oExtra := ku->(ExtraData():New(ku->Nummer))      
      IF oExtra:OnlineKauf
         hSettings["email_type"] := "ang_vk"
      ENDIF
   ENDIF
RETURN .T.
