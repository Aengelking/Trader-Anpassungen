FUNC RUN_POS_TO_ODS
   LOCAL cDir := "\\EK-Server4\data\Dokumente und Einstellungen\Amos\Documents\POS\"
   LOCAL cFile,nH := 0//:= cDir+"POS_ALL_"+Str(nYear,4)+"-"+StrZero(nMonth,2)+".xls"
   LOCAL nYear := Year(Date())-3 
   LOCAL nType := 1
   LOCAL nMonth := 0
   LOCAL nManu := 0
   LOCAL nArt := 2 //intern
   LOCAL aData,hData
   LOCAL aManu := GetManufacturerArray()
   LOCAL nX,nLastCol,nCol
 
   

   //lBatch := GetConfigValue("BATCHMODE")
   //SetConfigValue("BATCHMODE",.T.)
   hData := Bericht_Pos(@nType,@nYear,@nMonth,@nManu,@nArt,"DE",.F.,0) //2)
   cFile := cDir+"POS_"
   IF nManu != 0
      cFile += Trim(aManu[2][nManu])+"_"
   ENDIF
   IF nType == 1
      cFile += Str(nYear,4)+"-"+Str(Year(Date()),4)
      IF nMonth == 0
         cFile += "_YTD"
      ELSE
         cFile += "_"+Strzero(nMonth,2)
      ENDIF
   ELSE
      cFile += Str(nYear,4)+"-"+StrZero(nMonth,2)
   ENDIF
   cFile += ".ods"
   /*IF nType == 1
      /*FOR EACH aData IN hData
         IF aData:__eNumKey() == "CUSTOMER"
            nLast := 
         ELSEIF aData:__eNumKey() == "TOTALS"
            nLast := 4
         ELSEIF aData:__eNumKey() == "PRODUCTS"
            nLast := 
         ENDIF
         aData := hData["TOTALS"]
         FOR nX := 1 TO Len(aData)
            nLastCol := Len(aData[nX])
            IF nX == 1
               Aadd(aData[nX],"Diff. YTD")
               FOR nCol := nLastCol-2 TO 4 STEP -1
                  Aadd(aData[nX],"Diff. "+Right(aData[nX,nCol],2)+"-"+Right(aData[nX,nCol-1],2))
               NEXT
            ELSE
               FOR nCol := nLastCol TO 4 STEP -1
                  Aadd(aData[nX],"="+OOCell(nCol,nX)+"-"+OOCell(nCol-1,nX))
                  IF nCol == nLastCol
                     nCol++  //Jump YTD
                  ENDIF
               NEXT
                  //Aadd(aData[nX],"="+OOCell(nLastCol-2,nX)+"-"+OOCell(nLastCol-3,nX))
            ENDIF
         NEXT
      //NEXT
   ENDIF*/
   DO WHILE .T.
      cFile :=  Wvt_GetSaveFileName( 0,"" , "ODS Datei", { {"Spreadsheet (*.ods)","*.ods"},{"Alle Dateien (*.*)","*.*"} }, , "%home%" )
      IF Empty(cFile)
         RETURN NIL
      ENDIF
      IF RAT(".ods",cFile) != Len(cFile)-3
         cFile += ".ods"
      ENDIF

      IF File(cFile) .AND. Tr_MsgBox("Datei berschreiben?",,{"Nein","Ja"}) == 2 .AND. (nH := Fopen(cFile,1)) == -1
         Tr_MsgBox("Fehler beim ”ffnen der Datei")
      ELSE
         EXIT         
      ENDIF
   ENDDO

   IF nH > 0
      FClose(nH)
   ENDIF
   TxtBox("Daten werden gespeichert ... ")
   SaveToOO(cFile,hData)
   TxtClear()
   Wapi_ShellExecute(,"open",cFile)
RETURN NIL


#include "x:\run\reports\pos.prg"
#include 'X:\run\savetooo.prg'