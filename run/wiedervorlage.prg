//Alert("Wiedervorlage "+mcInfo+TtoC(mdWieder))
/*nBuy := Tr_Getini(28)
aEmail := {=>}
aEmail[1] := "steve.engelking@engelking.de"
aEmail[9] := "amos.engelking@engelking.de"
aEmail[32] := "tobias.vosseler@engelking.de"
aEmail[33] := "thimo.hamma@engelking.de"
cTo := aEmail[nBuy]

Set(120,"hh-mm-ss-ccc")
cFile := "\\bull\david\import\"+StrTran(TtoC(DateTime())," ","-")+".fax"
cData := "@@EMAIL@@@@TERMIN "+DToC(mdWieder)+" 9:00@@"
cData += "@@AN "+cTo+"@@"
cData += "@@BETREFF Wiedervorlage "+ku->Name1+"@@"
cData += mcInfo
MemoWrit(cFile,cData) */
dDateTime := SToT(Str(Year(Date()),4)+Str(Month(Date()),2)+Str(Day(Date()),2)+Str(Hour(DateTime()),2)+Str(Minute(DateTime())+2,2)+"00.00")
Alert(TToS(dDateTime))
AddWiedervorlage(dDateTime,"TEST "+Time(),"Hello World","TEST1")