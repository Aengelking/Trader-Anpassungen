PROC RUN_VDA4902(nBelegNr,cAblade,lKLT,nNr,lMisch,nQty,nPackCount,nPackNum,cPackNum2)

//#translate PDF_LINE(<width>) => oPdf:Box(oPdf:R2M(oPdf:Reportline),oPdf:X2M(oPdf:C2X(oPdf:ReportCol)),oPdf:R2M(oPdf:ReportLine)+oPdf:FontSize*0.1,oPdf:X2M(oPdf:C2X(oPdf:ReportCol))+<width>,0,100,"M")
#translate PDF_LINE(<y>,<x>,<width>) => oPdf:Box(<y>,<x>,<y>+0.3,<x>+<width>,0,100,"M")
#translate PDF_VLINE(<y>,<x>,<height>) => oPdf:Box(<y>,<x>,<y>+<height>,<x>+0.3,0,100,"M")
#translate @ <y>,<x> BARCODE TEXT <text> => oPdf:ReportLine := oPdf:M2R(<y>);oPdf:ReportCol  := oPdf:M2C(<x>-oPdf:PDFLEFT);MBaseRun(Trim(Tr_Getini(1))+"\run\barcode",{oPrinter,"C128",AllTrim(<text>),If(lKLT,12,33)})

If ValType(lKLT) != "L"
	lKLT := .F.
Endif
If ValType(lMisch) != "L"
	lMisch := .F.
Endif

oPrinter := GetCurrentPrinterObject()
oPdf := oPrinter:Data

//oPdf:PDFLEFT := 0

nT := 0 //top of sticker

If lKLT .AND. ValType(nNr) == "N" .AND. nNr%2 == 0
	nT := 69 //place every second small sticker at bottom of page
Else
	oPdf:NewPage()
	//if we want A5
	//oPdf:PageX := 8.27*72
	//oPdf:PageY := 5.83*72
Endif

//draw all the lines
If ! lKLT
	oPdf:Box(nT+5,5,143,205,0.3)
	//horizontal
	PDF_LINE(nT+If(lKLT,19,24),6,198)
	PDF_LINE(36,100,104)
	PDF_LINE(49,5,200)
	PDF_LINE(78,6,198)
	PDF_LINE(124,6,198)
	PDF_LINE(88,100,104)

	//vertikal
	PDF_VLINE(6,99,17)
	PDF_VLINE(25,99,23)


	PDF_VLINE(38,133,10)
	PDF_VLINE(38,168,10)

	PDF_VLINE(79,99,44)
Else
	oPdf:Box(nT+5,5,nT+74,205,0.3)
	//horizontal
	PDF_LINE(nT+19,6,198)
	PDF_LINE(nT+32,6,198)
	PDF_LINE(nT+46,6,100)
	PDF_LINE(nT+60,6,198)
	PDF_LINE(nT+40,106.5,98)
	PDF_LINE(nT+52,106.5,98)

	PDF_VLINE(nT+6,57,12)
	PDF_VLINE(nT+6,122,12)
	PDF_VLINE(nT+32,106,41)
Endif

//print text
oPdf:SetFont("HELVETICA",1,6)
oPdf:AtSay("(1) Warenempänger",nT+8,7,"M")
oPdf:AtSay("(2) Abladestelle - Lagerort - Verwendungsschlüssel",nT+8,If(lKLT,60,101),"M")
oPdf:AtSay("(3) Lieferschein-Nr (N)",If(lKLT,nT+8,27),If(lKLT,125,7),"M")
If ! lKLT
	oPdf:AtSay("(4) Lieferantenanschrift",27,101,"M")
	oPdf:AtSay("(5) Gewicht netto",39,101,"M")
	oPdf:AtSay("(6) Gewicht brutto",39,135,"M")
	oPdf:AtSay("(7) Anzahl Packstücke",39,170,"M")
Endif
oPdf:AtSay("(8) Sach-Nr. Kunde",If(lKLT,nT+22,52),7,"M")
oPdf:AtSay("(9) Füllmenge",If(lKLT,nT+35,81),7,"M")
oPdf:AtSAy("(10) Bezeichnung Lieferung, Leistung",If(lKLT,nT+35,81),If(lKLT,108,101),"M")
oPdf:AtSay("(11) Sach-Nr. Lieferant",If(lKLT,nT+43,91),If(lKLT,108,101),"M")
oPdf:AtSay("(15) Packstück-Nr",If(lKLT,nT+63,127),7,"M")

oPdf:SetFont("HELVETICA",1,If(lKLT,2*2.54,7*2.54))
oPdf:AtSay(HB_OEMToAnsi(Pad(Trim(ku->Name1)+" "+ku->Name2,20)),If(lKLT,nT+12,15),7,"M")
oPdf:AtSay(ku->Town,If(lKLT,nT+14,22),7,"M")

//oPdf:AtSay(Pad(re->Ablade,5),If(lKLT,nT+11,20),If(lKLT,60,101),"M")
oPdf:SetFont("HELVETICA",1,If(lKLT,5*2.54,13*2.54))
oPdf:AtSay(Pad(cAblade,5),If(lKLT,nT+12,20),If(lKLT,60,101),"M")

oPdf:AtSay(If(lMisch,"MISCHSENDUNG",aku->ArtLief),If(lKLT,nT+27,62),7,"M")
If ! lMisch
	@ If(lKLT,nT+27,62),7 BARCODE TEXT "P"+aku->ArtLief
	oPdf:AtSay(LTrim(Transform(nQty,Me(art->Me))),If(lKLT,nT+39,91),7,"M")
	@ If(lKLT,nT+39,91),7 BARCODE TEXT "Q"+LTrim(Transform(nQty,Me(art->Me)))
Endif

oPdf:SetFont("HELVETICA",1,If(lKLT,5*2.54,7*2.54))
oPdf:AtSAy(LTrim(Str(nBelegNr)),If(lKLT,nT+12,34),If(lKLT,125,7),"M")
@ If(lKLT,nT+12,34),If(lKLT,125,7) BARCODE TEXT "N"+Str(nBelegNr)

If ! lKLT
	oPdf:AtSAy("Engelking, 78609 Tuningen",33,101,"M")
	oPdf:AtSay(LTrim(Str(pnum->WeightNet,12,2)),45,101,"M")
	oPdf:AtSay(LTrim(Str(pnum->Weight,12,2)),45,135,"M")
	oPdf:AtSay(LTrim(Str(nPackCount)),45,170,"M")
Endif

If ! lMisch
   oPdf:AtSay(HB_OEMToAnsi(art->Artikel),If(lKLT,nT+39,87),If(lKLT,108,101),"M")

   oPdf:AtSay(HB_OEMToAnsi(art->Matchcode),If(lKLT,nT+47,98),If(lKLT,108,101),"M")
   @ If(lKLT,nT+47,98),If(lKLT,108,101) BARCODE TEXT "30S"+art->Matchcode
Endif

oPdf:AtSay(cPackNum2,If(lKLT,nT+67,134),7,"M")
@ If(lKLT,nT+63,128),40 BARCODE TEXT IF(lMisch,"G","S")+StrTran(cPackNum2," ","")

?