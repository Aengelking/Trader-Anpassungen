#define CRLF Chr(13)+Chr(10)

dStart := Date()-DoW(Date())+2 //beginning of week
If DoW(Date()) < 5
	dStart -= 7
Endif
dEnd := dStart+4
//dStart := CToD("28.09.09")
//dEnd := CToD("30.10.09")

nYear := Year(dStart)
nMonth := Month(dStart)


Head("New turnover") // with Bulgin Products")
nTotal := 0
nNew := 0
nNewCustVal := 0
nBuyTotal := 0

@ 01,00 SAY "Calculating new turnover between "+DToC(dStart)+" and "+DToC(dEnd)+"..."

NetUse("engauf","auf",.F.,0)
auf->(dbSetOrder( 9 )) //Kundma+Dtos(besda)

NetUse("artikel","art",.F.,0)
art->(dbSetOrder(2)) //Str(artikelnr)

NetUse("manufact","man",.F.,0)


/*StartPrint(,,"PDF")
oPrinter := GetCurrentPrinterObject()
oPdf := oPrinter:Data
oPdf:SetFont("COURIER")
oPdf:NewPage("A4")
*/

//oPdf:AtSay(Pad("Kunde",8)+" "+Pad("Artikel",25)+" "+Pad("Menge",12)+" "+Pad("VK/Stk.",12)+" "+Pad("EK/Stk.",12))

hManu := {=>}

auf->(dbGoTop())

hCustomers := {=>}
Do While ! auf->(Eof())
	art->(dbSeek( Str(auf->Artikelnr,6) ))
	If ! HHasKey(hManu,art->Manufactur)
		hManu[art->Manufactur] := {"new_week"=>0,"new_year"=>0,"new_month"=>0}
	Endif
	man->(dbSeek( Str(art->Manufactur,5) ))

//	If art->Manufactur == 1 //1=Bulgin, 3=ITW
		//.AND. (! HHasKey(hCustomers,auf->Kundma) .OR. ! HHasKey(hCustomers[auf->Kundma],art->Artikelnr) ) //new customer or new product
		lNew := .F.
		lNewCust := .F.
		If ! HHasKey(hCustomers,auf->Kundma) //new Customer
			lNew := .T.
			lNewCust := .T.
			hCustomers[auf->Kundma] := {"new_week"=>0,"new_year"=>0,"new_month"=>0} //{=>}
		Endif
		/*If ! HHasKey(hCustomers[auf->Kundma],art->Artikelnr) //new product
			lNew := .T.
			hCustomers[auf->Kundma][art->Artikelnr] := 0
		Endif*/
//		If auf->Besda >= dStart .AND. auf->Besda <= dEnd
			nAmount := auf->Vkqty*auf->Vkpr/auf->Pe
/*

			If lNew
                        	//Calculate the buying value
				nBuyPreis := 0
				nBuyPe := 0
				If auf->VkPr > 0
				GetBuyPrice(Pad("BULGIN",8),auf->Artikelnr,auf->VkQty,@nBuyPreis,@nBuyPe,.T.)
				If nBuyPreis == 0 .AND. ! Empty(art->vkpreis2) //Preis basis e.g. Bulgin
					nBuyPreis := art->vkpreis2
					nBuyPe := art->vkpe
				Endif
				If nBuyPreis == 0
					nBuyPreis := art->letzte_ek
					nBuyPe := art->pe
				Endif
				Endif
				If nBuyPe == 0
					nBuyPe := 1
				Endif


				hCustomers[auf->Kundma][art->Artikelnr] += nAmount
				nNew += nAmount
				nBuyTotal += nBuyPreis/nBuyPe*auf->VkQty
				If lNewCust
					nNewCustVal += nAmount
				Endif
//				oPdf:NewLine()
//				oPdf:AtSay(auf->Kundma+" "+art->Matchcode+" "+Str(auf->VkQty,12,2)+" "+Str(auf->Vkpr/auf->Pe,12,2)+" "+Str(nBuyPreis/nBuyPe,12,2))

			Endif*/
			nTotal += nAmount
			If lNew
				If auf->Besda >= dStart .AND. auf->Besda <= dEnd
					hManu[art->Manufactur]["new_week"] += nAmount
					hCustomers[auf->Kundma]["new_week"] += nAmount
				Endif
				If Year(auf->Besda) == nYear
					hManu[art->Manufactur]["new_year"] += nAmount
					hCustomers[auf->Kundma]["new_year"] += nAmount
					If Month(auf->Besda) == nMonth
						hManu[art->Manufactur]["new_month"] += nAmount
						hCustomers[auf->Kundma]["new_month"] += nAmount
					Endif
				Endif
			Endif
//		Endif
//	Endif

    auf->(dbSkip())
Enddo
//CopyPrint()

/*@ 02,00 SAY "Total sales: "+Str(nTotal)
@ 03,00 SAY "'New' sales: "+Str(nNew)
@ 04,00 SAY "Thereof new customers: "+Str(nNewCustVal)
@ 05,00 SAY "'New' Buying volume: "+Str(nBuyTotal)*/

/*cMsg := "Dear Darren, "+CRLF+CRLF
cMsg += "as requested we have calculated a rough figure for new business done this week ("+DToC(dStart)+" - "+DToC(dEnd)+")."+CRLF
cMsg += "We estimate that we have received sales orders for new business which reflect a purchasing value of a total of:"+CRLF
cMsg += "GBP "+LTrim(Str(Round(nBuyTotal/1000,0)*1000))+CRLF+CRLF
cMsg += "Best Regards"+CRLF+"Amos Engelking"
*/

cMsg := "Hallo,"+CRLF+CRLF
cMsg += "folgend die neuen Umsätze nach Hersteller aufgelistet."+CRLF+CRLF
cMsg += Pad("HERSTELLER",15)+" "+Pad("Woche",12)+" "+Pad("Monat",12)+" "+Pad("Jahr",12)+CRLF
nX := 1
Do While nX <= Len(hManu)

	man->(dbSeek( Str(HgetKeyAt(hManu,nX),5) ))
	hVal := HgetValueAt(hManu,nX)

	cMsg += man->Short+" "+Str(hVal["new_week"],12,2)+" "+Str(hVal["new_month"],12,2)+" "+Str(hVal["new_year"],12,2)+CRLF

	nX++
Enddo
/*cMsg += "Neue Kunden im Monat "+Str(nMonth)+CRLF
nX := 1
Do While nX <= Len(hCustomers)
	If HGetValueAt(hCustomers,nX)["new_month"] > 0
		cMsg += HGetKeyAt(hCustomers,nX)+CRLF
	Endif
	nX++
Enddo*/

SendMail({{"amos.engelking@engelking.de","Amos Engelking"}},"Data -CONFIDENTIAL-",cMsg)
//Alert("done")
//SInkey(0,128)

