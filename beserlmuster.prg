NetUse("engbes","bes",.F.,0)

CLS
Do While ! bes->(Eof())
	If bes->Bestat < 3 .AND. ;
		(bes->GelQty >= bes->beqty .AND. (bes->EkPr == 0 .OR. bes->Besda <= Date()-365)) ;//erledigte Muster oder alt)
		.OR. (bes->EkPr == 0 .AND. bes->BeQty <= 3 .AND. bes->Besda <= Date()-365) //alte muster
		bes->(Rec_Lock(0))
		bes->Bestat := 3
		bes->(dbUnLock())
	Endif
	bes->(dbSkip())
Enddo