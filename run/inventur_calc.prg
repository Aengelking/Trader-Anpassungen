#define CL Chr(13)+Chr(10)
FUNCTION Inventur_calc()
LOCAL dDate,nBestand

Head("Inventur")
NetUse("artikel","art",.F.,0)
NetUse("werkauf","wer",.F.,0)
NetUse("engabg","abg")
NetUse("engbes","bes")
NetUse("artlief","ali")
NetUse("engabg","abg",.F.,0)
NetUse("werks","we")

mcErrorLog := ""
mhArtikel := {=>}

art->(dbGoTop())

nWaren := 0
nRHB := 0
nUnfertig := 0

nDiff :=0

//nType := TR_MsgBox("Preisbasis",,{"Letzte EK","D/S Preis"})
nType := 2 //D/S Preise
//dDate := SToD("20130109")
//dDate:= SToD("20130430")
//dDate := StoD("20130109")

/*SET PRINTER TO ("C:\Users\Amos\AppData\Local\Temp\2\calc_test_ks26206_"+DToS(Date())+"_"+StrTran(Time(),":","-")+".txt")
SET PRINTER ON
art->(dbSeek( "KS26206" ))
//art->(dbSeek( "p10194.LP.BS.KONF.001" ))
? __GetAvPreis(Date())
SET PRINTER OFF
SET PRINTER TO
Inkey(0,128)
RETURN
  */
dDate := GetBox(Date(),"Datum","99.99.99")

/*If dDate < Date()
	Alert("Smaller date! "+DToC(dDate))
Endif*/
cList := Pad("Matchcode",25)+" "+Pad("Heute",12)+" "+Pad(DtoC(dDate),12)+" Finddatum"+CL
aUnfert := {}
aRHB    := {}
aWare   := {}

abg->(dbSetOrder(3))

//TEST
/*art->(dbSetOrder( 1 ))
art->(dbSeek("MPI002/28/BL"))

dDate := SToD("20120101")

nAvPreis := 0
nLastPreis := 0

DO WHILE dDate <= Date()
   nAvPreis := __GetAvPreis(dDate)
   IF nAvPreis != nLastPreis
      ? dDate,nAvPreis
      nLastPreis := nAvPreis
   ENDIF
   dDate += 5
ENDDO
 Inkey(0,128)
*/
/*IF ! abg->(dbSeek(art->Matchcode,.T.)) .AND. art->Bestand != 0
	? art->Matchcode+" keine Bewegungsdaten"+CL
ENDIF

nBestand := 0
lFound := .F.
dFoundDate := Date()

DO WHILE abg->Matchcode == art->Matchcode .AND. ! abg->(Eof()) .AND. abg->TransDate <= dDate
   ? abg->Buart,abg->TransDate,abg->Bestand
   If ! abg->BuArt $ "STD" .AND. abg->Bestand >= 0
		nBestand := abg->Bestand //+abg->Menge*IF(Trim(abg->Buart) $ "WA WE ZUG",-1,1)
      lFound := .T.
      dFoundDate := abg->Transdate
   Endif
   abg->(dbSkip())
ENDDO

? nBestand,DtoC(dFoundDate)
		Inkey(0,128)

RETURN  */
/*Do While ! art->(Eof())
   IF abg->(dbSeek(art->Matchcode))
      DO WHILE abg->Matchcode == art->Matchcode .AND. ! abg->(Eof())
         abg->(dbSkip())
      ENDDO
      abg->(dbSkip(-1))
      IF abg->Matchcode == art->Matchcode .AND. abg->Bestand != art->Bestand
            ? art->matchcode,art->Bestand,abg->Bestand
            abg->(Rec_Lock())
            abg->Bestand := art->Bestand
            abg->(dbUnLock())
      ENDIF
   ENDIF
   art->(dbSkip())
ENDDO
? "..."
Inkey(0)
RETURN*/

      cProtokoll := "C:\Users\Amos\AppData\Local\Temp\2\inventur_"+DToS(Date())+"_"+StrTran(Time(),":","-")+".csv"
      nPH := FCreate( cProtokoll )
      FWrite(nPH,"Matchcode;Artikelnummer;Bestand;Artikelart;AV-Preis;Gesamtwert;DS-Preis;Gesamtwert"+Chr(13)+Chr(10))


art->(dbGoTop())

Do While ! art->(Eof())
	nBestand := art->Bestand
	If dDate < Date()
		IF ! abg->(dbSeek(art->Matchcode,.T.)) .AND. art->Bestand != 0
	     mcErrorLog += art->Matchcode+" keine Bewegungsdaten"+CL
	   ENDIF

		nBestand := 0
		lFound := .F.
		dFoundDate := Date()
/*		Do While abg->Matchcode == art->Matchcode .AND. ! abg->(Eof()) .AND. abg->TransDate > dDate//! lFound
		    abg->(dbSkip())
		ENDDO*/
		DO WHILE abg->Matchcode == art->Matchcode .AND. ! abg->(Eof()) .AND. abg->TransDate <= dDate
			//? abg->Buart,abg->TransDate,abg->Bestand
			//If abg->TransDate < dDate
			//If ! abg->BuArt $ "STD" .AND. abg->Bestand >= 0
				nBestand := abg->Bestand //+abg->Menge*IF(Trim(abg->Buart) $ "WA WE ZUG",-1,1)
				//EXIT
				lFound := .T.
				dFoundDate := abg->Transdate
			//Endif
			abg->(dbSkip(1))
		ENDDO

		If art->Bestand != nBestand
		   abg->(dbSkip( -1 ))
/*         IF nBestand < 0 .AND. art->Bestand == 0 .AND. abg->Buart == "INV" .AND. dDate == Date()//Fehlbuchung inventur, durch Lagerorte
            abg->(Rec_Lock())
            abg->Bestand := 0
            abg->(dbUnLock())
		   ElSE*/
			   cList += art->Matchcode+" "+Pad(Transform(art->Bestand,Me(art->me)),12)+" "+Pad(Transform(nBestand,Me(art->me)),12)+" "+DToC(dFoundDate)+CL
//		   ENDIF
		Endif
	Endif

	If nBestand > 0
		@ 24,00 SAY art->Matchcode
      FWrite(nPH,Trim(art->Matchcode)+";"+LTrim(Str(art->Artikelnr))+";"+StrTran(LTrim(Transform(art->Bestand,ME(art->Me))),".",",")+";" )

      nPreis := __GetAvPreis(dDate)
      IF Round(nPreis,2) != Round(art->AvPreis*Currate(art->Money,"E"),2) .AND. dDate == Date()
//         mcErrorLog += art->Matchcode+" AvPreis-DB: "+Ltrim(Str(Round(art->AvPreis*Currate(art->Money,"E"),2)))+" AvPreis ber.:"+LTrim(Str(nPreis))+"("+Ltrim(Transform(art->Bestand,Me(art->me)))+")"+CL
         nDiff += art->Bestand*( nPreis-art->AvPreis*Currate(art->Money,"E") )
      ENDIF
		nValue := nBestand*nPreis


		@ 24,27 SAY Str(nValue,12,2)
		If Trim(art->Type) == "RHB"
			FWrite(nPh,"RHB")
         nRHB += nValue
			Aadd(aRHB,{art->Artikelnr,nBestand,nPreis})
		Elseif Trim(art->Type) == "UNFER"
			FWrite(nPh,"UNFER")
         //cUnfert += art->Matchcode+Str(nvalue)+Chr(13)+Chr(10)
			nUnfertig += nValue
			Aadd(aUnfert,{art->Artikelnr,nBestand,nPreis})
		Else
			FWrite(nPh,"WARE")
         nWaren += nValue
			Aadd(aWare,{art->Artikelnr,nBestand,nPreis})
		Endif
      FWrite(nPH,";"+StrTran(LTrim(Str(art->AvPreis*Currate(art->Money,"E"))),".",",")+";"+StrTran(LTrim(Str(art->Bestand*art->AvPreis*Currate(art->Money,"E" ))),".",","))
      FWrite(nPH,";"+StrTran(LTrim(Str(nPreis)),".",",")+";"+StrTran(LTrim(Str(nValue)),".",",")+Chr(13)+Chr(10))
	Endif
	art->(dbSkip())
Enddo
wer->(dbGoTop())
Do While ! wer->(Eof())
	if wer->Status < 4 .AND. wer->Status >= 3
		art->(dbSetOrder(2))
		art->(dbSeek(Str(wer->artno,6)))
		nGelQty := wer->gelqty



		@ 24,00 SAY art->Matchcode
		nPrice := StCalc(wer->artno,If(nType==2,5,1),99,.F.)
		nValue := (wer->qty-nGelqty)*nPrice*Currate(art->money,"E")
		If nValue > 10000
                //	Alert(art->Matchcode+Str(nvalue))
      Endif
                //cUnfert += art->Matchcode+Str(nvalue)+Chr(13)+Chr(10)
      nUnfertig += nValue

      Aadd(aUnfert,{art->Artikelnr,nBestand,nPrice})
      FWrite(nPH,Trim(art->Matchcode)+";"+LTrim(Str(art->Artikelnr))+";"+StrTran(LTrim(Transform(art->Bestand,ME(art->Me))),".",",")+";" )
      FWrite(nPh,"WA")
      FWrite(nPH,";"+StrTran(LTrim(Str(art->AvPreis*Currate(art->Money,"E"))),".",",")+";"+StrTran(LTrim(Str(art->Bestand*art->AvPreis*Currate(art->Money,"E" ))),".",","))
      FWrite(nPH,";"+StrTran(LTrim(Str(nPreis)),".",",")+";"+StrTran(LTrim(Str(nValue)),".",",")+Chr(13)+Chr(10))

	Endif
	wer->(dbSkip())
Enddo
FClose(nPH)
/*StartPrint()
SET DEVICE TO PRINTER
SET PRINTER ON
? cList
SET PRINTER OFF
SET DEVICE TO SCREEN
CopyPrint()*/
//MemoEdit/(cUnfert)
SetCursor(.T.)
If dDate < Date()
	MemoEdit(cList)
Endif
   Alert(Str(nDiff))
IF ! Empty(mcErrorLog)

   SAVE SCREEN
   HEAD("Fehlerprotokoll")
   MemoEdit(mcErrorLog,01,00,MaxRow(),MaxCol())
   RESTORE SCREEN
ENDIF
WAPI_ShellExecute(,cProtokoll,"OPEN")

CLS
@ 02,00 SAY "Waren und Fertigerzeugnisse    "+Str(nWaren,12,2)
@ 03,00 SAY "Roh-, Hilfs- u. Betriebsstoffe "+Str(nRHB,12,2)
@ 04,00 SAY "unfertige Erzeugnisse          "+Str(nUnfertig,12,2)

nChoice := 0
Do While nChoice != 1 .AND. LastKey() != 27
	nChoice := AMenu({"Verlassen","Drucken",t("In Lexware übertragen")})
	If nChoice == 2
      SAVE SCREEN
		BeginJob()
		StartPrint(,"VAR","PDF")
		oP := getCurrentPrinterObject()

		oP:Data:NewPage("A4","P",6)
		Conv("\17\\arialb,14\\y,80\\x,30\Inventur vom "+DToC(dDate),oP)
		oP:Data:REPORTLINE++;oP:Data:REPORTCOL := 0
		Conv("\1\\y,100\\x,30\Waren und Fertigerzeugnisse    "+Str(nWaren,12,2),oP)
		oP:Data:REPORTLINE++;oP:Data:REPORTCOL := 0
	    Conv("\x,30\Roh-, Hilfs- u. Betriebsstoffe "+Str(nRHB,12,2),oP)
		oP:Data:REPORTLINE++;oP:Data:REPORTCOL := 0
	    Conv("\x,30\unfertige Erzeugnisse          "+Str(nUnfertig,12,2),oP)
		oP:Data:REPORTLINE+=2;oP:Data:REPORTCOL := 0
	    Conv("\x,30\Gesamt                         "+Str(nWaren+nRHB+nUnfertig,12,2),oP)
	    /*If Lx_Start()
	    	oP:Data:REPORTLINE+=2;oP:Data:REPORTCOL := 0
	    	Conv("Buchungen")
	    	oP:Data:REPORTLINE+=1;oP:Data:REPORTCOL := 0
			oP:AtSay(Str(Lx_GetSaldo(8510,Date()),12,2))
	    Endif*/
		CopyPrint()
		EndJob()
		RESTORE SCREEN
	Elseif nChoice == 3
		hKonten := {"WARE"=>7140,"RHB"=>3970,"UNFERT"=>7050}
		hVerKonten := {"WARE"=>8980,"RHB"=>3960,"UNFERT"=>8960}
		hDiff := {"WARE"=>0,"RHB"=>0,"UNFERT"=>0}

		dDate := GetBox(dDate,"Buchungsdatum")

		LX_Start()
		//LX_CreateBooking(hData)
		//hData := {dBelegDate,dBookDate,cText,nHaben,nSoll,nBrutto,cBelegKreis}

		nSaldoW := LX_GetSaldo(hKonten["WARE"],dDate)
		@ 02,47 SAY Str(nSaldoW,12,2)
		@ 02,60 SAY Str(nSaldoW-nWaren,12,2)
                hDiff["WARE"] := nSaldoW-nWaren
		nSaldoR := LX_GetSaldo(hKonten["RHB"],dDate)
		@ 03,47 SAY Str(nSaldoR,12,2)
		@ 03,60 SAY Str(nSaldoR-nRHB,12,2)
		hDiff["RHB"] := nSaldoR-nRHB
		nSaldoU := LX_GetSaldo(hKonten["UNFERT"],dDate)
		@ 04,47 SAY Str(nSaldoU,12,2)
		@ 04,60 SAY Str(nSaldoU-nUnfertig,12,2)
		hDiff["UNFERT"] := nSaldoU-nUnfertig

		If TR_MsgBox(t("Buchungen durchführen?"),,{"Nein","Ja"}) == 2
			cMessage := ""
			nX := 1
			Do While nX <= 3
				cKey := HGetKeyAt(hKonten,nX)
				If Round(hDiff[cKey],2) != 0
					nSoll := nHaben := 0
					If hDiff[cKey] >= 0
						nSoll  := hVerKonten[cKey]
						nHaben := hKonten[cKey]
					Else
						nHaben  := hVerKonten[cKey]
						nSoll := hKonten[cKey]
					Endif
					? "Buche: S"+LTrim(Str(nSoll))+" H"+LTrim(Str(nHaben))+" "+LTrim(Str(Abs(Round(hDiff[cKey],2))))

					hData := {=>}
					hData:nBelegNr   := 0
					hData:dBelegDate := dDate
					hData:dBookDate  := dDate
					hData:cText      := "Inventur"
					hData:nHaben     := nHaben
					hData:nSoll      := nSoll
					hData:nBrutto    := Round(Abs(hDiff[cKey]),2)
					hData:cBelegKreis := NIL

					If ! LX_CreateBooking(hData,.F.)
						cMessage += "Buchung S"+LTrim(Str(nSoll))+" H"+LTrim(Str(nHaben))+" fehlgeschlagen!"+Chr(59)
						cMessage += LX_GetErrorMessage()+Chr(59)
					Endif
				Endif

				nX++
			Enddo
			If ! Empty(cMessage)
				Alert(cMessage)
			Endif
			Return
		Endif
	Endif
Enddo



Function __GetAvPreis(dDate,lArtLief,aWAs,nArtParent)
   LOCAL nGleitPreis := 0
   LOCAL nYear,hGewog := {=>},hYear,nGewogMenge := 0,nGewogSumme := 0,nGewog,nSumme,nMenge,nBestand
   LOCAL nPrice,nCachePrice
   LOCAL nQty := 0
   LOCAL nFolgeTo,nTotWeight := 0
   LOCAL lWeFound  := .F.
   LOCAL aEnv := SaveEnv()
//   LOCAL nArtRecno := art->(Recno())
//   LOCAL nArtInd   := art->(IndexOrd())
   LOCAL nFaktor   := 1
   bes->(dbSetOrder( 1 ))
   abg->(dbSetOrder( 3 ))

   IF HHasKey(mhArtikel,art->Matchcode)
      ? "rec value"
     // RETURN mhArtikel[art->Matchcode]
   ENDIF
   
   IF ValType(dDate) != "D"
      dDate := Date()
   ENDIF

   IF ValType(lArtLief) != "L"
      lArtLief := .T.
   ENDIF

   IF ValType(aWas) != "A"
      aWAs := {}
   ENDIF
   


   abg->(dbSeek( art->Matchcode ))
   nYear := Year(abg->Transdate)

   DO WHILE abg->Matchcode == art->Matchcode .AND. abg->Transdate <= dDate
      lPrice := .F.
      IF Trim(abg->Buart) == "WE" .AND. (abg->Bestand > 0 .OR. ! art->Lagerart)
         lWeFound := .T.
         bes->(dbSeek( Str(abg->besnr,6)+Str(abg->BesPos,3)))
         nFaktor := 1

         IF bes->FolgeTo != 0 //ist eine Folgeposition
            IF bes->Weight == 0 //no weights have been entered (or at least this one is missing)
               nFolgeTo := bes->FolgeTo
               bes->(dbSeek( Str(abg->besnr,6)+Str(nFolgeTo,3)))
               bes->(dbSkip())
               art->(dbSetOrder( 1 ))
               DO WHILE bes->besnr == abg->besnr .AND. bes->FolgeTo == nFolgeTo
                  art->(dbSeek( bes->Matchcode ))
                  IF art->Gewicht == 0
                     mcErrorLog += art->Matchcode+" kein Gewicht"+CL
                  ELSE
                     nTotWeight += art->Gewicht
                     bes->(Rec_Lock())
                     bes->Weight := art->Gewicht
                     bes->(dbUnLock())
                  ENDIF
                  bes->(dbSkip())
               ENDDO
               IF bes->(dbSeek( Str(abg->besnr,6)+Str(nFolgeTo,3)))
                  IF nTotWeight > 99999.999999
                     Alert(bes->Matchcode+Str(nTotWeight)+"g")
                  ELSE
                  bes->(Rec_Lock())
                  bes->Weight := nTotWeight
                  bes->(dbUnLock())
                  ENDIF
               ENDIF
            ELSE
               bes->(dbSeek( Str(abg->besnr,6)+Str(bes->FolgeTo,3)))
               nTotWeight := bes->Weight
            ENDIF
            IF nTotWeight == 0
               mcErrorLog += art->Matchcode+" kein Gewicht"+CL
               nFaktor := 0
            ELSE
               bes->(dbSeek( Str(abg->besnr,6)+Str(abg->BesPos,3)))
               nFaktor := bes->Weight/nTotWeight
               bes->(dbSeek( Str(abg->besnr,6)+Str(bes->FolgeTo,3)))  //price wird anhand der Mutterposition kalkuliert
            ENDIF

         ENDIF

         nPrice := bes->ekpr / Max(bes->pe,1) * If(bes->bestat==3.AND.bes->rate!=0,bes->rate,Currate(bes->Money,"E",abg->TransDate)) * ( 100 - bes->rabatt )/ 100 * nFaktor
         lPrice := .T.
         //? abg->Transdate,abg->Menge,nPrice,nGewogMenge

      ELSEIF Trim(abg->BuArt) == "WA" .AND. abg->Bestand > 0 //.AND. AScan(aParts,art->Artikelnr) == 0
         lWeFound := .T.
            IF abg->Besnr == 0
               //mcErrorLog += art->Matchcode+" WA Nr fehlt"+CL
               abg->(Rec_Lock())
               abg->Besnr := Val(abg->Beleg)
               abg->(dbUnLock())
            ENDIF
         nCachePrice := NIL
         IF abg->Preis != 0 .AND. abg->TransDate <= Date()-120
            nPrice := abg->Preis/abg->PE
            lPrice := .T.
         ELSEIF (nWA := AScan(aWAS,{|x| x["WA"]==abg->Besnr .AND. x["DATE"] == abg->TransDate})) != 0
            nPrice := aWAs[nWA]["PREIS"]
            lPrice := .T.
//            _WerCalc(abg->Besnr,abg->TransDate,aWAs,nArtParent)
         ELSE
            nPrice := _WerCalc(abg->Besnr,abg->TransDate,aWAs,nArtParent)
            IF nPrice != NIL  //if no error (endless loop)
               lPrice := .T.
               Aadd(aWAs,{"WA"=>abg->Besnr,"DATE"=>abg->Transdate,"PREIS"=>nPrice})

               abg->(Rec_Lock(0))
               IF nPrice < 9999
                  abg->Preis := nPrice*1000
                  abg->PE    := 1000
               ELSE
                  abg->Preis := nPrice
                  abg->PE    := 1
               ENDIF
               abg->(dbUnLock())

            ENDIF
         ENDIF
      ENDIF

      IF lPrice
               //Gleitender Durchschnittspreis
         IF art->Lagerart
            nGleitPreis := ((abg->Bestand-abg->Menge)*nGleitPreis + abg->Menge*nPrice) / abg->Bestand
         ELSE
            IF nQty+abg->Menge == 0
               nGleitPreis := 0
            ELSE
               nGleitPreis := (nQty*nGleitPreis + abg->Menge*nPrice) / (nQty+abg->Menge)
            ENDIF
            nQty +=abg->Menge
         ENDIF

         //Gewegoener Durschnittspreis
         IF Year(abg->TransDate) > nYear //Jahreswechsel
            IF nGewogMenge != 0
               //? "---"
               hGewog[nYear] := {"BESTAND"=>abg->Bestand-abg->Menge,"SUMME"=>nGewogSumme,"MENGE"=>nGewogMenge}
            ENDIF
            nGewogMenge := 0
            nGewogSumme := 0
            nYear := Year(abg->TransDate)
         ENDIF
         nGewogMenge += abg->Menge
         nGewogSumme += nPrice*abg->Menge
      ENDIF

      abg->(dbSkip(1))
   ENDDO
   abg->(dbSkip( -1 ))
   IF ! HHasKey(hGewog,nYear) .AND. nGewogMenge != 0
      hGewog[nYear] := {"BESTAND"=>abg->Bestand-abg->Menge,"SUMME"=>nGewogSumme,"MENGE"=>nGewogMenge}
   ENDIF
//   ? "Gewogene Werte"
//   ? "Jahr",PadL("Bestand",12),PadL("Jahresdurchschnitt",12),PadL("Gewogener Wert",12)
   nYear := 0
   nBestand := 0
   FOR EACH hYear IN hGewog
      IF hYear["BESTAND"] != 0
         IF hYear:__enumKey() == nYear+1 .AND. nBestand != 0
            //? nBestand,nGewog
            nSumme := hYear["SUMME"]+(nBestand*nGewog)
            nMenge := hYear["MENGE"]+nBestand
         ELSE
            nSumme := hYear["SUMME"]
            nMenge := hYear["MENGE"]
         ENDIF
         IF nMenge != 0
            nGewog := nSumme/nMenge
         ELSE
            nGewog := 0
         ENDIF
      ELSE
         nGewog := 0
      ENDIF
      nBestand := hYear["BESTAND"]
      nYear := hYear:__enumKey()
      IF Trim(art->Matchcode) == "KS26206"
         ? Str(hYear:__enumKey(),4),Str(hYear["BESTAND"],12,2),Str(hYear["SUMME"],12,2),Str(hYear["MENGE"],12,2),Str(hYear["SUMME"]/hYear["MENGE"],12,2),Str(nGewog,12,2)
      ENDIF
   NEXT
   //mhArtikel[art->Matchcode] := {"AVPREIS"=>nGleitPreis,"RECNO"=>abg->(Recno())}
   //art->(dbGoto( nArtRecno ))
   //art->(dbSetOrder( nArtInd ))
   RestEnv(aEnv,.F.)

   IF ! lWeFound .AND. art->Bestand > 5 .AND. lArtLief//bis 5 Stk wahrscheinlich muster
      ali->(dbSetOrder( 4 ))
      IF ali->(dbSeek( Str(art->Artikelnr,6) ))
         ali->(dbSetOrder( 3 ))
         cArtLief := ali->Kunde+ali->Artlief
         ali->(dbSeek( cArtLief ))
         DO WHILE ! ali->(EOF()) .AND. ali->Artikelnr == art->Artikelnr //jump this pa
            ali->(dbSkip())
         ENDDO
         IF ali->Kunde+ali->Artlief == cArtLief
            art->(dbSetOrder( 2 ))
            art->(dbSeek( Str(ali->Artikelnr,6) ))
            nGleitPreis := __GetAvPreis(dDate,.F.)
            //mhArtikel[art->Matchcode]:AvPreis := nGleitPreis
         ELSE
//            mcErrorLog += art->Matchcode+" kein Wareneingang ("+Ltrim(Str(art->Bestand))+")"+CL
         ENDif
         //art->(dbGoto( nArtRecno ))
         //art->(dbSetOrder( nArtInd ))
         RestEnv(aEnv)
      ELSE
//         mcErrorLog += art->Matchcode+" kein Wareneingang ("+Ltrim(Str(art->Bestand))+")"+CL
      ENDIF

   ENDIF

Return IF(nGewog!=NIL.AND.art->Lagerart,nGewog,nGleitPreis)
//SInkey(0)

STATIC Function _WerCalc(nAufno,dDate,aWAs,nArtParent)
LOCAL nTot := 0,nPreis,nQty
LOCAL aEnv := SaveEnv()

   we->(dbSetOrder( 1 ))
   we->(dbSeek( str(nAufno,6) ))

   wer->(dbSetOrder(1))
   wer->(dbSeek( str(nAufno,6) ))

   art->(dbSetOrder(2))
   bes->(dbSetOrder( 1 ))

   art->(dbSEEK(str(wer->artno,6)))

   //? nAufno,dDate,art->Matchcode
   DO WHILE ! we->(EOF()) .AND. (we->Aufno == nAufno)

      nQty := we->Qty*we->factor/wer->Qty
      IF ! art->(dbSEEK(str(we->partart,6)))
         mcErrorLog += Str(we->partart,6)+" nicht gefunden! (WA "+LTrim(Str(nAufno))+")"+CL
      ELSEIF we->Partart == nArtParent //avoid endless loop
         RETURN NIL
      ELSEIF we->Pos == -1 //Lohn
         IF wer->Besnr != 0 .AND. bes->(dbSeek( Str(wer->besnr,6)+Str(IF(wer->BesPos==0,1,wer->BesPos),3)))
            nPreis := bes->ekpr / Max(bes->pe,1) * If(bes->bestat==3.AND.bes->rate!=0,bes->rate,Currate(bes->Money,"E",dDate)) * ( 100 - bes->rabatt )/ 100
            ? art->Matchcode,nQty,nPreis
            nTot += nPreis*nQty
         ENDIF
      ELSE
         nPreis := __GetAvPreis(dDate,,aWAs,wer->Artno)
         ? art->Matchcode,nQty,nPreis
         nTot += nPreis*nQty
      ENDIF
      we->(dbSkip())
   ENDDO
   //? nTot

   RestEnv(aEnv,.F.)
Return(nTot)
