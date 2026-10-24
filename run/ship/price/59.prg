PARAMETERS mPreis,GEWICHT,hPakData

//Volumengewicht
nKub := Round(hPakData["H"]*hPakData["W"]*hPakData["L"],2)
nKG  := nKub/5000

IF nKG > GEWICHT
   mPreis := PakPreis(59,nKG,hPakData)
ENDIF

RETURN mPreis