//place this include file directly after the local definitions in the prg file and the script will only run on working days

LOCAL aDays,nDow

nDow := DoW(Date())
IF nDow == 1 .OR. nDow == 7  //Smastag oder Sonntag
   RETURN .F.
ENDIF  

IF IsFeierTag(Date(),"BW",.F.)
   RETURN .F.
ENDIF

aDays := Hook("get_firmclosed",{Year(Date())},{})

IF Date() $ aDays
   RETURN .F.
ENDIF

//RETURN .T.