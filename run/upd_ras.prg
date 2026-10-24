IF Tr_getini(28) != 9
   RETURN
ENDIF

NetUse("engkund","ku")
ku->(dbSetOrder( 2 ))
ku->(dbSeek( "K" ))


NetUse("englsre","re")
NetUse("enras","ras")
NetUse("skontoa","sk")

dStart := SToD("20090101")

DO WHILE ! ku->(Eof()) .AND. ku->Group == "K" .AND. Inkey() != 27
	nSumme := 0
	re->(dbSetOrder(1))
	re->(dbSeek(ku->Kunde,.T.))
	DO WHILE ! re->(Eof()) .AND. re->Kunde == ku->Kunde
		IF re->reposnr == 0 .AND. re->Rechdat <= dStart .AND. sk->(IsPrepay(re->Skonto))
			nSumme += re->PosWt //-re->AoQty-re->PaySkonto
		Endif
		re->(dbSkip())
	ENDDO
	ras->(dbSetOrder(1))
	ras->(dbSeek(ku->kunde,.T.))
	Do While ! ras->(Eof()) .AND. ras->Kunde == ku->Kunde
		If ras->Rechnr == 0 .AND. ras->paydate <= dStart
         nSumme -= ras->Betrag
		Endif
		IF Empty(ras->Money) 
		    ras->(Rec_Lock())
		    ras->Money := "E"
		    ras->(dbUnLock())
		ENDIF
		ras->(dbSkip())
	Enddo
   IF nSumme > 0
      ras->(Add_Rec())
      ras->PayDate := dStart
      ras->BuchDate := Date()
      ras->Bemerkung := "Abgleich alte Vorkassen"
      ras->Betrag := nSumme
      ras->Kunde := ku->Kunde
      ras->Money := "E"
      ras->(dbUnLock())
      ? ku->Nummer,nSumme
   ENDIF
   ku->(dbSkip())
ENDDO

//Inkey(0,128)