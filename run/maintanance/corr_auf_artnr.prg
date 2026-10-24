NetUse("engauf","auf")
auf->(dbGoTop())
NetUse("artikel","art")
art->(dbSetOrder( 1 ))
DO WHILE ! auf->(Eof())
   IF ! art->(dbSeek( auf->Matchcode )) .OR. art->Matchcode != auf->Matchcode
      ? auf->Abnr,auf->Itmnr,"Artikel nicht gefunden"
   ELSE
      IF art->Artikelnr != auf->Artikelnr
         ? auf->Abnr,auf->Itmnr,"Artikelnr korrigiert"
         auf->(Rec_Lock())
         auf->Artikelnr := art->Artikelnr
         auf->(dbUnLock())
      ENDIF
   ENDIF
   auf->(dbSkip())
ENDDO
Inkey(0,128)