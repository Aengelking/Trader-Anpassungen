PARAMETERS nAngnr,cPDF
lFirst := .T.

aValues := EnquiryAddUp(nAngnr,.T.)

dDate := Date()+7  //allgemein eine Woche
If aValues[2] > 500 //the quote is at least worth 500 EUR
	If DoW(dDate) > 3  //it is wednesday or later
		dDate := Date()+5  //add weekend
	Else
		dDate := Date()+3
	Endif
Endif

While lFirst .OR. LastKey() == 27 .OR. dDate < Date()+1
	dDate := GetBox(dDate,"Wiedervorlage")
	lFirst := .F.
End
aAttach := {}
If ! Empty(cPDF)
	aAttach := {cPDF}
Endif
cText := "Angebot: "+LTrim(Str(nAngNr))+Chr(13)+Chr(10)
cText += "Kunde: "+ku->Name1+Chr(13)+Chr(10)
aContact := GetContact(ang->Person)
cText += "Ansprechpartner: "+aContact["name"]+Chr(13)+Chr(10)
cText += "Telefon: "+aContact["fullphone"]+Chr(13)+Chr(10)
cText += "Wert: "+LTrim(Str(aValues[2],12,2))+Chr(13)+Chr(10)
cText += "Gedruckt am: "+DToC(Date())
AddWiedervorlage(dDate,"Wiedervorlage Angebot "+LTrim(Str(nAngNr))+" "+ku->Name1,cText,"ANG:"+ku->Kunde+Str(nAngNr,6),aAttach)

If aValues[1] > 3000 //Nachricht an Thimo
   SendMail({{"thimo.hamma@engelking.de","Thimo"}},"Interessantes Angebot "+LTrim(Str(nAngNr))+" "+ku->Name1,cText,aAttach)
   
Endif
