NetUse("me","me")
aRe := {44261,44262,45202,39915}
SetPrinterMethodType(1)
nRe := NIL
FOR EACH nRe IN aRe
//FOR nRe := 47920 TO 48010
   engrepr(,3,nRe,.F.,1,0)
NEXT
SetPrinterMethodType(0)