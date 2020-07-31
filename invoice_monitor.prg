LOCAL cPath := GetRegistry(2,"Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders","Personal")+"\Eingangsrechnungen Trader"
LOCAL aDir,nX
LOCAL oWin := GetMainWindow()

oWin:Hide()
//? cPath
IF ! IsDir(cPath)
   MakeDir(cPath)
ENDIF
DO WHILE .T.
   Head(t("Eingangsrechnung Pfadüberwachung"))

   aDir := Directory(cPath+"\*.pdf")
   FOR nX := 1 TO Len(aDir)
      //? aDir[nX,1]
      SetConfigValue("attachfile",cPath+"\"+aDir[nX,1])      
      oWin:Show()      
      MBaseRun(Trim(Tr_getini(1))+"\run\invoice_beleg",{"MONITOR"})      
      WvtSetPaint({})      
      DO WHILE ! DeleteAttachedFile() .AND. Ferror() == 32
         Tr_msgBox("Datei noch in einen Programm ge”ffnet. Bitte schlieáen.")         
      ENDDO
      oWin:Hide()
   NEXT
   dbCloseAll()
   IF Inkey(2) == 27
      EXIT
   ENDIF
ENDDO