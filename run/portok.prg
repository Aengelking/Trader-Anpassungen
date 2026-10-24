Head("Portofrei zurücksetzen")
NetUSe("engkund","ku",.F.,0)
ku->(dbSetOrder(2))

NetUse("englsre","re",.F.,0)


ku->(dbSeek("K"))

Do While ! ku->(Eof()) .AND. ku->Group == "K"
	If ku->Portok $ "Nn"
		If ku->Skonto == 8
			ku->(Rec_Lock(0))
			ku->Portok := "Y"
			ku->(dbUnLock())
		Else

			nWith := 0
			nWO := 0
			re->(dbSeek(ku->Kunde))
			Do While re->Kunde == ku->Kunde .AND. ! re->(Eof())
				If re->reposnr == 0 .AND. re->poswt > 0 .AND. re->Skonto != 8
					If Empty(re->ofqty)
						nWO ++
					Else
						nWith++
					Endif
				Endif
				re->(dbSkip())
			Enddo

            ? ku->Kunde,ku->Skonto,nWO,nWith
            If nWith+nWo > 0
				?? (nWo/(nWith+nWO))*100
			Endif
			If nWith+nWo == 0 .OR. (nWo/(nWith+nWO)) < .5
				ku->(Rec_Lock(0))
				ku->Portok := "Y"
				//?? "XX"
				ku->(dbUnLock())
			Endif
		Endif
	Endif
	ku->(dbSkip())
Enddo
Inkey(0)
