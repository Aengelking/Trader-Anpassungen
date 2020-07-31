Head("Remove defect invoice")

nRech := GetBox(0,"Rechnungsnummer","999999")
cMatch := GetBox(Space(25),"Matchcode")
aAB := Array()
/*nOrd := 1
do while dbSetOrder(nOrd) != NIL .AND. nOrd == IndexOrd()
	? '  '+Str(nOrd,1)+'. '+OrdKey(nOrd)
	//ordCondSet(,,.T.,{||.T.},{||  SetPos(Row(),0),QQout(STR((RECNO()/LASTREC()) * 100,3,0)+'%') },10)
	//ordListRebuild()
	nOrd++
enddo*/
NetUse("englsre","re",.F.,0)
re->(dbSetOrder(4))
//? '  '+Str(IndexOrd(),1)+'. '+OrdKey(IndexOrd())
lDel := .F.
nAnswer := MsgBox("Remove this invoice?",,{"NO","Simulate","Yes"})
if re->(dbSeek(Str(nRech,6))) .and. nAnswer > 1
	do while re->rechnr == nRech 
		if ( re->matchcode == cMatch )
			? "Deleting position: ",re->reposnr,re->matchcode,re->(recno())
			re->(Rec_Lock(0))
	        if nAnswer == 3
			  re->(dbDelete())
			endif
			re->(dbUnLock())
		endif
		re->(dbskip())
	enddo
	lDel := .T.
endif
NetUse("engabg","abg",.F.,0)
abg->(dbSetOrder(3))
? If(abg->(dbSeek(cMatch,.T.)),"Found","Not found")+" in ABG"
if ( nAnswer > 1 .and. abg->(dbSeek(cMatch,.T.)) )
	do while abg->matchcode == cMatch
		//?  "*"+Str(nRech,6)+"-*" ,"*"+abg->Beleg+"*"
		if ( Str(nRech,6)+"- " == SubStr(abg->Beleg,0,8) )
			? "Deleting bewegung: ",abg->(recno())
			abg->(Rec_Lock(0))
			if nAnswer == 3
	          abg->(dbDelete())
	        endif
			abg->(dbUnLock())
		endif
		abg->(dbSkip())
	enddo
endif

re->(dbCloseArea())


inkey(0)





