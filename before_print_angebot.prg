FUNCTION HOOK_before_print_angebot(nAngnr,hSettings,hData)
   LOCAL oExtra
   // Aktivieren f�r CRM-Benutzer, sonst �ndert sich nichts (noCRM bleibt aktiv).
   // Zum Aktivieren: lCrmQuotes := Tr_Getini(28) $ {9,33,28,58}
   LOCAL lCrmQuotes := Tr_Getini(28) $ {9}
   LOCAL nRef
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
   hData["crmtag"] := "" //backward compatibility: no tag if not assigned
   IF lCrmQuotes
      BEGIN SEQUENCE
         LoadPrg(Path("run\crm_email.prg"))
         HB_ExecFromArray({"CRM_QuoteAssign", nAngnr, LTrim(Str(ku->Nummer)), ku->Name1, @nRef})
         hData["crmtag"] := "[#EK-O"+LTrim(Str(nRef))+"]"
      RECOVER
         //nicht fatal
      END SEQUENCE
   ENDIF
RETURN .T.
