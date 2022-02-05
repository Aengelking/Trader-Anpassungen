NetUse("me","me")
aRe := {57806,57815,57919,58092,58111,58115,58123,58154,58217,58270,58284,58292}
SetConfigValue("BATCHMODE",.T.)
SetPrinterMethodType(1)
nRe := NIL
Head("Rechnungen drucken")
FOR EACH nRe IN aRe
//FOR nRe := 47920 TO 48010
   @ 01,00 SAY nRe
   engrepr(,3,nRe,.F.,1,0)
NEXT
SetPrinterMethodType(0)
SetConfigValue("BATCHMODE",.F.)