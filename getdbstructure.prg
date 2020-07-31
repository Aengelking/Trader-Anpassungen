PROCEDURE RUN_GetDBStructure
   LOCAL hData := {=>}
   LOCAL hFileData
   LOCAL nOrd
   LOCAL cFile
   LOCAL aDir,nX

   Head("Export DB structures to JSON")

   aDir := Directory(Trim(Tr_Getini(1))+"\*.dbf")

   FOR nX := 1 TO Len(aDir)
      @ 01,00 SAY cFile
      cFile := aDir[nX,1]
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
   NEXT
   gtSetClipBoard(HB_JsonEncode(hData))
   ? "done"
   Sinkey(0)
RETURN
