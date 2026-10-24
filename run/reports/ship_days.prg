Head("Anzahl Sendungen pro Tag")

NetUse("ups","ups")
ups->(dbSetOrder( 5 ))

ups->(dbSeek( StoD("20150101"), .T. ))
ups->(dbSetFilter({|| ups->Versandart != 21 },"versandart != 21"))

aDays := {"Sonntag","Montag","Dienstag","Mittwoch","Donnerstag","Freitag","Samstag"}
aTotal := Array(7)
nTotal := 0
AFill(aTotal,0)

aLQ   := Array(4)
FOR nX := 1 TO 4
   aLQ[nX] := {=>}
   aLQ[nX]["TOTAL"] := 0
   aLQ[nX]["Qs"] := Array(7)
   AFill(aLQ[nX]["Qs"],0)
NEXT
aTQ   := Array(4)
FOR nX := 1 TO 4
   aTQ[nX] := {=>}
   aTQ[nX]["TOTAL"] := 0
   aTQ[nX]["Qs"] := Array(7)
   AFill(aTQ[nX]["Qs"],0)
NEXT

aLY    := Array(7)
AFill(aLY,0)
nLYTot := 0

aLM    := Array(7)
AFill(aLM,0)
nLMTot := 0

nTY := Year(Date())
nLY := nTY-1
IF Month(Date()) == 1
   nLMY := nLY
   nLM  := 12
ELSE
   nLMY := nTY
   nLM  := Month(Date())-1
ENDIF

aTW     := Array(7)
AFill(aTW,0)
nTW    := CWeek(Date())
nTWTot := 0


aLW     := Array(7)
AFill(aLW,0)
nLW    := AddWeeks(nTW,-1) //-Dow(Date()))
nLWTot := 0



DO WHILE ! ups->(Eof())
   nDOW := Dow(ups->Datum)
   aTotal[nDOW]++
   nTotal++
   nQ := Quarter(ups->Datum)
   nW := CWeek(ups->Datum)
   IF Year(ups->Datum) == nLY
      aLY[nDOW]++
      nLYTot++
      aLQ[nQ]["Qs"][nDow]++
      aLQ[nQ]["TOTAL"]++
   ENDIF
   IF Year(ups->Datum) == nTY
      aTQ[nQ]["Qs"][nDow]++
      aTQ[nQ]["TOTAL"]++
   ENDIF

   IF Year(ups->Datum) == nLMY .AND. Month(ups->Datum) == nLM
      aLM[nDOW]++
      nLMTot++
   ENDIF
   IF nW == nLW
      aLW[nDOW]++
      nLWTot++
   ELSEIF nW == nTW
      aTW[nDOW]++
      nTWTot++
   ENDIF
   ups->(dbSkip())
ENDDO

CLS

@ 01,00 SAY "Tag"
@ 02,00 SAY "Gesamt"
@ 03,00 SAY Str(nLY,4)
FOR nQ := 1 TO 4
   @ 03+nQ,00 SAY Str(nLY,4)+"-Q"+Str(nQ,1)
NEXT

FOR nQ := 1 TO 4
   @ 07+nQ,00 SAY Str(nTY,4)+"-Q"+Str(nQ,1)
NEXT

@ 12,00 SAY Str(nLMY,4)+"-"+StrZero(nLM,2)
@ 13,00 SAY NiceWeek(nLW)
@ 14,00 SAY NiceWeek(nTW)

FOR nX := 2 TO 7
   nC := 11*(nX-1)
   @ 01,nC SAY aDays[nX]
   @ 02,nC SAY _Format(aTotal[nX],nTotal)
   @ 03,nC SAY _Format(aLY[nX],nLYTot)
   FOR nQ := 1 TO 4
      @ 03+nQ,nC SAY _Format(aLQ[nQ]["Qs"][nX],aLQ[nQ]["TOTAL"])
   NEXT
   FOR nQ := 1 TO 4
      @ 07+nQ,nC SAY _Format(aTQ[nQ]["Qs"][nX],aTQ[nQ]["TOTAL"])
   NEXT

   @ 12,nC SAY _Format(aLM[nX],nLMTot)
   @ 13,nC SAY _Format(aLW[nX],nLWTot)
   @ 14,nC SAY _Format(aTW[nX],nTWTot)
NEXT
Sinkey(0)

STATIC Function _Format(nVal,nTot)
RETURN Str(nVal/Max(ntot,1)*100,6,2)+"%"

Function Quarter(dDate)
   LOCAL nM := Month(dDate)
   IF nM <= 3
      RETURN 1
   ELSEIF nM <= 6
      RETURN 2
   ELSEIF nM <= 9
      RETURN 3
   ENDIF
RETURN 4