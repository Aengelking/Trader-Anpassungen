PROC RUN_BERICHT_STOCK_MOVEMENTS
   LOCAL hArtikel
   LOCAL dStart,dEnd
   LOCAL aTypes := {"Inventur","Inv. ohne Z/A","Eingang/Abgang"}
   LOCAL nType := 1,nOut := 1
   LOCAL getlist := {}
   LOCAL aData,cFile
   LOCAL nX,cBuArt,oPdf,nTotal,cMatch,nQty,oArt
   LOCAL nPreis

   MEMVAR cTypes

   Head(t("Bestandsveränderungen"))
NetUse("engabg","abg",.F.,0)
abg->(dbSetOrder(5))

NetUse("artikel","art",.F.,0)
NetUse("me","me",.F.,0)

dStart := CToD("17.12.13")
dEnd   := CToD("17.12.13")

hArtikel := {=>}

@ 01,00 SAY "Von" GET dStart
@ 02,00 SAY "Bis" GET dEnd
@ 03,00 SAY "Art" 
@ 03,04,13,20 GET nType LISTBOX aTypes DROPDOWN
@ 04,00 SAY "Ausgabe"
@ 04,08,14,20 GET nOut LISTBOX {"PDF","Scalc"} DROPDOWN
READ
IF LastKey() == 27
   RETURN
ENDIF

IF nType == 1
   cTypes := "INV ZUG ABG"
ELSEIF nType == 2
   cTypes := "INV"
ELSE
   cTypes := "WE WA RNR ENT"
ENDIF

//@ 24,13 SAY "/"+LTrim(Str(abg->(LastRec())))
nX := 0
abg->(dbSetFilter({|| Trim(abg->BuArt) $ cTypes },"Trim(BuArt) $ cTypes"))
abg->(dbSeek( DtoS(dStart) , .T. ))
art->(dbSetOrder(2))
Do While ! abg->(Eof()) .AND. abg->TransDate >= dStart .AND. abg->Transdate <= dEnd
//	If Trim(abg->BuArt) $ cTypes  //.AND. abg->TransTime > Pad("15:30:00",10)
   IF Trim(abg->Buart) != "WE" .OR. (art->(dbSeek(Str(abg->Artikelnr,6))) .AND. art->Lagerart)
        	If ! HHasKey(hArtikel,abg->Matchcode)
        		hArtikel[abg->Matchcode] := 0
        	Endif
        	cBuArt := Trim(abg->Buart)
        If cBuart $ {"INV","ZUG","WE","WA"}
			hArtikel[abg->Matchcode] += abg->Menge
		Else
			hArtikel[abg->Matchcode] -= abg->Menge
      Endif
   ENDIF
//	Endif
	nX++
	@ 24,00 SAY Str(nX,12)
	abg->(dbSkip(1))
Enddo

art->(dbSetOrder(1))

IF nOut == 1
   StartPrint(,,"PDF")
   oPdf := GetCurrentPrinterObject():Data
   oPdf:SetFont("Courier")
   oPdf:NewPage("A4","P")
ELSE
   aData := {{"Matchcode","Menge","Summe EUR"}}
ENDIF

nX := 1
nTotal := 0
Do While nX <= Len(hArtikel)
	nQty := HGetValueAt(hArtikel,nX)
	cMatch := HGetKeyAt(hArtikel,nX)
	If nQty != 0
		art->(dbSeek( cMatch ))
/*		nPreis := art->avpreis
		If art->Bezug >= 5
			nPreis := StCalc(art->artikelnr,5,99,.T.)
		Endif
*/
      oArt := Artikel():New(.F.)
      oArt:Load(art->Artikelnr)
      nPreis := oArt:GetAvgBuyPrice(date())
      IF nOut == 1
         oPdf:AtSAy(cMatch)
         oPdf:RJust(Transform(nQty,Me(art->me)),,70)
         oPdf:RJust(Str(nQty*nPreis,12,2),,100)
         oPdf:NewLine()
         nTotal += nQty*nPreis
      ELSE
         Aadd(aData,{Trim(cMatch),Val(Transform(nQty,Me(art->me))),nQty*nPreis})
      ENDIF

		
	Endif
	nX++
Enddo
IF nOut == 1
   oPdf:RJust(Replicate("=",12),,100)
   oPdf:NewLine()
   oPdf:RJust(Str(nTotal,12,2),,100)
   CopyPrint()
ELSE
   Aadd(aData,{,,"=SUM(C2:C"+LTrim(Str(Len(aData)))+")"})
   cFile := Wvt_GetSaveFileName( 0,"" , "OpenDocument Calc Datei", { {"OpenDocument Cal (*.ods)","*.ods"} }, , Trim(Tr_Getini(1))+"\export\" )
   IF ! Empty(cFile)
      IF AT(".",cFile) == 0
         cFile += ".ods"
      ENDIF
      SaveToOO(cFile,aData)
   ENDIF
ENDIF

#include 'X:\run\savetooo.prg'