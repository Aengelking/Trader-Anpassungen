PARAMETERS mPreis,GEWICHT,hPakData

LOCAL nNewWeight := GEWICHT

IF hPakData["TYPE"] == "EP"
   IF ku->CountryIso $ "AT PL" .AND. GEWICHT < 250
      nNewWeight := 250
   ELSEIF GEWICHT < 150
      nNewWeight := 150
   ENDIF
ELSEIF hPakData["TYPE"] == "HP" .AND. GEWICHT < 75
   IF ku->CountryIso $ "AT PL"
      nNewWeight := 150
   ELSE
      nNewWeight := 75
   ENDIF
ELSEIF hPakData["TYPE"] == "GP" .AND. GEWICHT < 250
   nNewWeight := 250
ENDIF

//Volumengewicht
nKub := Round(hPakData["H"]*hPakData["W"]*hPakData["L"]/(100*100*100),2)
IF ku->CountryIso == "AT"
   nKG  := 200*nKub
ELSEIF ku->CountryIso == "PL"
   nKG := 250*nKub
ELSE
   nKG  := 150*nKub
ENDIF

IF nKG > nNewWeight
   nNewWeight := nKG
ENDIF


IF nNewWeight != GEWICHT
   mPreis := PakPreis(57,nNewWeight,hPakData)
ELSEIF ku->CountryIso $ "AT PL"
   mPreis += 4  //Verbringungsnachweis
ENDIF

RETURN mPreis