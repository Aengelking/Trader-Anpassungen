FUNCTION RUN_SHIP_PRICE_40( mPreis,GEWICHT,hPakData )

LOCAL nNewWeight := GEWICHT
LOCAL nZuschlag := 6.8   //In Prozent 2019=6,8%
LOCAL nKub,nKG


IF hPakData["TYPE"] == "EP"
   IF ku->CountryIso $ "AT" .AND. GEWICHT < 200
      nNewWeight := 200
   ELSEIF GEWICHT < 150
      nNewWeight := 150
   ENDIF
//ELSEIF hPakData["TYPE"] == "HP" .AND. GEWICHT < 75 //Gilt bei Emons nur für halbe Europaletten. Also für uns nicht zutreffend.
ELSEIF hPakData["TYPE"] == "GP" .AND. GEWICHT < 250 .AND. ku->CountryIso $ "DE"
   nNewWeight := 250
ENDIF

//Volumengewicht
nKub := Round(hPakData["H"]*hPakData["W"]*hPakData["L"]/(100*100*100),2)
IF ku->CountryIso == "AT"
   nKG  := 250*nKub
ELSEIF ku->CountryIso == "PL"
   nKG := 250*nKub
ELSE
   nKG  := 150*nKub
ENDIF

IF nKG > nNewWeight
   nNewWeight := nKG
ENDIF

mPreis *= (1+nZuschlag/100)

IF nNewWeight != GEWICHT
   mPreis := PakPreis(40,nNewWeight,hPakData)
ELSEIF ku->CountryIso $ "AT PL"
   mPreis += 2.5  //Verbringungsnachweis
ENDIF

RETURN mPreis