PARAMETERS mWeight,lRech,mNr,mRech,aPakData

nVersandArt := 2
cShipPrg := Trim(Tr_Getini(1))+"\run\ship\"+LTrim(Str(nVersandArt))+".prg"
aNum := MBaseRun(cShipPrg,{mWeight,lRech,mNr,mRech,aPakData,"SV",.T.})

Return aNum