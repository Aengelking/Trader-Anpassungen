NetUse("engabg","abg")
NetUse("artikel","art",.F.,0)
art->(dbSetOrder(1))
art->(dbGoTop())

NetUse("lager","lag",.F.,0)
lag->(dbSetOrder(1))

Head("Artikelbestände an Lagerortbestände angleichen")
IF Tr_Getini(28) != 9
    Alert("Zugang verweigert")
    RETURN
ENDIF
nChoice := Tr_MsgBox("Bestände angleichen?",,{"Nein","Simulation","Ja"})
If nChoice < 2
	Return
Endif
If nChoice == 3 .AND. Tr_MsgBox("Sind Sie sicher?",,{"Nein","Ja"}) != 2
	Return
Endif

BeginJob()
StartPrint(,"BESTANDS_KORREKTUR","PDF")

oPrinter := getCurrentPrinterObject()
oPdf := oPrinter:Data

oPdf:NewPage()
oPdf:SetFont("COURIER")
oPdf:AtSay( "Art.Nr. "+Pad("Matchcode",25)+" "+Pad("Bestand",12)+" "+Pad("Ortbestand",12) )


Do While ! art->(Eof())

	lag->(dbSeek(art->Artikelnr))
	nBestand := 0
	Do While lag->artikelnr == art->artikelnr
		nBestand += lag->Lagermenge
		lag->(dbSkip())
	Enddo

	art->(Rec_Lock(0))
	If art->Bestand != nBestand
		oPdf:NewLine()
		oPdf:AtSay( Str(art->Artikelnr,6)+" "+art->Matchcode+" "+Str(art->Bestand,12,2)+" "+Str(nBestand,12,2) )
		If nChoice != 2
			art->bestand := nBestand
         Bewegung({IF(art->Bestand>nBestand,'ABG','ZUG'),1,Date(),art->Artikelnr,0,0,0,ABS(nBestand-art->bestand),art->Bestand,"Korrektur Lagermenge/Ortmenge",0,Tr_Getini(28)})
		Endif
	Endif
	If nChoice != 2
		art->Inventur := .F.
	Endif
	art->(dbUnLock())

	art->(dbSkip())
Enddo

CopyPrint()
EndJob()