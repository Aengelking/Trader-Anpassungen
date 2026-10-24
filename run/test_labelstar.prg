NetUse("artikel","art")
nSec := Seconds()
FOR nX := 1 TO 20
   __KeyBoard(Chr(13))
   StickPrint("WARE",1)
   art->(dbSkip())
   //Alert("Printed: "+Str(nX))
NEXT
Alert("Took: "+Str(Seconds()-nSec))

/*
Before 24.64s
.Remove Init: 18.13, 17.16
Saved fields: 12.18s
*/

