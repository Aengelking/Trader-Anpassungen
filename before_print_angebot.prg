FUNCTION HOOK_before_print_angebot(nAngnr,hSettings)
   //Alert(hSettings["email_type"])
   LOCAL oExtra
   // Aktivieren f�r CRM-Benutzer, sonst �ndert sich nichts (noCRM bleibt aktiv).
   // Zum Aktivieren: lCrmQuotes := Tr_Getini(28) $ {9,33,28,58}
   LOCAL lCrmQuotes := .F.
   /*IF ku->Skonto == 8
      oExtra := ku->(ExtraData():New(ku->Nummer))
      IF oExtra:OnlineKauf
         hSettings["email_type"] := "ang_vk"
      ENDIF
   ENDIF*/

   // CRM (Transition): Angebot einer Opportunity zuordnen. Ist es bereits
   // zugeordnet, passiert nichts; sonst �ffnet sich der Opportunity-Picker
   // (Auswahl oder Neuanlage). Best-effort � ein Fehler darf den Druck nicht
   // abbrechen.
   IF lCrmQuotes
      BEGIN SEQUENCE
         LoadPrg(Path("run\crm_email.prg"))
         HB_ExecFromArray({"CRM_QuoteAssign", nAngnr, ku->Kunde})
      RECOVER
         //nicht fatal
      END SEQUENCE
   ENDIF
RETURN .T.
