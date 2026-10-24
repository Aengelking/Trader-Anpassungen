FUNCTION HOOK_BEFORE_SAVE_ARTIKEL(lNew,oArt)
   //LOCAL oExtra := art->(ExtraData():New(oArt:Artikelnr))

   IF lNew .AND. Left(oArt:Matchcode,2) == "KS" .AND. ! oArt:QS
      Tr_MsgBox('WareneingangsprÅfung wurde aktiviert')
      oArt:QS := .T.
   ENDIF

RETURN .T.