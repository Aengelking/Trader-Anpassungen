LOCAL nKonto := 0,dDate := Date()

Head("Kontostand Lexware zu einem bestimmten Datum")

IF ! LX_Start()
	Alert("Keine Verbindung zu Lexware")
	Return .F.
ENDIF

DO WHILE .T.
   @ 01,00 SAY "Konto " GET nKonto PICTURE "999999"
   @ 01,15 SAY "Datum " GET dDate
   READ
   
   IF LastKey() == 27
      RETURN
   ENDIF

   Scroll(02,00,MaxRow(),MaxCol(),-1)
   @ 02,00 SAY dDate
   @ 02,09 SAY nKonto PICTURE "999999"
   @ 02,16 SAY Left(LX_GetAccountName(nKonto),30)
   @ 02,48 SAY Transform(LX_GetSaldo(nKonto,dDate),"@E 999,999.99")
ENDDO
