
FUNCTION _GetMinMargin(cMatchcode)

   LOCAL nMargin := 0.20

   LOCAL nLowMargin     := 0.14
   LOCAL aLowBeginnings := {"PX04","SA3347","SA3348","SA3350","SA3349"}  //400er Serie

   LOCAL nVeryLowMargin := 0.10
   LOCAL aVeryLowProducts := {} //{"PX0686"}

   LOCAL nMarg,nX

   nMarg := nMargin
   IF AScan(aVeryLowProducts,Trim(cMatchcode)) != 0
      nMarg := nVeryLowMargin
   ELSE
      FOR nX := 1 TO Len(aLowBeginnings)
         IF AT(aLowBeginnings[nX],cMatchcode) == 1
            nMarg := nLowMargin
            EXIT
         ENDIF
      NEXT
   ENDIF

RETURN nMarg
