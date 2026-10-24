PROC RUN_REPORT_NEWCUSTOMERS

   LOCAL aCust,aNewCust
   LOCAL nStartYear := Year(Date())-4,nTert
   LOCAL cYear,nY,nC
   LOCAL cKundma := ""
   LOCAL getlist := {}
   LOCAL dStart,dEnd

   Head("Anzahl Neukunden")

   //@ 01,00 SAY "Jahr" GET nStartYear PICTURE "9999" VALID nStartYear <= Year(Date())
   //READ

   IF LastKey() == 27
      RETURN 
   ENDIF

   NetUse("engauf","auf")
   NetUSe("engkund","ku")
   NetUse("englsre","re")

   auf->(dbSetOrder( 4 ))
   re->(dbSetOrder( 14 ))
   
   aCust := {}

   /*FOR nTert := 1 TO 3
      nC := 6+5*nTert-1
      @ 02,nC SAY "T"+Str(nTert,1)
   NEXT*/

   FOR nY := 0 TO Year(Date())-nStartYear
      FOR nTert := 1 TO 3
         aNewCust := {}
         
         cYear := Str(nStartYear+nY,4)
         dStart := StoD(cYear+StrZero(1+(nTert-1)*4,2)+"01")
         dEnd := EoM(StoD(cYear+StrZero(nTert*4,2)+"01"))
         
         auf->(dbSeek( DtoS(dStart), .T. ))
         DO WHILE auf->Besda <= dEnd .AND. ! auf->(EOF()) //auf->DTerm >= nStKW .AND. auf->DTerm <= nEnKW .AND. ! auf->(EOF())
            IF auf->Kundma != cKundMa
               IF AScan(aCust,auf->Kundma) == 0
                  Aadd(aCust,auf->Kundma)
                  IF (! re->(dbSeek( auf->Kundma )) .OR. re->Rechdat >= dStart) .AND. AScan(aNewCust,auf->Kundma) == 0
                     Aadd(aNewCust,auf->Kundma)
                  ENDIF
               ENDIF
               cKundma := auf->Kundma
            ENDIF
            auf->(dbSkip())
         ENDDO   

         nC := 1+30*nY-1+(nTert-1)*10
         @ 02,nC SAY Right(cYear,2)+"T"+Str(nTert,1)
         @ 03,nC SAY LTrim(Str(Len(aNewCust)))
         nTotal := 0
         FOR nX := 1 To Len(aNewCust)            
            IF 03+nX < MaxRow()-2
               @ 03+nX,nC SAY aNewCust[nX] //+"("+Str(hTurnOver["total"])+")"
            ENDIF
            hTurnOver := GetCustomerTurnover(aNewCust[nX])
            nTotal += hTurnOver["total"]
         NEXT
         @ MaxRow(),nC SAY Str(nTotal,10)
      NEXT
   NEXT

   //? "Gesamt: "+Str(Len(aCust))
   


Sinkey(0)