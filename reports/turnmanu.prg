PROCEDURE RUN_REPORT_TURNMANU
LOCAL cFile := Trim(Tr_Getini(1))+"\export\customer_per_manufacturer.csv"
LOCAL nYear,dStartDate,nCur,cKunde,stat_val
LOCAL aList := {}
LOCAL nCurYear := Year(Date())
LOCAL getlist := {}
LOCAL aManu,nManu

NETUSE( "englsre", "re" , .F., 5 )
NetUse( "artikel", "art", .F., 0 )
NetUse( "engkund", "ku" , .F., 0 )
NetUse( "manufact","man", .F., 0 )

Head("Umsatz Hersteller pro Kunde")

@ 01,00 SAY "Jahr" GET nCurYear PICTURE "9999" VALID nCurYear >= 2000 .AND. nCurYear <= Year(Date())
READ

IF LastKey() == 27
   RETURN
ENDIF

nH := FCreate(cFile)
IF nH < 0
   Alert(t("Datei "+cFile+" konnte nicht geöffnet werden"))
   RETURN
ENDIF


aManu := GetManufacturerArray()

hCustomers := {=>}

SetColor(c_five)
@ 07,05 CLEAR TO 09,56
@ 07,05 TO 09,56
@ 08,06 SAY "Ausgangsrechnungen "

nCur := 1
//dStartDate := AddMonth(Date(),-12)
//dStartDate := SToD(Str(Year(dStartDate),4)+StrZero(Month(dStartDate),2)+"01")
dStartDate := SToD(Str(nCurYear-1,4)+"0101")

//dStartDate := StoD("20161110") //for testing

art->(dbSetOrder(1))

re->(dbSetFilter({|| re->Reposnr != 0 .AND. re->AoQty != 0 .AND. re->poswt != 0},"reposnr != 0 .AND. poswt != 0 .AND. aoqty != 0"))
re->(dbSetOrder( 9 )) //Dtos(rechdat)+kunde
re->(dbSeek( DToS(dStartDate) ,.T. ))

nEskaDif := 0

DO while ! re->(eof()) .AND. re->RechDat <= StoD(Str(nCurYear,4)+"1231") //.AND. re->reposnr != 0 //.AND. nCur <= 500
   art->(dbSeek( re->Matchcode ))

   If /*re->rechdat >= dStartDate*/ /*re->Reposnr != 0 .AND.*/ art->Lagerart// ONLY PRINTED INVOICES AND last 12 months
      cKunde := re->Kunde

      IF ! HHasKey(hCustomers,cKunde)
         hCustomers[cKunde] := {=>}
         hCustomers[cKunde]["YEARS"] := {=>}
         FOR nYear := Year(dStartdate) TO nCurYear
            hCustomers[cKunde]["YEARS"][Str(nYear,4)] := 0
            hCustomers[cKunde]["YEARS"][Str(nYear,4)+"YTD"] := 0
         NEXT
         hCustomers[cKunde]["MAN"] := Array(Len(aManu[1]))
         AEval(hCustomers[cKunde]["MAN"],{|x,n| hCustomers[cKunde]["MAN"][n] := {0,0} } )
      ENDIF
      nCur ++
      
      @ 08,26 SAY Str(nCur,12)+" "+DtoC(re->Rechdat)

      stat_val := re->poswt * Currate(re->Money,"V")     // NET VALUE
      IF Trim(cKunde) == "FP"
         Aadd(aList,{re->Rechnr,art->Matchcode,stat_val})
      ENDIF

      nManu := AScan(aManu[1],{|x| x==art->Manufactur})
      IF nManu == 0
         Alert("Manufacturer not found "+art->Artikel+Str(art->Manufactur))
      ENDIF
      man->(dbSeek( Str(art->Manufactur,5) ))
      nBuyVal := 0
      IF ku->(dbSeek( Str(man->Address,6) ))
         hPrice := GetBuyPrice(ku->Kunde,art->Artikelnr,re->AOQty,0,1)
         nBuyVal := re->AoQty*hPrice["price"]/hPrice["unit"]
      ENDIF
      IF nBuyVal == 0
         nBuyVal := re->AoQty*art->avpreis/art->pe
      ENDIF
      
      hCustomers[cKunde]["YEARS"][Str(Year(re->Rechdat),4)] += stat_val
      IF Month(re->Rechdat) < Month(Date()) .OR. (Month(re->Rechdat)==Month(Date()) .AND. Day(re->Rechdat) <= Day(Date()))
         hCustomers[cKunde]["YEARS"][Str(Year(re->Rechdat),4)+"YTD"] += stat_val
      ENDIF
      IF Year(re->Rechdat) == nCurYear
         hCustomers[cKunde]["MAN"][nManu][1] += stat_val
         hCustomers[cKunde]["MAN"][nManu][2] += nBuyVal
      ENDIF
   ENDIF


   re->(dbSkip( 1 ))
ENDDO



FClose(nH)

SaveAsCSV("X:\export\fp_sales.csv",aList)


SET PRINTER TO (cFile)
SET CONSOLE OFF
SET PRINTER ON


?? Replicate(Chr(59),3+(nCurYear-Year(dStartdate)+1)*2+1)+Str(nCurYear,4)
? "#"+Chr(59)+"Customer"+Chr(59)+"Place"+Chr(59)+"Country"

FOR nYear := Year(dStartdate) TO nCurYear
   ?? Chr(59)+Str(nYear,4)
   ?? Chr(59)+Str(nYear,4)+" YTD"
NEXT

nX := 1
Do While nX < Len(aManu[2])
   ?? Chr(59)+Trim(aManu[2][nX])+Chr(59)+Trim(aManu[2][nX])+" buy"
   nX++
Enddo

ku->(dbSetOrder(1))

nX := 1
Do While nX < Len(hCustomers)
   cKunde := HGetKeyAt(hCustomers,nX)
   nManu := 1
   //If AScan(hCustomers[cKunde],{|x| x[1] != 0 .OR. x[2] != 0}) != 0
// If AScan(hCustomers[cKunde],{|x| x != 0 }) != 0
      ku->(dbSeek( cKunde+"K" ))
      ? LTrim(Str(ku->Nummer))+Chr(59)+HB_OemToAnsi(Trim(Trim(ku->Name1)+" "+ku->Name2))+Chr(59)+HB_OemToAnsi(Trim(ku->Town))+Chr(59)+HB_OemToAnsi(Trim(GetCountryName(ku->CountryIso)))
      
      FOR nYear := Year(dStartdate) TO nCurYear
         ?? Chr(59)+LTrim(StrTran(Str(hCustomers[cKunde]["YEARS"][Str(nYear,4)],12,2),".",","))
         ?? Chr(59)+LTrim(StrTran(Str(hCustomers[cKunde]["YEARS"][Str(nYear,4)+"YTD"],12,2),".",","))
      NEXT

      Do While nManu < Len(hCustomers[cKunde]["MAN"])
             //?? Chr(59)+LTrim(StrTran(Str(hCustomers[cKunde][nManu],12,2),".",","))
         ?? Chr(59)+LTrim(StrTran(Str(hCustomers[cKunde]["MAN"][nManu][1],12,2),".",","))
         ?? Chr(59)+LTrim(StrTran(Str(hCustomers[cKunde]["MAN"][nManu][2],12,2),".",","))
         nManu++
      Enddo
   //Endif
   nX++
Enddo



SET PRINTER TO
SET PRINTER OFF
SET CONSOLE ON

Wapi_ShellExecute(,"open",cFile)

//MemoEdit(ValtoPrg(hCustomers))


//TxtBox('done')
//Inkey(0,128)

/*StartPrint(,"TurnoverDevelopment","PDF")
oPrinter := GetCurrentPrinterObject()
oPdf := oPrinter:Data
oPdf:NewPage("A4","P",6)
oPdf:SetFont("HELVETICA",0,12)
oPdf:AtSay("Umsatzentwicklung letzte "+Ltrim(Str(nMonths))+" Monate, "+DtoC(Date()))
oPdf:NewLine()
oPdf:SetFont("HELVETICA",0,10)
oPdf:AtSay("Die angegebene Umsatszahl ist ein durchschnittlicher Monatsumatz.")
oPdf:NewLine()
oPdf:SetFont("COURIER")
oPdf:AtSay("Kunde",,10)
oPdf:AtSay("Anzahl",,30)
oPdf:AtSay("12 Monate",,50)
oPdf:AtSay(Ltrim(Str(nMonths))+" Monate",,100)
oPdf:AtSay("%",,150)
nX := 1
Do While nX <= Len(hCustomers)
   hCust := HGetValueAt(hCustomers,nX)
   //? HGetKeyAt(hCustomers,nX),hCust["last12"]/nDays*30,hCust["last2"]/nDaysShort
   If hCust["last12"] > 0 //.AND. hCust["count12"] > 3
      nDiff := hCust["last2"]/nDaysShort - hCust["last12"]/nDays
      nPerc := nDiff/(hCust["last12"]/nDays)
      //If hCust["last12"]/nDays > hCust["last2"]/nDaysShort
          oPdf:NewLine()

         cColor := Chr(0)+Chr(0)+Chr(0)
         If hCust["count12"] > 4
            If nPerc <= 0
               cColor := Chr(255)+Chr(210)+Chr(80)
            Endif
            If nPerc <= -0.2
               cColor := Chr(255)+Chr(160)+Chr(80)
            Endif
            If nPerc <= -0.5
               cColor := Chr(255)+Chr(0)+Chr(0)
            Endif
         Endif


         oPdf:AtSay(chr(253)+cColor+HB_OemToAnsi(HGetKeyAt(hCustomers,nX)),,10)
            oPdf:AtSay(Str(hCust["count12"]),,30)
         oPdf:AtSay(Str(hCust["last12"]/nDays*30),,50)
         oPdf:AtSay(Str(hCust["last2"]/nDaysShort*30),,100)
         oPdf:AtSay(Str(nPerc*100),,150)
      //Endif
   Endif
   nX++
Enddo
CopyPrint()*/
