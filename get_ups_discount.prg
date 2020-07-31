PARAMETERS cCountry,cService,nBoxCount

LOCAL nDiscount := 0

IF cCountry == "DE" 
   IF cService == "ST"  //Standard
      nDiscount := 65
   ELSEIF cService == "SV" .OR. cServce == "ES"  //Saver or Express
      nDiscount := 69
   ENDIF
ENDIF

RETURN nDiscount/100