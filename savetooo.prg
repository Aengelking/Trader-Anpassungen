FUNCTION RUN_TestSaveOO()
   SaveToOO("Y:\Dokumente und Einstellungen\amos\Documents\amos.xlsx",{;
      "FIRST"=>{{"TEXT","NUMERIC","DATE","TIME","BOOLEAN"},{"DATA ONE",1,Date()-1,DateTime(),.T.},{"DATA TWO",2,Date(),DateTime(),.F.},{"DATA THREE","=SUM(B2:B3)","=C3-C2"}},;
      "SECOND"=>{};
   })
   
RETURN NIL

FUNCTION SaveToOO(cFileName,hData,cPW,cType,lShow,bProgress)
   LOCAL oOO,aProps,oDesk
   LOCAL oDoc,oSheets,oSheet,oCell
   LOCAL nR,nC,aData
   LOCAL nDone := 0,nTot := 0
 
   IF ValType(hData) == "A"
      hData := {""=>hData}
   ENDIF
   

   IF ValType(cType) != "C" .OR. ! Upper(cType) $ {"ODS","XLS","XLSX"}
      cType := "ODS"
   ELSE
      cType := Upper(cType)
   ENDIF

   Default(@bProgress,{|| .T. })   
   Default(@lShow,.F.)

   oOO := CreateObject("com.sun.star.ServiceManager")
   
   oDesk := oOO:createInstance("com.sun.star.frame.Desktop")
   IF oDesk == NIL
      Tr_MsgBox(t("OpenOffice konnte nicht geöffnet werden"))
      RETURN .F.
   ENDIF
   aProps := {}  
   IF ! Empty(cFileName)
      Aadd(aProps,OOProperty(oOO,"Hidden",.T.)) //this will hide the window, so the save happens in the background
   ENDIF

   oDoc := oDesk:loadComponentFromURL("private:factory/scalc", "_blank", 0,aProps)  //create new document
   oSheets := oDoc:getSheets()

   FOR EACH aData IN hData
      nTot += Len(aData)
   NEXT

   FOR EACH aData IN hData
      
      IF aData:__eNumIndex() == 1  //get the sheet already contained in the new document
         oSheet := oSheets:getByIndex(0)
         IF ! Empty(aData:__eNumKey()) //we can leave the first sheet name blank (e.g. when we only have one sheet)
            oSheet:setName(aData:__eNumKey())
         ENDIF   
      ELSE
         oSheets:insertNewByName(aData:__eNumKey(),aData:__eNumIndex()-1)
         oSheet := oSheets:getByIndex(aData:__eNumIndex()-1)
      ENDIF

      FOR nR := 1 TO Len(aData)
         Eval(bProgress,nTot,nDone+nR)
         FOR nC := 1 TO Len(aData[nR])
            oCell := oSheet:getCellByPosition(nC-1,nR-1)
            SWITCH ValType(aData[nR,nC])
               CASE "C"
                  oCell:setFormula(aData[nR,nC])
                  EXIT
               CASE "N"
                  oCell:setValue(aData[nR,nC])
                  EXIT
               CASE "D"
                  oCell:setFormula(DToC(aData[nR,nC]))
                  EXIT
               CASE "T"
                  oCell:setFormula(TtoC(aData[nR,nC]))
                  EXIT
               CASE "L"
                  oCell:setFormula(IF(aData[nR,nC],"true","false"))
                  EXIT
            END
            
         NEXT
      NEXT      
      nDone := Len(aData)
   NEXT
   
   IF ! Empty(cFileName)      
      aProps := {}
      IF ! Empty(cPW)
         Aadd(aProps,OOProperty(oOO,"Password",cPW))
      ENDIF
      IF cType != "ODS"
         Aadd(aProps,OOProperty(oOO,"FilterName",IF(cType=="XLSX","Calc MS Excel 2007 XML","MS Excel 97")))
      ENDIF
      oDoc:storeAsUrl("file:///"+StrTran(cFileName,"\","/"),aProps)      
      IF ! lShow      
         oDoc:close(.F.)
      ENDIF
   ENDIF
   IF lShow
      oDoc:currentController:Frame:ContainerWindow:setVisible(.T.)      
   ENDIF
   
RETURN .T.

FUNCTION OOProperty( oServiceManager, cName, uValue )
   LOCAL cStructure
   LOCAL oProperty

   cStructure := "com.sun.star.beans.PropertyValue"

   oProperty := oServiceManager:bridge_GetStruct( cStructure )
   oProperty:Name := cName
   oProperty:Value := uValue
RETURN oProperty

FUNCTION OONumToCol(nNum)
   LOCAL nX := 1,nY := 26
   
   LOCAL cCol := ""
   DO WHILE nNum > 0 .AND. Inkey() != 27
      cCol := Chr(IF(Mod(nNum,26)==0,26,Mod(nNum,26))+64)+cCol
      //?? nNum,nNum/26,Mod(nNum,26)
      nNum := Int( nNum / 26 ) - IF(Mod(nNum,26)==0,1,0) 
      
   ENDDO
   
RETURN cCol
//RETURN Chr(64+nNum) //only workds up to col 26

FUNCTION OOCell(nCol,nRow)
RETURN OONumToCol(nCol)+LTrim(Str(nRow))

FUNCTION SaveToOO_Interface(hData,cPW,cType,lShow)
   LOCAL cFile,nH := 0

   IF ValType(cType) != "C" .OR. ! Upper(cType) $ {"ODS","XLS","XLSX"}
      cType := "ODS"
   ELSE
      cType := Upper(cType)
   ENDIF

   DO WHILE .T.
      cFile :=  Wvt_GetSaveFileName( 0,"" , cType+" Datei", { {"Spreadsheet (*."+Lower(cType)+")","*."+Lower(cType)},{"Alle Dateien (*.*)","*.*"} }, , "%home%" )
      IF Empty(cFile)
         RETURN NIL
      ENDIF
      IF RAT("."+Lower(cType),cFile) != Len(cFile)-3
         cFile += "."+Lower(cType)
      ENDIF

      IF File(cFile) .AND. Tr_MsgBox("Datei berschreiben?",,{"Nein","Ja"}) == 2 .AND. (nH := Fopen(cFile,1)) == -1
         Tr_MsgBox("Fehler beim ™ffnen der Datei")
      ELSE
         EXIT         
      ENDIF
   ENDDO

   IF nH > 0
      FClose(nH)
   ENDIF
   TxtBox("Daten werden gespeichert ... ")
   SaveToOO(cFile,hData,cPW,cType,lShow)
   TxtClear()   
RETURN .T.

