#include 'y:\hb32\include\inkey.ch'

PROC MASK_TODO

   LOCAL nKey, oButton, nB, nRow, nCol
   LOCAL aButtons := {}, aRegex
   LOCAL oUser
   LOCAL cColor, cUserText, cRefText
   LOCAL nDaysLeft
   LOCAL nSubCount, nSuccCount
   LOCAL oTodo := Todo():New()
   LOCAL aSubtaskDisplay := {}, nSubtaskScroll := 0, lScrollableSubtasks := .F.
   LOCAL nSubtaskStartRow, nSubtaskHeight, bDisplaySubtasks
   LOCAL nMainNoteLine, cMainNoteLine
   LOCAL oScrollbar
   LOCAL nMouseRow, nMouseCol, nOldScroll, nRelativePos, nNewScroll
   LOCAL nPreDaysLeft, cPreColor, oPreUser, nPreNoteLine, cPreNoteLine

   MEMVAR c_five

   SetColor(c_five)

   // Main window dimensions
   Box(00, 00, MaxRow(), MaxCol() ) //,,,.T., 2)
   
   // Title bar
   @ 00, 02 SAY "[Todo Information: " + IF(Empty(todo->Task), "Neue Aufgabe", Left(Trim(todo->Task), 40)) + "]"
   
   // Close instruction
   @ 00, MaxCol()-15 SAY "[ESC = Schlieáen]"

   // =============================================
   // SECTION 1: Basic Information (Left Column)
   // =============================================
   nRow := 02
   nCol := 02
   
   @ nRow++, nCol SAY "UUID        : " + Trim(todo->UUID)
   @ nRow++, nCol SAY "Task        : " + Trim(todo->Task)
   
   // User information
   cUserText := "Nicht zugewiesen"
   IF todo->User != 0
      oUser := User():New()
      oUser:Load(todo->User)
      cUserText := Trim(oUser:FirstName) //+ " " + Trim(oUser:LastName)
   ENDIF
   @ nRow++, nCol SAY "Benutzer    : " + cUserText
   
   // Priority display
   /*cPriorityText := "Normal"
   IF todo->Priority == 1
      cPriorityText := "Hoch"
   ELSEIF todo->Priority == 2
      cPriorityText := "Kritisch"
   ENDIF
   @ nRow++, nCol SAY "Priorit„t   : " + cPriorityText COLOR IF(todo->Priority > 0, "R+/G", c_five)
   */

   // Status
   @ nRow++, nCol SAY "Status      : " + IF(todo->Done, "Erledigt (" + DToC(todo->DoneDate) + ")", "Offen") COLOR IF(todo->Done, "G+/G", "Y+/G")
   
   // Dates
   IF ! Empty(todo->Due)
      nDaysLeft := todo->Due - Date()
      cColor := c_five
      IF ! todo->Done .AND. nDaysLeft < 0
         cColor := "W+/R"  // Overdue
      ELSEIF ! todo->Done .AND. nDaysLeft <= 3
         cColor := "Y+/R"  // Due soon
      ENDIF
      @ nRow++, nCol SAY "F„llig      : " + DToC(todo->Due) + " (" + IF(nDaysLeft >= 0, "+", "") + LTrim(Str(nDaysLeft)) + " Tage)" COLOR cColor
   ELSE
      @ nRow++, nCol SAY "F„llig      : Nicht festgelegt"
   ENDIF
   
   IF todo->Days > 0
      @ nRow++, nCol SAY "Gesch„tzt   : " + LTrim(Str(todo->Days)) + " Tage"
   ENDIF
   
   // Reference information
   cRefText := ""
   IF ! Empty(todo->RefType) .AND. todo->Ref != 0
      cRefText := Trim(todo->RefType) + " " + LTrim(Str(todo->Ref))
      
      // Add specific reference info
      IF todo->RefType == "PJ "
         NetUse("projekte", "proj")
         IF proj->(dbSeek(Str(todo->Ref, 6)))
            cRefText += " (" + Trim(proj->Beschreibu) + ")"
         ENDIF
      ELSEIF todo->RefType == "KU "
         NetUse("engkund", "ku")
         IF ku->(dbSeek(Str(todo->Ref, 6) + "K"))
            cRefText += " (" + Trim(ku->Name) + ")"
         ENDIF
      ELSEIF todo->RefType == "ART"
         NetUse("engartik", "art")
         IF art->(dbSeek(Str(todo->Ref, 6)))
            cRefText += " (" + Trim(art->Matchcode) + ")"
         ENDIF
      ENDIF
      
      @ nRow++, nCol SAY "Referenz    : " + cRefText
   ENDIF
   
   // Hierarchy information
   IF todo->Level > 0
      @ nRow++, nCol SAY "Ebene       : " + LTrim(Str(todo->Level))
   ENDIF
   
   IF ! Empty(todo->Parent)
      @ nRow++, nCol SAY "šbergeordnet: " + Trim(todo->Parent)
      
      // Show parent task info
      NetUse("todo", "ptodo")
      ptodo->(dbSetOrder(2)) // UUID index
      IF ptodo->(dbSeek(todo->Parent))
         @ nRow++, nCol SAY "              '" + Left(Trim(ptodo->Task), 45) + "'"
      ENDIF
   ENDIF
   
   IF ! Empty(todo->PreID)
      @ nRow++, nCol SAY "Vorg„nger   : " + Trim(todo->PreID)
      @ nRow++, nCol SAY "Vorg. erled.: " + IF(todo->PreDone, "Ja", "Nein") COLOR IF(todo->PreDone, "G+/G", "Y+/G")
      
      // Show predecessor task info using oPreTodo if available
      IF oTodo:oPreTodo != NIL
         @ nRow++, nCol SAY "              '" + Left(Trim(oTodo:oPreTodo:Task), 45) + "'"
         
         // Show predecessor details
         @ nRow++, nCol SAY "              Status: " + IF(oTodo:oPreTodo:Done, "Erledigt", "Offen") COLOR IF(oTodo:oPreTodo:Done, "G+/G", "Y+/G")
         
         IF ! Empty(oTodo:oPreTodo:Due)
            nPreDaysLeft := oTodo:oPreTodo:Due - Date()
            cPreColor := c_five
            IF ! oTodo:oPreTodo:Done .AND. nPreDaysLeft < 0
               cPreColor := "W+/R"  // Overdue
            ELSEIF ! oTodo:oPreTodo:Done .AND. nPreDaysLeft <= 3
               cPreColor := "Y+/R"  // Due soon
            ENDIF
            @ nRow++, nCol SAY "              F„llig: " + DToC(oTodo:oPreTodo:Due) + " (" + IF(nPreDaysLeft >= 0, "+", "") + LTrim(Str(nPreDaysLeft)) + " Tage)" COLOR cPreColor
         ENDIF
         
         IF oTodo:oPreTodo:User != 0
            oPreUser := User():New()
            oPreUser:Load(oTodo:oPreTodo:User)
            @ nRow++, nCol SAY "              User: " + Trim(oPreUser:FirstName)
         ENDIF
         
         // Show predecessor notes if available
         IF ! Empty(oTodo:oPreTodo:Notes)
            @ nRow++, nCol SAY "              Notizen:"
            FOR nPreNoteLine := 1 TO Min(3, MLCount(oTodo:oPreTodo:Notes, 40)) // Limit to 3 lines
               cPreNoteLine := MemoLine(oTodo:oPreTodo:Notes, 40, nPreNoteLine)
               @ nRow++, nCol SAY "                " + cPreNoteLine COLOR "N/G"
            NEXT
            IF MLCount(oTodo:oPreTodo:Notes, 40) > 3
               @ nRow++, nCol SAY "                ..." COLOR "N/G"
            ENDIF
         ENDIF
      ELSE
         // Fallback to database lookup if oPreTodo not available
         NetUse("todo", "pretodo")
         pretodo->(dbSetOrder(2)) // UUID index
         IF pretodo->(dbSeek(todo->PreID))
            @ nRow++, nCol SAY "              '" + Left(Trim(pretodo->Task), 45) + "'"
         ENDIF
      ENDIF
   ENDIF

   // =============================================
   // SECTION 2: Action Buttons
   // =============================================
   nRow += 1
   @ nRow, nCol SAY Replicate(Chr(196), 50)
   
   // Edit button
/*   oButton := HBPushButton():New(nRow, nCol, "&Bearbeiten")
   oButton:sBlock := {|| Todo_edit(todo->UUID) }
   Aadd(aButtons, oButton)
   
   // Complete/Reopen button
   oButton := HBPushButton():New(nRow, nCol + 15, IF(todo->Done, "&Wieder ”ffnen", "&Erledigen"))
   oButton:sBlock := {|| ToggleTodoStatus() }
   Aadd(aButtons, oButton)
   
   // Add subtask button if not done
   IF ! todo->Done
      oButton := HBPushButton():New(nRow + 1, nCol, "&Unteraufgabe")
      oButton:sBlock := {|| CreateSubTask() }
      Aadd(aButtons, oButton)
   ENDIF
   
   // Show related todos if reference exists
   IF ! Empty(todo->RefType) .AND. todo->Ref != 0
      oButton := HBPushButton():New(nRow + 1, nCol + 15, "&Verwandte Todos")
      oButton:sBlock := {|| ShowRelatedTodos() }
      Aadd(aButtons, oButton)
   ENDIF*/

   // =============================================
   // SECTION 3: Related Tasks Overview (Right Side)
   // =============================================
   nCol := 60
   nRow := 02
   
   @ nRow++, nCol SAY "Verwandte Aufgaben:"
   @ nRow++, nCol SAY Replicate(Chr(196), 30)
   
   // Count and show subtasks with scrolling (including main task notes)
   @ nRow++, nCol SAY "Notizen & Unteraufgaben:"
   nSubCount := 0
   aSubtaskDisplay := {}
   
   // Add main task notes first
   IF ! Empty(todo->Notes)
      AAdd(aSubtaskDisplay, {"=== Hauptaufgabe Notizen ===", "W+/B", "HEADER"})
      FOR nMainNoteLine := 1 TO MLCount(todo->Notes, MaxCol() - nCol - 4)
         cMainNoteLine := MemoLine(todo->Notes, MaxCol() - nCol - 4, nMainNoteLine)
         AAdd(aSubtaskDisplay, {cMainNoteLine, "N/W", "MAINNOTE"})
      NEXT
      AAdd(aSubtaskDisplay, {"", c_five, "SPACER"})
   ENDIF
   
   // Add subtasks header if there are any
   IF oTodo:oChildren:HasRecords()
      AAdd(aSubtaskDisplay, {"=== Unteraufgaben ===", "W+/B", "HEADER"})
   ENDIF
   
   // Build display array for subtasks
   oTodo:oChildren:Each({|oChild|
      LOCAL nNoteLine, cTaskLine, cNoteLine
      
      nSubCount++
      cColor := IF(oChild:Done, "G+/G", IF(! Empty(oChild:Due) .AND. oChild:Due < Date(), "W+/R", c_five))
      cTaskLine := IF(oChild:Done, Chr(251), Chr(250)) + " " + Left(Trim(oChild:Task), MaxCol() - nCol - 3)
      
      AAdd(aSubtaskDisplay, {cTaskLine, cColor, "TASK"})
      
      // Add notes lines
      IF ! Empty(oChild:Notes)
         FOR nNoteLine := 1 TO MLCount(oChild:Notes, MaxCol() - nCol - 6)
            cNoteLine := MemoLine(oChild:Notes, MaxCol() - nCol - 6, nNoteLine)
            AAdd(aSubtaskDisplay, {"    " + cNoteLine, "N/G", "NOTE"})
         NEXT
      ENDIF
      
      RETURN .T.
   })
   
   // Add message if no subtasks
   IF nSubCount == 0 .AND. Empty(todo->Notes)
      AAdd(aSubtaskDisplay, {"Keine Notizen oder Unteraufgaben", "N/W", "MESSAGE"})
   ELSEIF nSubCount == 0
      AAdd(aSubtaskDisplay, {"=== Keine Unteraufgaben ===", "N/W", "MESSAGE"})
   ENDIF
   
   // Setup scrollable display
   nSubtaskStartRow := nRow
   nSubtaskHeight := MaxRow() - nRow - 5 // Use more space since we removed separate notes section
   lScrollableSubtasks := Len(aSubtaskDisplay) > nSubtaskHeight
   
   IF lScrollableSubtasks
      @ nRow, MaxCol() - 25 SAY "[?/? = Scrollen, Maus]"
      
      // Create scrollbar
      oScrollbar := HBScrollbar():New(nSubtaskStartRow, nSubtaskStartRow + nSubtaskHeight - 1, MaxCol() - 1)
      oScrollbar:total := Len(aSubtaskDisplay)-nSubtaskHeight
      oScrollbar:current := 0 //nSubtaskScroll + 1
      oScrollbar:BarLength := nSubtaskHeight
      oScrollbar:style := 1 
      oScrollbar:Display()
   ENDIF
   
   // Display function for subtasks and notes
   bDisplaySubtasks := {||
      LOCAL nLine, nDisplayLine := 0, nStartLine := nSubtaskScroll + 1, nEndLine
      LOCAL aDisplayItem
      
      // Clear subtask area
      FOR nLine := nSubtaskStartRow TO nSubtaskStartRow + nSubtaskHeight - 1
         @ nLine, nCol + 2 SAY Space(MaxCol() - nCol - 4)
      NEXT
      
      IF Len(aSubtaskDisplay) == 0
         @ nSubtaskStartRow, nCol + 2 SAY "Keine Daten verfgbar"
         RETURN NIL
      ENDIF
      
      nEndLine := MIN(nStartLine + nSubtaskHeight - 1, Len(aSubtaskDisplay))
      
      FOR nLine := nStartLine TO nEndLine
         aDisplayItem := aSubtaskDisplay[nLine]
         @ nSubtaskStartRow + nDisplayLine, nCol + 2 SAY aDisplayItem[1] COLOR aDisplayItem[2]
         nDisplayLine++
      NEXT
      
      // Update scrollbar position if it exists
      IF lScrollableSubtasks .AND. oScrollbar != NIL
         oScrollbar:current := nSubtaskScroll + 1
         oScrollbar:Display()
      ENDIF
      
      RETURN NIL
   }
   
   Eval(bDisplaySubtasks)
   nRow := nSubtaskStartRow + nSubtaskHeight + 1
   
   // Show successor tasks (tasks that depend on this one)
   nRow++
   NetUse("todo", "succtodo")
   succtodo->(dbSetOrder(3)) // PreID index
   IF succtodo->(dbSeek(todo->UUID))
      nSuccCount := 0
      @ nRow++, nCol SAY "Nachfolger-Aufgaben:"
      DO WHILE succtodo->PreID == todo->UUID .AND. ! succtodo->(EOF())
         nSuccCount++
         cColor := IF(succtodo->Done, "G+/G", IF(! Empty(succtodo->Due) .AND. succtodo->Due < Date(), "W+/R", c_five))
         @ nRow++, nCol + 2 SAY IF(succtodo->Done, Chr(251), Chr(250)) + " " + Left(Trim(succtodo->Task), 25) COLOR cColor
         succtodo->(dbSkip())
         IF nRow > MaxRow() - 8
            @ nRow++, nCol + 2 SAY "... (" + LTrim(Str(nSuccCount)) + " weitere)"
            EXIT
         ENDIF
      ENDDO
      IF nSuccCount == 0
         @ nRow, nCol + 2 SAY "Keine Nachfolger"
      ENDIF
   ELSE
      @ nRow, nCol + 2 SAY "Keine Nachfolger"
   ENDIF

   // =============================================
   // SECTION 4: Notes Display - Now Integrated Above
   // =============================================
   /*
   nNotesStartRow := MaxRow() - 15
   nNotesHeight := 12
   nNotesEndRow := nNotesStartRow + nNotesHeight - 1
   
   @ nNotesStartRow - 1, 02 SAY Replicate(Chr(196), MaxCol() - 4)
   @ nNotesStartRow, 02 SAY "Notizen:"
   
   IF ! Empty(todo->Notes)
      cNotesText := Trim(todo->Notes)
      nMaxNotesLines := MLCount(cNotesText, MaxCol() - 6)
      lScrollableNotes := nMaxNotesLines > nNotesHeight - 2
      
      IF lScrollableNotes
         @ nNotesStartRow, MaxCol() - 25 SAY "[?/? = Scrollen, PgUp/PgDn]"
      ENDIF
      
      // Draw notes box
      DispBox(nNotesStartRow + 1, 02, nNotesEndRow, MaxCol() - 2, 1)
      
      // Function to display notes with scroll
      bDisplayNotes := {||
         LOCAL nLine, nDisplayLine := 0, nStartLine := nNotesScroll + 1, nEndLine
         
         // Clear notes area
         FOR nLine := nNotesStartRow + 2 TO nNotesEndRow - 1
            @ nLine, 03 SAY Space(MaxCol() - 6)
         NEXT
         
         nEndLine := MIN(nStartLine + nNotesHeight - 3, nMaxNotesLines)
         
         FOR nLine := nStartLine TO nEndLine
            @ nNotesStartRow + 2 + nDisplayLine, 03 SAY MemoLine(cNotesText, MaxCol() - 6, nLine)
            nDisplayLine++
         NEXT
         
         // Show scroll indicators
         IF lScrollableNotes
            IF nNotesScroll > 0
               @ nNotesStartRow + 2, MaxCol() - 3 SAY Chr(24) // Up arrow
            ENDIF
            IF nNotesScroll + nNotesHeight - 2 < nMaxNotesLines
               @ nNotesEndRow - 1, MaxCol() - 3 SAY Chr(25) // Down arrow
            ENDIF
         ENDIF
         
         RETURN NIL
      }
      
      Eval(bDisplayNotes)
   ELSE
      @ nNotesStartRow + 2, 04 SAY "Keine Notizen vorhanden"
   ENDIF
   */

   // Display all buttons
   AEval(aButtons, {|x| x:ColorSpec := "N/W,N/W,GR+/RB,R+/W", x:Display() })

   // =============================================
   // MAIN EVENT LOOP
   // =============================================
   nKey := 0
   DO WHILE nKey != 27
      
      nKey := Inkey(0)
      
      IF nKey == 27
         EXIT
         
      // Handle combined notes & subtask scrolling
      ELSEIF lScrollableSubtasks .AND. (nKey == K_UP .OR. nKey == K_DOWN .OR. nKey == K_PGUP .OR. nKey == K_PGDN)
         IF nKey == K_UP .AND. nSubtaskScroll > 0
            nSubtaskScroll--
            Eval(bDisplaySubtasks)
         ELSEIF nKey == K_DOWN .AND. nSubtaskScroll + nSubtaskHeight < Len(aSubtaskDisplay)
            nSubtaskScroll++
            Eval(bDisplaySubtasks)
         ELSEIF nKey == K_PGUP .AND. nSubtaskScroll > 0
            nSubtaskScroll := MAX(0, nSubtaskScroll - nSubtaskHeight)
            Eval(bDisplaySubtasks)
         ELSEIF nKey == K_PGDN .AND. nSubtaskScroll + nSubtaskHeight < Len(aSubtaskDisplay)
            nSubtaskScroll := MIN(Len(aSubtaskDisplay) - nSubtaskHeight, nSubtaskScroll + nSubtaskHeight)
            Eval(bDisplaySubtasks)
         ENDIF
         
      // Handle mouse scrolling on scrollbar
      ELSEIF nKey == K_LBUTTONDOWN .AND. lScrollableSubtasks .AND. oScrollbar != NIL
         nMouseRow := MRow()
         nMouseCol := MCol()
         nOldScroll := nSubtaskScroll
         
         // Check if click is on scrollbar
         IF nMouseCol == MaxCol() - 1 .AND. nMouseRow >= nSubtaskStartRow .AND. nMouseRow <= nSubtaskStartRow + nSubtaskHeight - 1
            // Calculate new scroll position based on mouse click
            nRelativePos := nMouseRow - nSubtaskStartRow
            nNewScroll := Int((nRelativePos / nSubtaskHeight) * Len(aSubtaskDisplay))
            
            nSubtaskScroll := MAX(0, MIN(Len(aSubtaskDisplay) - nSubtaskHeight, nNewScroll))
            
            IF nSubtaskScroll != nOldScroll
               Eval(bDisplaySubtasks)
            ENDIF
         ENDIF
         
      // Handle mouse wheel scrolling
      ELSEIF (nKey == K_MWFORWARD .OR. nKey == K_MWBACKWARD) .AND. lScrollableSubtasks
         nMouseRow := MRow()
         nMouseCol := MCol()
         
         // Check if mouse is over the scrollable area
         IF nMouseRow >= nSubtaskStartRow .AND. nMouseRow <= nSubtaskStartRow + nSubtaskHeight - 1 .AND. nMouseCol >= nCol
            IF nKey == K_MWFORWARD .AND. nSubtaskScroll > 0
               nSubtaskScroll := MAX(0, nSubtaskScroll - 3) // Scroll 3 lines up
               Eval(bDisplaySubtasks)
            ELSEIF nKey == K_MWBACKWARD .AND. nSubtaskScroll + nSubtaskHeight < Len(aSubtaskDisplay)
               nSubtaskScroll := MIN(Len(aSubtaskDisplay) - nSubtaskHeight, nSubtaskScroll + 3) // Scroll 3 lines down
               Eval(bDisplaySubtasks)
            ENDIF
         ENDIF
         
      // Handle button clicks
      ELSEIF (nKey == K_LBUTTONDOWN .AND. (nB := AScan(aButtons, {|oButton|oButton:HitTest(MRow(),MCol()) != 0})) != 0) .OR.;
         (! Empty(Chr(nKey)) .AND. (nB := AScan(aButtons, {|oButton| aRegex:= HB_Regex("\&([A-Za-zÖÜÄöüä])", oButton:Caption), Len(aRegex) > 0 .AND. Upper(aRegex[2]) == Upper(Chr(nKey))} )) != 0)
         oButton := aButtons[nB]
         oButton:setFocus()
         oButton:select()
         oButton:killFocus()
         
      // Handle other keys
      ELSEIF SetKey(nKEY) != NIL
         Eval(SetKey(nKEY), PROCNAME(2), PROCLINE(2), "", "")
      ENDIF
   ENDDO

RETURN

// =============================================
// HELPER FUNCTIONS
// =============================================

/*STATIC FUNCTION ToggleTodoStatus()
   LOCAL oTodoEdit := Todo():New()
   
   oTodoEdit:Load(todo->UUID)
   oTodoEdit:Done := ! oTodoEdit:Done
   IF oTodoEdit:Done
      oTodoEdit:DoneDate := Date()
   ELSE
      oTodoEdit:DoneDate := CToD("")
   ENDIF
   oTodoEdit:Save()
   
   // Refresh current record
   todo->(dbSkip(0))
   
   // Refresh display by calling mask again
   DispInfo("TRD_TODO")
   
RETURN NIL

STATIC FUNCTION CreateSubTask()
   LOCAL cNewUUID := GenUUID()
   LOCAL oNewTodo := Todo():New()
   
   oNewTodo:UUID := cNewUUID
   oNewTodo:Task := "Neue Unteraufgabe von: " + Left(Trim(todo->Task), 30)
   oNewTodo:Parent := todo->UUID
   oNewTodo:Level := todo->Level + 1
   oNewTodo:RefType := todo->RefType
   oNewTodo:Ref := todo->Ref
   oNewTodo:User := todo->User
   oNewTodo:Done := .F.
   oNewTodo:Save()
   
   // Edit the new subtask
   Todo_edit(cNewUUID)
   
RETURN NIL*/
/*
STATIC FUNCTION ShowRelatedTodos()
   LOCAL oBrowse, nKey
   
   // Create a browse for related todos
   NetUse("todo", "rtodo")
   rtodo->(dbSetOrder(5)) // RefType + Ref index
   rtodo->(dbSeek(todo->RefType + Str(todo->Ref, 6)))
   
   oBrowse := rtodo->(TBrowseTr():New(5, 5, MaxRow() - 5, MaxCol() - 5))
   oBrowse:lBox := .T.
   oBrowse:HeadSep := Chr(205)
   oBrowse:ColSep := Chr(179)
   
   oBrowse:NewColumn("Status", {|| IF(rtodo->Done, Chr(251), Chr(250)) })
   oBrowse:NewColumn("Aufgabe", {|| PadR(Trim(rtodo->Task), 40) })
   oBrowse:NewColumn("Benutzer", {|| 
      LOCAL oU := User():New()
      IF rtodo->User != 0
         oU:Load(rtodo->User)
         RETURN PadR(Trim(oU:FirstName), 12)
      ENDIF
      RETURN Space(12)
   })
   oBrowse:NewColumn("F„llig", {|| IF(Empty(rtodo->Due), Space(10), DToC(rtodo->Due)) })
   
   oBrowse:WhileBlock := {|| rtodo->RefType == todo->RefType .AND. rtodo->Ref == todo->Ref }
   //oBrowse:AddKey(K_ENTER, {|| Todo_edit(rtodo->UUID) })
   oBrowse:AddKey(27, {|| .F. })
   
   Box(4, 4, MaxRow() - 4, MaxCol() - 4) //,,,.T., 1)
   @ 4, 6 SAY "[Verwandte Todos - ENTER=Bearbeiten, ESC=Schlieáen]"
   
   oBrowse:Display()
   
   DO WHILE .T.
      nKey := Inkey(0)
      IF nKey == 27
         EXIT
      ENDIF
      oBrowse:Event({nKey})
   ENDDO
   
RETURN NIL*/
