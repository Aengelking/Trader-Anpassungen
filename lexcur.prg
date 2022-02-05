PROC RUN_LEXCUR
   LOCAL nCur := 1
   LOCAL dDate 
   LOCAL dSaldoDate
   //LOCAL nDiffSaldo
   LOCAL lStapel := .F.
   LOCAL hSummen
   LOCAL nSaldo
   LOCAL nDiffRate
   //LOCAL cPic := "@E 999,999.99"
   LOCAL getlist := {}
   LOCAL nKonto,nDiffKto
   LOCAL hBooking,aDiffBookings,aKontoBookings
   LOCAL nIncome,nDiffIncome,nSumme
   LOCAL nX,nY
   LOCAL aNewDiff
   LOCAL oPdf,nMonth := Month(Date()),nYear := Year(Date())
   LOCAL nRow,nCol
   LOCAL bBackground,nL,bUpdateDiff
   

   IF ! LX_Start()
      Alert("Keine Verbindung zu Lexware")
      Return 
   ENDIF

   DO WHILE .T.
      aNewDiff := {}
      Head(t("Eurodifferenz für Währungskonto berechnent"))
      @ 01,00 SAY t("Währung")
      @ 01,10,10,40 GET nCur LISTBOX {"GBP - Sparkasse (1231/1232)","USD - Sparkasse (1235/1236)","GBP - Volksbank (1222/1223)","USD - Volksbank (1237/1238)"} DROPDOWN
      @ 02,00 SAY "Jahr"
      @ 02,10 GET nYear PICTURE "9999" VALID nYear >= 2010 .AND. nYear <= Year(Date())
      @ 03,00 SAY "Monat"
      @ 03,10 GET nMonth PICTURE "99" VALID nMonth >= 1 .AND. nMonth <= 12
      //@ 02,08 GET dDate VALID dDate <= Date()
      
      //@ 01,17 SAY "Betrag"
      //@ 02,17 GET nAmount PICTURE cPic
      /*@ 01,27 SAY "Stapel"
      @ 02,29 GET lStapel PICTURE "Y"
      @ 01,34 SAY "Kurs"
      @ 01,40 SAY "Differenz"
      @ 01,50 SAY "Wert EUR"*/
      READ
      IF LastKey() == 27
         EXIT
      ENDIF
      dDate := EoM(StoD(Str(nYear,4)+StrZero(nMonth,2)+"01"))
      IF nCur == 1
         nKonto := 1231
         nDiffKto := 1232
      ELSEIF nCur == 2
         nKonto := 1235
         nDiffKto := 1236
      ELSEIF nCur == 3
         nKonto := 1222
         nDiffKto := 1223            
      ELSEIF nCur == 4
         nKonto := 1237
         nDiffKto := 1238
      ENDIF

      /*
      IF Month(dDate) == 1
         dSaldoDate := Str(Year(dDate)-1,4)+"1201"
      ELSE
         dSaldoDate := Str(Year(dDate),4)+StrZero(Month(dDate)-1,2)+"01"
      ENDIF

      dSaldoDate := StoD(dSaldoDate)

      hSummen := LX_getSummen(nDiffKto,StoD(Str(Year(dDate),4)+"0101"),dDate,lStapel)
      nDiffSaldo := hSummen:Haben-hSummen:Soll

      hSummen := LX_getSummen(nKonto,StoD(Str(Year(dDate),4)+"0101"),dDate,lStapel)
      nSaldo := hSummen:Haben-hSummen:Soll

      //Alert("Saldo: "+Str(nSaldo)+";"+"Diff"+Str(nDiffSaldo))

      Scroll(03,00,MaxRow(),MaxCol(),-1)
      IF nSaldo == 0
         @ 03,00 SAY "Nicht berechenbar - kein Saldo vorhanden"
      ELSE
         nDiffRate := nDiffSaldo/nSaldo

         @ 03,00 SAY IF(nCur==1,"GBP","USD")
         @ 03,08 SAY DToC(dDate)
         @ 03,17 SAY Transform(nAmount,cPic)
         @ 03,29 SAY lStapel PICTURE "Y"
         @ 03,34 SAY Str(1/(1+nDiffRate),5,2)
         @ 03,40 SAY Transform(nAmount*nDiffRate,cPic)
         @ 03,50 SAY Transform(nAmount+nAmount*nDiffRate,cPic)
      ENDIF*/

      //NEW WAY

      hSummen := LX_getSummen(nKonto,StoD(Str(Year(dDate),4)+"0101"),dDate,lStapel)
      nSaldo := hSummen:Haben-hSummen:Soll
      IF Tr_MsgBox("Saldo zum "+DToC(dDate)+": "+LTrim(Str(nSaldo)),,{"falsch","richtig"})  != 2
         LOOP
      ENDIF
      //Alert("Saldo: "+Str(nSaldo)+";"+"Diff"+Str(nDiffSaldo))



      aKontoBookings := LX_GetAllBookings(Year(dDate),nKonto,lStapel)
      aDiffBookings  := LX_GetAllBookings(Year(dDate),nDiffKto,lStapel)
      dSaldoDate := StoD("")
      nDiffRate  := 0
      nSaldo     := 0
      nX         := 1
      nY         := 1
      nIncome    := 0
      nDiffIncome := 0
      nSumme := 0


      ASort(aKontoBookings,,,{|x,y| x["DATUM"] < y["DATUM"] })
      ASort(aDiffBookings,,,{|x,y| x["DATUM"] < y["DATUM"] })

      bUpdateDiff := {|| 
               DO WHILE nY <= Len(aNewDiff)
                  IF ! HHasKey(aNewDiff[nY],"DIFF")
                     aNewDiff[nY]["DIFF"] := aNewDiff[nY]["NETTO"]*nDiffRate                  
                     aNewDiff[nY][IF(aNewDiff[nY]["HABEN"] == nKonto,"HABEN","SOLL")] := nDiffKto      
                     aNewDiff[nY]["RATE"] := nDiffRate            
                  ENDIF
                  nY++
               ENDDO
            RETURN NIL
         }

      //? Pad("Datum",8),Pad("Saldo",10),Pad("Eingang",9),Pad("WD Eingang",8),Pad("WD Saldo",8),"Faktor"
//MemoEdit(ValToPrg(aKontoBookings))
      FOR EACH hBooking IN aKontoBookings
         IF hBooking["DATUM"] != dSaldoDate //date has changed  
            
            IF ! Empty(dSaldoDate)
               IF nIncome != 0
                  nDiffRate := ((nSaldo*nDiffRate)+nDiffIncome)/(nSaldo+nIncome)
               ENDIF
               //? dSaldoDate,Str(nSaldo+nSumme+nIncome,10,2),Str(nIncome,9,2),Str(nDiffIncome,8,2),Str((nSaldo+nSumme+nIncome)*nDiffRate,8,2),Str(nDiffRate,8,6)
            ENDIF

            Eval(bUpdateDiff)

            dSaldoDate := hBooking["DATUM"]
            nSaldo += nIncome+nSumme
            nIncome := 0
            nSumme  := 0
            nDiffIncome := 0
            
            DO WHILE nX <= Len(aDiffBookings) .AND. aDiffBookings[nX]["DATUM"] <= dSaldoDate
               
               IF __IsFinanz(aDiffBookings[nX],nDiffKto)
                  nDiffIncome += aDiffBookings[nX]["NETTO"]*IF(aDiffBookings[nX]["HABEN"]==nDiffKto,-1,1)
                  Aadd(aNewDiff,aDiffBookings[nX])
                  ATail(aNewDiff)["DIFF"] := aDiffBookings[nX]["NETTO"] 
               ENDIF
               nX++
            ENDDO            
            
         ENDIF
         IF  hBooking["DATUM"] > dDate
            EXIT
         ENDIF
         IF __IsFinanz(hBooking,nKonto)
            nIncome += hBooking["NETTO"]*IF(hBooking["HABEN"]==nKonto,-1,1)
         ELSE
            nSumme += hBooking["NETTO"]*IF(hBooking["HABEN"]==nKonto,-1,1)
            Aadd(aNewDiff,hBooking)
         ENDIF
         
         
      NEXT

      Eval(bUpdateDiff)

      /*Scroll(03,00,MaxRow(),MaxCol(),-1)

      @ 03,00 SAY IF(nCur==1,"GBP","USD")
      @ 03,08 SAY DToC(dDate)
      @ 03,17 SAY Transform(nAmount,cPic)
      @ 03,29 SAY lStapel PICTURE "Y"
      @ 03,34 SAY Str(1/(1+nDiffRate),5,2)
      @ 03,40 SAY Transform(nAmount*nDiffRate,cPic)
      @ 03,50 SAY Transform(nAmount+nAmount*nDiffRate,cPic)
      */
      //Sinkey(0)
      
      StartPrint(,"WD_"+LTrim(Str(nDiffKto))+"_"+DtoS(dDate),"PDF")
      oPdf := getCurrentPrinterObject():Data

      @ 03,00 CLEAR
      //? Pad("Datum",8),Pad("Text",30),Pad("Betrag",9)," ","Saldo"
      oPdf:NewPage()
      oPdf:Bold()
      oPdf:SetFont("Helvetica",,14)
      oPdf:AtSay("Wechselkursdifferenzkonto "+LTrim(Str(nDiffKto))+" "+{"Januar","Februar","M„rz","April","Mai","Juni","Juli","August","September","Oktober","November","Dezember"}[nMonth]+" "+Str(nYear,4))
      oPdf:NewLine(2)
      oPdf:SetFont("Helvetica",,10)
      oPdf:AtSay("Datum")
      oPdf:AtSay("Text",,20)
      oPdf:AtSay("Betrag",,80)
      oPdf:AtSAy("Saldo",,110)
      oPdf:AtSAy("Faktor",,150)
      oPdf:AtSAy("Kurs",,165)
      nSaldo := 0

      bBackground := {||
         IF Int(nL/2) != nL/2
            nRow := oPdf:R2D( oPdf:ReportLine+1 )
            nCol := oPdf:M2X( oPdf:PDFLEFT ) + ;
            oPdf:ReportCol * 100.00 / oPdf:REPORTWIDTH * ;
            ( oPdf:PAGEX - oPdf:M2X( oPdf:PDFLEFT ) * 2 - 9.0 ) / 100.00
            oPdf:Box( oPdf:PAGEY - nRow - oPdf:FONTSIZE + 2.0 , nCol, oPdf:PAGEY  - nRow + 2.0,600,,100, "D",HB_HexToStr("FFBDBDBD"))
         //nCol + oPdf:M2X( oPdf:Len( 100 )) + 1
         ENDIF
         RETURN .T.
      }

      nL := 0

      FOR nY := 1 TO Len(aNewDiff)         
         IF nY > 1 .AND. Month(aNewDiff[nY-1]["DATUM"]) == nMonth-1 .AND. Month(aNewDiff[nY]["DATUM"]) == nMonth
            oPdf:NewLine()
            nL++
            Eval(bBackground)
            oPdf:AtSay( "Saldo Vormonat",,20 )
            oPdf:RJust(Str(nSaldo,10,2),,130)
            
         ENDIF
         IF HHasKey(aNewDiff[nY],"DIFF")
            nSaldo += aNewDiff[nY]["DIFF"]*IF(aNewDiff[nY]["HABEN"]==nDiffKto,1,-1)
         ENDIF
            IF Month(aNewDiff[nY]["DATUM"]) == nMonth .AND. aNewDiff[nY]["DATUM"] <= dDate
               oPdf:NewLine()
               nL++
               Eval(bBackground)
               oPdf:AtSay( Dtoc(aNewDiff[nY]["DATUM"]) )
               oPdf:Atsay(HB_OemToAnsi(Pad(aNewDiff[nY]["TEXT"],30)),,20)
               IF HHasKey(aNewDiff[nY],"DIFF")
                  oPdf:RJust(Str(aNewDiff[nY]["DIFF"],9,2),,95)
               ENDIF
               oPdf:AtSAy(IF(aNewDiff[nY]["SOLL"]==nDiffKto,"S","H"),,100)
               IF HHasKey(aNewDiff[nY],"RATE")
                  oPdf:RJust(Str(aNewDiff[nY]["RATE"],7,4),,160)
                  oPdf:RJust(Str(1+aNewDiff[nY]["RATE"],7,4),,175)
               ENDIF

               //? Dtoc(aNewDiff[nY]["DATUM"]),Pad(aNewDiff[nY]["TEXT"],30),Str(aNewDiff[nY]["DIFF"],9,2),IF(aNewDiff[nY]["SOLL"]==nDiffKto,"S","H")
               
               oPdf:RJust(Str(nSaldo,10,2),,130)
               
               //?? "",Str(nSaldo,10,2)
            ENDIF
         //ENDIF
         
      NEXT
      CopyPrint()
      
   ENDDO

   STATIC FUNCTION __IsFinanz(hBooking,nKonto)
      LOCAL aBookings,nGegenKonto,cSH,aBooking
      IF hBooking["SOLL"] != nKonto 
         nGegenKonto := hBooking["SOLL"]
         cSH := "S"
      ELSEIF hBooking["HABEN"] != nKonto 
         nGegenKonto := hBooking["HABEN"]
         cSH := "S"
      ELSE
         RETURN .F.
      ENDIF
      IF nGegenKonto == 0
         aBookings := LX_GetSplitBooking(hBooking["NR"],hBooking["JAHR"],cSH)
         FOR EACH aBooking IN aBookings
            IF __IsFinanzKonto(aBooking["KONTO"])
               RETURN .T.
            ENDIF
         NEXT
         RETURN .F.
      ENDIF
   RETURN __IsFinanzKonto(nGegenKonto)

   STATIC FUNCTION __IsFinanzKonto(nKonto)
   RETURN nKonto == 9000 .OR. (nKonto >= 1200 .AND. nKonto <= 1299) .OR. nKonto == 1360 //EB Buchung oder Finanzkonto