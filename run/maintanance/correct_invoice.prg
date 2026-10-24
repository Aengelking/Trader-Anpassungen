netUse("englsre","re",.F.,0)
re->(dbSetOrder( 12 ))
nRechnr := 0
/*Do While .T.
	nRechnr := GetBox(nRechnr,"Rechnung","999999")
	If LastKey() == 27
		Return
	Endif*/
	re->(dbSeek( Str(33006,6) ))
	Do While ! re->(Eof())
	//If re->(dbSeek( Str(nRechnr,6)+Str(0,3) ))
		If re->Reposnr == 0
			nRechnr := re->Rechnr
			nTotal := 0
			re->(dbSkip())
			DO WHILE ! re->(EOF()) .AND. re->RECHNR == nRechnr
				If re->reposnr != 0
					nTotal += ROUND( (re->aoqty*re->preis/re->pe)*(1-re->rabatt/100),2)+re->Zuschlag
				Endif
				re->(dbSkip())
			ENDDO
			nMwSt := 0
	                re->(dbSeek( Str(nRechnr,6)+Str(0,3) ))
			taxit( re->taxcode,@nMwst,re->rechdat,.F. )
			nMwStWert := 0
			If  re->reart < 2
				nMwStWert := Int( (nTotal+re->OfQty)*nMwst+If(nTotal>=0,0.5,-0.5) )/100.00
			Else
				nMwStWert := Round( (nTotal+re->OfQty)-(nTotal+re->OfQty)/nMwst ,2)
			Endif

			If Round(nTotal+re->OfQty+If(re->reart < 2,nMwStWert,0),2) != Round(re->Poswt,2)
				If Tr_MsgBox({"Summen korrigieren?","Bisher: "+Str(re->poswt,12,2),"Neu:    "+Str( nTotal+re->OfQty+If(re->reart < 2,nMwStWert,0),12,2)},"Rechnung "+LTrim(Str(nRechnr)),{"Nein","Ja"}) == 2
					//RechnungSetTotal(nTotal)
					RechnungUpdateTotal()
				Endif
			Endif
		Endif
		re->(dbSkip())
	Enddo
