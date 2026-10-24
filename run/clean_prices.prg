LOCAL cIndex,aIndex := {},nCount := 1,nX := 0

Head("Preisetabelle bereinigen")

NetUSe("buyprice","bpr",.F.,0)
NetUse("artikel","art")
art->(dbSetOrder( 2 ))

@ 01,00 SAY "Duplikate entfernen"
bpr->(dbSetOrder( 0 ))
@ 02,00 SAY Str(bpr->(LastRec()),6)+"/"
bpr->(dbSetOrder( 1 ))

DO WHILE ! bpr->(EOF())
	@ 02,08 SAY LTrim(Str(nCount))
	IF Trim(bpr->Type) == "LIST"
		cIndex := bpr->LIEFMA+Str(bpr->artikelnr,6,0)+Str(bpr->Qty,12,2)+bpr->Number
		IF AScan(aIndex,cIndex) != 0
			art->(dbSeek( Str(bpr->Artikelnr,6) ))
   	   @ 03+nX,00 SAY Pad(Trim(art->Matchcode)+" "+LTrim(Str(bpr->Qty,6))+" "+bpr->Number+" entfernt",MaxCol())
   	   bpr->(Rec_Lock())
   	   bpr->(dbDelete())
   	   bpr->(dbUnLock())
		ELSE
			Aadd(aIndex,cIndex)
		ENDIF
	ENDIF
	nCount++
	bpr->(dbSkip())
ENDDO

@ MaxRow(),00 SAY t("Beliebige Taste drücken...")
Inkey(0,128)