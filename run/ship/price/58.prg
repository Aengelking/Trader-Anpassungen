PARAMETERS mPreis,GEWICHT,hPakData

LOCAL aMinWeightsDE  := {"EP"=>150,"HP"=>0,"GP"=>250}
LOCAL aMinWeightsInt := {"EP"=>150,"HP"=>0,"GP"=>250}
LOCAL nCbmKgDE       := 150
LOCAL nCbmKgInt      := 250
LOCAL hCbmKgCountry  := {"BA"=>333,"FI"=>333,"NO"=>333,"SE"=>333,"UA"=>333,"LU"=>150}
LOCAL nNewWeight     := GEWICHT

//Dieselzuschlag
NetUse("diesel_schenker","ds_sch")
ds_sch->(dbGoBottom())
IF ds_sch->From <= Date() .AND. ds_sch->From >= BoM(AddMonth(Date(),-1))
   mPreis *= 1+ds_sch->Percent/100
ENDIF

//Mindestgewichte für Sperrigkeiten
IF ku->CountryIso == "DE" .AND. HHasKey(aMinWeightsDE,hPakData["TYPE"]) .AND. GEWICHT < aMinWeightsDE[hPakData["TYPE"]]
   nNewWeight := aMinWeightsDE[hPakData["TYPE"]]
ELSEIF ku->CountryIso != "DE" .AND. HHasKey(aMinWeightsInt,hPakData["TYPE"]) .AND. GEWICHT < aMinWeightsInt[hPakData["TYPE"]]
   nNewWeight := aMinWeightsInt[hPakData["TYPE"]]
ENDIF

//Volumengewicht
nKub := Round(hPakData["H"]*hPakData["W"]*hPakData["L"]/(100*100*100),2)
IF HHasKey(hCbmKgCountry,ku->CountryIso)
   nKG  := hCbmKgCountry[ku->CountryIso]*nKub
ELSEIF ku->CountryIso == "DE"
   nKG  := nCbmKgDE*nKub
ELSE
   nKG  := nCbmKgInt*nKub
ENDIF

IF nKG > nNewWeight
   nNewWeight := nKG
ENDIF

IF nNewWeight != GEWICHT
   mPreis := PakPreis(58,nNewWeight,hPakData)
   //Alert(Str(mPreis))
   RETURN mPreis //do not add tauschgebühr (twice!)
ENDIF

//Tauschgebühr
IF hPakData["TYPE"] $ "EP GP"
   IF ku->CountryIso == "DE"
      mPreis += IF(hPakData["TYPE"]=="EP",1.50,10.50)
   ELSEIF ku->CountryIso $ "AT BE LU NL"
      mPreis += IF(hPakData["TYPE"]=="EP",5.50,10.50)
   ENDIF
ENDIF

//Maut berechnen wir nicht (ist zu kompliziert, und wird durch die Pauschale gedeckt)

RETURN mPreis




