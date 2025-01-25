PROCEDURE Monatsabschluss
LOCAL nYear := Year(Date())
LOCAL nMonat := Month(Date())
LOCAL dDate
LOCAL aKonten,nX
LOCAL getlist := {}
LOCAl oPDF,cText,nSaldo

Head(t("Saldenst‰nde f¸r Monatsabschluss"))

IF ! LX_Start()
	Alert("Keine Verbindung zu Lexware")
	Return
ENDIF


IF nMonat == 1
   nYear--
   nMonat := 12
ELSE
   nMonat--
ENDIF
//GetValue("BH_MAKONTEN",{},"Konten fÅr Monatsabschluss") //crashed after a cetain number of entries, most likely is too long to be saved
aKonten := {1201,1207,1206,1741,1742,1748,1755,1740,1410,1236,1235,1231,1232,1230,1200,1593,1591,1590,1360,1260,1220,;
1792,651,1348,1251,1252,1253,1254,1730,1799,1237,0656,0658,1222,1223,1261,1354,1238,1731,1510,1226,1227}

//1203,1211,1212,1214,

@ 01,00 SAY "Jahr " GET nYear PICTURE "9999" VALID nYear <= Year(Date())
@ 02,00 SAY "Monat" GET nMonat PICTURE "99" VALID nMonat >= 1 .AND. nMonat <= 12
READ

ASort(aKonten)
dDate := EoM(StoD(Str(nYear,4)+StrZero(nMonat,2)+"01"))

StartPrint(,,"PDF")
oPdf := GetCurrentPrinterObject():Data
oPdf:NewPage()
oPdf:SetFont("HELVETICA",0,14)
oPdf:Bold()
oPdf:AtSay("Monatsabschluss "+Str(nYear,4)+"-"+StrZero(nMonat,2))
oPdf:NewLine(2)
oPdf:SetFont("HELVETICA",0,12)
oPdf:Bold()
oPdf:AtSay("Konto",,0,"R")
oPdf:AtSay("Name",,20,"R")
cText := "Saldo"
oPdf:Text(cText,oPdf:ReportLine-1,160,oPdf:Len(cText),0,3,'R')
oPdf:Normal()
oPdf:NewLine(3)
FOR nX := 1 TO Len(aKonten)
   nSaldo := LX_GetSaldo(aKonten[nX],dDate)
   oPdf:AtSay(Transform(aKonten[nX],"999999"),,0,"R")
   oPdf:AtSay(Left(LX_GetAccountName(aKonten[nX]),50),,20,"R")
//   oPdf:AtSay(Transform(ABS(nSaldo),"@E 9,999,999.99")+" "+IF(nSaldo<0,"S","H"),,150,"R")
   cText := Transform(nSaldo,"@E 9,999,999.99")//+" "+IF(nSaldo<0,"S","H")
   oPdf:Text(cText,oPdf:ReportLine-1,160,oPdf:Len(cText),0,3,'R')
   oPdf:NewLine(3)
//   ? Transform(aKonten[nX],"999999"),Left(LX_GetAccountName(aKonten[nX]),30),Transform(ABS(nSaldo),"@E 9,999,999.99")
NEXT

CopyPrint()


If LastKey() == 27
   RETURN
ENDIF