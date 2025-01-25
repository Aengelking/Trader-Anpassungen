#define CRLF Chr(13)+Chr(10)
PROC LX_Correct_WD()
   LOCAL dStart := Stod("20230301")
   //LOCAL dEnd := EoM(dStart) 
   LOCAL dEnd := EoY(dStart)
   //LOCAL dEnd := Date()
   LOCAL nAmount,aBookings,nX,dPayDate
   LOCAL nNew,hData,cKonto
   LOCAL cList := ""
   NetUse("engrech","rech")
   NetUse("reb","reb")
   NetUse("engkund","ku")
   NetUse("vat","vat",.F.,0)

   CLS   
   LX_Start()

   rech->(dbSetOrder( 3 ))
   IF rech->(dbSeek( DToS(dStart),.T. ))
      //? "Keine Rechnung gefunden"
   ENDIF

   reb->(dbSetOrder( 2 ))
   ku->(dbSetOrder( 1 ))
   
   Do While rech->RechDat >= dStart .AND. ! rech->(EOF()) .AND. rech->Rechdat <= dEnd
      //? rech->Rechdat,URRATE(rech->Money,"X") 
      If rech->Transfer .AND. rech->Booked .AND. rech->CurKonto != 0 .AND. rech->Money == "U" .AND. rech->GrAmt > 0 //.AND. rech->Payme != 0 
         ku->(dbSeek( rech->Liefma+"L" ))

         @ 24,00 SAY rech->Liefma+" "+rech->Rechnr

                  
         
         reb->(dbSeek( Str(ku->Nummer,6)+rech->rechnr ))
         


         aBookings := LX_GetBookingsForID("ER"+Str(reb->ID,9))
         nAmount := 0
         dPayDate := Stod("")
         FOR nX := 1 TO Len(aBookings)
            IF aBookings[nX,"HABEN"] == rech->CurKonto
               nAmount += aBookings[nX,"NETTO"]
            ELSEIF Left(LTrim(Str(aBookings[nX,"HABEN"])),2) == "12"
               dPayDate := aBookings[nX,"DATUM"]
            ENDIF
         NEXT

         nNew := Round(rech->GrAmt*(CURRATE(rech->Money,"E",rech->Rechdat)-1),2)


         IF nNew != Round(nAmount,2)
            cList += DtoC(rech->Rechdat)+" "+rech->Liefma+" "+rech->Rechnr+" #ER"+Str(reb->ID,9)
            cList += " "+Str(nAmount,12,2)
            cList += " "+Str(nNew,12,2) //dPayDate
               
   
            //? "Create booking"
            lEG := .F.
            If rech->steuer > 0
               vat->(dbGoTo(rech->Steuer))
               IF rech->Rechdat >= vat->Date
                  cKonto := AllTrim(vat->EkNeu)
               ELSE
                  cKonto := AllTrim(vat->EkAlt)
               ENDIF
               lEG    := Alltrim(Upper(vat->text)) == "EG"
            Else
               cKonto := AllTrim(LX_GetConfigValue("KONTEN","WareneingangOhneUSt"))
            Endif

            hData := {=>}
            hData:cBelegNr      := rech->rechnr
            hData:dBelegDate    := rech->rechdat
            hData:dBookDate     := Date()
            hData:cText         := "Rechnung"+" "+Trim(rech->rechnr)+IF(reb->(dbSeek( Str(ku->Nummer,6)+rech->rechnr ))," #ER"+Str(reb->ID,9),"")         
            
            hData:nSoll         := Val(cKonto)            
            hData:nHaben        := rech->CurKonto

            //zur Korrektur
            /*hData:nSoll         := rech->CurKonto
            hData:nHaben        := 2151*/

            IF rech->Skonto != 0
               hData:nSkonto             :=  rech->Skonto
               hData:nZahlungsziel       := rech->Wait
               hData:nZahlungszielSkonto := rech->WaitSkonto
            ELSE
               hData:nSkonto             :=  0
               hData:nZahlungsziel       := rech->WaitSkonto
               hData:nZahlungszielSkonto := 0
            ENDIF

            If ValType(LX_GetConfigValue("BELEGKREISE","ER")) == "C"
               hData:cBelegKreis := AllTrim(LX_GetConfigValue("BELEGKREISE","ER"))
            Endif          
            

            hData:nBrutto  := nNew-nAmount
            //hData:nBrutto  := nNew
            hData:cText    := HB_AnsiToOem("Währungsdifferenz ")+hData:cText
            //deactivate for testing
            /*IF ! LX_CreateBooking(hData,.T.) //,rech->Payme==0)
               cList += " Fehler beim Eintragen der Währungsdifferenz"               
            ENDIF*/
            IF lEG
               cList += "EG !!!!"
            ENDIF
            cList += CRLF
            gtsetClipBoard(cList)
         ENDIF
         

         
      ENDIF
      rech->(dbSkip())
   ENDDO

   ? "I'm done"
   Sinkey(0)
   