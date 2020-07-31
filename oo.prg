FUNCTION OOProperty( oServiceManager, cName, uValue )
   LOCAL cStructure
   LOCAL oProperty

   cStructure := "com.sun.star.beans.PropertyValue"

   oProperty := oServiceManager:bridge_GetStruct( cStructure )
   oProperty:Name := cName
   oProperty:Value := uValue
   RETURN oProperty