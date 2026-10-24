NetUse("englsre","re")
NetUse("engauf","auf")

re->(dbSetOrder( 12 ))
re->(dbGoTop())

auf->(dbSetOrder( 1 ))

Head("Korrektur AB-Nummern in Rechnungsdaten")

Do While ! re->(Eof()) .AND. re->Rechnr <= 4000
	If ! auf->(dbSeek( Str(re->AbNr,6) )) .OR. auf->Kundma != re->Kunde
		@ 01,00 CLEAR TO 05,00
		@ 01,00 SAY "Rechnung: "+LTrim(Str(re->rechnr))
		@ 02,00 SAY "Kunde...: "+re->Kunde

		nRechnr := re->Rechnr
		//nAbnr := GetBox(re->AbNr,t("AB-Nr.","999999")
		Do While re->Rechnr == nRechnr
			re->(Rec_Lock(0))
			//re->AbNr := nAbNr
			//re->AbNr := 0
			re->(dbUnLock())
			re->(dbSkip())
		Enddo
		re->(dbSkip(-1))
	Endif
	re->(dbSkip())
Enddo

Inkey(0,128)