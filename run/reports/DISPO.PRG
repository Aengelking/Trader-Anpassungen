NetUse("engbes","bes",.F.,0)
bes->(dbSetOrder(3))

NetUse("engauf","auf",.F.,0)
auf->(dbSetOrder(3))

NetUse("artikel","art",.F.,0)
art->(dbSetOrder(4)) //gruppe+matchcode

NetUse("group","gr",.F.,0)
gr->(dbSetOrder(1)) //group

NetUse("werkauf","wer",.F.,0)
wer->(dbSetOrder(2))  //str(artno,6)

Head("Dispositionsliste")
cFrom  := Space(4)
cTo    := Replicate("þ",4)
lBed   := .F.
nDTerm := Val(CalWeek(Date()-365))
lDisp := .T.

@ 01,00 SAY "Von Gruppe " GET cfrom
@ 02,00 SAY "Bis Gruppe " GET cTo
@ 03,00 SAY "Artikel ohne Bedarf?" GET lBed PICTURE "Y" VALID Eval({|| If(lBed,lDisp:=.F.,""),.T. })
@ 04,00 SAY "Nur Artikel mit Dispositionsbedarf?" GET lDisp PICTURE "Y" WHEN ! lBed
READ


/*BeginJob()
StartPrint()
SET PRINTER ON
SET CONSOLE ON
*/

StartPrint(,"ProductRequirement","PDF")
oPrinter := GetCurrentPrinterObject()
oPdf := oPrinter:Data

art->(dbSeek(cFrom,.T.))
cGrup := ""
nCount := 0
Do While ! art->(Eof()) .AND. art->Gruppe >= cFrom .AND. art->Gruppe <= cTo

//  @ 23,00 SAy art->Gruppe
//  @ 24,00 SAY art->Matchcode
  nBes := 0
  nAuf := 0
  nLast12 := 0
  nWA  := 0
  nCount++
  If Int(nCount / 10) == nCount / 10
  	@ 24,00 SAY nCount
  Endif
  
  hReq := GetProductRequirementAndIncoming(art->Artikelnr)

  /*bes->(dbSeek(art->Matchcode))
  Do While ! bes->(Eof()) .AND. bes->Matchcode == art->Matchcode
    If bes->bestat < 3
      nBes := nBes+bes->BeQty-bes->GelQty
    Endif
    bes->(dbSkip())
  Enddo

  wer->(dbSeek(Str(art->Artikelnr,6)))
  Do While ! wer->(Eof()) .AND. wer->Artno == art->Artikelnr
    If wer->status < 4
      nWA := nWA+wer->Qty-wer->GelQty
    Endif
    wer->(dbSkip())
  Enddo

  auf->(dbSeek(art->Matchcode))
  cKunden := ""
  nKunden := 0
  Do While ! auf->(Eof()) .AND. auf->Matchcode == art->Matchcode
    If auf->bestat < 3
      nAuf := nAuf+auf->VkQty-auf->GelQty
    Endif
    If CalWD(auf->DTerm) >= CalWD(nDTerm) .AND. CalWD(auf->DTerm) <= Date()
      nLast12 := nLast12+auf->VkQty
      If At(auf->Kundma,cKunden) == 0
        nKunden := nKunden+1
        cKunden := cKunden + auf->Kundma+" "
      Endif
    Endif
    auf->(dbSkip())
  Enddo*/

  //Update fields
  art->(Rec_Lock(0))
  art->EkQty := hReq["income"] //nBes+nWA
  art->VkQty := hReq["requirement"] //nAuf
  art->Bedarf := hReq["avgrequirement"] //nLast12/12
  art->(dbUnLock())

*  SET DEVICE TO PRINTER
// If nBes+nAuf+nWa+nLast12 > 0 .OR. (lBed .AND. art->Bestand > 0)
  If (! lDisp .AND. art->EkQty+art->VkQty+art->Bedarf > 0) .OR. (lDisp .AND. art->Bedarf > 0 .AND. (art->Bestand+art->EkQty-art->VkQty)/(art->Bedarf) < 0)  .OR. (lBed .AND. art->Bestand > 0)
	  If ! art->Gruppe == cGrup
	    gr->(dbSeek(art->Gruppe))
	    cGrup := art->Gruppe

		oPdf:NewPage("A4","P",6)
		oPdf:SetFont("HELVETICA",1,10)
		oPdf:AtSay("Dispositionsliste")
        oPdf:SetFont("HELVETICA",0,8)
        oPdf:NewLine()
		oPdf:AtSay("Gruppe: "+art->Gruppe+"   "+gr->Name)
		oPdf:NewLine()
		oPdf:SetFont("COURIER",0,8)
		oPdf:NewLine()

	//    ? Pad("Matchcode",25),Pad("Beschreibung",30),"ME  ","Bestan","Bestellungen",PadL("Aufträge",12),PadL("WA",12),PadL("Bedarf/Monat",12),"KA",PadL("Dispo Monate",12)
	    oPdf:AtSay(Pad("Matchcode",25)+" "+Pad("Beschreibung",30)+" ME  "+" Bestan"+" Bestellungen"+" "+PadL("Auftr„ge",12)+" "+PadL("Bedarf/Monat",12)+" "+PadL("Dispo Monate",12))
	  Endif
	  	oPdf:NewLine()
    	oPdf:AtSay(art->Matchcode+" "+Left(art->Artikel,30)+" "+art->Me+Str(art->Bestand,6)+" "+Str(art->EkQty,12,2)+" "+Str(art->VkQty,12,2)+" "+Str(art->Bedarf,12,2)+" ")
//    ?? Str(nKunden,3,0),If(nLast12>0,Str( (art->Bestand+nBes+nWA-nAuf)/(nLast12/12),12,2 ),"")
      oPdf:AtSay(If(art->Bedarf>0,Str( (art->Bestand+art->EkQty-art->VkQty)/(art->Bedarf),12,2 ),""))
  Endif
*  SET DEVICE TO SCREEN

  art->(dbSkip())

Enddo

//SET PRINTER OFF
CopyPrint()
EndJob()
