PROC ShowAdrInfo(nNr,nContact)
   MEMVAR c_one
   SetColor(c_one)
   CLS
   NetUse("engkund","ku")
   ku->(dbSetOrder( 8 ))
   ku->(dbSeek(Str(nNr,6)))
   MBaseRun(Path("trd_02","MASK"),{nContact}) 
RETURN