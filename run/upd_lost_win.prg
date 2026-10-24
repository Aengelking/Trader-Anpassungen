FUNCTION UPD_LOST_WIN
   LOCAL nManu := 3
   LOCAL nX,aData
   LOCAL aTotalData := {}

   SetConfigValue("BATCHMODE",.T.)

   aData := Bericht_Pos(1,Year(Date())-2,0,nManu,2,"DE",.F.,2)

   SetConfigValue("BATCHMODE",.F.)

   CLS

   FOR nX := 1 TO 10 
      ? aData[nX][2],aData[nX][4]
   NEXT

   //hTotalData[nManu] := aData
   
   ? HB_JsonEncode(aData)  

   Sinkey(0)

#include "x:\run\reports\pos.prg"