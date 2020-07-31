NetUse("artikel","art")
art->(dbSetOrder( 1 ))
art->(dbSeek( "ARS" ))
art->(dbSkip())

NetUse("artlief","ali")
ali->(dbSetOrder( 1 ))

CLS
DO WHILE At("ARS",art->Matchcode) == 1
   cStart := SubStr(art->Matchcode,15,1)+SubStr(art->Matchcode,4,4)+SubStr(art->Matchcode,8,1)+SubStr(art->Matchcode,13,1)

   IF ali->(dbSeek( Pad("BULGIN",8)+Str(art->Artikelnr,6) )) .AND. ! Empty(ali->Artlief)

      IF Left(ali->Artlief,7) == cStart
         SetColor("G+/W")
         //?? " ok"
         SetColor("N/W")
      ELSE
         SetColor("R/W")
         ? art->Matchcode,cStart,ali->Artlief 
         //?? " NOT OK"
         SetColor("N/W")
      ENDIF
   ELSE
//      ?? "---"
   ENDIF
   art->(dbSkip())
ENDDO
? "done"
SInkey(0,128)