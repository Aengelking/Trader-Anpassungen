LOCAL nArt,aList:= {}
LOCAL cFile := Trim(Tr_getini(1))+"\export\folgeart.csv",nH

nH := FCreate(cFile)
IF nH == 0
   Alert("File could not be opened")
   RETURN
ENDIF

NetUse("artikel","art")
NetUse("folgeart","fol")
art->(dbSetOrder( 2 ))
fol->(dbSetOrder( 2 ))
fol->(dbGoTop())
Aadd(aList,{"Artikel","Gewicht","Wert"})
DO WHILE ! fol->(EOF())
   @ 00,00 SAY fol->Folgeart
   art->(dbSeek( Str(fol->Folgeart,6) ))
   Aadd(aList,{ art->Matchcode,art->Gewicht,GetLowestBuyPrice( art->Artikelnr, 99999999, Date() ) })
   nArt := fol->Folgeart
   DO WHILE fol->FolgeArt == nArt .AND. ! fol->(Eof())
      fol->(dbSkip())
   ENDDO
ENDDO

FClose(nH)

SaveAsCSV(cFile,aList)
Wapi_ShellExecute(,"open",cFile)