Head(t("Vorkasse bei Rechnungen wird überprüft"))

NETUSE("skontoa","sk",.F.,0)
NETUSE("englsre","re",.F.,0)

re->(DBSETORDER(3))
re->(dbGoTop())
LOCATE FOR re->code == 2
nR := 1

DO WHILE ! re->(EOF()) .AND. re->status <= 1 .AND.  re->reposnr == 0
	
	DO WHILE ( re->code != 2 .OR. re->Reposnr != 0 .OR. ! re->Packed ) .AND. ! re->(EOF()) .AND. re->Status <= 1
		re->(dbSkip())
	Enddo

	If re->(Eof()) .OR. re->status > 1 .OR. re->Reposnr != 0
		EXIT
	Endif

	@ 00,00 SAY re->Rechnr

	If sk->(IsPrepay(re->skonto)) .AND. re->AoQty == 0
		@ nR,00 SAY re->Kunde+" "+Str(re->Rechnr)+" "+DToC(re->REchdat)+" "+Str(re->poswt)+" "+Str(re->aoqty)
		If re->Poswt >= 0
			re->(Rec_Lock())
			re->AoQty := re->Poswt
			re->Code  := 3
			re->(dbUnLock())
		Endif
		nR++
		If nR > MaxRow()
			nR := 1
		Endif
	Endif

	re->(dbSkip())
ENDDO (EOF)

Inkey(0,128)