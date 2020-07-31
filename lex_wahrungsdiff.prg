PROCEDURE RUN_LEX_WAEHRUNGSDIFF
   LOCAL nYear := Year(Date())-1,dDate
   LOCAL nStart_CurUpd := 2014
   LOCAL aKonten := {}
   LOCAL nX
   LOCAL nKtoSaldo,nNewSaldo,nDifSaldo
   LOCAL getlist := {}
   LOCAL nErtragKto := 2660
   LOCAL nAufwandKto := 2150 

   Head(t("W„hrungsdifferenzen berrechnen"))

   NetUse("engrech","rech")

   @ 01,00 SAY "Jahr" GET nYear PICTURE "9999"
   READ 

   IF LastKey() == 27
      RETURN
   ENDIF

   IF nYear == 2017
      hCur := {"U"=>Round(1/1.1993,4),"P"=>Round(1/0.88723,4),"Y"=>1/135.01}
   ELSEIF nYear == 2018
      hCur := {"U"=>Round(1/1.145,4),"P"=>Round(1/0.89453,4)}
   ELSEIF nYear == 2019
      hCur := {"U"=>Round(1/1.1234,4),"P"=>Round(1/0.8508,4)}
   ELSE
      Alert("W„hrungskurse in der Datenbank mssen 4 Nachkommastellen haben. Bitte Wechselkurs in der PRG hinterlegen.")
      RETURN
   ENDIF

   dDate := Eom(SToD(Str(nYear,4)+StrZero(12,2)+"01"))


   //Devisenkonten (manuelle Liste)
   Aadd(aKonten,{1235,1236,"U","Sparkasse USD"})
   Aadd(aKonten,{1231,1232,"P","Spaskasse GBP"})
   Aadd(aKonten,{1237,1238,"U","Volksbank USD"})

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
         ELSEIF (aKonten[nX,2] >= 70000 .AND. nDifSaldo-nNewSaldo>0) .OR. (aKonten[nX,2] < 70000 .AND. nDifSaldo-nNewSaldo<0)
            ?? Str(aKonten[nX,2],6),Str(nErtragKto,6),Str((nDifSaldo-nNewSaldo)*IF(aKonten[nX,2] < 70000,-1,1),9,2)            
         ELSE
            ?? Str(nAufwandKto,6),Str(aKonten[nX,2],6),Str((nDifSaldo-nNewSaldo)*IF(aKonten[nX,2] < 70000,1,-1),9,2)
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
      
Sinkey(0)
   