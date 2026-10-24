NetUse("englsre","re",.F.,0)
re->(dbSetOrder( 5 ))
re->(dbSeek( Str(0,3)+"T" ))
StartPrint()
SET PRINTER ON
Do While re->ReposNr == 0 .AND. re->packed .AND. ! re->(Eof())
	If re->Rechdat >= CToD("24.01.11") .AND. re->delad != 0
		? re->Rechnr,re->Rechdat,re->Kunde
	Endif
	re->(dbSkip())
Enddo
CopyPrint()

Inkey(0,128)