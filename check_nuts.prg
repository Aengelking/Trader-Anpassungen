LOCAL cFilter,lDichtung,lMutter
LOCAL nArtnr,nRec,bCheck
LOCAL aSeriesNoDi := {"ESI11","ES02","NK01"}
LOCAL aSeriesNoNut := {"NK01"}
CLS
NetUse("artikel","art")
NetUse("folgeart","fol")
NetUse("parts","part")

art->(dbSetOrder( 2 ))
fol->(dbSetOrder( 1 ))

cFilter := "manufactur = 6 .AND. Left(gruppe,2) == 'SW' .AND. Variant != 'B'"

art->(dbSetFilter({|| &cFilter },cFilter))
art->(dbGoTop())
StartPrint()
SET PRINTER ON

DO WHILE ! art->(EOF())

   nArtNr := art->Artikelnr
   nRec := art->(Recno())
   lDichtung := .F.
   lMutter := .F.
   bCheck := {||
      IF Left(art->Matchcode,3) == "DI."
         lDichtung := .T.
      ELSEIF Left(art->Matchcode,6) == "MUTTER"
         lMutter := .T.
      ENDIF
      RETURN NIL
   }
   IF ASCan(aSeriesNoDi,{|cSeries| AT(cSeries,art->Matchcode) == 1 }) != 0
      lDichtung := .T.
   ENDIF
   IF ASCan(aSeriesNoNut,{|cSeries| AT(cSeries,art->Matchcode) == 1 }) != 0
      lMutter := .T.
   ENDIF

   art->(dbClearFilter())



   fol->(dbSeek(Str(art->Artikelnr,6)))
   DO WHILE fol->Artikelnr == nArtnr .AND. ! fol->(EOF())
      art->(dbSeek( Str(fol->Folgeart,6) ))
      Eval(bCheck)
      fol->(dbSkip())
   ENDDO

   part->(dbSeek( Str(nArtnr,6) ))
   DO WHILE part->ListArt == nArtnr .AND. ! part->(EOF())
      art->(dbSeek( Str(part->PartArt,6) ))
      Eval(bCheck)
      part->(dbSkip())
   ENDDO


   art->(dbSetFilter({|| &cFilter },cFilter))
   art->(dbGoto(nRec))
   IF ! lDichtung .OR. ! lMutter
      ? art->Matchcode
   ENDIF
   IF ! lDichtung
      ?? " Dichtung fehlt"
   ENDIF
   IF ! lMutter
      ?? " Mutter fehlt"
   ENDIF
   art->(dbSkip())
ENDDO
CopyPrint()
Sinkey(0)