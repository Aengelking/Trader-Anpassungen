FUNCTION HOOK_BEFORE_SAVE_ARTIKEL(lNew,oArt)
   //LOCAL oExtra := art->(ExtraData():New(oArt:Artikelnr))
   
   IF AT("p",oArt:Matchcode) == 1 .AND. AT(".KONF",oArt:Matchcode) != 0 .AND. ! Empty(oArt:Zeichnung) .AND. oArt:Type == "LOHN"
      IF ! GetConfigValue("BATCHMODE")
         Tr_MsgBox("Konfektionsartikel dÅrfen keine Zeichnung haben!",{"OK"})
      ENDIF
      RETURN .F.
   ENDIF
   IF oArt:Updated("Zeichnung") .AND. Empty(oArt:GetField("Zeichnung",.T.)) .AND. ! Empty(oArt:Zeichnung)
      oArt:QS := .T.
   ELSEIF lNew .AND. ".LP.BS" $ oArt:Matchcode .AND. Tr_MsgBox("WE-QS PrÅfung durchfÅhren?",,{"Ja","Nein"}) == 1
      oArt:QS := .T.
   ENDIF
RETURN .T.