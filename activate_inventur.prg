PROC RUN_ACTIVATE_INVENTUR
   NetUse("engnr","nr")
   IF ! SystemUser():CheckPermission("U","ART_INVENTUR")
      RETURN
   ENDIF
   IF Tr_MsgBox("Inventur "+IF(nr->Inventur,"de","")+"aktivieren?",,{"Nein","Ja"}) == 2
      nr->(Rec_Lock(0))
      nr->Inventur := ! nr->Inventur
      nr->(dbUnLock())
   ENDIF
RETURN 
