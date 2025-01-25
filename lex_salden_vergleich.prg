PROC LX_SALDEN_VERGLEICH
   LOCAL oPdf
   LOCAL hSummen1,hSummen2
   LOCAL hWD1,hWD2
   LOCAL dStart1,dEnd1,dStart2,dEnd2
   LOCAL nTotal1 := 0,nTotal2 := 0
   LOCAL cPic := "@E 9,999,999.99"
   LOCAL hKonten := {=>},hKonto,hTurnover,cR

   LOCAL hXLSX := {=>},aData
   

   NetUse("fibu","fibu")
   netUse("engkund","ku")
   NetUse("engrech","rech")

   Head("Lexware Kontost„nde vergleichen")

   IF ! LX_Start()
      Alert("Keine Verbindung zu Lexware")
      Return
   ENDIF

   fibu->(dbSetOrder( 3 ))
   fibu->(dbGoTop())

   dStart1 := BoY(Date())
   dEnd1   := Date()

   dStart2 := BoY(Date()-365)
   dEnd2   := Date()-365

   /*StartPrint(,,"PDF")
   oPdf := GetCurrentPrinterObject():Data

   oPdf:NewPage()
   oPdf:SetFont("Courier-Bold",0,14)
   oPdf:AtSay("Jahresvergleich Kreditorenkonten")
   oPdf:SetFont("Courier",0,12)
   oPdf:NewLine()
   oPdf:AtSay(PadL("Konto",6)+" "+Space(35)+" "+PadL(Str(Year(dStart1),4),12)+" "+PadL(Str(Year(dStart2),4),12)+" "+PAdL("%",7))
*/
   aData := {{"Konto","Kontoname",Str(Year(dStart1),4),Str(Year(dStart2),4),"Ver„nderung"}}

   DO WHILE ! fibu->(EOF()) .AND. Inkey() != 27

      
      hSummen1 := LX_GetSummen(fibu->Konto,dStart1,dEnd1,.T.,.T.)
      hSummen2 := LX_GetSummen(fibu->Konto,dStart2,dEnd2,.T.,.T.)
      IF hSummen1:Haben != 0 .OR. hSummen2:Haben != 0
         hSummen1:Haben -= hSummen1:UstHaben

         hSummen1:Haben -= __EBWert(fibu->Konto,dStart1)
         hSummen2:Haben -= __EBWert(fibu->Konto,dStart2)

         IF fibu->CurKonto != 0
            hWD1 := LX_GetSummen(fibu->CurKonto,dStart1,dEnd1,.T.,.T.)
            hWD2 := LX_GetSummen(fibu->CurKonto,dStart2,dEnd2,.T.,.T.)
            hSummen1:Haben += hWD1:Haben-__EBWert(fibu->CurKonto,dStart1)
            hSummen2:Haben += hWD2:Haben-__EBWert(fibu->CurKonto,dStart2)
         ENDIF
         
         

         ? fibu->Konto,Pad(LX_GetAccountName(fibu->Konto),50),hSummen1:Haben,hSummen2:Haben,hSummen1:UstHaben,hSummen2:UstHaben
         nTotal1 += hSummen1:Haben-hSummen1:UstHaben
         nTotal2 += hSummen2:Haben-hSummen2:UstHaben
         hKonten[fibu->Konto] := {"NAME"=>LX_GetAccountName(fibu->Konto),"SUMME1"=>hSummen1:Haben,"SUMME2"=>hSummen2:Haben}
         //oPdf:NewLine()
         //oPdf:AtSay(Str(fibu->Konto,6)+" "+Pad(LX_GetAccountName(fibu->Konto),35)+" "+Transform(hSummen1:Haben,cPic)+" "+Transform(hSummen2:Haben,cPic)+" "+IF(hSummen2:Haben>0,Transform((hSummen1:Haben-hSummen2:Haben)/hSummen2:Haben*100,"@E 9999.99"),""))

         cR := LTrim(Str(Len(aData)+1))
         Aadd(aData,{fibu->Konto,LX_GetAccountName(fibu->Konto),hSummen1:Haben,hSummen2:Haben,"=C"+cR+"-D"+cR})
      ENDIF
      fibu->(dbSkip())
   ENDDO
   /*oPdf:NewLine()
   oPdf:AtSay(Space(6)+" "+Space(35)+" "+Replicate("_",12)+" "+Replicate("_",12))
   oPdf:NewLine()
   oPdf:AtSay(Space(6)+" "+Space(35)+" "+Transform(nTotal1,cPic)+" "+Transform(nTotal2,cPic)+" "+IF(nTotal2>0,Transform((nTotal1-nTotal2)/nTotal2*100,"@E 9999.9"),""))   
*/
   Aadd(aData,{})
   cR := LTrim(Str(Len(aData)-1))
   Aadd(aData,{,,"=SUMME(C2:C"+cR+")","=SUMME(D2:D"+cR+")"})

   hXLSX["Jahresvergleich"] := aData
   SaveToOO_Interface(hXLSX,,"XLSX",.T.)
   /*aData := {}
   

   oPdf:NewPage()
   oPdf:AtSay("Vergleich Kreditorenkonten - Trader")
   oPdf:NewLine()
   oPdf:AtSay(PadL("Konto",6)+" "+Space(35)+" "+PadL("Lexware",12)+" "+PadL("Trader",12)+" "+PAdL("%",7))
   
   nTotal1 := 0
   nTotal2 := 0
   
   FOR EACH hKonto IN hKonten
      fibu->(dbSetOrder(2))
      ku->(dbSetOrder( 8 ))
      fibu->(dbSeek( Str(hKonto:__eNumKey(),6) ))
      ku->(dbSeek( Str(fibu->Adresse,6) ))
      rech->(dbsetOrder(1))
      rech->(dbSeek( ku->Kunde+DtoS(dStart1),.T. ))

      nValue := 0
      Do While ! rech->(EOF()) .AND. rech->liefma == ku->Kunde
         If rech->Booked
            nValue +=  (rech->netamt+rech->Porto)*currate(rech->money,"E",rech->RechDat)
         ENDIF  
         rech->(dbSkip())
      ENDDO
    
    
      //hTurnover := GetSupplierTurnover(ku->Kunde)
      //hTurnover["current"]

      oPdf:NewLine()
      oPdf:AtSay(Str(hKonto:__eNumKey(),6)+" "+Pad(hKonto:Name,35)+" "+Transform(hKonto:Summe1,cPic)+" "+Transform(nValue,cPic)+" "+IF(nValue>0,Transform((hKonto:summe1)/nValue*100,"@E 9999.99"),"9999.99"))
      nTotal1 += hKonto:Summe1
      nTotal2 += nValue //hTurnover["current"]
   NEXT
   oPdf:NewLine()
   oPdf:AtSay(Space(6)+" "+Space(35)+" "+Replicate("_",12)+" "+Replicate("_",12))
   oPdf:NewLine()
   oPdf:AtSay(Space(6)+" "+Space(35)+" "+Transform(nTotal1,cPic)+" "+Transform(nTotal2,cPic)) //+" "+IF(nTotal2>0,Transform((nTotal1-nTotal2)/nTotal2*100,"@E 9999.9"),"9999.99"))
   hXLSX["Lexware-Trader"] := aData*/

   //CopyPrint()
   LX_Close()

   //SaveToOO(aData)

   Sinkey(0)
/*






   @ 10,00 SAY "Offeneposten"

   FOR EACH nKonto IN aKonten
      //nKonto := nSumme:__eNumKey()
      IF HHasKey(hOps,nKonto)
         nSumme := hOps[nKonto]
      ELSE
         nSumme := 0
      ENDIF
      @ 10,13 SAY nKonto
      //IF ! fibu->(dbSeek( Str(nKonto,6) )) //Währungsdifferenzkonten ignorieren, da diese sowieso zum Monatsende abgelichen werden und dadurch auch Differenzen zwischen OP und Kreditorenkten entstehen können
         nLXSaldo := LX_GetSaldo(nKonto,dEoY)
         hSummen := LX_GetSummen(nKonto,StoD("20000101"),dEoY,.T.,.F.) //all bookings in the stapel
         nLXSaldo += hSummen:Haben-hSummen:Haben
         IF Abs(nLxSaldo-nSumme) >  0.03 .OR.;
            nLXSaldo == 0 .AND. nSumme != 0
            oPdf:NewLine()
            oPdf:AtSay(Str(nKonto,6)+" "+Pad(LX_GetAccountName(nKonto),30)+" "+Str(nSumme,10,2)+" "+Str(nLxSaldo,10,2))
         ENDIF
      //ENDIF
   NEXT*/

   STATIC FUNCTION __EBWert(nKonto,dDate)
      LOCAL nEB := 0
      LOCAL aBookings := LX_GetAllBookings(Year(dDate),nKonto,.T.)
      LOCAL nX
      FOR nX := 1 TO Len(aBookings)
         IF aBookings[nX]:Soll >= 9000 .AND. aBookings[nX]:Soll <= 9999
            nEB += aBookings[nX]:Netto
         ENDIF
      NEXT
   RETURN nEB