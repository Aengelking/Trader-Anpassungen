#include "y:\hb32\include\dll.ch"

PROC RUN_Test_Busylight
   LOCAL hDll := DllLoad("BusylightSDK.dll")
   LOCAL oCol,cRet
   Alert(ValToPrg(hDll))
   oCol := DllCall(hDll,DLL_SYSTEM,"Busylight.SDK",,@cRet)
   Alert(ValToPrg(oCol))
   Alert(ValToPrg(cRet))