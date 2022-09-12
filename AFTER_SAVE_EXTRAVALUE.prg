Function AFTER_SAVE_EXTRAVALUE(cName,oExtra)
   IF oExtra:cDBID == "KU"
      IF oExtra:WerksBesch .AND. Empty(oExtra:ShpNtfyTo)
         Tr_MsgBox("EmpfÑnger fÅr Versandmitteilung hinterlegen, Werkbescheinigung wird dorthin gesendet.")
      ENDIF
      IF oExtra:WerksBesch .AND. ! oExtra:Shipnotify
         oExtra:Shipnotify := .T.
         oExtra:Save()
         Tr_MsgBox("Versandmitteilung wurde fÅr Werksbescheinigung aktiviert.")
      ENDIF
   ENDIF
RETURN .T.