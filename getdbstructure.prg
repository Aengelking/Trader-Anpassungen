FUNCTION RUN_GetDBStructure
   LOCAL hData := {=>}
   LOCAL hFileData
   LOCAL nOrd
   LOCAL cFile
   LOCAL aDir,nX

   Head("Export DB structures to JSON")

   aDir := Directory(Trim(Tr_Getini(1))+"\db\*.dbf")

   FOR nX := 1 TO Len(aDir)      
      cFile := SubStr(aDir[nX,1],1,At(".",aDir[nX,1])-1)
      @ 01,00 SAY cFile
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
      END SEQUENCE
   NEXT
   
RETURN HB_JsonEncode(hData)
