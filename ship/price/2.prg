PARAMETERS mPreis,GEWICHT,hPakData

IF ku->CountryIso == "DE" //Deutschland
   GEWICHT := Round(GEWICHT,0)
   IF GEWICHT > 30
      mPreis := 11.48
   ELSEIF GEWICHT > 28
      mPreis := 9.69
   ELSEIF GEWICHT > 26
      mPreis := 9.21
   ELSEIF GEWICHT > 24
      mPreis := 8.70
   ELSEIF GEWICHT > 22
      mPreis := 8.18
   ELSEIF GEWICHT > 18
      mPreis := 7.66
   ELSEIF GEWICHT > 14
      mPreis := 6.61
   ELSEIF GEWICHT > 10
      mPreis := 5.50
   ELSEIF GEWICHT > 7
      mPreis := 4.26
   ELSEIF GEWICHT > 4
      mPreis := 3.67
   ELSE
      mPreis := 3.48
   ENDIF
ENDIF

RETURN mPreis