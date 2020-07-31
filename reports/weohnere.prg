LOCAL cYear := Str(2014,4)
LOCAL aMonths := Array(12)
LOCAL nX,nC,nCount

Head("Wareneingang ohne Rechnung")

NetUse("lsbook","lsbk")
NetUse("rechpos","rpos")
NetUse("engbes","bes")

AFill(aMonths,0)

CLS

@ 01,00 SAY "Lieferscheine"

lsbk->(dbSetOrder( 0 ))
@ 01,28 SAY "/"+LTrim(Str(lsbk->(LAstRec())))
lsbk->(dbSetOrder( 1 ))
lsbk->(dbGoTop())
nCount := 1

DO WHILE ! lsbk->(EOF())
   @ 01,20 SAY Str(nCount,8)
   IF lsbk->Datum >= StoD(cYear+"0101") .AND. lsbk->Datum <= StoD(cYear+"1231")
      bes->(dbSeek( Str(lsbk->Besnr,6)+Str(lsbk->bespos,3) ))
      aMonths[Month(lsbk->Datum)] += lsbk->Geliefert*bes->EkPr/bes->Pe*(1-bes->Rabatt/100)*Currate(bes->Money,"E",Eom(lsbk->Datum))
   ENDIF
   lsbk->(dbSkip())
   nCount++
ENDDO

@ 02,00 SAY "Rechnungen"
rpos->(dbSetOrder( 0 ))
@ 02,28 SAY "/"+LTrim(Str(rpos->(LAstRec())))
rpos->(dbSetOrder( 1 ))
rpos->(dbGoTop())
nCount := 1

DO WHILE ! rpos->(EOF())
   @ 02,20 SAY Str(nCount,8)
   IF rpos->Date >= StoD(cYear+"0101") .AND. rpos->Date <= StoD(cYear+"1231")
      IF bes->(dbSeek( Str(rpos->Besnr,6)+Str(rpos->Posnr,3) ))
         aMonths[Month(rpos->Date)] -= rpos->Menge*bes->EkPr/Max(bes->Pe,1)*(1-bes->Rabatt/100)*Currate(bes->Money,"E",Eom(rpos->Date))   //use the price in the PO not on the invoice to correlate it with the del notes
      ENDIF
   ENDIF
   nCount++
   rpos->(dbSkip())
ENDDO

FOR nX := 1 TO 6
   nC := 14*(nX-1)
   @ 04,nC SAY Str(nX,12)
   @ 05,nC SAY Str(aMonths[nX],12)
NEXT
FOR nX := 7 TO 12
   nC := 14*(nX-7)
   @ 07,nC SAY Str(nX,12)
   @ 08,nC SAY Str(aMonths[nX],12)
NEXT

Inkey(0,128)