LOCAL dAb := AddMonth(Date(),-1)
LOCAL nValue := 50
LOCAL nBuy := 0
LOCAL getlist := {}

Head("Auswertung Angebote")

@ 01,00 SAY "Mitarbeiter" GET nBuy PICTURE "99"
ATail(getlist):postBlock := {||
   IF nBuy == 0
      @ 01,15 SAY Pad("Alle",50)
      RETURN .T.
   ENDIF
   RETURN Buy(nBuy,.F.)
}
@ 01,15 SAY "0=Alle"

@ 02,00 SAY "Ab Datum   " GET dAb VALID dAb < Date()
@ 03,00 SAY "Ab Wert    " GET nValue PICTURE "99999" VALID nValue >= 0
READ
IF LastKey() == 27
   RETURN
ENDIF


NetUse("angebot","ang")
NetUse("buyer","buy")
NetUse("notes","nts")
NetUse("artikel","art")
NetUSe("engauf","auf")

nts->(dbSetOrder( 3 )) //betreff+Str(nummer)
auf->(dbSetOrder( 6 ))

bPrintMemo := {||
	oPdf:NewLine()
	oPdf:AtSay(Space(7)+DToC(nts->Date))
	For nY := 2 To MlCount(nts->Note,55)
		If nY > 2
			oPdf:NewLine()
		Endif
		oPdf:AtSay(Space(If(nY>2,24,9))+HB_OemToAnsi(MemoLine(nts->Note,55,nY)))
	Next
}

bEnquiryBought := {|nAngnr|
	Local nRec := ang->(dbPush())
	Local lBought := .F.
	ang->(dbSetOrder( 1 ))
	ang->(dbSeek( Str(nAngnr,6) ))
	@ 24,00 SAY nAngnr
	auf->(dbSetFilter({|| auf->Besda >= ang->Besda },"Besda >= StoD('"+DtoS(ang->Besda)+"')"))
	Do While ang->Angnr == nAngnr
		art->( dbSeek( STR( ang->Artikelnr, 6 ) ) )
		If auf->(dbSeek( ang->Kundma+ang->Matchcode ))
			nQty := 0
			nAb := 0
			Do While ! auf->(Eof()) .AND. auf->Kundma == ang->Kundma .AND. auf->Matchcode == ang->Matchcode //Eval(bWhile) //.AND. ! Eval(bFind)
				//If auf->Besda >= ang->Besda //Eval(bFind)
					lBought := .T.
					Exit
				//Endif
				auf->(dbSkip())
			Enddo
		Endif
		ang->(dbSkip())
	Enddo
	auf->(dbClearFilter())

	ang->(dbPop())
	Return lBought
}

//StartPrint(,,"PDF")
//oPdf := GetCurrentPrinterObject():Data
cFile := Trim(Tr_Getini(1))+"\pdf\angebote_analyse.pdf"
If File(cFile)
	DELETE FILE cFile
Endif
oPdf := PDF():New(cFile)
oPdf:NewPage()
oPdf:SetFont("COURIER",1,14)
oPdf:AtSay("ANGEBOTE ab dem "+DToC(dAb))
oPdf:SetFont("COURIER",1,12)
oPdf:NewLine(2)
oPdf:AtSay("Nicht bestellt und nicht kontaktiert")
oPdf:Normal()
oPdf:NewLine()
oPdf:AtSay(Pad("Nr.",6)+" "+Pad("Datum",8)+" "+Pad("Anruf bis",8)+" "+Pad("Wert",7)+" "+"Einkäufer")
aAng := {}
aNotes := {}

ang->(dbSetFilter({|| ang->Bestat >= 1 .AND. ang->Besda >= dAb .AND. (nBuy == 0 .OR. ang->Buyer == nBuy) },"Bestat >= 1 .AND. Besda >= StoD('"+DtoS(dAb)+"')"+IF(nBuy!=0," .AND. Buyer=="+LTrIm(Str(nBuy)),"") ))
//ang->(dbSetOrder( 4 )) //str(bestat,1)+kundma
//ang->(dbSeek( Str(1,1) ))
ang->(dbSetOrder( 1 ))
ang->(dbGoTop())
Do While ! ang->(Eof())
	IF AScan(aAng,ang->Angnr) == 0 .AND. ! Eval(bEnquiryBought,ang->angnr)
		aValues := EnquiryAddUp(ang->Angnr,.T.)
		IF aValues[2] > nValue
   		If ! nts->(dbSeek( "ANG"+Str(ang->Angnr,6) ))
            dDate := ang->Besda+7  //allgemein eine Woche
   			If aValues[2] > 500 //the quote is at least worth 500 EUR
   				If DoW(dDate) > 3  //it is wednesday or later
   					dDate := ang->Besda+5  //add weekend
   				Else
   					dDate := ang->Besda+3
   				Endif
   			Endif
   			If dDate < Date()
   				oPdf:NewLine()
   				oPdf:AtSay( Str(ang->Angnr)+" "+DToC(ang->Besda)+" "+DToC(dDate)+" "+Str(aValues[2],7)+" "+Trim(Buy(ang->Buyer,.T.)) )
   			Endif
   		Else
   			Aadd(aNotes,{ang->Angnr,ang->Besda,aValues[2],Trim(Buy(ang->Buyer,.T.))})
   		Endif
   	ENDIF
		Aadd(aAng,ang->Angnr)
	ENDIF
	ang->(dbSkip())
Enddo     

oPdf:NewLine(2)
oPdf:Bold()
oPdf:AtSay("Nicht bestellt und erledigt")
oPdf:Normal()
oPdf:NewLine()
oPdf:AtSay(Pad("Nr.",6)+" "+Pad("Datum",8)+" "+Pad("Wert",7)+" "+"Einkäufer")
Do While ! ang->(Eof())
	If AScan(aAng,ang->Angnr) == 0 .AND. ! Eval(bEnquiryBought,ang->angnr)
		aValues := EnquiryAddUp(ang->Angnr,.F.)
//		? ang->Angnr,ang->Besda,dDate,aValues[1],Trim(Buy(ang->Buyer,.T.))
		oPdf:NewLine()
		oPdf:AtSay(Str(ang->Angnr)+" "+DToC(ang->Besda)+" "+Str(aValues[2],7)+" "+Trim(Buy(ang->Buyer,.T.)))
		nts->(dbSeek( "ANG"+Str(ang->Angnr,6) ))
		Do While nts->Betreff == "ANG" .AND. nts->Nummer == ang->Angnr
			Eval(bPrintMemo)
                	nts->(dbSkip())
                Enddo

		Aadd(aAng,ang->Angnr)
	Endif
	ang->(dbSkip())
Enddo
ang->(dbClearFilter())

oPdf:NewLine(2)
oPdf:Bold()
oPdf:AtSay("Nicht bestellt und offen")
oPdf:Normal()
oPdf:NewLine()
oPdf:AtSay(Pad("Nr.",6)+" "+Pad("Datum",8)+" "+Pad("Wert",7)+" "+"Einkäufer")
For nX := 1 To Len(aNotes)
	oPdf:NewLine()
	oPdf:AtSay(Str(aNotes[nX,1])+" "+DToC(aNotes[nX,2])+" "+Str(aNotes[nX,3],7)+" "+aNotes[nX,4])
	nts->(dbSeek( "ANG"+Str(aNotes[nX,1],6) ))
	Do While nts->Betreff == "ANG" .AND. nts->Nummer == aNotes[nX,1]
		Eval(bPrintMemo)
		nts->(dbSkip())
	Enddo
Next
oPdf:Close()
Wapi_ShellExecute(NIL,"open",cFile)
//SendMail({{"amos.engelking@engelking.de","Amos"}},"Angebots Analyse","Siehe Anhang",{cFile})
//Inkey(0,128)
//CopyPrint()


