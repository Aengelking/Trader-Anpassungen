PROC REPORT_SHIPMENTS_VALUE
LOCAL nVersandart := 1
LOCAL oRechnung
LOCAL dFrom := Date()-365
LOCAL dTo := Date()
LOCAL getlist := {}
LOCAL dDate,nTotal,nMax := 0

DO WHILE .T.

   Head("Sendungswert pro Tag fr Versender")
   
   //@ 01,00 SAY "Versandart" GET nVersandart PICTURE "99" VALID nVersandart == 0 .OR. VersBrowse(01,13,01,14,@nVersandart)
   @ 01,00 SAY "Versandart UPS"
   @ 02,00 SAY "ab Datum  " GET dFrom
   @ 03,00 SAY "bis Datum " GET dTo   VALID dTo >= dFrom
   READ
   
   IF LastKey() == 27
      RETURN
   ENDIF
   
   IF nVersandart == 0
      @ 01,13 SAY Pad(" ALLE",50)
   ENDIF

   NetUse("ups","ups")
   NetUse("englsre","re")
   NetUse("lagerne","lne")
   NetUse("engkund","ku")
   NetUse("paknum","pnum")

   ups->(dbSetOrder( 5 )) //Datum
   //ups->(dbSetFilter({|| IF(nVersandArt==0,ups->Versand != -1,ups->Versandart == nVersandart) },"versandart "+IF(nVersandArt==0,"!=-1","== "+LTrim(str(nVersandart))) ))
   ups->(dbSetFilter({|| IF(nVersandArt==0,ups->Versand != -1,ups->Versandart $ {2,19,23,34,46,49,56}) },"versandart "+IF(nVersandArt==0,"!=-1","  $ {2,19,23,34,46,49,56} ") ))
   ups->(dbSeek( dFrom, .T. ))
   dDate := ups->Datum
   nTotal := 0

   re->(dbSetOrder( 4 ))
   lne->(dbSetOrder( 4 ))

   DO WHILE ! ups->(EOF()) .AND. ups->Datum <= dTo
      //@ 04,00 SAY ups->Nr
      IF ups->Rechnr != 0
         oRechnung := Rechnung():New(.F.)
         oRechnung:Load(ups->Rechnr)
         IF oRechnung:Brutto <= 0
            ups->(dbSkip())
            LOOP
         ENDIF
         nTotal += oRechnung:Brutto
      ELSE
         /*lne->(dbSeek( Str(ups->Nr,6) ))
         IF Empty(lne->KUNDE)
            ups->(dbSkip())
            LOOP
         ENDIF
         ku->(dbSeek( lne->Kunde+lne->Gruppe ))*/
         
      ENDIF

      ups->(dbSkip())
      IF ups->Datum != dDate
         ? dDate,nTotal
         dDate := ups->Datum
         nMax := Max(nMax,nTotal)
         nTotal := 0
      ENDIF
      IF Inkey() == 27
         EXIT
      ENDIF
   ENDDO

   ? "Max",nMax
   Sinkey(0)
   
   ups->(dbClearFilter())
ENDDO
