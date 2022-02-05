//RUN_PRINT_VDA(61655,.T.)
FUNCTION RUN_PRINT_VDA(nRechnr,lRech)
   LOCAL cScreen,hArt,cKunde,cAblade,nPackCount
   LOCAL oTabs,nP,oGet,cI
   LOCAL nX,cX,lAdd,hArt2,nPackNum,cPackNum,nPak,nSubPackNum,cSubPackNum
   LOCAL getlist := {}
   MEMVAR mnPos,aNetWeights,aArt

//#include 'inkey.ch'

cScreen := SaveScreen()
Head("VDA Etikett(en) drucken")
// := 16670
//TxtBox("VDA Etikett(en) drucken")
If ValType(lRech) != "L"
	lRech := .T.
Endif

NetUse("englsre","re"   ,.F.,0)
NetUse("engkund","ku",   .F.,0)
NetUse("ups",    "ups",  .F.,0)
NetUse("paknum", "pnum", .F.,0)
NetUse("artikel","art",  .F.,0)
NetUSe("artkund","aku",  .F.,0)
NetUse("pakart", "pkart",.F.,0)
NetUse("lagerne","lne"  ,.F.,0)

mnPos := 0
hArt := {=>}
cAblade := ""

If lRech
	re->(dbsetorder(12))
	re->(dbSeek(STR(nRechnr,6)))

	GotoRechAddress()

	cKunde := re->Kunde
	cAblade := re->Ablade

	ups->(dbSetOrder(3))
  	ups->(dbSeek(Str(re->Rechnr,10)))

	re->(dbSkip())
	Do While re->Rechnr == nRechnr
		art->(dbSeek( re->Matchcode ))
		If re->AoQty > 0 .AND. art->Lagerart
			If ! HHasKey(hArt,re->Matchcode)
				hArt[re->Matchcode] := 0
			Endif
			hArt[re->Matchcode] += re->AoQty

			mnPos++
		Endif
		re->(dbSkip())
	Enddo
Else
	lne->(dbSetORder(1))
	If ! lne->(dbSeek( nRechnr ))
		Alert("Not found")
	Endif
	//Alert(Str(nRechnr)+" "+Str(lne->Nummer)+lne->Kunde)

	cKunde := lne->Kunde

	ups->(dbSetOrder(4))
  	ups->(dbSeek(lne->Nummer))

	art->(dbSetORder(2))
	Do While lne->Nummer == nRechnr
		art->(dbSeek( Str(lne->Artikelnr,6) ))
		If lne->Menge > 0 .AND. art->Lagerart
			If ! HHasKey(hArt,art->Matchcode)
				hArt[art->Matchcode] := 0
			Endif
			hArt[art->Matchcode] += lne->Menge

			mnPos++
		Endif
		lne->(dbSkip())
	Enddo
Endif

If Len(hArt) == 0
	Tr_MsgBox("Keine Artikel")
	RestScreen(,,,,cScreen)
   RETURN .F.
Endif

nPackCount := 0
pnum->(dbSeek(ups->Nr))
Do While pnum->Nr == ups->Nr
	nPackCount ++
	pnum->(dbSkip())
Enddo

aNetWeights := {}
aArt := {}

oTabs := GetTabs():new(01,00,MaxRow(),MaxCol())
If ! pkart->(dbSeek( Str(ups->Nr) ,.T.))
	nP := 0
	pnum->(dbSeek(ups->Nr))
	Do While pnum->Nr == ups->Nr
		nP ++
		@ 03,02 SAY "Nummer: "
		@ 03,18 SAY LTrim(pnum->Nummer)
		@ 04,02 SAY "Brutto Gewicht:"
		@ 04,18 SAY pnum->Weight
		Aadd(aNetWeights,If(pnum->WeightNet==0,pnum->Weight,pnum->WeightNet))
		@ 05,02 SAY "Netto Gewicht: "
		oGet := Get():new(05,18,,"aNetWeights[]")
		cI := LTrim(Str(nP))
		oGet:block := &("{|xValue| IIf( xValue==NIL, aNetWeights["+cI+"], aNetWeights["+cI+"] := xValue ) }")
		oGet:Display()
		IF Trim(pnum->Type) == "CT"
   		oGet:preBlock := {|| .F. }
   	ENDIF
		AAdd(GetList,oGet)
		@ 05,26 SAY t("(ohne Ladungsträger [z.B. Palette], mit Verpackung)")

		Aadd(aArt,{})

/*		pkart->(dbSeek( Str(ups->Nr)+pnum->Nummer ))
		Do While pkart->Nr == ups->Nr .AND. pkart->PakNum == pnum->Nummer
			art->(dbSetOrder( 2 ))
			art->(dbSeek( Str(pkart->Artikelnr,6) ))
			Aadd(aArt[nP],{"matchcode"=>art->Matchcode,"menge"=>pkart->Menge})
			pkart->(dbSkip())
		Enddo*/
		nX := 1
		Do While nX <= Len(hArt)
			//If AScan(aArt[nP],{|x| x["matchcode"] == HGetKeyAt(hArt,nX)}) == 0
				Aadd(aArt[nP],{"matchcode"=>HGetKeyAt(hArt,nX),"menge"=>If(nP==1,HGetValueAt(hArt,nX),0)})
			//Endif
			nX++
		Enddo

		@ 06,02 SAY "Inhalt:"

		nX := 1
		Do While nX <= Len(aArt[nP])
			@ 06+nX,02 SAY aArt[nP][nX]["matchcode"]
			art->(dbSetOrder(1))
			art->(dbSeek( aArt[nP][nX]["matchcode"] ))
			cX := LTrim(Str(nX))
			cI := LTrim(Str(nP))
			oGet := Get():new(06+nX,28,,"aArt[]")
			oGet:cargo := nX
			oGet:block := &("{|xValue| IIf( xValue==NIL, aArt["+cI+"]["+cX+"]['menge'], aArt["+cI+"]["+cX+"]['menge'] := xValue ) }")
			oGet:preBlock := {|| nPackCount > 1 }
			oGet:picture := Me(art->Me)
			oGet:Display()
			AAdd(GetList,oGet)

			nX++
		Enddo

		oTabs:AddTab(If(nP==1,"Paket ","")+LTrim(Str(nP)),getlist); getlist := {}

		pnum->(dbSkip())
	Enddo
	lAdd := .F.
	//nTab := 1
   Do While ! lAdd
   //Alert("Tab "+Str(nTab))
		//oTabs:GoToTab(nTab)
		oTabs:Modal()
		IF LastKey() == 27 .AND. Tr_MsgBox("Abbrechen?",,{"Ja","Nein"}) != 2
		    RETURN .F.
		ENDIF
		//nTab := oTabs:Current
		nP := 1
		hArt2 := {=>}
		#ifndef __XHARBOUR__
		HB_HCopy(hArt,hArt2)
		#else
		HCopy(hArt,hArt2)
		#endif
		Do While nP <= Len(aArt)
			nX := 1
			Do While nX <= Len(aArt[nP])
				hArt2[aArt[nP][nX]["matchcode"]] -= aArt[nP][nX]["menge"]
				nX++
			Enddo   
			nP++
		Enddo
		lAdd := .T.
		nX := 1
		Do While nX <= Len(hArt2)
			If HGetValueAt(hArt2,nX) != 0
				Tr_MsgBox("Menge bei Artikel "+Trim(HGetKeyAt(hArt2,nX))+" nicht korrekt")
				lAdd := .F.
			Endif
			nX++
		Enddo
   Enddo
   
   //@ MaxRow(),00 SAY "Waiting..."
   //Sinkey(0)

	nP := 0
	pnum->(dbSeek(ups->Nr))
	Do While pnum->Nr == ups->Nr
		nP ++
		pnum->(Rec_Lock(0))
		pnum->WeightNet := aNetWeights[nP]

		nX := 1
		Do While nX <= Len(aArt[nP])
			If aArt[nP][nX]["menge"] != 0
				art->(dbSetORder( 1 ))
				art->(dbSeek( aArt[nP][nX]["matchcode"] ))
				pkart->(Add_Rec(0))
				pkart->Nr        := ups->Nr
				pkart->PakNum    := pnum->Nummer
				pkart->Artikelnr := art->Artikelnr
				pkart->Menge     := aArt[nP][nX]["menge"]
				pkart->(dbUnLock())
			Endif
			nX++
		Enddo
		pnum->(dbSkip())
	Enddo
Endif


/*If Len(hArt) > 1
	Tr_MsgBox("Aktuell werden nur Sendungen mit einem Artikel korrekt untersttzt")
Endif*/

pnum->(dbSeek(ups->Nr))
If lRech
	re->(dbSeek(STR(nRechnr,6)))
Endif

art->(dbSetOrder( 2 ))
aku->(dbSetOrder( 1 ))

StartPrint(,,"PDF")

nPackNum := 0
Do While pnum->Nr == ups->Nr
	nPackNum++
	cPackNum := Ltrim(Str(nRechnr))+" "+StrZero(nPackNum,2)

	//lMisch := .F.
	pkart->(dbSeek( Str(ups->Nr)+pnum->Nummer ))
	pkart->(dbSkip())
	If pkart->Nr == ups->Nr .AND. pkart->PakNum == pnum->Nummer  //mehrere Artikel in diesem Packstück == Mischsendung
		MBaseRun(Trim(Tr_getini(1))+"\run\vda4902",{nRechnr,cAblade,.F.,1,.T.,0,nPackCount,nPackNum,cPackNum})
		nPak := 1
		pkart->(dbSkip(-1))
		nSubPackNum := 0
		Do While pkart->Nr == ups->Nr .AND. pkart->PakNum == pnum->Nummer
			art->(dbSeek( Str(pkart->Artikelnr,6) ))
			aku->(dbSeek( cKunde+Str(art->Artikelnr,6) ))

			nSubPackNum++
			cSubPackNum := cPackNum+" "+StrZero(nSubPackNum,3)

			MBaseRun(Trim(Tr_getini(1))+"\run\vda4902",{nRechnr,cAblade,.T.,nPak,.F.,pkart->Menge,nPackCount,nSubPackNum,cSubPackNum})
			nPak++
			pkart->(dbSkip())
		Enddo
	Else
		pkart->(dbSkip(-1))
		art->(dbSeek( Str(pkart->Artikelnr,6) ))
		aku->(dbSeek( cKunde+Str(art->Artikelnr,6) ))

		MBaseRun(Trim(Tr_getini(1))+"\run\vda4902",{nRechnr,cAblade,.F.,1,.F.,pkart->Menge,nPackCount,nPackNum,cPackNum})
	Endif
//	nQty := HGetValueAt(hArt,1)
	//Stickprint("VDA4902",1)
//	MBaseRun(Trim(Tr_getini(1))+"\run\vda4902",{.F.,1,.F.,nQty,nPackCount,nPackNum,cPackNum})
	//MBaseRun(Trim(Tr_getini(1))+"\run\vda4902",{.T.,2})
	pnum->(dbSkip())
Enddo
CopyPrint()
RETURN .T.