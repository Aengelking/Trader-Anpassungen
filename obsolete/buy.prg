cLief := GetBox(Space(8),"Lieferant","@!")
dVon := CToD(GetBox(DToC(Date()-365),"Von","99.99.99"))
dBis := CToD(GetBox(DToC(Date()),"Bis","99.99.99"))

NetUse("artikel","art",.F.,0)
art->(dbSetOrder(2))

NetUse("engkund","ku",.F.,0)
ku->(dbSeek(cLief+"K"))

NetUse("engbes","bes",.F.,0)
bes->(dbSetOrder(2))
bes->(dbSeek(cLief))

hEK := {=>}

cMain := ""
cMain := If(Trim(cLief) == "BULGIN","BL",If(Trim(cLief)=="ITW","IT",If(Trim(cLief)=="EDAC","ED","")))
lWrong := .F.
CLS
@ 00,00 SAY "Bestellungen an "+cLief+" werden untersucht..."
Do While ! bes->(EOF()) .AND. bes->liefma == cLief .AND. Inkey() != 27
	If bes->besda >= dVon .AND. bes->besda <= dBis
		art->(dbSeek(Str(bes->ArtikelNr,6)))
	    If ! HHasKey(hEK,art->Gruppe)
	    	hEk[art->Gruppe] := 0
		Endif
		If ! Empty(cMain) .AND. SubStr(art->Gruppe,0,2) != cMain
			? bes->besnr,art->Matchcode,"in",art->Gruppe+" nicht "+cMain
			lWrong := .T.
		Endif
		nValue := bes->ekPr*If(bes->bestat>=3,bes->GelQty,bes->BeQty)/If(bes->Pe==0,1,bes->pe)
		If bes->money != ku->money
			nValue  := nValue*currate(bes->money,"V")/currate(ku->money,"V")
		Endif
	    hEk[art->Gruppe] += nValue
	Endif
  	bes->(dbSkip(1))
ENDDO
bes->(dbCloseArea())

If lWrong
	? "Weiter mit beliebiger Taste.."
	Sinkey(0)
Endif

NetUse("group","gr",.F.,0)
CLS
@ 00,00 SAY cLief+" Einkauf von "+DToC(dVon)+" bis "+DToC(dBis)+Space(20)+"Erstellt am: "+DToC(Date())
nX := 1
Do While nX <= Len(hEK)
	gr->(dbSeek(HGetKeyAt(hEK,nX)))
	? HGetKeyAt(hEK,nX),gr->Name,Currate(ku->Money,"X"),Str(HGetValueAt(hEK,nX),12,2)
	nX++
Enddo
SInkey(0)