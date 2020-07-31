LOCAL cLiefma := Space(8)
LOCAL dEnd    := Date()
LOCAL dMove   := StoD()
LOCAL lQuote  := .T.
LOCAL lList   := .F.
LOCAL nDays   := 0
LOCAL lVar    := .F.
LOCAL getlist := {}

NetUse("buyprice","bpr")
NetUse("engkund","ku")

DO WHILE .T.
   Head("Enddatum Preise setzen")

   @ 01,00 SAY t("Setzt das Enddatum für Preise bei denen das Enddatum leer ist")
   @ 02,00 SAY t("und das Startdatum vor dem neuen Enddatum liegt.")

   @ 04,00 SAY "Lieferant " GET cLiefma PICTURE "@!" VALID Findad( cLiefma, "L", 04, 50 )

   @ 05,00 TO 10,49
   @ 05,01 SAY " Enddatum "
   @ 06,01 SAY "Variabel   " GET lVar PICTURE "Y"
   @ 07,01 SAY "Datum      " GET dEnd VALID ! Empty(dEnd) WHEN ! lVar
   @ 08,01 SAY "Verschieben" GET dMove
   @ 08,21 SAY "(Leer=alle ohne Enddatum)"
   @ 09,01 SAY "Start+Tage " GET nDays VALID nDays != 0 WHEN lVar PICTURE "999"

   @ 11,00 SAY "Angebote  " GET lQuote PICTURE "Y"
   @ 12,00 SAY "Preisliste" GET lList  PICTURE "Y" VALID lList .OR. lQuote
   READ

   IF LastKey() == 27
      RETURN
   ENDIF

   IF Empty(dMove)
      cFilter := 'Empty(enddate) '
   ELSE
      cFilter := 'endDate == StoD("'+DToS(dMove)+'") '
   ENDIF
   IF ! lVar
      cFilter += '.AND. startdate <= StoD("'+DToS(dEnd)+'")'
   ENDIF
   cFilter += '.AND. ('
   
   IF lQuote
      cFilter += 'Trim(type) == "QUOTE"'
      IF lList
         cFilter += '.OR.'
      ENDIF
   ENDIF
   IF lList
      cFilter += 'Trim(type) == "LIST"'
   ENDIF
   cFilter += ")"
   //? cFilter
   
   nChoice := Tr_MsgBox("Angeaben in Ordnung?",,{"Nein",t("Ja - Update durchführen"),"Demo"})
   IF nChoice == 1
      LOOP
   ENDIF

   bpr->(dbSetFilter({|| bpr->(&(cFilter)) },cFilter))
   bpr->(dbSeek(cLiefma))

   DO WHILE bpr->Liefma == cLiefma .AND. ! bpr->(EOF())
      IF lVar
         dEnd := bpr->StartDate+nDays
      ENDIF
      ? bpr->Artikelnr,bpr->Qty,bpr->Startdate,dEnd,bpr->Number
      IF nChoice == 2
         bpr->(Rec_Lock())
         bpr->Enddate := dEnd
         bpr->(dbUnLock())
      ENDIF
      bpr->(dbSkip())
   ENDDO

   ? "beendet"

   Sinkey(0)
ENDDO