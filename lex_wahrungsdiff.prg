PROCEDURE RUN_LEX_WAEHRUNGSDIFF
   LOCAL nYear := Year(Date())-1,dDate,dDateNY
   LOCAL nStart_CurUpd := 2014
   LOCAL aKonten := {}
   LOCAL nX
   LOCAL nKtoSaldo,nNewSaldo,nDifSaldo
   LOCAL getlist := {}
   LOCAL nErtragKto := 2660
   LOCAL nAufwandKto := 2150 
   LOCAL aBookings := {{"Belegdatum","Buchungsperiode","Belegnummer","Buchungstext","Sollkonto","Habenkonto","Buchungsbetrag"}}
   LOCAL aBookings2 := AClone(aBookings)
   LOCAL cBeleg := Space(15)
   LOCAL nSoll,nHaben,nValue
   LOCAL nSoll2,nHaben2,nValue2
   LOCAL hCur

   Head(t("W„hrungsdifferenzen berrechnen"))

   LX_Start()

   NetUse("engrech","rech")

   @ 01,00 SAY "Jahr       " GET nYear PICTURE "9999"
   @ 02,00 SAY "Belegnummer" GET cBeleg 
   READ 

   IF LastKey() == 27
      RETURN
   ENDIF

   IF nYear == 2017
      hCur := {"U"=>Round(1/1.1993,4),"P"=>Round(1/0.88723,4),"Y"=>1/135.01}
   ELSEIF nYear == 2018
      hCur := {"U"=>Round(1/1.145,4),"P"=>Round(1/0.89453,4)}
   ELSEIF nYear == 2019
      hCur := {"U"=>Round(1/1.1228,4),"P"=>Round(1/0.8501,4)}
   ELSEIF nYear == 2020
      hCur := {"U"=>Round(1/1.2275,4),"P"=>Round(1/0.89955,4)}
   ELSEIF nYear == 2021
      hCur := {"U"=>Round(1/1.1320,4),"P"=>Round(1/0.84000,4),"Y"=>Round(1/130.32,4)}
   ELSEIF nYear == 2022
      hCur := {"U"=>Round(1/1.0676,4),"P"=>Round(1/0.88680,4),"Y"=>Round(1/140.68,4)}
   ELSEIF nYear == 2023
      hCur := {"U"=>Round(1/1.1077,4),"P"=>Round(1/0.86910,4),"Y"=>Round(1/156.81,4)}
   ELSEIF nYear == 2024
      hCur := {"U"=>Round(1/1.0411,4),"P"=>Round(1/0.82831,4),"Y"=>Round(1/163.01,4)}
   ELSE
      Alert("Bitte Wechselkurs in lex_wahrungsdiff.prg hinterlegen. Devisenmittelkurs z.B. von der Commerzbank")
      //https://www.commerzbank.de/konzern/service/kursinformationen/devisenmarktkurse/
      RETURN
   ENDIF

   dDate := Eom(SToD(Str(nYear,4)+StrZero(12,2)+"01"))
   dDateNY := SToD(Str(nYear+1,4)+StrZero(01,2)+"01")

   //Devisenkonten (manuelle Liste)
   Aadd(aKonten,{1235,1236,"U","Sparkasse USD"})
   Aadd(aKonten,{1231,1232,"P","Spaskasse GBP"})  

   Aadd(aKonten,{1237,1238,"U","Volksbank USD"})
   Aadd(aKonten,{1222,1223,"P","Volksbank GBP"})
   Aadd(aKonten,{1226,1227,"Y","Volksbank JPY"})

   //Alle verwendeten W„hrungsdifferenzkonten (Kreditoren) suchen
   rech->(dbSetOrder( 3 ))
   rech->(dbSeek( Str(nStart_CurUpd,4)+"0101" ,.T.))
   DO WHILE Year(rech->Rechdat) >= nStart_CurUpd
      IF rech->CurKonto != 0 .AND. AScan(aKonten,{|x| x[1] == rech->Konto .AND. x[2] == rech->CurKonto }) == 0
         Aadd(aKonten,{rech->Konto,rech->Curkonto,rech->Money,rech->Liefma})
      ENDIF
      rech->(dbSkip())
   ENDDO 


   
   CLS
   ? "Beleg-Nr.: "+cBeleg
   ? "Berechnung W„hrungsdifferenzen nach Par. 256a HGB zum "+DtoC(dDate)
   ? Space(6+1+9+4+1+9+1+9+1+9),"Buchung"
   ? Pad("Konto",6),Pad("Saldo",9+4),Pad("Kurs",9),Pad("WD alt",9),Pad("WD neu",9),Pad("Soll",6),Pad("Haben",6),Pad("Betrag",9)

   FOR nX := 1 TO Len(aKonten)
      nKtoSaldo := LX_GetSaldo(aKonten[nX,1],dDate)
      nDifSaldo := LX_GetSaldo(aKonten[nX,2],dDate)
      IF (nKtoSaldo != 0 .OR. nDifSaldo != 0) 
         nNewSaldo := nKtoSaldo*hCur[aKonten[nX,3]]-nKtoSaldo  //Currate(aKonten[nX,3],"E",dDate)
   
         //.AND. Round(nDifSaldo,2) != Round(nNewSaldo,2) .AND. (ABS(nNewSaldo-nDifSaldo) > 5 .OR. dDate > AddMonth(Date(),-12)) //muss berichtigt werden und innerhalb der letzten 12 Monate oder größer als 5€
         ? Str(aKonten[nX,1],6),Str(nKtoSaldo,9,2),Currate(aKonten[nX,3],"X"),Str(hCur[aKonten[nX,3]],9,4),Str(nDifSaldo,9,2),Str(nNewSaldo,9,2),""
         IF Round(nDifSaldo-nNewSaldo,2) == 0
            ?? "---"
            nValue := 0
         ELSEIF (aKonten[nX,2] >= 70000 .AND. nDifSaldo-nNewSaldo>0) .OR. (aKonten[nX,2] < 70000 .AND. nDifSaldo-nNewSaldo<0)
            nSoll := aKonten[nX,2]
            nHaben := nErtragKto
            nValue := (nDifSaldo-nNewSaldo)*IF(aKonten[nX,2] < 70000,-1,1)
            nHaben2 := aKonten[nX,1]
            nSoll2 := aKonten[nX,2]
            nValue2 := nNewSaldo*IF(aKonten[nX,2] < 70000,-1,1)
         ELSE
            nSoll := nAufwandKto
            nHaben := aKonten[nX,2]
            nValue := (nDifSaldo-nNewSaldo)*IF(aKonten[nX,2] < 70000,1,-1)

            nHaben2 := aKonten[nX,2]
            nSoll2 := aKonten[nX,1]
            nValue2 := nNewSaldo*IF(aKonten[nX,2] < 70000,1,-1)
         ENDIF
         IF nValue != 0
            Aadd(aBookings,{dDate,13,Trim(cBeleg),"Anpassung W„hrungsdifferenz Par.256a HGB",nSoll,nHaben,Round(nValue,2)})
            

            ?? Str(nSoll,6),Str(nHaben,6),Str(nValue,9,2)
            
         ENDIF
         IF nValue2 != 0
            cText := "Umbuchung W„hrungsdifferenz"
            IF nSoll2 < 70000 .AND. nHaben2 < 70000 //Finanzkonten k”nnen direkt miteinander verbucht werden.
               Aadd(aBookings,{dDate,13,"",cText,nSoll2,nHaben2,Round(nValue2,2)})
               Aadd(aBookings2,{dDateNY,1,"",cText,nHaben2,nSoll2,Round(nValue2,2)})
            ELSE
               Aadd(aBookings,{dDate,13,"",cText,nSoll2,1590,Round(nValue2,2)})
               Aadd(aBookings2,{dDateNY,1,"",cText,1590,nSoll2,Round(nValue2,2)})
               Aadd(aBookings,{dDate,13,"",cText,1590,nHaben2,Round(nValue2,2)})
               Aadd(aBookings2,{dDateNY,1,"",cText,nHaben2,1590,Round(nValue2,2)})
            ENDIF
         ENDIF
         /*ku->(dbSetOrder( 1 ))
         ku->(dbSeek( aKonten[nX,4]+"L" ))
         @ nR,35 SAY ku->Kunde
           IF ku->TaxCode == 3
               vat->(dbGoTo(ku->TaxCode))
               cKonto := AllTrim(vat->EkNeu)
            ELSEIF ku->TaxCode == 0
               cKonto := AllTrim(LX_GetConfigValue("KONTEN","WareneingangOhneUSt"))
            ELSE
               FWrite(nPH,"*** Falsches Wareneingangskonto "+LTrim(Str(aKonten[nX,1]))+" "+ku->Kunde)
               FWrite(nPH,CRLF)
               cKonto := ""
            ENDIF

            IF ! Empty(cKonto)
                  hData := {=>}
                  hData:cBelegNr      := ""
                  hData:dBelegDate    := dDate
                  hData:dBookDate     := Date()
                  hData:cText         := HB_AnsiToOem("Aktualisierung Währungdifferenz")

                  hData:nHaben        := Val(cKonto)
                  hData:nSoll         := aKonten[nX,2]

                  hData:nBrutto       := Round(nDifSaldo-nNewSaldo,2)
                  hData:nKundenLiefnr := ku->Nummer
                  hData:cMatchcode    := Trim(ku->Kunde)

                  hData:cBelegKreis   := NIL

                  IF ! LX_CreateBooking(hData,.F.)  //Buchung erzeugen, keine OP
                        FWrite(nPH,"**** FEHLER BEIM BUCHEN "+LX_GetErrorMessage())
                        FWrite(nPH,CRLF)
                        //Return .F.
                  ENDIF

                  FWrite(nPH,"Währungsdifferenz "+Str(aKonten[nX,1],6)+": "+DToC(dDate)+" Saldo ("+Str(aKonten[nX,2],6)+") neu: "+Str(nNewSaldo,9,2)+" Differenz: "+Str(nDifSaldo-nNewSaldo,9,2)+" Konto: "+Str(nKtoSaldo,9,2))
                  FWrite(nPH,CRLF)
               //ENDIF
            ENDIF
         ELSE
            //FWrite(nPH,"*** Währungsdifferenz (nicht berichtigt)"+Str(aKonten[nX,1],6)+": "+DToC(dDate)+" Saldo ("+Str(aKonten[nX,2],6)+") neu: "+Str(nNewSaldo,9,2)+" Differenz: "+Str(nDifSaldo-nNewSaldo,9,2)+" Konto: "+Str(nKtoSaldo,9,2))
         ENDIF*/
      ENDIF
   NEXT  
   
   PRTSCR()
   TxtBox("Buchungen WJ "+Str(nYear,4))
   SaveASCsvInterface(aBookings)
   TxtClear()
   TxtBox("Buchungen WJ "+Str(nYear+1,4))
   SaveASCsvInterface(aBookings2)
   TxtClear()
Sinkey(0)
   