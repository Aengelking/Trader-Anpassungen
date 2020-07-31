NetUse("engabg","abg",.F.,0)
NetUse("engbes","bes",.F.,0)
bes->(dbSetOrder(9))
abg->(dbGoTop())
aRecs := {}

CLS
hRecs := {=>}
Do While ! abg->(Eof())
	If Trim(abg->Buart) == "WE" //.AND. abg->BesPos == 0
		Aadd(aRecs,{"besnr"=>abg->Besnr,"matchcode"=>abg->Matchcode,"menge"=>abg->Menge,"recno"=>abg->(Recno())})
		cKey := Str(abg->Besnr,6)+abg->Matchcode
		If ! HB_HHasKey(hRecs,cKey)
			hRecs[cKey] := {"besnr"=>abg->Besnr,"matchcode"=>abg->Matchcode,"pos"=>{}}
		Endif
		Aadd(hRecs[cKey]["pos"],{"menge"=>abg->Menge,"recno"=>abg->(Recno())})
	Endif
	abg->(dbSkip())
Enddo
bSort := {|x,y| Str(x["besnr"],6)+x["matchcode"] > Str(y["besnr"],6)+y["matchcode"] }

/*? Len(aRecs)
nR := 0
CLS
For nX := 1 To 300
	hRec := HGetValueAt(hRecs,nX)

	//ASort(hRec["pos"],,,{|x,y| If(x["menge"]<0,x["menge"] < y["menge"],x["menge"]>y["menge"]) })
	ASort(hRec["pos"],,,{|x,y| If(x["menge"]<0,.T.,If(y["menge"]<0,.F.,x["menge"] > y["menge"])) })
	For nY := 1 To Len(hRec["pos"])

		@ nR++,00 SAY Str(hRec["besnr"],6)+" "+hRec["matchcode"]+Str(hRec["pos"][nY]["menge"])
		If nR == MaxRow()
			Inkey(0,128)
			CLS
			nR := 0
		Endif
	Next
Next
Inkey(0,128) */

hBes := {=>}
bConds := {}
Aadd(bConds,{|| abg->Menge == hBes[Str(bes->Besnr,6)+Str(bes->Posnr,3)] }) //first of exact matches
Aadd(bConds,{|| (bes->GelQty >= 0 .AND. abg->Menge <= hBes[Str(bes->Besnr,6)+Str(bes->Posnr,3)]) .OR. (bes->GelQty < 0 .AND. abg->Menge >= hBes[Str(bes->Besnr,6)+Str(bes->Posnr,3)]) })
For nR := 1 To Len(hRecs)
	hRec := HGetValueAt(hRecs,nR)
	ASort(hRec["pos"],,,{|x,y| If(x["menge"]<0,.T.,If(y["menge"]<0,.F.,x["menge"] > y["menge"])) })
	aRecs := hRec["pos"]
	For nX := 1 To Len(aRecs)
		//@ 00,00 SAY aRecs[nX]["recno"]
		abg->(dbGoTo( aRecs[nX]["recno"] ))
		For nC := 1 To Len(bConds)
			If bes->(dbSeek( Str(hRec["besnr"],6)+hRec["matchcode"] ))
				nPos := 0
			Else
				nPos := -1
			Endif
			Do While bes->Besnr == hRec["besnr"] .AND. bes->Matchcode == hRec["matchcode"] .AND. nPos == 0
				If ! HHasKey(hBes,Str(bes->Besnr,6)+Str(bes->Posnr,3))
				     hBes[Str(bes->Besnr,6)+Str(bes->Posnr,3)] := bes->GelQty
				Endif
				If Eval(bConds[nC])
					hBes[Str(bes->Besnr,6)+Str(bes->Posnr,3)] -= abg->Menge
					nPos := bes->Posnr
				Endif
				bes->(dbSkip())
			Enddo
			If nPos != 0
				EXIT
			Endif
		Next
		If nPos == 0
			? aRecs[nX]["recno"],hRec["besnr"],hRec["matchcode"],abg->Menge, If(nPos==-1,"Artikel nicht gefunden","nicht zugeordnet")
/*			If Tr_MsgBox(Str(hRec["besnr"],6)+" "+Trim(hRec["matchcode"])+" "+Str(abg->Menge)+" nicht zugeordnet",,{"Zuordnen","Ignorieren"}) == 1
				nPos := GetBox(nPos,"Position","999")
			Endif*/
		Endif
		If nPos > 0
			abg->(Rec_Lock(0))
			abg->BesPos := nPos
			abg->(dbUnLock())
		Endif
	Next
	//?? bes->GelQty
Next
SInkey(0,128)