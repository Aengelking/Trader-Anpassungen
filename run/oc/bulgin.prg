LOCAL cDir := "Y:\Dokumente und Einstellungen\Amos\Eigene Dateien\AUTO_OC\"


LOCAL cFile := '"'+cDir+'e797342.pdf"'
LOCAL hSearch := {"PO"=>"Customer Order No:s*([0-9]*)","AB"=>"Order No:\s*(E[0-9]{1,})"}

/**
   Function to get from PDF file

   Tabula (https://github.com/tabulapdf/tabula-java/) is used to extract the position information and GhostScript.to convert the PDF to text which can then been searched with regex's

   RETURN: Array containing the data rows


**/

FUNCTION GetDataFromPDF(cFile,hSearch,hResults)
   LOCAL cTabulaExe := GetConfigValue("PATHS_JAVA")+'java -jar "'+Trim(Tr_getini(1))+"\3rdparty\"+'tabula-0.9.2-jar-with-dependencies.jar" -i -g '
   LOCAL cGSExe := '"C:\Program Files (x86)\gs\gs9.14\bin\gswin32c.exe" -sDEVICE=txtwrite -q -dBATCH -dNOPAUSE -sOutputFile=- '
   LOCAL nStdOut,cData,nProc,cCSV := "",cTXT := ""
   LOCAL cRegex,nX
   LOCAL aData := {}

   hResults := {=>}

   FOR nX := 1 TO 2
      nProc := HB_OpenProcess(IF(nX==1,cTabulaExe,cGSExe)+cFile,,@nStdOut,,.T.)

      IF nProc < 0
         ? "Error executing exe"
         Sinkey(0)
         RETURN
      ENDIF

      DO WHILE HB_ProcessValue(nProc,.F.) == -1
         cData := Space( 1000 )
         nBytes := Fread( nStdOUT, @cData, Len(cData) )
         IF nX == 1
            cCSV += Trim(cData)
         ELSE
            cTxt += Trim(cData)
         ENDIF
      ENDDO
      IF Empty(hSearch)
         EXIT
      ENDIF
   NEXT

   FOR EACH cRegex IN hSearch
      aRegex := HB_Regex(cRegex,cTxt)
      IF Len(aRegex) < 2
         Alert(cRegex:__eNumKey()+" not found;"+cRegex+";"+ValToPRg(aRegex))
      ELSE
         hResults[cRegex:__eNumKey()] := aRegex[2]
      ENDIF
   NEXT

   ? MlCount(cCSV,4096)
   FOR nX := 1 TO MlCount(cCSV,4096)
      ? ValToPrg(FParseLine(Trim(MemoLine(cCSV,4096,nX,,,.T.))))
   NEXT

   HB_CloseProcess(nProc)
RETURN aData
