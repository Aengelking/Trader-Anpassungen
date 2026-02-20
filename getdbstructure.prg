FUNCTION RUN_GetDBStructure
   LOCAL hData := {=>}
   LOCAL hFileData
   LOCAL nOrd
   LOCAL cFile
   LOCAL aDir,nX
   LOCAL cJson
   LOCAL cOutputFile
   LOCAL hFile
   LOCAL cConfigPath

   Head("Export DB structures to JSON")

   // Determine config path
   cConfigPath := HB_CmdArgArgV()
   cConfigPath := SubStr(cConfigPath,1,RAt(HB_OSPATHSEPARATOR(),cConfigPath))+".."+HB_OSPATHSEPARATOR()+"config"+HB_OSPATHSEPARATOR()
   cOutputFile := cConfigPath + "dbstructure.json"

   aDir := LETO_Directory("*.dbf")

   @ 02,00 SAY "Scanning " + AllTrim(Str(Len(aDir))) + " database files..."
   @ 03,00 SAY ""

   FOR nX := 1 TO Len(aDir)      
      cFile := SubStr(aDir[nX,1],1,At(".",aDir[nX,1])-1)
      @ 04,00 SAY PadR("Processing: " + cFile, 60)
      BEGIN SEQUENCE
         hFileData := {=>}
         NetUse(cFile,"tmp")
         
         hFileData["STRUCT"] :=  tmp->(dbStruct())   
         hFileData["INDEXES"] := {}
         nOrd := 1
         DO WHILE ! Empty(tmp->(OrdBagName(nOrd))) // tmp->(dbSetOrder(nOrd) != NIL .AND. nOrd == tmp->(IndexOrd())
            Aadd(hFileData["INDEXES"],{"NAME"=>tmp->(OrdName(nOrd)),"UNIQUE"=>tmp->(OrdIsUnique(nOrd)),"DESCEND"=>tmp->(OrdDescend()),"FOR"=>tmp->(OrdFor(nOrd)),"KEY"=>tmp->(OrdKey(nOrd))})
            nOrd++
         ENDDO
         hData[cFile] := hFileData
         tmp->(dbCloseArea())
      RECOVER
         @ 05,00 SAY "ERROR processing: " + cFile
      END SEQUENCE
   NEXT

   @ 06,00 SAY ""
   @ 07,00 SAY "Generating JSON..."
   
   cJson := HB_JsonEncode(hData, .T.)  // .T. for pretty-print
   
   @ 08,00 SAY "Writing to file: " + cOutputFile
   
   // Write JSON to file
   hFile := FCreate(cOutputFile)
   IF hFile == -1
      @ 09,00 SAY "ERROR: Could not create file!"
      @ 10,00 SAY "File: " + cOutputFile
      @ 11,00 SAY "Error code: " + AllTrim(Str(FError()))
      @ 12,00 SAY ""
      @ 13,00 SAY "Press any key..."
      Inkey(0)
      RETURN .F.
   ENDIF
   
   FWrite(hFile, cJson)
   FClose(hFile)
   
   @ 09,00 SAY "SUCCESS! Database structure exported."
   @ 10,00 SAY "File: " + cOutputFile
   @ 11,00 SAY "Size: " + AllTrim(Str(Len(cJson))) + " bytes"
   @ 12,00 SAY "Tables: " + AllTrim(Str(Len(HB_HKeys(hData))))
   @ 13,00 SAY ""
   @ 14,00 SAY "Press any key..."
   Inkey(0,128)
   
RETURN .T.
