  PROC TEST_DAVID_DLL
   local pLib := hb_LibLoad( "dvapi32.dll" )
   LOCAL oObj
   Alert(ValToPRg(pLib))
   oObj := hb_DynCall( { "Chatmanager", pLib })
   Alert(ValToPRg(oObj))
