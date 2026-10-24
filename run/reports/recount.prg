
Head("Anzahl Rechnungen")

NetUse("engkund","ku",.F.,0)

NetUse("ups","ups",.F.,0)
ups->(dbSetOrder(3))

NetUse("paknum","pnum",.F.,0)

NetUse("artikel","art",.F.,0)

NetUse("englsre","re",.F.,0)
re->(dbGoTop())
//nYear := GetBox(Year(date()),"Jahr","9999")

cFile := Trim(Tr_Getini(1))+"\export\rechnungen.csv"

nCount := 0
nNettoTot := 0
nBruttoTot := 0
nGut := 0
nForeign := 0
nGutVal := 0
TxtBox("Bitte warten...")
hInvoices := {=>}
aPacker := {}

re->(dbSetORder(8)) //str(reposnr)+str(rechnr)
re->(dbGoTop())

Do While ! re->(Eof()) .AND. re->reposnr == 0
//	If re->reposnr == 0 .and. re->rechdat >= CToD("01.01."+Str(nYear,4)) .AND. re->rechdat <= CToD("31.12."+Str(nYear,4))
		cMonth := Str(Year(re->rechdat),4)+"-"+StrZero(Month(re->Rechdat),2)

		If ! HHasKey(hInvoices,cMonth)
			hInvoices[cMonth] := {"count"=>0,"cnt_foreign"=>0,"cnt_credit"=>0,"val_net"=>0,"val_brut"=>0,"val_credit"=>0,"boxes"=>0,"packer"=>{=>},"positions"=>0}
		Endif

		ku->(dbSeek(re->kunde+"K"))

		nNetto := ( re->poswt - re->preis ) * If(!Empty(re->money),Currate(re->Money,"V"),1)
        nBrutto := ( re->poswt ) * If(!Empty(re->money),Currate(re->Money,"V"),1)

		nCount++
	If re->poswt < 0
        	nGut++
        	nGutVal += nNetto
        	hInvoices[cMonth]["cnt_credit"]++
        	hInvoices[cMonth]["val_credit"] += nNetto
        Endif
        If ! ku->CountryIso == "DE"
        	hInvoices[cMonth]["cnt_foreign"]++
        	nForeign++
        Endif

        hInvoices[cMonth]["val_net"] += nNetto
        hInvoices[cMonth]["val_brut"] += nBrutto

        nNettoTot += nNetto
        nBruttoTot += nBrutto

	nBoxes := 0
        If ups->(dbSeek( Str(re->Rechnr,10) ))
		If ! HHasKey(hInvoices[cMonth]["packer"],ups->Person)
                	hInvoices[cMonth]["packer"][ups->Person] := 0
                Endif
                If AScan(aPacker,ups->Person) == 0
                	Aadd(aPacker,ups->Person)
                Endif
                hInvoices[cMonth]["packer"][ups->Person]++
        	pnum->(dbSeek( ups->Nr ))
			Do While pnum->Nr == ups->Nr
				nBoxes++
        		pnum->(dbSkip())
        	Enddo
        Endif

        hInvoices[cMonth]["boxes"] += nBoxes
	hInvoices[cMonth]["count"] ++

	//positions
	If nNetto > 0
		re->(dbSetOrder(4))
		nNr := re->Rechnr
		nRec := re->(Recno())
		Do While ! re->(EOF()) .AND. re->Rechnr == nNr
			art->(dbSeek( re->Matchcode ))
			If re->reposnr != 0 .AND. re->AoQty != 0 .AND. art->LagerArt
				hInvoices[cMonth]["positions"] ++
			Endif
			re->(dbSkip())
		Enddo
		re->(dbSetOrder(8))
		re->(dbGoto(nRec))
	Endif

//	Endif
	re->(dbSkip())
Enddo

//{"count"=>0,"cnt_foreign"=>0,"cnt_credit"=>0,"val_net"=>0,"val_brut"=>0,"val_credit"=>0}

#define D +Chr(59)+
SET PRINTER TO (cFile)
SET PRINTER ON
?? "Month" D "invoices" D "boxes" D "foreign invoices" D "credit notes" D "positions" D "net value" D "total value" D "value credit notes"

nX := 1
Do While nX <= Len(aPacker)
	?? "" D Buy(aPacker[nX],.T.)
	nX++
Enddo


nX := 1
Do While nX <= Len(hInvoices)
	hI := HGetValueAt(hInvoices,nX)
	? HGetKeyAt(hInvoices,nX) D StrTran(LTrim(Str(hI["count"])) D LTrim(Str(hI["boxes"])) D LTrim(Str(hI["cnt_foreign"])) D LTrim(Str(hI["cnt_credit"],12,2)) D LTrim(Str(hI["positions"],12,2)) D LTrim(Str(hI["val_net"],12,2)),".",",")
	?? StrTran("" D LTrim(Str(hI["val_brut"],12,2)) D LTrim(Str(hI["val_credit"],12,2)),".",",")
	nP := 1
	Do While nP < Len(aPacker)
		?? Chr(59)
		If HHasKey(hI["packer"],aPacker[nP])
			?? hI["packer"][aPacker[nP]]
		Endif
		nP++
	Enddo
	nX++
Enddo
SET PRINTER OFF
SET PRINTER TO
#undef D

CLEAR
//? nYear
? "Anzahl Rechnungen        ",str(nCount)
? "Anzahl Ausland           ",nForeign
? "Anzahl Inland            ",nCount-nForeign
? "Anzahl Gutschriften      ",nGut
? "Wert Gutschriften (netto)",nGutVal
? "Netto                    ",nNettoTot
? "Brutto                   ",nBruttoTot
WAPI_ShellExecute(,"open",cFile)
SInkey(0)