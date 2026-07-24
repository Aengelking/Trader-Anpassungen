PROC HOOK_after_confirm_bes_pos(oPos)
   LOCAL oExtra

   oExtra := art->(ExtraData():New(oPos:Artikelnr))
   IF oExtra:SDS
      IF Type("MCPCHATMESSAGE()") != "U"   //im MCP-Server?
         HB_ExecFromArray("MCPChatMessage", {"Sicherheitsdatenblatt zu "+Trim(oPos:Matchcode)+" abspeichern!"})
      ELSEIF ! GetConfigValue("BATCHMODE")
         DO WHILE Tr_MsgBox("Sicherheitsdatenblatt abgespeichert?",,{"Nein","Ja"}) != 2
         ENDDO
      ENDIF
   ENDIF
RETURN