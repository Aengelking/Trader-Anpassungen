FUNC HOOK_ON_OVER_MAXSTOCK(nArtnr,nStock) //nLZ   
   LOCAL oExtra := art->(ExtraData():New(nArtnr))
   LOCAL oArt
   IF oExtra:MaxStock >= nStock
      oArt := Artikel():New()
      oArt:Load(nArtnr)
      oArt:MaxBestand := nStock
      oArt:Save()
      RETURN .F.
   ENDIF
RETURN .T.