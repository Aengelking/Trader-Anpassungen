LOCAL cLager1
LOCAL cLager2
LOCAL nRec
LOCAL getlist := {}

NETUSE("LAGER","LAG")

DO WHILE .T.
   cLager1 := Space(12)
   cLager2 := Space(12)

   Head("Alle Artikel im Lagerort umbuchen")


   @ 01,00 SAY "AUS LAGER"
   @ 02,00 GET cLager1 PICTURE "999/!!!!!!!!" VALID LAGSHOW(cLAGER1,02,34) .AND. LastKey() == 13
   @ 03,00 SAY "IN LAGER"
   @ 04,00 GET cLager2 PICTURE "999/!!!!!!!!" VALID LAGSHOW(cLAGER2,04,34) .AND. LastKey() == 13
   READ

   IF LastKey() == 27
      RETURN
   ENDIF
   
   IF TR_MsgBox(t("Umbuchung wirklich durchführen"),,{"Nein","Ja"}) != 2
      LOOP
   ENDIF

   lag->(dbSetOrder( 2 ))
   lag->(dbSeek( cLager1 ))

   DO WHILE lag->Lagerort == cLager1
      ? lag->Artikelnr

      //get next record
      lag->(dbSkip())
      nRec := lag->(Recno())
      lag->(dbSkip(-1))

      lag->(Rec_Lock())
      lag->Lagerort := cLager2
      lag->(dbUnLock())

      //goto next record
      lag->(dbGoto( nRec ))
   ENDDO

ENDDO