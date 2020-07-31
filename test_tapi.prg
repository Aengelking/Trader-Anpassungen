#include "y:\hb32\include\hbdyn.ch"

/*
//this works fine
pDLL := HB_LibLoad("user32.dll")
IF pDLL == NIL
   Alert("LIB not loaded")
ENDIF

hb_dynCall( { "MessageBoxA", pDLL, HB_DYN_CALLCONV_STDCALL }, 0, "Hello world!", "Harbour sez", hb_bitOr( 0x00000001, 0x00000030, 0x00004000 ) )
Alert(ValToPrg(HB_LIBERROR()))
HB_LibFree(pDLL)*/

/*pDLL := HB_LibLoad("tapi3.dll")
IF pDLL == NIL
   Alert("LIB not loaded")
ENDIF
//oTapi := hb_dynCall( { "TAPIClass", pDLL, HB_DYN_CALLCONV_STDCALL } ) //returns NIL
oTapi := hb_dynCall( { "TTapi", pDLL, HB_DYN_CALLCONV_STDCALL } ) //also returns NIL
oTapi := hb_dynCall( {"tapiRequestMakeCall",pDLL, HB_DYN_CALLCONV_STDCALL } ) //also NIL (strNumber, CStr(Caption), strLocation, "")

Alert(ValToPrg(oTapi))
//Alert(ValToPrg(HB_LIBERROR()))

HB_LibFree(pDLL) */

Head(" TAPI Test ")

oTapi := CreateObject("TAPI.TAPI.1")
IF ValType(oTapi) == "O"
   oTapi:initialize()

   ? "TAPI-Lines: "+Str(oTapi:Addresses:Count())
   FOR nX := 1 TO oTapi:Addresses:Count()
      ? oTapi:Addresses:Item(nX):AddressName
   NEXT
ENDIF

Sinkey(0)