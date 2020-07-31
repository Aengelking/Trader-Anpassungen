LOCAL cLager1
LOCAL cLager2
LOCAL nRec
LOCAL getlist := {}

NETUSE("LAGERORT","LAGO")

DO WHILE .T.
   cLager1 := Space(12)
   cLager2 := Space(12)

   Head("Etiketten für Lagerorte drucken")


   @ 01,00 SAY "Von Lagerort"
   @ 02,00 GET cLager1 PICTURE "999/!!!!!!!!" VALID /*LAGSHOW(cLAGER1,02,34) .AND.*/ LastKey() == 13
   @ 03,00 SAY "Bis Lagerort"
   @ 04,00 GET cLager2 PICTURE "999/!!!!!!!!" VALID /*LAGSHOW(cLAGER2,04,34) .AND.*/ LastKey() == 13
   READ

   IF LastKey() == 27
      RETURN
   ENDIF

   lago->(dbSeek( cLager1, .T. ))

   DO WHILE lago->Lagerort >= cLager1 .AND. lago->Lagerort <= cLager2
      ? lago->Lagerort
      StickPrint("LAGERORT",1)
      lago->(dbSkip())
   ENDDO
   
   //Inkey(0)

ENDDO