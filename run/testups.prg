NetUse("engkund","ku",.F.,0)
ku->(dBSetOrder( 1 ))
ku->(dbSeek( "HOPA    L" ))

NetUse("upsaccou","upsac",.F.,0)
cNummer := Space(6)
If upsac->(dbSeek( Str(ku->Nummer,6) ))
	cNummer := upsac->Ups
Endif

cNummer := GetBox(cNummer,t("UPS Kundennummer des Empfängers"),"NNNNNN")

If ! Empty(cNummer)
	If upsac->(dbSeek( Str(ku->Nummer,6) ))
		If cNummer != upsac->UPS .AND. Tr_MsgBox("UPS Kundennummer aktualisieren",,{"Ja","Nein"}) == 1
			upsac->(Rec_Lock())
			upsac->Ups := cNummer
			upsac->(dbUnLock())
		Endif
	Else
		upsac->(Add_Rec())
		upsac->KuNummer := ku->Nummer
		upsac->Ups := cNummer
		upsac->(dbUnLock())
	Endif
Endif
