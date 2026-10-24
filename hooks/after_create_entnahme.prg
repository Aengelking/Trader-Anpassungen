PROC HOOK_after_create_entnahme(nVorg,lVersand)
   //engrepr("ENGREAB",0,nRenr)
   LOCAL oExtra
   If GetConfigValue("BATCHMODE") .OR. Tr_MsgBox("Entnahme zum "+If(lVersand,"Versand","Richten")+" freigeben?",,{"Ja","Nein"}) == 1
      UpdateLNEStatus(nVorg,1)
   Endif
   IF lne->Gruppe == "K"
      oExtra := ku->(ExtraData():New(ku->Nummer))
      IF ! Empty(oExtra:StdLief)
         DO WHILE Tr_MsgBox("Lieferung muss erfolgen an: "+oExtra:StdLief,,"Lieferadresse",,{"abbrechen","OK"}) != 2
         ENDDO
      ENDIF
   ENDIF
RETURN 