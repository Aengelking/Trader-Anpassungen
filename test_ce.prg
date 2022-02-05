oArtikel:=Artikel():New()


nPoles := Val(Substr(oArtikel:Matchcode,7,2))
cSeries := Substr(oArtikel:Matchcode,3,2)
IF (cSeries == "08" .AND. nPoles <= 6) .OR.;
   (cSeries == "12" .AND. nPoles <= 5)   
   oExtra := art->(ExtraData():New(art->Artikelnr))
   oExtra:APPR_CE := .T.
   oExtra:Save()
ENDIF