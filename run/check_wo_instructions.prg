*:*********************************************************************
*:
*:        Program: check_wo_instructions.prg
*:
*:         System: TRADER  
*:         Author: GitHub Copilot
*:         Usage : Check work order instructions format (JSON/PDF) for next 4 weeks
*:         Created: November 13, 2025
*:*********************************************************************

//#include 'trader.ch'
#include 'inkey.ch'

PROCEDURE RUN_CHECK_WO_INSTRUCTIONS
   LOCAL dStartDate, dEndDate, nStartWeek, nEndWeek
   LOCAL aWorkOrders := {}
   LOCAL aPDFInstructions := {}
   LOCAL aJSONInstructions := {}
   LOCAL aNoInstructions := {}
   LOCAL cFileName, cFileExt, lHasInstructions
   LOCAL nCount := 0
   LOCAL cOutputFile, nHandle
   LOCAL aEnv := SaveEnv()
   LOCAL aWO
   LOCAL oBrowse, nChoice := 1, getlist := {}
   
   // Clear screen and show header
   CLS
   @ 00,00 SAY "FERTIGUNGSAUFTRéGE ARBEITSANWEISUNGEN PRöFUNG - NéCHSTE 4 WOCHEN"
   @ 01,00 SAY Replicate("=", 80)
   
   // Calculate date range (next 4 weeks)
   dStartDate := Date()
   dEndDate := Date() + 28
   nStartWeek := Val(CalWeek(dStartDate))
   nEndWeek := Val(CalWeek(dEndDate))
   
   @ 03,00 SAY "PrÅfe FertigungsauftrÑge vom " + DtoC(dStartDate) + " bis " + DtoC(dEndDate)
   @ 04,00 SAY "Wochenbereich: " + Str(nStartWeek,4) + " bis " + Str(nEndWeek,4)
   @ 05,00 SAY Replicate("-", 80)
   
   // Open required databases
   NetUse("werkauf","wer",.F.,0)  // Work orders
   NetUse("artikel","art",.F.,0)  // Articles
   NetUse("aw","aw",.F.,0)        // Work instructions
   
   @ 07,00 SAY "Durchsuche FertigungsauftrÑge..."
   
   // Set filter for work orders in the next 4 weeks
   // Status: 0=open, 1=stock taken, 2=printed, 3=printed and stock taken, 4=finished
   wer->(dbSetOrder(1))  // Order by work order number
   wer->(dbGoTop())
   
   DO WHILE ! wer->(EOF())
      // Check if work order is in our date/week range and not finished
      IF (wer->Status < 4) .AND. Empty(wer->Liefma) .AND.;
         ((wer->Termin >= nStartWeek .AND. wer->Termin <= nEndWeek) .OR. ;
          (wer->StartDate >= dStartDate .AND. wer->StartDate <= dEndDate))
         
         nCount++
         @ 08,00 SAY "Bearbeite FA: " + Str(wer->Aufno,6) + " (" + Str(nCount,4) + ")"
         
         // Get article information
         art->(dbSetOrder(2)) // By article number
         art->(dbSeek(Str(wer->Artno,6)))
         
         lHasInstructions := .F.
         cFileName := ""
         cFileExt := ""
         
         // Check if article has work instructions
         IF ! Empty(art->Anweisung)
            aw->(dbSetOrder(1)) // By instruction number
            IF aw->(dbSeek(Str(Val(art->Anweisung),6))) .AND. aw->Genehmig
               // Get the instruction file
               cFileName := Hook("get_drawingfile",{.T.,LTrim(Str(aw->Nummer))})
               
               IF ! Empty(cFileName) .AND. File(cFileName)
                  lHasInstructions := .T.
                  cFileExt := Upper(Right(cFileName, 4))
                  
                  // Determine file type
                  DO CASE
                  CASE cFileExt == ".PDF"
                     Aadd(aPDFInstructions, {;
                        wer->Aufno, ;
                        art->Matchcode, ;
                        art->Artikel, ;
                        wer->Qty, ;
                        wer->Status, ;
                        wer->Termin, ;
                        wer->StartDate, ;
                        cFileName;
                     })
                     
                  CASE cFileExt == "JSON" .OR. cFileExt == ".JSN"
                     Aadd(aJSONInstructions, {;
                        wer->Aufno, ;
                        art->Matchcode, ;
                        art->Artikel, ;
                        wer->Qty, ;
                        wer->Status, ;
                        wer->Termin, ;
                        wer->StartDate, ;
                        cFileName;
                     })
                     
                  OTHERWISE
                     // Other file format
                     Aadd(aNoInstructions, {;
                        wer->Aufno, ;
                        art->Matchcode, ;
                        art->Artikel, ;
                        wer->Qty, ;
                        wer->Status, ;
                        wer->Termin, ;
                        wer->StartDate, ;
                        "Anderes Format: " + cFileExt;
                     })
                  ENDCASE
               ENDIF
            ENDIF
         ENDIF
         
         // If no instructions found
         IF ! lHasInstructions
            Aadd(aNoInstructions, {;
               wer->Aufno, ;
               art->Matchcode, ;
               art->Artikel, ;
               wer->Qty, ;
               wer->Status, ;
               wer->Termin, ;
               wer->StartDate, ;
               "Keine Arbeitsanweisung";
            })
         ENDIF
         
         // Add to all work orders list
         Aadd(aWorkOrders, {;
            wer->Aufno, ;
            art->Matchcode, ;
            art->Artikel, ;
            wer->Qty, ;
            wer->Status, ;
            wer->Termin, ;
            wer->StartDate, ;
            IF(lHasInstructions, cFileExt, "NONE");
         })
      ENDIF
      
      wer->(dbSkip())
   ENDDO
   
   // Sort all arrays by start date (7th element in each array)
   ASort(aPDFInstructions,,,{|x,y| x[7] < y[7] })
   ASort(aJSONInstructions,,,{|x,y| x[7] < y[7] })
   ASort(aNoInstructions,,,{|x,y| x[7] < y[7] })
   ASort(aWorkOrders,,,{|x,y| x[7] < y[7] })
   
   // Display results
   CLS
   @ 00,00 SAY "FERTIGUNGSAUFTRéGE ARBEITSANWEISUNGEN ANALYSE - ERGEBNISSE"
   @ 01,00 SAY Replicate("=", 80)
   @ 03,00 SAY "FertigungsauftrÑge gesamt:   " + Str(Len(aWorkOrders),4)
   @ 04,00 SAY "PDF Arbeitsanweisungen:      " + Str(Len(aPDFInstructions),4)
   @ 05,00 SAY "JSON Arbeitsanweisungen:     " + Str(Len(aJSONInstructions),4) 
   @ 06,00 SAY "Ohne/Andere Anweisungen:    " + Str(Len(aNoInstructions),4)
   @ 07,00 SAY Replicate("-", 80)
   
   IF Tr_Getini(28) == 0 //9
      // Show selection menu
      @ 15,00 SAY "WÑhlen Sie die Anzeige:"
      @ 16,00 SAY "1. PDF FertigungsauftrÑge durchsuchen (" + Str(Len(aPDFInstructions),4) + ")"
      @ 17,00 SAY "2. JSON FertigungsauftrÑge durchsuchen (" + Str(Len(aJSONInstructions),4) + ")"
      @ 18,00 SAY "3. Alle FertigungsauftrÑge durchsuchen (" + Str(Len(aWorkOrders),4) + ")"
      @ 19,00 SAY "4. AuftrÑge ohne Arbeitsanweisung (" + Str(Len(aNoInstructions),4) + ")"
      @ 20,00 SAY "0. Beenden"
      @ 22,00 SAY "Auswahl eingeben: " GET nChoice PICTURE "9" RANGE 0,4
      READ
      
      IF nChoice == 0 .OR. LastKey() == 27
         RestEnv(aEnv,.T.)
         RETURN
      ENDIF
   ELSE
      nChoice := 1 // Default to PDF instructions
   ENDIF
   
   // Display browse based on selection
   DO CASE
   CASE nChoice == 1
      IF Len(aPDFInstructions) > 0
         DisplayWorkOrderBrowse(aPDFInstructions, "PDF FERTIGUNGSAUFTRéGE")
      ELSE
         @ 24,00 SAY "Keine PDF FertigungsauftrÑge gefunden! Taste drÅcken..."
         Inkey(0)
      ENDIF
      
   CASE nChoice == 2
      IF Len(aJSONInstructions) > 0
         DisplayWorkOrderBrowse(aJSONInstructions, "JSON FERTIGUNGSAUFTRéGE")
      ELSE
         @ 24,00 SAY "Keine JSON FertigungsauftrÑge gefunden! Taste drÅcken..."
         Inkey(0)
      ENDIF
      
   CASE nChoice == 3
      DisplayWorkOrderBrowse(aWorkOrders, "ALLE FERTIGUNGSAUFTRéGE")
      
   CASE nChoice == 4
      IF Len(aNoInstructions) > 0
         DisplayWorkOrderBrowse(aNoInstructions, "FERTIGUNGSAUFTRéGE OHNE ARBEITSANWEISUNGEN")
      ELSE
         @ 24,00 SAY "Alle FertigungsauftrÑge haben Arbeitsanweisungen! Taste drÅcken..."
         Inkey(0)
      ENDIF
   ENDCASE
   
   // Restore environment
   RestEnv(aEnv,.T.)
   
RETURN

// Function to display work orders in a browse window
STATIC FUNCTION DisplayWorkOrderBrowse(aData, cTitle)
   LOCAL oBrowse, nX
   LOCAL aArrayData := {}
   LOCAL nKey
   LOCAL nWONumber, nAWNumber
   
   // Convert data to array format for TBrowse
   FOR nX := 1 TO Len(aData)
      Aadd(aArrayData, aData[nX])
   NEXT
   
   CLS
   
   // Create browse
   oBrowse := TBrowse():New(02, 01, MaxRow()-2, MaxCol()-1)
   oBrowse:headSep := "ƒ"
   oBrowse:colSep := "≥"
   oBrowse:footSep := "ƒ"
   
   // Set data source
   oBrowse:goTopBlock := {|| nX := 1 }
   oBrowse:goBottomBlock := {|| nX := Len(aArrayData) }
   oBrowse:skipBlock := {|n| _ArraySkip(@nX, aArrayData, n) }
   
   // Add columns
   oBrowse:AddColumn(TBColumnNew("FA#", {|| Str(aArrayData[nX,1],6) }))
   oBrowse:AddColumn(TBColumnNew("Matchcode", {|| PadR(aArrayData[nX,2],16) }))
   oBrowse:AddColumn(TBColumnNew("Artikel", {|| PadR(Left(aArrayData[nX,3],25),25) }))
   oBrowse:AddColumn(TBColumnNew("Menge", {|| Str(aArrayData[nX,4],8,2) }))
   oBrowse:AddColumn(TBColumnNew("St", {|| Str(aArrayData[nX,5],1) }))
   oBrowse:AddColumn(TBColumnNew("KW", {|| Str(aArrayData[nX,6],4) }))
   oBrowse:AddColumn(TBColumnNew("Startdatum", {|| DtoC(aArrayData[nX,7]) }))
   oBrowse:AddColumn(TBColumnNew("AAW#", {|| _GetInstructionNumber(aArrayData[nX,1]) }))
   
   // Set initial position
   nX := 1
   
   // Display title and instructions
   @ 00,00 SAY PadC(cTitle, MaxCol()) COLOR "W+/B"
   @ 01,00 SAY Replicate("ƒ", MaxCol())
   @ MaxRow()-1,00 SAY "ESC=Beenden | ENTER=Arbeitsanweisung bearbeiten | F10=CSV Export | Pfeiltasten=Navigation" COLOR "N/W"
   @ MaxRow(),00 SAY "Anzahl DatensÑtze: " + Str(Len(aArrayData),4) COLOR "N/W"
   
   // Browse loop
   DO WHILE .T.
      oBrowse:ForceStable()
      
      nKey := Inkey(0)
      
      DO CASE
      CASE nKey == K_ESC
         EXIT
         
      CASE nKey == K_ENTER
         // Open AAW editor for the work instruction
         IF Len(aArrayData) > 0
            BEGIN SEQUENCE
               // Get article and work instruction information
               nWONumber := aArrayData[nX,1]
               nAWNumber := 0
               
               // Find the work order to get article number
               wer->(dbSetOrder(1))
               IF wer->(dbSeek(Str(nWONumber,6)))
                  art->(dbSetOrder(2))
                  IF art->(dbSeek(Str(wer->Artno,6))) .AND. ! Empty(art->Anweisung)
                     nAWNumber := Val(art->Anweisung)
                  ENDIF
               ENDIF
               
               IF nAWNumber > 0
                  // Call AAW editor
                  MBaseRun(Path("run\aaweditor"),{nAWNumber})
               ELSE
                  @ MaxRow(),40 SAY "Keine Arbeitsanweisung fÅr diesen Fertigungsauftrag"
                  Inkey(2000)  // Show message for 2 seconds
                  @ MaxRow(),40 SAY Space(50)  // Clear message
               ENDIF
            RECOVER
               @ MaxRow(),40 SAY "Fehler beim ôffnen des AAW Editors"
               Inkey(2000)  // Show message for 2 seconds  
               @ MaxRow(),40 SAY Space(30)  // Clear message
            END SEQUENCE
         ENDIF
         
      CASE nKey == K_F10
         // Export to CSV
         _ExportBrowseData(aArrayData, cTitle)
         
      CASE nKey == K_UP
         oBrowse:Up()
         
      CASE nKey == K_DOWN
         oBrowse:Down()
         
      CASE nKey == K_PGUP
         oBrowse:PageUp()
         
      CASE nKey == K_PGDN
         oBrowse:PageDown()
         
      CASE nKey == K_HOME
         oBrowse:GoTop()
         
      CASE nKey == K_END
         oBrowse:GoBottom()
         
      OTHERWISE
         // Ignore other keys
      ENDCASE
   ENDDO
   
RETURN NIL

// Array navigation function
STATIC FUNCTION _ArraySkip(nCurrent, aData, nSkip)
   LOCAL nOriginal := nCurrent
   
   nCurrent += nSkip
   
   IF nCurrent < 1
      nCurrent := 1
   ELSEIF nCurrent > Len(aData)
      nCurrent := Len(aData)
   ENDIF
   
RETURN nCurrent - nOriginal

// Export function
STATIC FUNCTION _ExportBrowseData(aData, cTitle)
   LOCAL cFile, nHandle, nX
   
   cFile := Trim(Tr_Getini(1)) + "\export\browse_" + StrTran(Lower(cTitle)," ","_") + "_" + DToS(Date()) + ".csv"
   
   nHandle := FCreate(cFile)
   IF nHandle > 0
      // Write header
      FWrite(nHandle, "WO_Number;Matchcode;Article;Quantity;Status;Week;StartDate;Instructions" + Chr(13) + Chr(10))
      
      // Write data
      FOR nX := 1 TO Len(aData)
         FWrite(nHandle, Str(aData[nX,1],6) + ";" + ;
                        Trim(aData[nX,2]) + ";" + ;
                        Trim(aData[nX,3]) + ";" + ;
                        Str(aData[nX,4],8,2) + ";" + ;
                        Str(aData[nX,5],1) + ";" + ;
                        Str(aData[nX,6],4) + ";" + ;
                        DtoC(aData[nX,7]) + ";" + ;
                        Trim(aData[nX,8]) + Chr(13) + Chr(10))
      NEXT
      
      FClose(nHandle)
      @ MaxRow(),50 SAY "Exportiert nach: " + cFile
   ELSE
      @ MaxRow(),50 SAY "Export fehlgeschlagen!"
   ENDIF
   
RETURN NIL

// Helper function to get instruction number from work order
STATIC FUNCTION _GetInstructionNumber(nWONumber)
   LOCAL cResult := ""
   LOCAL nAWNumber := 0
 
   // Try to get the instruction number from the work order
   BEGIN SEQUENCE
      wer->(dbSetOrder(1))
      IF wer->(dbSeek(Str(nWONumber,6)))
         art->(dbSetOrder(2))
         IF art->(dbSeek(Str(wer->Artno,6))) .AND. ! Empty(art->Anweisung)
            nAWNumber := Val(art->Anweisung)
            IF nAWNumber > 0
               cResult := Str(nAWNumber,6)
            ENDIF
         ENDIF
      ENDIF
   RECOVER
      // If there's an error, return empty
   END SEQUENCE
   
   IF Empty(cResult)
      cResult := "-"
   ENDIF
   
RETURN PadR(cResult, 6)
