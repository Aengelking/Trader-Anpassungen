LOCAL nRenr := 0

DO WHILE .T.
   Head(t("Gelangensbestätigung drucken"))

   @ 01,00 SAY "Rechnung" GET nRenr PICTURE "999999" VALID nRenr != 0
   READ
   IF LastKey() == 27
      EXIT
   ENDIF
   Englipr(nRenr,1,.t.,.T.)
ENDDO