FUNC HOOK_GET_BES_RAHMEN_MATCHCODE(oBesPos)
    LOCAL oExtra := art->(ExtraData():New(oBesPos:Artikelnr))
    IF ! Empty(oExtra:RahmArt)
        RETURN oExtra:RahmArt
    ENDIF
RETURN NIL