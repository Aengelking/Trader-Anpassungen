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
   ELSEIF oExtra:cDBID == "ART"
      IF oExtra:Gefahr .AND. ! oExtra:SDS
         oExtra:SDS := .T.
         oExtra:Save()
         Tr_MsgBox("Sicherheitsdatenblatt ist bei Gefahrstoffen notwendig")
      ENDIF
   ENDIF
RETURN .T.