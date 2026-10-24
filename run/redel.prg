LOCAL nYear := Year(Date())-1
LOCAL nChoice,aChoice,aNr

IF Tr_Getini(28) != 9
	Alert("Zugriff verweigert!")
ENDIF

NetUse("englsre","re")

Head(t("Nullrechnung löschen (Wiederverwendung der Nummer!)"))

re->(dbSetOrder( 9 ))
re->(dbSeek( Str(nYear,4)+"0101", .T. ))
DO WHILE re->Reposnr != 0 .AND. ! re->(EOF())
	re->(dbSkip())
ENDDO
IF re->(EOF())
	? "KEINE RECHNUNG GEFUNDEN"
	Inkey(0,128)
ENDIF

re->(dbSetOrder( 8 ))  //reposnr+rechnr

@ 01,00 SAY "Rechnungen werden gesucht..."

aChoice := {}
aNr     := {}
DO WHILE re->reposnr==0 .AND. Year(re->Rechdat) == nYear
	@ 01,29 SAY re->Rechnr
	IF re->Poswt == 0
		Aadd(aChoice,Str(re->Rechnr,6)+"  "+DToC(re->RechDat))
		Aadd(aNr,re->Rechnr)
	ENDIF
	re->(dbSkip())
ENDDO
@ 01,00 CLEAR TO 01,79
nChoice := AMenu(aChoice)
IF nChoice != 0 .AND. Tr_MsgBox(t("Rechnung "+LTrim(Str(aNr[nChoice]))+" wirklich löschen?"),,{t("Nein"),t("Ja")}) == 2
	re->(dbSetOrder( 4 ))
	DO WHILE re->(dbSeek( Str(aNr[nChoice],6) ))
		re->(Rec_Lock())
		re->(dbDelete())
		re->(dbUnLock())
	ENDDO
ENDIF