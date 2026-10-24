#define TEST
#define DEBUG

PROC RUN_TEST_ONPOW_PRICE  
   LOCAL cMatch := "CMI15/AS/F/R/RD/06/M/S/18" //Space(25)
   LOCAL cLief :=  Pad("ONPOW",8)

   Head("Onpow Preisimport prfen")
   NetUse("artikel","art")
   NetUse("artlief","ali")

   DO WHILE .T.
      @ 01,00 SAY "Matchcode" GET cMatch VALID art->(dbSeek(cMatch)) //PICTURE ValidVar(@cMatch)
      READ

      IF LastKey() == 27
         RETURN
      ENDIF

      ali->(dbSetOrder( 2 ))
      IF ! ali->(dbSeek(cLief+cMatch))
         ? "Lieferantenartikel nicht gefunden"
         LOOP
      ENDIF
      
      RUN_ONPOW_PRICES(.T.)
      ? "abgeschlossen. Weiter mit beliebiger Taste..."
      Sinkey(0)

   ENDDO



#include 'x:\run\onpow_prices.prg'
