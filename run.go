PROC RUN_GEFAHRSTOFF
   LOCAL aArt := GetIdsWithExtraField("ku","GEFAHR")
	LOCAL nX

	NetUse("artikel","art")
	art->(dbSetOrder( 2 ))

	FOR nX := 1 TO Len(aArt)
		art->(dbSetOrder( Str(aArt[nX],6) ))
		? aArt[nX],art->artikel
	NEXT
	Sinkey(0)
	