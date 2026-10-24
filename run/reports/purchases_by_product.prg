//LOCAL cLiefma := Pad("BULGIN",8)
LOCAL cLiefma := Pad("EDAC",8)
LOCAL hMonths := {=>}
LOCAL hYears  := {=>}

LOCAL nQty,dDate,cKey,hData

Head("Bestellungen pro Monat und Produkt")

NetUse("engbes","bes")
bes->(dbSetOrder( 2 ))
cFile := Trim(Tr_GetIni(1))+"\reports\"+Trim(cLiefma)+"_purchases_by_product_months.csv"
nHM := FCreate(cFile)
IF nHM == 0 .OR. Ferror() != 0
   Alert("Creation of file "+Trim(cFile)+" failed "+Str(Ferror()))
   RETURN
ENDIF
cFile := Trim(Tr_GetIni(1))+"\reports\"+Trim(cLiefma)+"_purchases_by_productvalue_months.csv"
nHMV := FCreate(cFile)
IF nHMV == 0 .OR. Ferror() != 0
   Alert("Creation of file "+Trim(cFile)+" failed "+Str(Ferror()))
   RETURN
ENDIF

cFile := Trim(Tr_GetIni(1))+"\reports\"+Trim(cLiefma)+"_purchases_by_product_years.csv"
nHY := FCreate(cFile)
IF nHY == 0 .OR. Ferror() != 0
   Alert("Creation of file "+Trim(cFile)+" failed "+Str(Ferror()))
   RETURN
ENDIF
cFile := Trim(Tr_GetIni(1))+"\reports\"+Trim(cLiefma)+"_purchases_by_productvalue_years.csv"
nHYV := FCreate(cFile)
IF nHYV == 0 .OR. Ferror() != 0
   Alert("Creation of file "+Trim(cFile)+" failed "+Str(Ferror()))
   RETURN
ENDIF


bes->(dbSeek( cLiefma ,.T.) )
? "Collecting data"
DO WHILE bes->Liefma == cLiefma .AND. ! bes->(EOF())
   nQty := IF(bes->Bestat<3,bes->BeQty,bes->GelQty)
   IF nQty != 0
     dDate := CalWD(bes->Lterm,NIL,NIL,.T.)
     cYear := Str(Year(dDate),4)
     cKey := cYear+StrZero(Month(dDate),2)
     IF ! HHasKey(hMonths,bes->Matchcode)
        hMonths[bes->Matchcode] := {=>}
     ENDIF
     IF ! HHasKey(hMonths[bes->Matchcode],cKey)
        hMonths[bes->Matchcode][cKey] := {"QTY"=>0,"VALUE"=>0}
     ENDIF

     IF ! HHasKey(hYears,bes->Matchcode)
        hYears[bes->Matchcode] := {=>}
     ENDIF
     IF ! HHasKey(hYears[bes->Matchcode],cYEar)
        hYears[bes->Matchcode][cYear] := {"QTY"=>0,"VALUE"=>0}
     ENDIF

     nValue :=  nQty*bes->EkPr/bes->Pe *currate(bes->Money,"E",bes->Besda)
     hMonths[bes->Matchcode][cKey]["QTY"] += nQty
     hMonths[bes->Matchcode][cKey]["VALUE"] += nValue
     hYears[bes->Matchcode][cYear]["QTY"] += nQty
     hYears[bes->Matchcode][cYear]["VALUE"] += nValue
   ENDIF
   bes->(dbSkip())
ENDDO

? "Saving data"


dStart := STod("20991231")
dEnd   := STod("")

FOR EACH hData IN hMonths
   aKeys := HGetKeys(hData)
   ASort(aKeys)

   IF Len(aKeys) > 0
      dStart := Min(dStart,Stod(aKeys[1]+"01"))
      dEnd   := Max(dEnd,STod(ATail(aKeys)+"01"))
   ENDIF
NEXT

FWrite(nHM,"Artikel;")
FWrite(nHMV,"Artikel;")
dDate := dStart
DO WHILE dDate < dEnd
    IF dDate > dStart
       FWrite(nHM,";")
       FWrite(nHMV,";")
    ENDIF
   FWrite(nHM,Str(Year(dDate),4)+"-"+StrZero(Month(dDate),2))
   FWrite(nHMV,Str(Year(dDate),4)+"-"+StrZero(Month(dDate),2))
   dDate := AddMonth(dDate,1)
ENDDO

FOR EACH hData IN hMonths
   FWrite(nHM,Chr(13)+Chr(10))
   FWrite(nHM,Trim(hData:__enumKey())+";")

   FWrite(nHMV,Chr(13)+Chr(10))
   FWrite(nHMV,Trim(hData:__enumKey())+";")
   dDate := dStart
   DO WHILE dDate < dEnd
      cKey := Str(Year(dDate),4)+StrZero(Month(dDate),2)
      IF dDate > dStart
         FWrite(nHM,";")
          FWrite(nHMV,";")
      ENDIF
      IF HHAsKey(hData,cKey)
         FWrite(nHM,StrTran(LTrim(Str(hData[cKey]["QTY"])),".",",")) //+";"+StrTran(LTrim(Str(hData["VALUE"])),".",",")+Chr(13)+Chr(10))
         FWrite(nHMV,StrTran(LTrim(Str(hData[cKey]["VALUE"])),".",",")) //+";"+StrTran(LTrim(Str(hData["VALUE"])),".",",")+Chr(13)+Chr(10))
      ELSE
         FWrite(nHM,"0")
         FWrite(nHMV,"0")
      ENDIF
      dDate := AddMonth(dDate,1)
   ENDDO
NEXT

nStart := Year(dStart)
nEnd   := Year(dEnd)

FWrite(nHY,"Artikel;")
FWrite(nHYV,"Artikel;")
nYear := nStart
FOR nYear := nStart TO nEnd
    IF nYear > nStart
       FWrite(nHY,";")
       FWrite(nHYV,";")
    ENDIF
   FWrite(nHY,Str(nYear,4))
   FWrite(nHYV,Str(nYear,4))
NEXT

FOR EACH hData IN hYears
   FWrite(nHY,Chr(13)+Chr(10))
   FWrite(nHY,Trim(hData:__enumKey())+";")
   FWrite(nHYV,Chr(13)+Chr(10))
   FWrite(nHYV,Trim(hData:__enumKey())+";")

   FOR nYear := nStart TO nEnd
      cYear := Str(nYear,4)
      IF nYear > nStart
         FWrite(nHY,";")
         FWrite(nHYV,";")
      ENDIF
      IF HHasKey(hData,cYear)
         FWrite(nHY,StrTran(LTrim(Str(hData[cYear]["QTY"])),".",",")) //+";"+StrTran(LTrim(Str(hData["VALUE"])),".",",")+Chr(13)+Chr(10))
         FWrite(nHYV,StrTran(LTrim(Str(hData[cYear]["VALUE"])),".",","))
      ENDIF
   NEXT
NEXT


FClose(nHM)
FClose(nHY)
FClose(nHMV)
FClose(nHYV)

? "DONE"
Inkey(0,128)