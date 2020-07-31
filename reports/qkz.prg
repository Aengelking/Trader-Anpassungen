LOCAL dEnd,dStart
LOCAL cStWeek,cEndWeek
LOCAL nYear := Year(Date())-1
LOCAL dDelDate,aQuarters := Array(4)
LOCAL hLief := {=>},hData
LOCAL aUmsatz := {{0,0},{0,0},{0,0},{0,0}}
LOCAL cFilter
LOCAL dDate,cFormat

Head(HB_AnsiToOem("Qualitätskennzahlen"))

@ 01,00 SAY "Jahr" GET nYear PICTURE "9999" VALID nYear > 2000 .AND. nYear <= Year(Date())
READ

IF LastKey() == 27
   RETURN
ENDIF

dEnd := STOD(Str(nYear,4)+"1231")
dStart := STOD(Str(nYear,4)+"0101")
cStWeek := Right(Str(nYear,4),2)+"01"
cEndWeek := Right(Str(nYear,4),2)+"52"

NetUse("engbes","bes")
netUse("engauf","auf")
netUse("englsre","re")
NetUse("lspos","lsp")
NetUse("ls","ls")
NetUse("qs","qs")
NetUse("umsatz","um")
NetUse("engkund","ku")

lsp->(dbSetOrder( 3 )) //besnr+bespos

cFilter := 'Lterm <= '+cEndWeek+' .AND. lTerm >= '+cStWeek+' .AND. GelQty > 0'

bes->(dbSetFilter({|| bes->(&(cFilter)) },cFilter ))

//bes->(dbSeek( Str( 17000,6 ) ))
bes->(dbGoTop())

aQuarters[1] := {"LIEF"=>{"COUNT"=>0,"LATE"=>0,"QS"=>0},"KU"=>{"COUNT"=>0,"LATE"=>0,"QS"=>0},"INT"=>{"COUNT"=>0,"LATE"=>0,"QS"=>0}}
aQuarters[2] := {"LIEF"=>{"COUNT"=>0,"LATE"=>0,"QS"=>0},"KU"=>{"COUNT"=>0,"LATE"=>0,"QS"=>0},"INT"=>{"COUNT"=>0,"LATE"=>0,"QS"=>0}}
aQuarters[3] := {"LIEF"=>{"COUNT"=>0,"LATE"=>0,"QS"=>0},"KU"=>{"COUNT"=>0,"LATE"=>0,"QS"=>0},"INT"=>{"COUNT"=>0,"LATE"=>0,"QS"=>0}}
aQuarters[4] := {"LIEF"=>{"COUNT"=>0,"LATE"=>0,"QS"=>0},"KU"=>{"COUNT"=>0,"LATE"=>0,"QS"=>0},"INT"=>{"COUNT"=>0,"LATE"=>0,"QS"=>0}}

bAdd := {|cLiefma|
   IF ! HHasKey(hLief,cLiefma)
      hLief[cLiefma] := {"COUNT"=>0,"LATE"=>0,"QS"=>0}
   ENDIF
}

DO WHILE ! bes->(Eof()) .AND. Inkey() != 27
   IF bes->FolgeTo == 0
      lNoEk := bes->EkPr == 0
   ENDIF
   //? CalWd(bes->LTerm),CalWd(bes->LTerm) >= dStart
   IF CalWd(bes->LTerm) <= dEnd .AND. CalWd(bes->lTerm) >= dStart .AND. bes->GelQty > 0 .AND. ! lNoEk

      nQ := Int( (Month(CalWd(bes->LTerm))-1) /3)+1

      Eval(bAdd,bes->Liefma)
      hLief[bes->Liefma]["COUNT"]++
      aQuarters[nQ]["LIEF"]["COUNT"]++

      lsp->(dbSeek( Str(bes->Besnr,6)+Str(bes->Posnr,3) ))
      dDelDate := CTOD("")
      DO WHILE lsp->Besnr == bes->Besnr .AND. lsp->Bespos == bes->Posnr
         ls->(dbSeek( lsp->Liefma+lsp->Beleg ))
         dDelDate := Max(dDelDate,ls->Datum)
         lsp->(dbSkip())
      ENDDO
      dLast := CalWD(bes->LTerm+Max(bes->Shiptime,1))+4  //end of the week

      //add Kulanztage excluding days when the firm is closed
      nAdded := 0

      nYear := Year(dLast)
      aDays := Hook("get_firmclosed",{nYear},{})

      DO WHILE AScan(aDays,dLast) != 0 .AND. nAdded < 2 //two days
         dLast := AddWorkingDays( dLast, 1, "BW", .T. )
         IF nYear != Year(dLast)
            nYear := Year(dLast)
            aDays := Hook("get_firmclosed",{nYear},{})
         ENDIF
         IF AScan(aDays,dLast) == 0
            nAdded++
         ENDIF
      ENDDO

      IF dLast < dDelDate
         hLief[bes->Liefma]["LATE"]++
         aQuarters[nQ]["LIEF"]["LATE"]++

         //IF Trim(bes->Liefma) == "TECHNO"
         ? bes->Liefma,bes->Besnr,bes->Posnr,bes->LTerm,dLast,dDelDate,nQ
         //ENDIF
      ENDIF
   ENDIF
   bes->(dbSkip())
ENDDO

bes->(dbClearFilter())

re->(dbSetOrder( 10 ))
auf->(dbSetOrder( 4 ))
cFilter := 'Right(Str(dTerm,4),2) != "99" .AND. (BeStat != 3 .OR. GelQty != 0) .AND. Wterm >= '+cStWeek+' .AND. Wterm <= '+cEndWeek
auf->(dbSetFilter( {|| auf->(&(cFilter)) } , cFilter ))
//auf->(dbSeek( dStart, .T. ))
auf->(dbGoTop())

DO WHILE ! auf->(EOF()) .AND. auf->Besda <= dEnd
   nQ := Int( (Month(CalWd(auf->WTerm))-1) /3)+1
   aQuarters[nQ]["KU"]["COUNT"]++
   re->(dbSetFilter({|| re->AoQty > 0 },"AoQty > 0"))
   re->(dbSeek( Str(auf->Abnr,6)+Str(auf->Itmnr,3) ))
   dLast := STOD("")
   DO WHILE re->AbNr == auf->AbNr .AND. re->Reposnr == auf->Itmnr
      dLast := Max(dLast,re->Rechdat)
      re->(dbSkip())
   ENDDO
   re->(dbClearFilter())
   ku->(dbSeek( auf->Kundma+"K" ))
   IF Empty(auf->DTerm)
      dDate := auf->BDatum+2 //acuh wenn wir das 2 Tage zu spät versenden dürfte es rechtzeitig ankommen (geht dann per Express)
   ELSE
      dDate := CalWd(auf->DTerm)+5 //innerhalb der bestätigten Woche
   ENDIF
   IF dLast > dDate
      ? auf->Abnr,auf->Itmnr,auf->Dterm,dDate,dLast
     aQuarters[nQ]["KU"]["LATE"]++
   ENDIF
   auf->(dbSkip())
   IF Chr(Inkey()) $ "pP"
      IF Chr(SInkey(0)) $ "qQ"
         RETURN
      ENDIF
   ENDIF
ENDDO

auf->(dbClearFilter())

qs->(dbSetFilter( {|| qs->Datum >= dStart .AND. qs->Datum <= dEnd },"Datum >= SToD('"+Dtos(dStart)+"') .AND. Datum <= Stod('"+Dtos(dEnd)+"')" ))
qs->(dbGoTop())
DO WHILE ! qs->(EOF())
   nQ := Int( (Month(qs->Datum)-1) /3)+1
      ? qs->Nummer,qs->Liefma
   IF ! Empty(qs->Liefma)
      Eval(bAdd,qs->Liefma)
      hLief[qs->Liefma]["QS"]++
      aQuarters[nQ]["LIEF"]["QS"]++
   ENDIF
   IF ! Empty(qs->Kunde)
      aQuarters[nQ]["KU"]["QS"]++
   ENDIF
   IF Empty(qs->Liefma) .AND. Empty(qs->Kunde)
      aQuarters[nQ]["INT"]["QS"]++
   ENDIF
   qs->(dbSkip())
ENDDO

//Inkey(0,128)

CLS
? "Lieferanteneinzelbewertung"
? Pad("Lieferant",8),PadL("Anzahl",6),PadL(t("Spät"),6),Space(6),PadL("QS",6)

aList := {{"Name",t("Terminverzögerung %"),t("Qualitätsprobleme %"),"Summe","Bewertung"}}

FOR EACH hData IN hLief
   IF hData:Count >= 50
      nV := (hData:Late)/hData:Count*100
      nQ := hData:QS/hData:Count*100
      nT := nV+(2*nQ)
      ? hData:__enumKey(),Str(hData:Count,6),Str(hData:Late,6),Str(nV,6,2)+"%",Str(hData:Qs,6),Str(nQ,6,2)+"%"
      ku->(dbSeek(hData:__enumKey()+"L"))
      Aadd(aList,{Trim(Trim(ku->Name1)+" "+ku->Name2),nV,nQ,nT,IF(nT>20,"C",IF(nT>10,"B","A"))})
   ENDIF
NEXT

cFile := Trim(Tr_getini(1))+"\export\lieferantenbewertung.csv"
SaveAsCSV(cFile,aList)
Wapi_ShellExecute(,"open",cFile)

?
cType := ""
FOR EACH cType IN {"Lieferantenbewertungen"=>"LIEF","Intern"=>"INT","Kundenbewertung"=>"KU"}
   nTotal := 0
   nTotQS := 0
   nTotLate := 0
   ? cType:__eNumKey()
   ? "Q"
   IF cType != "INT"
      ?? "",PadL("Anzahl",6),PadL(t("Spät"),6),Space(6),Space(8)
   ENDIF
   ?? "",PadL("QS",6)
   FOR EACH hData IN aQuarters
      ? Str(hData:__enumIndex(),1)
      IF cType != "INT"
         ?? "",Str(hData[cType]:Count,6),Str(hData[cType]:Late,6),Str((hData[cType]:Late)/Max(hData[cType]:Count,1)*100,6,2)+"%","("+Str(100-(hData[cType]:Late)/Max(hData[cType]:Count,1)*100,6,2)+"%)"
         nTotal += hData[cType]:Count
         nTotLate += hData[cType]:Late
      ENDIF
      ?? "",Str(hData[cType]:Qs,6)
      IF cType != "INT"
         ?? "",Str(hData[cType]:QS/Max(hData[cType]:Count,1)*100,6,2)+"%"
      ENDIF
      nTotQS += hData[cType]:Qs
   NEXT
   ? Replicate("-",70)
   IF cType != "INT"
      ? " ",Str(nTotal,6),Str(nTotLate,6),Str(nTotLate/Max(nTotal,1)*100,6,2)+"%","("+Str(100-nTotLate/Max(nTotal,1)*100,6,2)+"%)"
   ELSE
      ? " "
   ENDIF
   ?? "",Str(nTotQs,6)
   IF cType != "INT"
      ?? "",Str(nTotQS/nTotal*100,6,2)+"%"
   ENDIF
NEXT


SInkey(0,128)

CLS
NetUse("stats","st")
nTot1 := 0
nTot2 := 0
cFormat := "@E 9,999,999"
? t("Umsätze")
? "Q",Str(nYear-1,9),Str(nYear,9),"Steigerung"
FOR nX := 1 TO 12 STEP 3
   nUm1 := st->(Leto_Sum("billings","",Str(nYear-1,4)+" "+Str(nx,2),Str(nYear-1,4)+" "+Str(nX+2,2)))
   nUm2 := st->(Leto_Sum("billings","",Str(nYear,4)+" "+Str(nX,2),Str(nYear,4)+" "+Str(nX+2,2)))
   ? Str(nX/3+1,1),Transform(nUm1,cFormat),Transform(nUm2,cFormat),Str((nUm2-nUm1)/Max(nUm1,1)*100,6,2)+"%"
   nTot1 += nUm1
   nTot2 += nUm2
NEXT
? " ",Replicate("-",9),Replicate("-",9)
? " ",Transform(nTot1,cFormat),Transform(nTot2,cFormat),Str((nTot2-nTot1)/Max(nTot1,1)*100,6,2)+"%"
st->(dbCloseArea())
SInkey(0,128)
