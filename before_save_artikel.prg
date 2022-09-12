FUNCTION HOOK_BEFORE_SAVE_ARTIKEL(lNew,oArt)
   LOCAL oExtra := art->(ExtraData():New(oArt:Artikelnr))
   HB_SYMBOL_UNUSED(lNew)
   IF oArt:Updated("Zeichnung") .AND. Empty(oArt:GetField("Zeichnung",.T.)) .AND. ! Empty(oArt:Zeichnung)
      oArt:QS := .T.
   ELSEIF lNew .AND. ".LP.BS" $ oArt:Matchcode .AND. Tr_MsgBox("WE-QS PrÅfung durchfÅhren?",,{"Ja","Nein"}) == 1
      oArt:QS := .T.
   ENDIF
RETURN .T.