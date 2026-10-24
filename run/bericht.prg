#ifndef __XHARBOUR__
	#xtranslate HexToStr([<c,...>])      => HB_HexToStr(<c>)
#endif
FUNCTION RUN_BERICHT(cOut)

   LOCAL lStream := ValType(cOut) == "C"
   LOCAL nPrinter
   LOCAL hTurnover
   LOCAL oPdf
   LOCAL bSchusterJunge
   LOCAL hContacts
   LOCAL nX
   LOCAL hContact
   LOCAL oPrinter
   LOCAL nMaxPayTime,nKSRow,nYear
   LOCAL nFirstYear,nYears
   LOCAL nHeight,nWidth,nBottom,nLeft,nBigest,nCol,nROw,nColu,nBBot,nBTop,nLastLine,nEndLastLine,nPage
   LOCAL aColours,cColour
   LOCAL lQtyOnly,hBought,nQty,lNewLine
   LOCAL hYear,hMonth

   LOCAL aEnv := SaveEnv()

   MEMVAR SYS_LAN

IF ! SystemUser():CheckPermission("READ","ADR_CUSTOMER_REPORT")
   RETURN NIl
ENDIF

NetUse("angebot","ang",.F.,0)
ang->(dbSetOrder(2))
NetUse("engauf","auf",.F.,0)
auf->(dbSetOrder(2))
NetUse("engbew","bew",.F.,0)
NetUse("artikel","art",.F.,0)
NetUse("me","me",.F.,0)
NETUSE("englsre","re",.F.,0)
re->(dbSetOrder(1))
NetUse("notes","nts",.F.,0)
NetUse( "engtext2","tx",.F.,0 )

NetUse("muster","mus",.F.,0)
NetUse("lagerne","lne",.F.,0)

NetUse("viewlog","vlog")

vlog->(Add_Rec(0))
vlog->Nummer := ku->Nummer
vlog->Datum  := Date()
vlog->Time   := Time()
vlog->TimeStamp  := TtoS(DateTime())
vlog->Type   := "B"
vlog->User   := Tr_Getini(28)
vlog->(dbUnLock())



nPrinter := Nil
        /*aData := {}
        cBr := Chr(13)+Chr(10)
        cData := ""
        auf->(dbSeek(ku->Kunde,.T.))
        Do While auf->Kundma == ku->Kunde .AND. ! auf->(Eof())
          //If CalWD(auf->DTerm) >= dAbDat
            Aadd(aData,{auf->Besda,"Auftrag ("+LTrim(Str(auf->AbNr))+"): "+Ltrim(Str(auf->VkQty,11,2))+"("+;
                          LTrim(Str(auf->GelQty,11,2));
                          +") x "+ Trim(auf->Matchcode)+" KW: "+Str(auf->DTerm)})
          //Endif
          auf->(dbSkip())
        Enddo
        ang->(dbSeek(ku->Kunde,.T.))
        Do While ang->Kundma == ku->Kunde
          //If ang->Besda >= dAbDat
            Aadd(aData,{ang->Besda,"Angebot ("+LTrim(Str(ang->AngNr))+"): "+Ltrim(Str(ang->VkQty,11,2))+" x "+ ang->Matchcode})
          //Endif
          ang->(dbSkip())
        Enddo
        bew->(dbSeek( Descend(Str(ku->Nummer)) ))
        Do While bew->Kundennr == ku->Nummer
          //If bew->Datum >= dAbDat
            If bew->Buart $ "BRF FAX"
              Aadd(aData,{bew->Datum,If(bew->Buart=="RNR ","RECHNUNG",;
                        If(bew->BuArt=="BRF ","BRIEF","FAX"))+" "+bew->Beleg })
            Endif
          //Endif
          bew->(dbSkip())
        Enddo

        aData := ASort(aData,,,{|x,y| x[1] > y[1] })
        nLen := Len(aData)
        */

hTurnover := If(ku->Group=="L",GetSupplierTurnOver(ku->Kunde),GetCustomerTurnOver(ku->Kunde))
oPdf := NIL
If ! lStream
	BeginJob()

	StartPrint(@nPrinter,"Adressenbericht_"+ku->kunde,"PDF")
	oPrinter := getCurrentPrinterObject()
	oPdf := oPrinter:Data
Else
	oPdf := Pdf():New(cOut,200,6)
Endif
bSchusterJunge := {|| If(oPdf:ReportLine+3+ oPdf:PDFTop > oPdf:PdfBottom,oPdf:NewPage(),"") } //break if we are 2 lines before the end of the page

//Header Page 1
oPdf:NewPage("A4","P",6)
oPdf:Image(Trim(Tr_Getini(1))+"\images\eklogo_bw.jpg",1,170,'R',3,33)

oPdf:SetFont("Helvetica",,16); oPdf:Bold()
oPdf:AtSay(If(ku->Group=="L","Lieferanten","Kunden")+"bericht",1,0,'R')
oPdf:SetFont("Helvetica",,11); oPdf:Normal()
oPdf:AtSay("vom "+DToC(Date()),1,50,'R')


//Header further pages
/*oPdf:EditOnHeader()
oPdf:AtSay("Kundenbericht "+ku->kunde+" vom "+DToc(Date())+" Seite: #pagenumber#",1,0,'R',,"follow-l1")
oPdf:AtSay("",2,0,'R',,"follow-l2")
oPdf:EditOffHeader()
oPdf:EnableHeader("follow")*/

//when using the header - page 2 is blank!

          //oPdf:Box( 1, 0, 14, 100,1,1,'D')
oPdf:AtSay(HB_OemToAnsi("Matchcode: "+ku->Kunde),2,0,'R')
oPdf:AtSay(If(ku->Group=="L","Lieferanten","Kunden")+"nr.: "+LTrim(Str(ku->Nummer)),2,50,'R')
oPdf:AtSay(HB_OemToAnsi(ku->Name1),4,0,'R')
oPdf:AtSay(HB_OemToAnsi(ku->Name2),5,0,'R')
oPdf:AtSay(HB_OemToAnsi(ku->Street),6,0,'R')
oPdf:AtSay(ku->PLZ+" "+HB_OemToAnsi(ku->Town),7,0,'R')
oPdf:AtSay(HB_OemToAnsi(GetCountryName(ku->CountryIso)),8,0,'R')

oPdf:AtSay("Telefon",4,100,'R'); oPdf:AtSay(ku->Telefon,4,120,'R')
oPdf:AtSay("Fax",5,100,'R'); oPdf:AtSay(ku->Telefax,5,120,'R')
oPdf:AtSay("E-Mail",6,100,'R'); oPdf:AtSay(ku->email,6,120,'R')

//oPdf:AtSay("Branche: "+ku->Branch,11,0,'R')
//oPdf:AtSay("Zuletzt erfasst am: "+DToC(ku->Date),14,0,'R')

		  //oPdf:AtSay("Vertretergebiet:"
NETUSE("skontoa","sk",.F.,0)
sk->(DBGOTO(ku->skonto+1))
oPdf:AtSay(skont(,,sk->ziel1,sk->ziel2,sk->ziel3,sk->rate1,sk->rate2,sk->rate3,sys_lan,.F.),8,100)
nMaxPayTime := Max(Max(sk->ziel1,sk->ziel2),sk->ziel3)

oPdf:NewLine(2)
oPdf:Bold()
oPdf:AtSay("Kontaktpersonen",,0,'R')
oPdf:Normal()
oPdf:NewLine()
oPdf:AtSay("Person",,0,'R');oPdf:AtSay("Abteilung",,60,'R');oPdf:AtSay("Telefon",,100,'R');oPdf:AtSay("E-Mail",,140,'R')

hContacts := GetAddressContacts(.F.,.T.)

nX := 1
/*Do While nX <= 5
	cPerson := &("ku->Person"+If(nX>1,Str(nX,1),""))
	If ! Empty(cPerson)
		oPdf:NewLine()
		oPdf:AtSay(HB_OemToAnsi(cPerson),,0,'R')
		oPdf:AtSay(HB_OemToAnsi(&("ku->Abteil"+Str(nX,1))),,60,'R')
		oPdf:AtSay(HB_OemToAnsi(&("ku->Telefon"+Str(nX,1))),,100,'R')
	Endif
	nX++
Enddo*/
Do While nX <= Len(hContacts)
	hContact := HGetValueAt(hContacts,nX)
	oPdf:NewLine()
	oPdf:AtSay(HB_OemToAnsi(oPdf:Pad(hContact["name"],55)),,0,'R')
	oPdf:AtSay(HB_OemToAnsi(oPdf:Pad(hContact["department"],35)),,60,'R')
	oPdf:AtSay(HB_OemToAnsi(hContact["email"]),,140,'R')
	If Empty(hContact["telephone"])
		oPdf:AtSay(HB_OemToAnsi(oPdf:Pad(hContact["mobile"],35)),,100,'R')
	Else
		oPdf:AtSay(HB_OemToAnsi(oPdf:Pad(hContact["telephone"],35)),,100,'R')
		If ! Empty(hContact["mobile"])
			oPdf:NewLine()
			oPdf:AtSay(HB_OemToAnsi(hContact["mobile"]),,100,'R')
		Endif
	Endif
	nX++
Enddo


//oPdf:SetFont("Helvetica",,14);
oPdf:NewLine(2)
oPdf:Bold()
oPdf:AtSay("Umsatz",,0,'R')
//oPdf:SetFont("Helvetica",,11);
oPdf:NewLine(1)
oPdf:Normal()
nKSRow := oPdf:ReportLine
oPdf:AtSay("Aktuell ",,0,'R'); oPdf:AtSay(LTrim(Str(hTurnover["current"],12,2)),,20,'R')
oPdf:AtSay("Letzten 3-Jahre: ",,50,'R'); oPdf:AtSay(LTrim(Str(hTurnover["last3"],12,2)),,90,'R')

oPdf:NewLine()
oPdf:AtSay("Vorjahr ",,0,'R'); oPdf:AtSAy(LTrim(Str(hTurnover["last"],12,2)),,20,'R')
oPdf:AtSay("Gesamt ",,50,'R'); oPdf:AtSay(LTrim(Str(hTurnover["total"],12,2)),,90,'R')

auf->(dbSetOrder(9))
auf->(dbSeek(ku->Kunde,.T.))
If auf->Kundma == ku->Kunde
	nRow := oPdf:ReportLine
	oPdf:AtSay("Kunde seit: "+DToC(auf->Besda),nKSRow,130)
	oPdf:ReportLine := nRow
Endif

IF ku->Group == "L"
   hTurnover["years"] := {=>}

   FOR EACH hYear IN hTurnover["months"]
      nYear := hYear:__eNumKey()
      FOR EACH hMonth IN hYear
         IF ! HHasKey(hTurnover["years"],nYear)
            hTurnover["years"][nYear] := 0
         ENDIF
         hTurnover["years"][nYear] += hMonth["billings"]
      NEXT
   NEXT
   Alert(hTurnover["years"])
ENDIF
ASort(hTurnover["years"])
nBigest := 0

nLeft := 30
nBottom := oPdf:PageY-oPdf:R2D(oPdf:REPORTLINE+2)
nWidth := 250
nHeight := 100

If Len(hTurnover["years"]) > 0
	nFirstYear := Year(Date())-9 //HGetKeyAt(hTurnover["years"],1)
	//nYears := Max(HGetKeyAt(hTurnover["years"],Len(hTurnover["years"]))-nFirstYear+1,10)
   nYears := 10 //HGetKeyAt(hTurnover["years"],Len(hTurnover["years"]))-nFirstYear+1
   

	nX := 1
	Do While nX <= Len(hTurnover["years"])
		nBigest := Max(HGetValueAt(hTurnover["years"],nX),nBigest)
		nX++
	Enddo

	If nBottom+nHeight > oPdf:PageY
		nBottom := 0
		oPdf:NewPage()
	Endif
	
	aColours := {"9F0000","FF591F","FFA07F","FF7A0F","FFBE0F","FFE900","B5FF00","40BF00","7FFF9C","7FFFC0","00AF59","00AF8B","00AFAB","0071AF","0040AF","0F008F","8147BF","A347BF","BF47BC","CF0090","CF0069","AF0028"}
	
	//oPdf:Box( nBottom, nLeft, nBottom+nHeight, nLeft+nWidth,2,0,'D')
	
	nX := 1
	nCol := 1
	nRow := nBottom+10
	nColu := nLeft+nwidth+10
	Do While nX <= nYears //Len(hTurnover["years"])
		If HHasKey(hTurnover["years"],nFirstYear+nX-1)
			cColour := HexToStr(aColours[nCol])
			nCol++
			If nCol > Len(aColours)
				nCol := 1
			Endif
			oPdf:AtSay(Chr(253)+cColour+Str(nFirstYear+nX-1,4)+": "+Ltrim(Str(hTurnover["years"][nFirstYear+nX-1],12,2)),oPdf:PageY-nRow,nColu,'D')
			nRow += 12
			If nRow >= nBottom+nHeight
				nRow := nBottom+10
				nColu += 100
			Endif
	
	        nBBot := nBottom+nHeight  // -nWidth/nBigest*HGetValueAt(hTurnover["years"],nX)
			nBTop := nBBot - (nHeight/Max(nBigest,0.0000001))*hTurnover["years"][nFirstYear+nX-1]
			oPdf:Box1(nBBot,nLeft+(nwidth/(nYears*2))*(nX*2-1.5),nBTop,nLeft+(nwidth/(nYears*2))*(nX*2-.5),0,cColour,cColour)
		Endif
		nX++
	Enddo
Endif
oPdf:REPORTLINE := oPdf:PDFBOTTOM-oPdf:D2R(nBottom+nHeight)             // nBottom+nHeight
oPdf:AtSAy(Chr(253)+HexToStr("000000")) //black

If ku->Group == "K"
oPdf:NewLine(2)
oPdf:Bold()
oPdf:AtSay("Offene Posten",,0,'R')
oPdf:Normal()

oPdf:NewLine()
oPdf:AtSAy("Datum",,0)
oPdf:AtSAy("Rechnung",,20)
oPdf:RJust("Offen",,70)
oPdf:RJust("Fällig",,90)
oPdf:RJust("Mahnung",,110)
oPdf:RJust("St",,118)
oPdf:RJust("Frist",,138)


re->(dbSetOrder(1))
re->(dbSeek(ku->Kunde+"0",.T.))

Do While re->Kunde == ku->Kunde .AND. ! re->(Eof())
	If re->reposnr == 0 .AND. re->status == 0 .AND. re->code == 2 .AND. re->packed
		If Date() >= re->rechdat+sk->(GetSkontoWait(re->Skonto,re->Rechdat)) //nMaxPayTime
			oPdf:AtSay(Chr(253)+HexToStr("FF0000"))
		Endif
		oPdf:NewLine()
		oPdf:AtSAy(DToC(re->rechdat),,0)
		oPdf:AtSAy(Ltrim(STR(re->rechnr,6)),,20)
		oPdf:AtSay(Currate(re->money,"X"),,40)
		oPdf:RJust(Str((re->poswt-re->aoqty),12,2),,70)
		oPdf:RJust(DToC(re->rechdat+sk->(GetSkontoWait(re->skonto,re->rechdat))),,90)
		oPdf:RJust(DToC(re->MaDate),,110)
		oPdf:RJust(Str(re->rem),,118)
		oPdf:RJust(DToc(re->NextMa),,138)
		oPdf:AtSay(Chr(253)+HexToStr("000000"))
	Endif
	re->(dbSkip())
Enddo

oPdf:NewLine(2)
oPdf:Bold()
oPdf:AtSay("Jahresrückblick Rechnungen",,0,'R')
oPdf:Normal()

oPdf:NewLine()
oPdf:AtSAy("Datum",,0)
oPdf:AtSAy("Rechnung",,20)
oPdf:RJust("Wert",,70)
oPdf:RJust("Fällig",,90)
oPdf:RJust("Zahldat.",,110)
oPdf:RJust("Mahnung",,130)
oPdf:RJust("St",,138)
oPdf:RJust("Frist",,158)


re->(dbSetOrder(1))
re->(dbSeek(ku->Kunde+"0",.T.))

Do While re->Kunde == ku->Kunde .AND. ! re->(Eof())
	If re->Rechdat >= Date()-365 .AND. re->reposnr == 0 .AND. re->code == 3 //.AND. re->packed
		If Date() >= re->rechdat+nMaxPayTime
			//oPdf:AtSay(Chr(253)+HexToStr("FF0000"))
		Endif
		oPdf:NewLine()
		oPdf:AtSAy(DToC(re->rechdat),,0)
		oPdf:AtSAy(Ltrim(STR(re->rechnr,6)),,20)
		oPdf:AtSay(Currate(re->money,"X"),,40)
		oPdf:RJust(Str((re->poswt),12,2),,70)
		oPdf:RJust(DToC(re->rechdat+sk->(GetSkontoWait(re->skonto,re->rechdat))),,90)
        oPdf:RJust(DToC(re->PayDate),,110)
		oPdf:RJust(DToC(re->MaDate),,130)
		oPdf:RJust(Str(re->rem),,138)
		oPdf:RJust(DToc(re->NextMa),,158)
		//oPdf:AtSay(Chr(253)+HexToStr("000000"))
	Endif
	re->(dbSkip())
Enddo


oPdf:NewLine(2)
Eval(bSchusterJunge)

oPdf:Bold()
//oPdf:AtSay(Chr(253)+HexToStr("000000")+"XXXXXXXX",nBottom,0,'D')
oPdf:AtSay("Aktuelle Angebote",,0,'R')
oPdf:Normal()
oPdf:NewLine()
//oPdf:SetFont("Helvetica",,9);

oPdf:AtSay("Datum",,0)
oPdf:AtSay("Nr.",,20)
oPdf:AtSay("Artikel",,35)
oPdf:RJust("Menge",,123)
oPdf:RJust("Preis",,158)
oPdf:AtSAy("PE",,163)
oPdf:RJust("Gesamt",,oPdf:ReportWidth)


ang->(dbSetOrder(7)) //kundma+Str(angnr)+Str(itmnr)
art->(dbSetOrder(1)) //matchcode
ang->(dbSeek(ku->Kunde,.T.))
nLastLine := oPdf:ReportLine()
nEndLastLine := oPdf:ReportLine()
nPage := oPdf:ReportPage
Do While ang->Kundma == ku->Kunde
	If ( (ang->vkpr != 0 .OR. ang->vkqty != 0) .AND. ang->bestat < 3 .AND. ang->Besda >= Date()-365*2)
		art->(dbSeek(ang->matchcode))

		lQtyOnly := (ang->vkqty > 0 .OR. ang->vkpr > 0) .AND. (!art->prmatch .AND. empty(ang->artikel))

		If oPdf:ReportPage == nPage
			oPdf:ReportLine := If(lQtyOnly,nLastLine,nEndLastLine)
		Endif

		oPdf:NewLine()

		If ! lQtyOnly
			nLastLine := oPdf:ReportLine
			oPdf:AtSay(DToC(ang->Besda),,0)
			oPdf:AtSay(LTrim(Str(ang->AngNr,6)),,20)
			oPdf:AtSay(HB_OemToAnsi(If(art->prmatch,ang->Matchcode,ang->artikel)),,35)
		Endif
		oPdf:RJust(Ltrim(Transform(ang->VkQty,Me(art->me))),,123)
		oPdf:AtSAy(art->me,,125)
		oPdf:RJust(Ltrim(Str(ang->vkpr,11,2)),,158)
		oPdf:AtSAy(Ltrim(Str(ang->pe,3)),,163)
		oPdf:RJust(Ltrim(Str(ang->vkqty*ang->vkpr/ang->pe,14,2)),,oPdf:ReportWidth)

		If ( art->prmatch )
			oPdf:SetFont("Helvetica",,8)
			oPdf:NewLine()
			oPdf:AtSay(HB_OemToAnsi(ang->artikel),,35)
			oPdf:SetFont("Helvetica",,11)
		Endif
		nEndLastLine := Max(oPdf:ReportLine,nEndLastLine)
		If lQtyOnly
			nLastLine := oPdf:ReportLine
			nPage := oPdf:ReportPage
		Endif
	Endif


    ang->(dbSkip())
Enddo

mus->(dbSetOrder( 5 )) //kunde+Str(Status)
mus->(dbSeek( ku->Kunde ))

lne->(dbSetOrder( 3 )) //pos+nummer
art->(dbSetOrder( 1 ))

oPdf:NewLine(2)
Eval(bSchusterJunge)
oPdf:Bold()
oPdf:AtSay("Rückblick Muster",,0,'R')

oPdf:NewLine()
oPdf:Normal()
oPdf:AtSay("Datum")
oPdf:AtSay("Lief.dat.",,20)
oPdf:AtSay("Artikel",,50)
oPdf:RJust("Menge",,122)

Do While mus->Kunde == ku->Kunde
	art->(dbSeek(mus->matchcode))

	oPdf:NewLine()
	oPdf:AtSay( DToC(mus->Datum) )
	If lne->(dbSeek( Str(mus->pos,3)+Str(mus->nummer,6) ))
		oPdf:AtSay( DToC(lne->Datum),,20 )
	Endif
	oPdf:AtSay( mus->Matchcode,,50 )
	oPdf:RJust(Ltrim(Transform(mus->Menge,Me(art->me))),,122)

	oPdf:NewLine()
	oPdf:SetFont("Helvetica",,8)
	oPdf:AtSay( HB_OemToAnsi(art->Artikel),,50 )
	oPdf:SetFont("Helvetica",,11)


	mus->(dbSkip())
Enddo



oPdf:NewLine(2)
Eval(bSchusterJunge)
oPdf:Bold()
oPdf:AtSay("Jahresrückblick Aufträge",,0,'R')

auf->(dbSetOrder(2))
auf->(dbSeek(ku->Kunde,.T.))
oPdf:Normal()
oPdf:NewLine()
oPdf:AtSay("Datum")
oPdf:AtSay("Nr.",,20)
oPdf:RJust("Menge",,50)
oPdf:RJust("Geliefert",,70)
oPdf:AtSay("Artikel",,72)
oPdf:AtSay("Termin",,145)
oPdf:AtSay("Wunsch",,160)
oPdf:RJust("Preis",,190)
oPdf:RJust("PE",,200) //"PE"

hBought := {=>}

auf->(dbSetFilter({|| ! Trim(auf->Matchcode) $ "PORTO PORTOPAUSCHALE FRAIGHT" .AND. auf->FolgeTo == 0 },'! Trim(Matchcode) $ "PORTO PORTOPAUSCHALE FRAIGHT" .AND. FolgeTo == 0'))
//auf->(SET FILTER TO ! Trim(Matchcode) $ "PORTO PORTOPAUSCHALE FRAIGHT" .AND. FolgeTo == 0)

Do While auf->Kundma == ku->Kunde .AND. ! auf->(Eof())
	If ! Trim(auf->Matchcode) $ "PORTO PORTOPAUSCHALE FRAIGHT"
	    If auf->besda >= Date()-365
			oPdf:NewLine()
			art->(dbSetOrder( 1 ))
			art->(dbSeek(auf->matchcode))
			
			oPdf:AtSay(DToC(auf->Besda))
			oPdf:AtSay(LTrim(Str(auf->AbNr)),,18)
			oPdf:RJust(Ltrim(Transform(auf->VkQty,Me(art->me))),,50)
			oPdf:RJust(LTrim(Transform(auf->GelQty,Me(art->me))),,70)
			If At("@",auf->Matchcode) == 1
				oPdf:AtSay(HB_OemToAnsi(Pad(TextSho(auf->Text,0,0,"tx",1),25)),,72)
			Else
				oPdf:AtSay(HB_OemToAnsi(auf->Matchcode),,72)
			Endif
			If CalWd(auf->DTerm) <= Date() .AND. auf->vkqty > auf->gelqty .AND. auf->bestat < 3
				oPdf:AtSay(Chr(253)+HexToStr("FF0000"))
			Endif
			oPdf:AtSay(If(Right(Str(auf->dterm,4),2)=="99","Abruf",StrZero(auf->Dterm,4)),,145)
			oPdf:AtSay(Chr(253)+HexToStr("000000"))
			oPdf:AtSay(If(Right(Str(auf->dterm,4),2)=="99","Abruf",StrZero(auf->Wterm,4)),,160)


			oPdf:RJust(LTrim(Str(auf->vkpr,11,2)),,190)
			oPdf:Rjust(LTrim(Str(auf->pe,4)),,200)

			oPdf:NewLine()
			oPdf:SetFont("Helvetica",,8)
			oPdf:AtSay( HB_OemToAnsi(art->Artikel),,72 )
			oPdf:SetFont("Helvetica",,11)

	    Endif
		If ! HHasKey(hBought,auf->matchcode)
			hBought[auf->matchcode] := {"total"=>0,"years"=>{0,0,0,0}}
		Endif
		nQty := If(auf->bestat<3,Max(auf->VkQty,auf->GelQty),auf->GelQty)
		hBought[auf->matchcode]["total"] +=  nQty
		nX := 1
		Do While nX <= 4
			If (auf->Wterm != 0 .AND. CalWd(auf->WTerm) >= Date()-365*(nX)-1 .AND. CalWd(auf->Wterm) <= Date()-365*(nX-1)) .OR.;
				 (auf->Wterm == 0 .AND. CalWd(auf->DTerm) >= Date()-365*(nX)-1 .AND. CalWd(auf->Dterm) <= Date()-365*(nX-1)) //Aufträge mit Wunschtermin innerhalb der letzten 365 Tage
				hBought[auf->matchcode]["years"][nX] +=  nQty
			Endif
			nX++
		Enddo
	Endif
    auf->(dbSkip())
Enddo



ASort(hBought)

oPdf:NewLine(2)
Eval(bSchusterJunge)
oPdf:Bold()
oPdf:AtSay("Bisher gekaufte Artikel",,0,'R')
oPdf:Normal()

oPdf:NewLine()
oPdf:AtSay("Artikel")
oPdf:RJust("Gesamt",,90)
oPdf:RJust(DToC(Date()-365*1),,115)
oPdf:RJust(DToC(Date()-365*2),,140)
oPdf:RJust(DToC(Date()-365*3),,165)
oPdf:RJust(DToC(Date()-365*4),,190)
oPdf:NewLine()
oPdf:RJust("-"+DToC(Date()-365*0-1),,115)
oPdf:RJust("-"+DToC(Date()-365*1-1),,140)
oPdf:RJust("-"+DToC(Date()-365*2-1),,165)
oPdf:RJust("-"+DToC(Date()-365*3-1),,190)

nX := 1
Do While nX <= Len(hBought)
	oPdf:NewLine()
	art->(dbSeek(HGetKeyAt(hBought,nX)))
	oPdf:AtSay(HGetKeyAt(hBought,nX))
	oPdf:RJust(Transform(HGetValueAt(hBought,nX)["total"],Me(art->me)),,90)
	oPdf:RJust(Transform(HGetValueAt(hBought,nX)["years"][1],Me(art->me)),,115)
	oPdf:RJust(Transform(HGetValueAt(hBought,nX)["years"][2],Me(art->me)),,140)
	oPdf:RJust(Transform(HGetValueAt(hBought,nX)["years"][3],Me(art->me)),,165)
	oPdf:RJust(Transform(HGetValueAt(hBought,nX)["years"][4],Me(art->me)),,190)
	oPdf:AtSay(art->me,,195)
	
	oPdf:NewLine()
	oPdf:SetFont("Helvetica",,8)
	oPdf:AtSay( HB_OemToAnsi(art->Artikel) )
	oPdf:SetFont("Helvetica",,11)

	nX++
Enddo

//oPdf:NewPage("A4","P",6)
//oPdf:NewPage("A4","P",6)
Endif

oPdf:NewLine(2)
Eval(bSchusterJunge)
oPdf:Bold()
oPdf:AtSay("Notizen",,0)
oPdf:Normal()

nts->(dbSeek(ku->Kunde+ku->Group,.T.))
Do While nts->Matchcode == ku->Kunde .AND. nts->Group == ku->Group .AND. ! nts->(Eof())
	lNewLine := .F.
	oPdf:NewLine()
	oPdf:AtSay(DToC(nts->Date)+" "+Left(nts->Time,5))
	oPdf:ReportCol := 30
	If ! Empty(nts->Type)
		oPdf:AtSay(HB_OemToAnsi(Trim(NoteType(nts->Type))))
		oPdf:ReportCol += 3
		lNewLine := .T.
	Endif
	If nts->Buyer != 0
		oPdf:ReportCol++
		oPdf:AtSay("von: "+Trim(Buy(nts->Buyer,.T.)))
		oPdf:ReportCol += 2
		lNewLine := .T.
	Endif
	If nts->Person != 0
		oPdf:ReportCol++
		oPdf:AtSay(IF(nts->Type=="VISIT","bei: ","mit: ")+Trim(PERSAY(nts->Person,.T.)))
		oPdf:ReportCol += 2
		lNewLine := .T.
	Endif
	nX := 1
	Do While nX <= MlCount(nts->Note)
		If lNewLine
			oPdf:NewLine()
		Endif
		oPdf:AtSay(HB_OemToAnsi(MemoLine(nts->Note,,nX)),,30)
		nX++
		lNewLine := .T.
	Enddo
	nts->(dbSkip())
Enddo


/*          ?
          ? "Info:"
          ? InfTran(ku->Info)
          ?

          nX := 1
          nP := 22
          Do While nX <= nLen
            oPdf:AtSay(HB_OemToAnsi(DToC(aData[nX,1])+" "+Trim(aData[nX,2])),nP,0)
            nX := nX+1
            nP++
            If nP > 65
            	oPdf:NewPage("A4","P",6)
            	nP := 1
            Endif
          Enddo  */


/*cSQL := ""

FOR EACH hContact IN hContacts
	IF ! Empty(hContact["email"])
      IF ! Empty(cSQL)
         cSQL += " OR "
      ENDIF
      cSQL += "srFrom LIKE '"+Trim(hContact["email"])+"'"
   ENDIF
NEXT

cSQL := "SELECT * FROM dbo.msg WHERE "+cSQL+" ORDER BY srStatusTime DESC"


oPdf:NewLine(2)
Eval(bSchusterJunge)
oPdf:Bold()
oPdf:AtSay("Letzten Emails",,0)
oPdf:Normal()

oPdf:NewLine()
oPdf:AtSay(cSQL,,0)

oDB := TODBC():New( "David","sa","0gakemur54")
SQLError( oDB:hEnv, oDB:hDbc, oDB:hStmt, @cErrorClass, @nType, @cErrorMsg )
IF ! Empty(cErrorclass) .AND. cErrorClass != "00000" .AND.  cErrorClass != "01000"
	Alert("Fehler bei der Verbindung zur Datenbank. Error " + cErrorClass + " - " + cErrorMsg)
	RETURN .F.
ENDIF

oDB:SetSQL(cSQL)
IF ! oDB:Open()
   SQLError( oDB:hEnv, oDB:hDbc, oDB:hStmt, @cErrorClass, @nType, @cErrorMsg )
   Alert("Error " + cErrorClass + " - " + cErrorMsg)
ELSE
   FOR nX := 1 TO oDB:RecCount()
      oDB:LoadData(nX)

      oPdf:NewLine()
      oPdf:AtSay(SecToTime(oDB:FieldByName("srStatusTime"):Value)+" "+oDB:FieldByName("srFrom"):Value+" "+oDB:FieldByName("srTo"):Value)
      oPdf:NewLine()
      oPdf:AtSay(oDB:FieldByName("srSubject"):Value)
      oPdf:NewLine()
   NEXT
ENDIF */



If ! lStream
	SET PRINTER OFF
	CopyPrint()
	EndJob()
Else
	oPdf:Close()
Endif




RestEnv(aEnv)