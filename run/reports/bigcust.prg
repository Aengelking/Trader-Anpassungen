PROC RUN_REPORT_BIGCUST
   LOCAL aChoice,nChoice := 1
   LOCAL nMax := 100
   LOCAL aTurn := {}
   LOCAL cHead
   LOCAL nX,nMaxLen,nPercMax := 0,nTotalPerc,nYear,cYear
   LOCAL nTotal,oPDF,oPrinter,nPerc
   LOCAL getlist := {}

   NetUse("engkund","ku",.F.,0)
   ku->(dbGoTop())   

   Head(HB_AnsiToOem("Umsatzstärksten Kunden"))

   aChoice := {Str(Year(Date()),4)+" mit Umsatz und Anteil",Str(Year(Date()),4)+" mit Anteil",Str(Year(Date())-1,4)+" mit Umsatz und Anteil",Str(Year(Date())-1,4)+" mit Anteil",Str(Year(Date())-2,4)+" mit Umsatz und Anteil",Str(Year(Date())-2,4)+" mit Anteil"}

   @ 01,00,06,20 GET nChoice LISTBOX aChoice
   @ 07,00 SAY "Anzahl     " GET nMax PICTURE "9999" VALID {||
      IF nMax >= 0
         nPercMax := 0
         RETURN .T.
      ENDIF
      RETURN .F.
   }
   @ 08,00 SAY "Bis Prozent" GET nPercMax PICTURE "99" WHEN nMax == 0 VALID nPercMax > 0
   READ

   IF LastKey() == 27
      RETURN
   ENDIF

   cHead := LTrim(Str(nMax))+" Umsatzstaerksten Kunden "

   nYear := Year(Date())
   If nChoice >= 5
      nYear := Year(Date())-2
   Elseif nChoice >= 3
      nYear := Year(Date())-1
   Endif
   cYear := Str(nYear,4)

   Head(cHead+cYear)

   @ 01,00 SAY "Daten werden gesammelt..."
   nTotal := 0
   Do While ! ku->(Eof())
      If ku->Group == "K"		
         hTurn := GetCustomerTurnover(ku->Kunde)
         If HHasKey(hTurn["years"],nYear) .AND. hTurn["years"][nYear] > 0
            Aadd(aTurn,{ku->Kunde,hTurn["years"][nYear]})
            nTotal += hTurn["years"][nYear]
         Endif
      Endif
      ku->(dbSkip())
   Enddo
   aTurn := ASort(aTurn,,,{|x,y| x[2] > y[2] })
   @ 01,00 SAY Space(70)
   @ 00,00 SAY ""

   StartPrint(,"Kundenliste_"+DToC(Date()),"PDF")
   SET DEVICE TO PRINTER
   SET PRINTER ON
   oPrinter := getCurrentPrinterObject()
   oPrinter:Data:HeadFile := Path("\head\engelking_logoonly.pdf")
   oPdf := oPrinter:Data

   oPdf:NewPage("A4","P",6)
   //oPdf:Image(Trim(Tr_Getini(1))+"\images\logo.jpg",1,170,'R',1,33)
   
   oPdf:SetFont("Helvetica",,16); oPdf:Bold()
   oPdf:AtSay("Kundenbestandsliste "+cYear,2.5,0,'R')
   oPdf:SetFont("Helvetica",,11); oPdf:Normal()
   oPdf:AtSay("erstellt am "+DToC(Date()),2.5,80,'R')


   nX := 1
   IF nMax > 0
      nMaxLen := Len(LTrim(Str(nMax)))
   ELSE
      nMaxLen := 4
   ENDIF
   nTotalPerc := 0
   oPdf:NewLine()
   oPdf:NewLine()   
   oPdf:AtSay("Matchcode",,07,"R" )
   oPdf:AtSay("Kunde",,40,"R" )
   oPdf:Rjust("Prozent",,135 ,"R" )
   If nChoice == 1 .OR. nChoice == 3 .OR. nChoice == 5
      oPdf:RJust("Euro",,180,"R" )
   Endif

   While nX <= Len(aTurn)
      IF (nMax > 0 .AND. nX > nMax) .OR. (nPercMax > 0 .AND. nTotalPerc > nPercMax )
         EXIT
      ENDIF         
      ku->(dbSeek(aTurn[nX,1]+"K"))
      oPdf:NewLine()
      oPdf:RJust(HB_OemtoAnsi( Str(nX,nMaxLen)+"." ),,05)
      oPdf:AtSay(HB_OemtoAnsi( ku->Kunde),,07,"R" )
      oPdf:AtSay(HB_OemtoAnsi( ku->Name1),,40,"R" )

      nPerc := aTurn[nX,2]/nTotal*100
      nTotalPerc += nPerc
      oPdf:Rjust(HB_OemtoAnsi( Str( nPerc  ,12,2)+"%"),,135 ,"R" )
      If nChoice == 1 .OR. nChoice == 3 .OR. nChoice == 5
         oPdf:RJust(HB_OemtoAnsi( Transform(aTurn[nX,2],"@E 999,999")),,180,"R" )
      Endif

      

      nX++
   Enddo
   oPdf:NewLine();oPdf:RJust(HB_OemtoAnsi( Str( nTotalPerc  ,12,2)+"%"),,135,"R" )

   EJECT
   CopyPrint()
   SET DEVICE TO SCREEN
   SET PRINTER OFF
