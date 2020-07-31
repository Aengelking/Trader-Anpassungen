NetUse("artikel","art")
art->(dbSetOrder( 2 ))
art->(dbGoTop())

DO WHILE ! art->(EOF())
   nArtnr := art->Artikelnr
   art->(dbSkip())
   IF nArtnr == art->Artikelnr
      ? nArtnr
   ENDIF
ENDDO
Inkey(0,128)