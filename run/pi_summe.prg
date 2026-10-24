LOCAL cAbNr := Space(10),nTotal := 0,nC := 1,nFracht
LOCAL nNext,nNextTot := 0,nVor,nVorTot := 0
LOCAL nYear := Year(Date())

NetUse("engbes","bes")
NetUse("rechpos","rpos")

Head(t("Summe für Proforma Rechnungen berechnen"))

DO WHILE LastKey() != 27
   nFracht := 0

   @ 01,00 SAY "AB-Nr" GET cAbNr
   @ 01,18 SAY "Fracht" GEt nFracht PICTURE "999.99" 
   @ 01,32 SAY "Jahr der Zahlung" GET nYear PICTURE "9999"
   READ
   IF LastKey() != 27
      bes->(dbGoTop())
      //"gelqty*ekpr"
      aSumme := bes->(LETO_SUM( "gelqty,gelqty*ekpr/pe*1-(rabatt/100),beqty*ekpr/pe*(1-rabatt/100),#", 'abnr=="'+cAbNr+'"')) //, [xScope], [xScopeBottom] )
      @ 03,00 SAY Pad("PI",10)+" "+Pad("Sum",8)+" "+Pad("Freight",6)+" "+Pad("Summe",8)
      @ 03,37 SAY Pad("Folgejahr",8)+" "+Pad("Vorjahr",8)

      nSumme := Min(aSumme[2],aSumme[3])
      @ 03+nC,00 SAY cAbNr+" "+Str(nSumme,8,2)+" "+Str(nFracht,6,2)+" "+Str(nSumme+nFracht,8,2)
      nTotal += nSumme+nFracht
      bes->(dbSetFilter( {|| bes->abnr==cAbNr },'abnr=="'+cAbNr+'"' ))
      bes->(dbGoTop())
      nNext := 0
      nVor := 0
      rpos->(dbSetOrder( 2 ))
      DO WHILE ! bes->(EOF())
         rpos->(dbSeek( Str(bes->Besnr,6)+Str(bes->Posnr,3) ))
         DO WHILE rpos->Besnr == bes->Besnr .AND. rpos->Posnr == bes->Posnr
            IF Year(rpos->Date) > nYear
               nNext += rpos->Menge*ekpr/pe*(1-rabatt/100)
            ELSEIF Year(rpos->Date) < nYear
               nVor += rpos->Menge*ekpr/pe*(1-rabatt/100)
            ENDIF
            rpos->(dbSkip())
         ENDDO
         bes->(dbSkip())
      ENDDO
      bes->(dbClearFilter())
      nNextTot += nNext
      nVorTot  += nVor
      @ 03+nC,37 SAY Str(nNext,8,2)
      @ 03+nC,46 SAY Str(nVor,8,2)

      nC++
      @ MaxRow(),00 SAY Pad("Total",10)+Space(17)+Str(nTotal,8,2)
      @ MaxRow(),37 SAY Str(nNextTot,8,2)+" "+Str(nVorTot,8,2)

   ENDIF
ENDDO