//#define _SET_DATEFORMAT       4
//#define TEST
#define DEBUG .F. //Tr_Getini(28) == 9

FUNCTION AutoBeleg(aAutoOC,cMsgId)
   LOCAL oAccount := DV_GetMailAccount()
   LOCAL oArchive,cArchive //  := oAccount:GetSpecialArchive(101) //Personal IN
   LOCAL oMsg
   LOCAL hAutoOC
   LOCAL lBooked := .F.
   LOCAL cFile
   LOCAL nAtt

   IF ! Empty(cMsgId)     
      cArchive := SubStr(cMsgId,1,RAT("\",cMsgId)-1)
      oArchive := oAccount:GetArchive(cArchive)
      oMsg := oArchive:GetArchiveEntryById(cMsgId)      
      FOR EACH hAutoOC IN aAutoOC
         IF HB_RegexMatch(hAutoOC["EMAIL"],Lower(oMsg:Fields("SRFrom"):Value)) //HB_RegexMatch("(onpow@vip\.163\.com)|(*.@onpow\.com)$","123") //
            IF HHasKey(hAutoOC,"FILE")
               FOR nAtt := 0 TO oMsg:Attachments:Count-1
                  IF HB_RegexMatch(hAutoOC["FILE"],oMsg:Attachments:Item(nAtt):FileName,.F.)
                     cFile := CopyAttToTemp(oMsg:Attachments:Item(nAtt))
                     lBooked := Eval(hAutoOC["BLOCK"],oMsg,cFile)
                     FErase(cFile)
                  ENDIF
               NEXT
            ELSE
               lBooked := Eval(hAutoOC["BLOCK"],oMsg,cFile)
            ENDIF
         ENDIF
      NEXT
   ENDIF
RETURN lBooked

FUNCTION ProcessOCData(aData,cSup,cAbNr,nPO,cDate,caDateFormat,cIgnoreParts,lKomma,aAddProds,bFormatPartNo)
   LOCAL hRow
   LOCAL cError := ""
   LOCAL nKw := 0,dDate
   LOCAL aBes := {}
   LOCAL cDFormat := Set(_SET_DATEFORMAT) //save the current setting
   LOCAL nR,nC,nX
   LOCAL lDone := .F.
   LOCAL lFound,cScreen
   LOCAL bProcessPos
   LOCAL aPos := {}
   LOCAL nQty,nPrice
   LOCAL bAddErr := {|| cError += IF(nPO==0,Pad(hRow["PO"],6),Str(nPo,6))+" "+Pad(hRow["PART"],40)+" "+PadL(hRow["QTY"],12)+IF(HHasKey(hRow,"PRICE")," "+Pad(hRow["PRICE"],6)+IF(HHasKey(hRow,"PE"),"/"+Pad(hRow["PE"],4),Space(5)),Space(7))+" "+NiceWeek(nKW)+Chr(13)+Chr(10) }  
   LOCAL cDateFormat
   LOCAL nPE,bStrToVal,oBesPos

   MEMVAR c_five

   Default(@lKomma,.F.)
   Default(@aAddprods,{})
   Default(@bFormatPartNo,{|cPart| cPart })

   IF ValType(caDateFormat) == "C"
      caDateFormat := {caDateFormat}
   ENDIF

   NetUse("engbes","bes")
   NetUse("artlief","ali")
   NetUse("artikel","art")
   NetUse("werkauf","wer")

   cAbNr := Pad(cAbNr,10)

   Head("AB von "+Trim(cSup)+" halbautomatisch verbuchen")
   @ 01,00 SAY "AB-Nr.: "+cAbNr

   IF ! Empty(aData) //the DOC File contains data
      ? Pad("Bestellung",6),"Pos",Pad("Artikel",25),PadL("Menge",12+5),Pad("Termin",8),Pad("Wunsch",8),Pad("Bisher",8)
      FOR EACH hRow IN aData

         IF ! Empty(cDate) .OR. ! Empty(hRow["DATE"]) //if it is empty it stays the same as before
            FOR EACH cDateFormat IN caDateFormat
               Set(_SET_DATEFORMAT,cDateFormat)
               IF ! Empty(cDate)
                  dDate := CtoD(cDate)
               ELSE
                  dDate := CtoD(hRow["DATE"])
               ENDIF
               IF ! Empty(dDate)
                  EXIT
               ENDIF
            NEXT
            IF Empty(dDate)
               nKW := 0
               IF Len(caDateFormat) > 1
                  Set(_SET_DATEFORMAT,cDFormat)
                  dDate := GetBox(CToD(""),"Datum: "+IF(!Empty(cDate),cDate,hRow["DATE"]))
               ENDIF
            ENDIF
            IF ! Empty(dDate)
               nKW := Val( Right(Str(KWYear(dDate),4),2)+StrZero(DToKW(dDate),2) )
            ENDIF
         ENDIF

         IF HHasKey(hRow,"PO") .AND. ! Empty(hRow["PO"]) //if a PO is defined via the fields, then we get it here, if it is empty it stays the same as before
            nPO := Val(hRow["PO"])
         ENDIF
         IF nPO == 0
            //23.05.24 this causes an error and I do not understand what it does. Does not make any sense to me. Cannot find any referencce to "TOTAL" in the code
            /*IF ! "TOTAL" $ Upper(hRow["PO"])
               Eval(bAddErr)
               IF DEBUG
                  cError += "NO TOTAL"+Chr(13)+Chr(10)
               ENDIF
            ENDIF
            LOOP*/
         ENDIF

         IF ! nPO $ aBes
            Aadd(aBes,nPo)
         ENDIF
        
         bStrToVal := {|cVal|
            cVal := StrTran(cVal,IF(lKomma,".",","),"")  //replace thousander divider with nothing
            IF lKomma //swap comma with dot
               cVal := StrTran(cVal,",",".")
            ENDIF
//            Alert(cVal+";"+IF(lKomma,",","."))
            RETURN Val(cVal)
         }

         nQty := Eval(bStrToVal,hRow["QTY"])
         
         IF HHasKey(hRow,"PRICE")
            nPrice := Eval(bStrToVal,hRow["PRICE"])
            IF HHasKey(hRow,"PE")
               nPE := Eval(bStrToVal,hRow["PE"])
               IF nPE > 0
                  nPrice := nPrice/nPE
               ENDIF
            ENDIF
            IF HHasKey(hRow,"DIS")
               nPrice *= 1-Eval(bStrToVal,hRow["DIS"])/100
            ENDIF
         ENDIF         

         bes->(dbSetOrder(1))

         bProcessPos := {||
            LOCAL nPos
            LOCAL cPosAbnr := cAbNr
            art->(dbSetOrder(2))
            art->(dbSeek( Str(bes->Artikelnr,6) ))
            ali->(dbSetOrder( 1 ))
            ali->(dbSeek( cSup+Str(bes->Artikelnr,6) ))
            
            IF HHasKey(hRow,"AB")
               cPosAbNr := hRow["AB"]
            ENDIF

            IF  ( Trim(ali->Artlief) == Trim(hRow["PART"]) .OR. Trim(art->Matchcode) == Trim(hRow["PART"]) .OR. Trim(art->Matchcode) == Trim(Eval(bFormatPartno,hRow["PART"])) ) .AND. bes->BeQty == nQty
               lFound := .T.
               IF Empty(bes->Abnr) .OR. Trim(bes->Abnr) == Trim(cPosAbNr)
                  IF nKW == 0 .OR. nKW >= bes->Wterm
                     art->(dbSeek( Str(bes->Artikelnr,6) ))
                     ? bes->besnr,bes->Posnr,art->Matchcode,PadL(Transform(bes->BeQty,Me(art->Me)),12),art->Me,IF(nKW!=0,NiceWeek(nKW),"--------"),NiceWeek(bes->wTerm),NiceWeek(bes->Lterm)
                     IF HHasKey(hRow,"PRICE") .AND. nPrice != bes->EkPR/bes->Pe*(1-bes->Rabatt/100)
                        nR := Row()
                        nC := Col()
                        IF ABS(nPrice-bes->EkPR/bes->Pe*(1-bes->Rabatt/100)) <= 0.01 .OR. Tr_MsgBox({"Bestellung "+LTrim(Str(nPo)),"Artikel: "+hRow["PART"],"Menge "+hRow["QTY"],t("Preis Bestätigung: ")+hRow["PRICE"],"Preis Bestellung: "+LTrim(Str(bes->EkPr/bes->Pe))},"Preis weicht ab ",{t("ignorieren"),t("buchen")}) == 2
                           //preis speichern
                           #ifndef TEST
                           bes->(Rec_Lock())
                           bes->PE := AutoPE(nPrice)
                           bes->EkPr := nPrice*bes->PE
                           bes->(dbUnLock())
                           #endif
                        ENDIF
                        SetPos(nR,nC)
                     ENDIF
                     nPos := bes->Posnr
                     //save the delivery week
                     DO WHILE bes->Besnr == nPO .AND. (bes->Posnr == nPos .OR. bes->Folgeto == nPos)
                        #ifndef TEST
                        bes->(Rec_Lock())
                        IF nKW != 0
                           bes->LTerm := nKW
                        ENDIF
                        bes->AbNr  := cPosAbNr
                        bes->Confirmed := "Y"
                        bes->(dbUnLock())

                        wer->(dbSetOrder(6)) //Besnr
                        If wer->(dbSeek( Str(bes->Besnr,6)+Str(bes->Posnr,3) )) .AND. Right(Str(wer->End,4),2) != "99"   //Termin auch im Fertigungsauftrag (auáer bei Rahmen) hinterlegen
                           wer->(Rec_Lock(0))
                           wer->end := IF(Val(Right(Str(nKW,4),2))<=52,nKW+bes->ShipTime,nKW)
                           wer->(dbUnlock())
                        Endif
                        #endif
      
                        Aadd(aPos,Str(bes->Besnr,6)+Str(bes->Posnr,3))
                        bes->(dbSkip())
                     ENDDO
                     bes->(dbSkip(-1))
                  ELSE
                     Tr_MsgBox({"Bestellung "+LTrim(Str(nPo)),"Artikel: "+hRow["PART"],"Menge: "+hRow["QTY"],"frher als der Wunschtermin ("+NiceWeek(bes->WTerm)+") best„tigt ("+NiceWeek(nKW)+").","Position wurde nicht verbucht"},"Fehler")
                     IF DEBUG
                        cError += "CONFIRMED DATE EARLIER THAN REQUESTED "+Chr(13)+Chr(10)
                     endif
                  ENDIF
               ELSE
                  nR := Row()
                  nC := Col()
                  ? cPosAbNr
                  Tr_MsgBox({"Bestellung "+LTrim(Str(nPo)),"Artikel: "+hRow["PART"],"Menge: "+hRow["QTY"],"bereits mit "+Trim(bes->Abnr)+" "+t("bestätigt")},"ACHTUNG! Doppelbuchung")
                  SetPos(nR,nC)
               ENDIF
            ELSE
               IF DEBUG
                  cError += "PART/QTY NOT FOUND"+Chr(13)+Chr(10)
               endif
            ENDIF
            RETURN NIL
         }

         IF ! HHasKey(hRow,"LINE")

            IF  nQty != 0 //ignore lines with no quantity
               IF (Empty(cIgnoreParts) .OR. ! HB_RegexMatch(cIgnoreParts,hRow["PART"])) .AND. ! Empty(hRow["PART"])//if we should not ignore this line                        
                  lFound := .F.
                  IF bes->(dbSeek( Str(nPO,6) )) .AND. bes->Liefma == cSup
                     DO WHILE bes->Besnr == nPO .AND. ! bes->(EOF()) .AND. ! lFound
                        IF ! Str(bes->Besnr,6)+Str(bes->Posnr,3) $ aPos //position has been processed
                           Eval(bProcessPos)
                        ENDIF
                        bes->(dbSkip())
                     ENDDO
                  ELSE
                     IF DEBUG
                        cError += "PO ("+LTrim(Str(nPo))+") NOT FOUND"+Chr(13)+Chr(10)
                     ENDIF
                  ENDIF
                  IF ! lFound       
                     ali->(dbSetOrder( 3 ))
                     IF ali->(dbseek(cSup+hRow["PART"] ))
                        art->(dbSetOrder( 2 ))
                        art->(dbSeek( Str(ali->Artikelnr,6) ))
                     ELSE
                        art->(dbSetOrder( 1 ))
                        art->(dbSeek( Eval(bFormatPartno,hRow["PART"]) ))
                     ENDIF
                     IF art->(Found()) .AND. Trim(art->Matchcode) $ aAddProds
                        nR := Row()
                        nC := Col()
                        IF Tr_MsgBox({"Bestellung: "+LTrim(Str(nPo)),"Artikel: "+Trim(art->Matchcode),"Menge: "+Transform(nQty,Me(art->Me)),IF(HHasKey(hRow,"PRICE"),"Preis: "+LTrim(Str(nPrice)),"")},t("Position hinzufügen?"),{"Nein","Ja"}) == 2
                           SetPos(nR,nC)
                           bes->(dbSeek( Str(nPO,6) ))
                           DO WHILE bes->Besnr == nPO .AND. ! bes->(EOF())
                              bes->(dbSkip())
                           ENDDO
                           bes->(dbSkip(-1))
                           lFound := .T.
                           oBesPos := bes->(BestellungPos():New(.T.))
                           oBesPos:Besnr     := nPO
                           oBesPos:Posnr     := bes->posnr+1
                           oBesPos:Liefma    := cSup
                           oBesPos:Besda     := bes->besda
                           oBesPos:Matchcode := art->Matchcode
                           oBesPos:Wterm     := nKW
                           oBesPos:LTerm     := nKW
                           IF HHasKey(hRow,"PRICE")
                              oBesPos:PE        := AutoPe(nPrice)
                              oBesPos:EkPr      := nPrice*oBesPos:PE
                           ENDIF
                           oBesPos:BeQty     := nQty
                           oBesPos:Buyer     := bes->buyer
                           oBesPos:Pay       := bes->pay
                           oBesPos:abnr      := cAbNr
                           oBesPos:Person    := bes->person
                           oBesPos:Printed   := .F.
                           oBesPos:Money     := bes->Money
                           oBesPos:rate      := currate(bes->Money,"E")
                           oBesPos:Confirmed := "Y"
                           oBesPos:Save()
                           ? bes->besnr,oBesPos:Posnr,art->Matchcode,PadL(Transform(oBesPos:BeQty,Me(art->Me)),12),art->Me,NiceWeek(nKW),NiceWeek(bes->wTerm),"hinzu"
                        ELSE
                           SetPos(nR,nC)
                        ENDIF
                     ELSE
                        IF DEBUG
                           cError += "PART ("+hRow["PART"]+") NOT FOUND"+Chr(13)+Chr(10)
                        ENDIF
                     ENDIF
                     IF ! lFound
                        Eval(bAddErr)      
                     ENDIF
                  ENDIF
               ENDIF
               lDone := .T.
            ENDIF
         ELSE                                     
            IF Val(hRow["LINE"]) != 0 //ignore lines withoit Line no.
               lFound := .F.
               IF bes->(dbSeek( Str(nPO,6)+PadL(hRow["LINE"],3) )) .AND. bes->Liefma == cSup
                  Eval(bProcessPos)
               ENDIF
               IF ! lFound
                  Eval(bAddErr)
               ENDIF
               lDone := .T.
            ENDIF
         ENDIF
      NEXT
   ENDIF

   #ifndef TEST
   FOR nX := 1 TO Len(aBes)
      IF ! Hook("has_archive_file",{"BB",aBes[nX],GetConfigValue("attachfile")}) //attach the file if the file has not already been attached
         AddAttachedFileToArchive("BB",aBes[nX],.F.,.F.)
      ENDIF
   NEXT
   #endif


   Set(_SET_DATEFORMAT,cDFormat)

   IF ! Empty(cError)
      SetColor(c_Five)
      cScreen := SaveScreen()
      @ 10,05 CLEAR TO 20,88
      @ 10,05 TO 20,88
      @ 10,06 SAY "[ FEHLER! Bestellpositionen nicht gefunden, bitte manuell buchen ]"
      @ 20,06 SAY "[ Beenden mit >ESC< ]"
      cError := Pad("Bes.Nr.",6)+" "+Pad("Artikel",40)+" "+PadL("Menge",12)+" "+Pad("Preis",6)+Space(5)+" "+"Termin"+Chr(13)+Chr(10)+cError
      MemoEdit(cError,11,06,19,87,.F.)
      RestScreen(,,,,cScreen)
      RETURN .F.
   ENDIF
   //ELSEIF lDone
      ? ""
      @ Row(),00 SAY "Buchung abgeschlossen! Weiter mit beliebiger Taste..." COLOR c_five
      Sinkey(0)
//   ENDIF

RETURN lDone    


/**

   Function to get the table contained in table(s) in a .doc (or similar file) or the sheets from a .xls

   This uses the OpenOffice API - so this needs to be installed
   
**/

FUNCTION GetDataFromDoc(cPathFile,hFields)
   LOCAL oOO,oDesk,aProps,oDoc,oTables,oTable
   LOCAL nTable,nCol,nRows,nCols,cCol,cField,hRow,aData := {},nRow,hCols
   LOCAL cContent,cRegex
   LOCAL lDbg := .F. //Tr_getIni(28) == 9
   LOCAL lSpread := .F.
   LOCAL oCell

   oOO := CreateObject("com.sun.star.ServiceManager")
   oDesk := oOO:createInstance("com.sun.star.frame.Desktop")
   IF oDesk == NIL
      Tr_MsgBox(t("OpenOffice konnte nicht geöffnet werden"))
      RETURN {}
   ENDIF

   aProps := {}

   IF ! lDbg
      Aadd(aProps,OOProperty(oOO,"ReadOnly",.T.))
      Aadd(aProps,OOProperty(oOO,"Hidden",.T.))
   ELSE
      Alert("We are debugging "+cPathFile)
   ENDIF

   oDoc := oDesk:loadComponentFromURL("file:\\\"+cPathFile, "_blank", 0,aProps)
   IF oDoc == NIL
      Tr_MsgBox({t("Dokument konnte in OpenOffice nicht geladen werden"),cPathFile})
      RETURN {}
   ENDIF
   IF oDoc:supportsService("com.sun.star.sheet.SpreadsheetDocument")
      IF lDbg
         Alert("It's a spreadsheet")
      ENDIF
      lSpread := .T.
      oTables := oDoc:getSheets()
   ELSE
      oTables := oDoc:getTextTables()
   ENDIF
   FOR nTable := 0 TO oTables:getCount()-1
      oTable := oTables:getByIndex(nTable)
      nRows := Min(oTable:getRows():getCount(),1000)
      nCols := Min(oTable:getColumns():getCount(),30)

      hCols := {=>}
      IF nRows > 1 //at least two rows (header + one line)
         FOR nCol := 1 TO nCols
            IF lSpread
               cCol := nCol
               cContent := oTables:getCellByPosition(nCol-1,0,nTable):getFormula()
            ELSE
               cCol := Chr(64+nCol)
               cContent := oTable:getCellByName(cCol+"1"):getString()
            ENDIF

            //find the columns based on a regex
            FOR EACH cRegex IN hFields
               IF HB_RegexMatch(cRegex,cContent,.F.)
                  hCols[cRegex:__eNumKey()] := cCol
                  EXIT
               ENDIF
            NEXT

         NEXT
      ENDIF
      IF Len(hCols) == Len(hFields) //all fields have been found
         FOR nRow := 2 TO nRows
            hRow := {=>}
            FOR EACH cCol IN hCols
               cField := cCol:__eNumKey()
               IF lSpread
                  oCell := oTables:getCellByPosition(cCol-1,nRow-1,nTable)
                  cContent := oCell:getFormula()
                  IF AT("=",cContent) == 1 //it is a forumla, let's get the value
                     cContent := oCell:getValue()
                     IF ValType(cContent) == "N"
                        cContent := Str(cContent) //getForumla always returns a string, this way it is constant
//                         Alert(oCell:getFormula()+";"+cContent)
                     ENDIF
                  ENDIF
                  IF lDbg
                     ? cField,cContent
                  ENDIF
               ELSE
                  cContent := oTable:getCellByName(cCol+LTrim(Str(nRow))):getString()
               ENDIF
               hRow[cField] := cContent
            NEXT
            Aadd(aData,hRow)
         NEXT
      ENDIF
   NEXT
   IF lDbg
      ? "Press any key..."
      SInkey(0)
   ENDIF
   oDoc:close(.F.)
RETURN aData


FUNCTION OOProperty( oServiceManager, cName, uValue )
   LOCAL cStructure
   LOCAL oProperty

   cStructure := "com.sun.star.beans.PropertyValue"

   oProperty := oServiceManager:bridge_GetStruct( cStructure )
   oProperty:Name := cName
   oProperty:Value := uValue
RETURN oProperty

/**
   Function to get data from PDF file

   Tabula (https://github.com/tabulapdf/tabula-java/) is used to extract the position information and GhostScript.to convert the PDF to text which can then been searched with regex's

   RETURN: Array containing the data rows


**/

FUNCTION GetDataFromPDF(cFile,aArea,hFields,hSearch,hResults,cAreaHead,hCols)
   LOCAL cTabulaExe := GetConfigValue("PATHS_JAVA")+'java -jar "'+Path("3rdparty\")+'tabula-1.0.2-jar-with-dependencies.jar" -i '
   //LOCAL cGSExe := '"C:\Program Files (x86)\gs\gs9.14\bin\gswin32c.exe" -sDEVICE=txtwrite -q -dBATCH -dNOPAUSE -sOutputFile=- '
   LOCAL cGSExe := '"C:\Program Files\gs\gs9.22\bin\gswin64c.exe" -sDEVICE=txtwrite -q -dBATCH -dNOPAUSE -sOutputFile=- '
   LOCAL nStdOut,cData,nProc,cCSV := "",cTXT := ""
   LOCAL cRegex,nX
   LOCAL aData
   LOCAL nRows,aRow,nRow,nCol
   LOCAL nPages,nP,oPDF,cRun
   LOCAL aRegex

   hResults := {=>}
   IF Empty(aArea)
     aArea := {"-g -p all"}
   ENDIF

   cRegex := "\%p(-[0-9]{1,})?\%"
   FOR nX := 1 TO Len(aArea)+1
      IF nX<=Len(aArea)
         cRun := cTabulaExe+aArea[nX]+" "
      ELSEIF !Empty(cAreaHead)
         cRun := cTabulaExe+cAreaHead
      ELSE
         cRun := cGSExe
      ENDIF
      IF (nX <= Len(aArea) .OR. ! Empty(cAreaHead)) .AND. Len(aRegex := HB_Regex(cRegex,IF(nX <= Len(aArea),aArea[nX],cAreaHead))) > 0
         IF ValType(oPDF) != "O"
            oPDF := CreateObject("AcroExch.PDDoc") //CreateObject("AcroExch.App")
         ENDIF
         oPDF:Open(cFile)
         nPages := oPdf:GetNumPages()
         IF Len(aRegex) >= 2
            nPages += Val(aRegex[2])
         ENDIF
         oPDF:Close()
      ELSE
         nPages := nX
      ENDIF
      FOR nP := nX TO nPages
         nProc := HB_OpenProcess(IF(Len(aRegex) > 0,StrTran(cRun,aRegex[1],LTrim(Str(nP))),cRun)+' "'+cFile+'"',,@nStdOut,,.T.)
   
         IF nProc < 0
            ? "Error executing exe "+cRun
            Sinkey(0)
            RETURN NIL
         ENDIF
   
         DO WHILE HB_ProcessValue(nProc,.F.) == -1
            cData := Space( 1000 )
            Fread( nStdOUT, @cData, Len(cData) )
            IF nX <= Len(aArea)
               cCSV += Trim(cData)
            ELSE
               cTxt += Trim(cData)
            ENDIF
         ENDDO
      NEXT
      
      
      IF nX == Len(aArea) .AND. Empty(hSearch)
         EXIT
      ENDIF
   NEXT

   IF ! Empty(cAreaHead)
      IF DEBUG
         ? cTxt
         Sinkey(0)
      ENDIF
      nRows :=  MlCount(cTxt,4096)
      FOR nRow := 1 TO nRows
         aRow := FParseLine(Trim(MemoLine(cTxt,4096,nRow,,,.T.)))
         //? ValToPrg(aRow)
         FOR nCol := 1 TO Len(aRow)
            FOR EACH cRegex IN hSearch
               IF DEBUG
                  ? cRegex
               ENDIF
               aRegex := HB_Regex(cRegex,aRow[nCol])
               IF DEBUG .AND. ! Empty(aRegex)
                  ? ValToPrg(aRegex)
               ENDIF
               IF Len(aRegex) >= 2
                  hResults[cRegex:__eNumKey()] := aRegex[2]
               ENDIF
            NEXT
         NEXT
      NEXT
      IF DEBUG
        //Sinkey(0)
      ENDIF
   ELSE
      FOR EACH cRegex IN hSearch
         aRegex := HB_Regex(cRegex,cTxt)
         IF Len(aRegex) < 2
            Alert(cRegex:__eNumKey()+" not found;"+cRegex+";"+ValToPRg(aRegex))
         ELSE
            hResults[cRegex:__eNumKey()] := aRegex[2]
         ENDIF
      NEXT
   ENDIF

   IF DEBUG
      ? StrTran(cCSV,Chr(13),"")
      SInkey(0)
   ENDIF

   aData := __CSVToData(cCSV,hFields,hCols)

   HB_CloseProcess(nProc)
RETURN aData

FUNCTION GetDataFromHTMLTable(oTable,hFields,nFirst)
   LOCAL nRow,nCol,cRegex,hCols := {=>},aData := {},cContent,oTbody
   LOCAL aCols
   LOCAL aRows,hRow
   LOCAL bGetContent := {|| StrTran(HB_RegexReplace("<[^>]*>",aCols[nCol]:getText(),""),Chr(13)+Chr(10),"") }

   Default(@nFirst,1)
   
   aRows := oTable:childNodes() //findNodesByTagName("tr")
   IF Len(aRows) > 0 .AND. Upper(aRows[1]:htmlTagName) != "TR" //in case there is a tbody tag
      aRows := aRows[1]:childNodes()      
   ENDIF

   FOR nRow := nFirst TO Len(aRows)      
      aCols := aRows[nRow]:childNodes() //findNodesByTagName(IF(nRow==1,"th","td"))
      IF aCols != NIL
         IF nRow == nFirst            
            FOR nCol := 1 TO Len(aCols)
               cContent := Eval(bGetContent) //remove all HTML tags
               ? cContent

               //find the columns based on a regex
               FOR EACH cRegex IN hFields
                  ? cRegex
                  IF HB_RegexMatch(cRegex,cContent,.F.)
                     hCols[cRegex:__eNumKey()] := nCol
                     EXIT
                  ELSE
                     ?? "no match"
                  ENDIF
               NEXT
            NEXT
            IF Len(hCols) != Len(hFields) //not all fields have been found
               EXIT
            ENDIF
         ELSE
            hRow := {=>}
            FOR EACH nCol IN hCols
               IF nCol <= Len(aCols)
                  cContent := Eval(bGetContent)
               ELSE
                  cContent := "NF"+Str(nCol)
               ENDIF
               hRow[nCol:__eNumKey()] := cContent
            NEXT
            Aadd(aData,hRow)
         ENDIF
      ELSE
         ? "No children"
      ENDIF
   NEXT
   IF DEBUG
      //SInkey(0)
   ENDIF
RETURN aData

FUNCTION __CSVToData(cCSV,hFields,hCols)
   LOCAL nRow,nCol,cRegex,aData := {}
   LOCAL nMax := 0
   LOCAL nRows,aRow,hRow
   Default(@hCols,{=>})
   nRows :=  MlCount(cCSV,4096)
   IF nRows > 1
      FOR nRow := 1 TO MlCount(cCSV,4096)
         aRow := FParseLine(Trim(MemoLine(cCSV,4096,nRow,,,.T.)))
         IF DEBUG
            ? ValToPrg(aRow)
            Sinkey(0)
         ENDIF
         IF nRow == 1 .AND. Len(hCols) == 0
            FOR nCol := 1 TO Len(aRow)
            //find the columns based on a regex
               FOR EACH cRegex IN hFields
                  IF HB_RegexMatch(cRegex,aRow[nCol],.F.)
                     nMax := Max(nMax,nCol)
                     hCols[cRegex:__eNumKey()] := nCol
                     EXIT
                  ENDIF
               NEXT
            NEXT
            IF Len(hCols) != Len(hFields) //not all fields have been found
               IF DEBUG
                  ? "NOT ALL FOUND"
                  ? ValToPrg(hCols)
                  Sinkey(0)
               ENDIF
               EXIT
            ENDIF
         ELSE
            IF Len(aRow) >= nMax
               hRow := {=>}
               FOR EACH nCol IN hCols
                  IF DEBUG
                     ? nCol:__eNumKey(),aRow[nCol]
                  ENDIF
                  hRow[nCol:__eNumKey()] := aRow[nCol]
               NEXT
               Aadd(aData,hRow)
            ENDIF
         ENDIF
      NEXT
   ENDIF
RETURN aData

STATIC FUNCTION CopyAttToTemp(oAtt)
   LOCAL cTempPath := GetEnv("temp")

   oAtt:CopyOut(cTempPath,oAtt:FileName)

RETURN cTempPath+"\"+oAtt:FileName