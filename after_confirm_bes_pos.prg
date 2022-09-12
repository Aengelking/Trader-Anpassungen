PROC HOOK_after_confirm_bes_pos(oPos)
   LOCAL oExtra   

   oExtra := art->(ExtraData():New(oPos:Artikelnr))
   IF oExtra:SDS
      DO WHILE Tr_MsgBox("Sicherheitsdatenblatt abgespeichert?",,{"Nein","Ja"}) != 2
      ENDDO
   ENDIF
   
RETURN