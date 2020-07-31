LOCAL nYear := Year(Date())
LOCAL dStart := Date()-365*2
LOCAL cKunde := Space(8)
//dEnd := EoY(Date())


Head("Gekaufte Produkte")

NetUse("engkund","ku")
NetUse("englsre","re",.F.,0)

@ 01,00 SAY "Kunde" GET cKunde VALID ku->(Check(cKunde+"K","ku->Name1",1,0))
READ

re->(dbSetOrder(1))

/*Do While ku->Kunde == ku->Kunde .AND. Year(re->Rechdat) < nYear
	re->(dbSkip())
Enddo
If re->Kunde != ku->Kunde .OR. Year(re->Rechdat) != nYear .OR. re->(Eof())
	MsgBox("Keine Artikel gefunden")
	Return
Endif  */

NetUse("engauf","auf",.F.,0)

NetUse("artikel","art",.F.,0)
art->(dbSetOrder(1))

NetUse("artkund","aku",.F.,0)
aku->(dbSetOrder(1))

NetUse("le","le",.F.,0)
NetUSe("le_art","leart",.F.,0)
leart->(dbSetOrder( 2 ))
aArt := {}

StartPrint(,"produkte_kunde_"+HB_OemToAnsi(Trim(ku->Kunde)),"PDF")

oPdf := GetCurrentPrinterObject():Data

oPdf:NewPage("A4","L")
oPdf:SetFont("Helvetica",,10)

oPdf:AtSay("Kunde: "+HB_OemToAnsi(ku->Name1),5)
oPdf:NewLine()
oPdf:AtSay("ab Datum: "+DtoC(dStart))

oPdf:Image(Trim(Tr_Getini(1))+"\images\eklogo_bw.jpg",1,170,'R',3,27)

oPdf:Bold()
oPdf:AtSay("Artikelnr.",10,0)
oPdf:AtSay("Artikelnr. Kunde",,40)
oPdf:AtSay("Bezeichnung",,80)
oPdf:AtSay("Ursprungsland",,150)
oPdf:Normal()

re->(dbSeek( ku->Kunde  ))
Do While ! re->(Eof()) .AND. re->Kunde == ku->Kunde  //.AND. Year(re->Rechdat) >= nYear-1 .AND. Year(re->Rechdat) <= nYear
	If re->Reposnr != 0 .AND. re->Rechdat >= dStart
		If AScan(aArt,re->Matchcode) == 0
		    Aadd(aArt,re->Matchcode)
		Endif
	Endif
	re->(dbSkip())
Enddo

auf->(dbSetOrder( 11 ))
auf->(dbSeek( ku->Kunde ))

Do While ! auf->(Eof()) .AND. auf->Kundma == ku->Kunde  //.AND. Year(auf->Besda) >= nYear-1 .AND. Year(auf->Besda) >= nYear
	If AScan(aArt,auf->Matchcode) == 0 .AND. auf->Besda >= dStart
		Aadd(aArt,auf->Matchcode)
	Endif
	auf->(dbSkip())
Enddo

aPraef := {}
aNonPreaf := {}

ASort(aArt)
nX := 1

Do While nX <= Len(aArt)
	art->(dbSeek( aArt[nX] ))
	If art->Lagerart
		oPdf:NewLine()
		oPdf:AtSay(art->Matchcode,,0)
	    oPdf:AtSay(HB_OemToAnsi(art->Artikel),,80)
	    oPdf:AtSay(HB_OemToAnsi(GetCountryName(art->Ursprung)),,150)
	    If aku->(dbSeek( ku->Kunde+art->Matchcode ))
	    	oPdf:AtSay(aku->Artlief,,20)
	    Endif
		leart->(dbSeek(  Str(art->Artikelnr,6) ))
		lEG := .F.
		Do While leart->Artnr == art->Artikelnr .AND. ! lEG
			le->(dbSeek( Str(le->Nr,6) ))
			If le->Von <= Date() .AND. le->Bis >= Date() //gültig?
				lEG := .T.
			Endif
			leart->(dbSkip())
		Enddo
		oPdf:AtSAy(If(lEG,"ja","nein"),,200)
	Endif
	nX++
Enddo

CopyPrint()