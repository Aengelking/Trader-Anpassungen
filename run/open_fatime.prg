PARAMETERS cID
IF At("RT",cID) == 1
   nRT := Val(SubStr(cID,3))
   NetUse("restime","rst")
   rst->(dbSetOrder( 2 ))
   IF rst->(dbSeek( Str(nRT,12) )) .AND. Trim(rst->Type) == "WA"
      cID := Str(rst->No,6)
   ENDIF
ENDIF
WerkAuf(Val(cID))
