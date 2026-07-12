#include 'y:\hb32\include\inkey.ch'

#define HB_CALL_FUNC_DIRECT      1     // e.g. hb_memoread( "text.txt" )               --> &'hb_memoread("text.txt")'

THREAD STATIC STATIC_ProjectNr

PROC MASK_PROJECT

   LOCAL nKey,oButton,nB,nRow
   LOCAL aButtons := {},aRegex
   LOCAL cDir,aDir,oTodos
   LOCAL aTaskLines := {}, nTopLine := 1, nMaxRows, oScrollbar
   LOCAL nScrollAreaTop := 15, nScrollAreaBottom := MaxRow()-2, nScrollAreaLeft := 6, nScrollAreaRight := 92

   MEMVAR c_five

   SetColor(c_five)

   Box( 10,05,MaxRow()-1,93,,.T.,1)

   @ 10,06 SAY "[Projekt "+LTrim(Str(pj->Nummer))+"]"

   cDir := "Y:\Dokumente und Einstellungen\All Users\Dokumente\Projekte\"

   aDir := Directory(cDir+StrZero(pj->Nummer,4)+"*","D")

   IF Len(aDir) > 0 
      oButton := HBPushButton():New(11,06,"&Ordner îffnen")
      oButton:sBlock := {|| WAPI_ShellExecute(,"open",cDir+aDir[1,1]) }
      Aadd(aButtons,oButton)
   ELSE
      @ 11,06 SAY "Kein Ordner vorhanden "+cDir+StrZero(pj->Nummer,4)+"*"
   ENDIF

   // Add GANTT Chart button
   oButton := HBPushButton():New(11,25,"&GANTT Chart")
   oButton:sBlock := {|| RUN_ProjectGantt(pj->Nummer) }
   Aadd(aButtons,oButton)
   AEval(aButtons,{|x| x:ColorSpec := "N/W,N/W,GR+/RB,R+/W", x:Display() })

   @ 13,06 SAY "Aktuelle Aufgaben:"
   @ 14,06 SAY "------------------"
   
   // Build task lines array
   oTodos := todo->(RecordCollection():New("TODO",,{|| "PJ "+Str(pj->Nummer,6) },{|| todo->RefType == "PJ " .AND. todo->Ref == pj->Nummer },8,"todo"))
   oTodos:Each({|oTodo|
      LOCAL cText,cColor := c_five
      LOCAL oParent,oUser,nLine
      LOCAL nRec,nOrder
      IF todo->Level == 0 .OR. (! todo->Done .AND. (Empty(todo->PreID) .OR. todo->PreDone)) //only top level and uncompleted tasks
         cText := IF(todo->Done,Chr(251)," ")+" "         
         IF todo->Level > 0
            cText += Replicate(Chr(179)+Space(2),(todo->Level-1))         
         ENDIF
         IF ! Empty(todo->Parent) 
            nRec := todo->(Recno())
            nOrder := todo->(IndexOrd())
            oParent := todo->(Todo():New())
            oParent:Load(todo->Parent)
            IF ! Empty(oParent:PreId) .AND. ! oParent:PreDone
               RETURN .T.
            ENDIF
            todo->(dbGoTo(nRec))
            todo->(dbSetOrder(nOrder))
            IF todo->Last
               cText += Chr(192)
            ELSE
               cText += Chr(195)
            ENDIF
            cText += Chr(196)+" "
         ENDIF
         IF ! todo->Done 
            IF ! Empty(todo->Due)
               cColor := "GR+/R"
            ENDIF
            IF todo->User != 0
               oUser := User():New()
               oUser:Load(todo->User)
               cText += Trim(oUser:FirstName)+": "
            ENDIF
         ENDIF
         
         cText += Trim(todo->Task)

         IF ! todo->Done .AND. ! Empty(todo->Due)
            cText += " (bis "+DToC(todo->Due)+")"
         ENDIF

         // Add main task line
         AAdd(aTaskLines, {cText, cColor})

         IF ! Empty(todo->Notes) .AND. ! todo->Done
            FOR nLine := 1 TO MLCount(todo->Notes)                           
               AAdd(aTaskLines, {Space(IF(oUser!=NIL,Len(Trim(oUser:FirstName)),0)+2)+MemoLine(todo->Notes,,nLine), cColor})
            NEXT
         ENDIF
      ENDIF
      RETURN .T.
   })

   // Calculate display parameters
   nMaxRows := nScrollAreaBottom - nScrollAreaTop + 1
   
   // Create scrollbar if needed
   IF Len(aTaskLines) > nMaxRows
      oScrollbar := HBScrollbar():New(nScrollAreaTop, nScrollAreaBottom,nScrollAreaRight) //, .T.)
      //oScrollbar:SetRange(1, Len(aTaskLines) - nMaxRows + 1)
      oScrollbar:Total := Len(aTaskLines)-nMaxRows+1
      oScrollbar:Current := nTopLine-1
      oScrollbar:Display()
   ENDIF
   
   // Initial display of tasks
   DisplayTaskLines(aTaskLines, nTopLine, nMaxRows, nScrollAreaTop, nScrollAreaLeft, c_five)

   
   nKey := 0
   DO WHILE nKey != 27
      
      nKey := Inkey(0)
      
      IF nKey == 27
         EXIT
      ELSEIF nKey == K_UP .AND. nTopLine > 1
         nTopLine--
         DisplayTaskLines(aTaskLines, nTopLine, nMaxRows, nScrollAreaTop, nScrollAreaLeft, c_five)
         IF oScrollbar != NIL
            oScrollbar:Current := nTopLine-1
            oScrollbar:Display()
         ENDIF
      ELSEIF nKey == K_DOWN .AND. nTopLine < Len(aTaskLines) - nMaxRows + 1
         nTopLine++
         DisplayTaskLines(aTaskLines, nTopLine, nMaxRows, nScrollAreaTop, nScrollAreaLeft, c_five)
         IF oScrollbar != NIL
            oScrollbar:Current := nTopLine-1
            oScrollbar:Display()
         ENDIF
      ELSEIF nKey == K_PGUP
         nTopLine := MAX(1, nTopLine - nMaxRows)
         DisplayTaskLines(aTaskLines, nTopLine, nMaxRows, nScrollAreaTop, nScrollAreaLeft, c_five)
         IF oScrollbar != NIL
            oScrollbar:Current := nTopLine-1
            oScrollbar:Display()
         ENDIF
      ELSEIF nKey == K_PGDN
         nTopLine := MIN(Len(aTaskLines) - nMaxRows + 1, nTopLine + nMaxRows)
         DisplayTaskLines(aTaskLines, nTopLine, nMaxRows, nScrollAreaTop, nScrollAreaLeft, c_five)
         IF oScrollbar != NIL
            oScrollbar:Current := nTopLine-1
            oScrollbar:Display()
         ENDIF
      ELSEIF nKey == K_HOME
         nTopLine := 1
         DisplayTaskLines(aTaskLines, nTopLine, nMaxRows, nScrollAreaTop, nScrollAreaLeft, c_five)
         IF oScrollbar != NIL
            oScrollbar:Currnet := nTopLine-1
            oScrollbar:Display()
         ENDIF
      ELSEIF nKey == K_END
         nTopLine := MAX(1, Len(aTaskLines) - nMaxRows + 1)
         DisplayTaskLines(aTaskLines, nTopLine, nMaxRows, nScrollAreaTop, nScrollAreaLeft, c_five)
         IF oScrollbar != NIL
            oScrollbar:Currnet := nTopLine-1
            oScrollbar:Display()
         ENDIF
      ELSEIF (nKey == K_LBUTTONDOWN .AND. (nB := AScan(aButtons,{|oButton|oButton:HitTest(MRow(),MCol()) != 0})) != 0) .OR.;
         (! Empty(Chr(nKey)) .AND. (nB := AScan(aButtons,{|oButton| aRegex:= HB_Regex("\&([A-Za-z÷‹ƒˆ¸‰])",oButton:Caption), Len(aRegex) > 0 .AND. Upper(aRegex[2]) == Upper(Chr(nKey))} )) != 0)
         oButton := aButtons[nB]
         oButton:setFocus()
         oButton:select()
         oButton:killFocus()   
      ELSEIF SetKey(nKEY) != NIL
         Eval(SetKey(nKEY),PROCNAME(2),PROCLINE(2),"","")
      ENDIF
   ENDDO

RETURN

STATIC FUNC DisplayTaskLines(aTaskLines, nTopLine, nMaxRows, nStartRow, nStartCol, cDefaultColor)
   LOCAL nI, nRow, cText, cColor
   
   // Clear the display area
   FOR nI := 1 TO nMaxRows
      @ nStartRow + nI - 1, nStartCol SAY Space(86) COLOR cDefaultColor
   NEXT
   
   // Display visible lines
   FOR nI := 1 TO MIN(nMaxRows, Len(aTaskLines) - nTopLine + 1)
      nRow := nStartRow + nI - 1
      cText := aTaskLines[nTopLine + nI - 1][1]
      cColor := aTaskLines[nTopLine + nI - 1][2]
      @ nRow, nStartCol SAY Left(cText, 86) COLOR cColor
   NEXT
   
RETURN NIL

PROC RUN_ProjectGantt(nProjectNr)
   LOCAL nW
   
   IF ValType(nProjectNr) != "N"
      Alert("UngÅltige Projekt Nummer")
      RETURN
   ENDIF
/*STATIC_ProjectNr := nProjectNr
   Alert(ValToPrg(ganttLoadTodos()))
RETURN
*/
   BEGIN SEQUENCE
      hb_threadStart({|nProjectNr|         
         LOCAL cError
         HB_gtSelect(HB_GTCREATE("gtcgi"))  //this avoids any problems with things being displayed on the screen
         nW := hb_webview_create(.T.)

         ErrorBlock({|oError| 
            LOCAL cError := ErrorMessage(oError)
            hb_webview_eval(nW, 'window.alert("'+cError+'")')
            RETURN NIL            
         })         

         IF LETO_Connect(getConfigValue("leto_server"),HB_UserName()) < 0 
            hb_webview_eval(nW, 'window.alert("Could not connect to Leto server")')   
            hb_webview_run(nW)    
            hb_webview_destroy(nW)     
            RETURN .T.
         ENDIF
         
         LoadPrg(Path("MASK\trd_project.prg")) //make sure the functions are available in this thread
         STATIC_ProjectNr := nProjectNr
         hb_webview_set_title(nW,"Projekt "+LTrim(Str(nProjectNr))+" - GANTT Chart")   
         hb_webview_bind2(nW,"ganttLoadTodos",HB_CALL_FUNC_DIRECT)
         hb_webview_navigate(nW,"file:///"+Path("www/GanttChart/gantt.html"))
         hb_webview_run(nW)

         hb_webview_destroy(nW)
         RETURN .T.
      },nProjectNr)
   RECOVER      
   ENDSEQUENCE

RETURN

FUNC ganttLoadTodos()
   LOCAL hReturn := {=>}
   LOCAL aData := {}
   LOCAL oTodos, cRefType
   LOCAL oUsr
   

   NetUse("todo","todo")

   hReturn["success"] := .T.
   hReturn["projectNumber"] := LTrim(Str(STATIC_ProjectNr))
   
   IF Select("todo") == 0
      NetUse("todo","todo")
   ENDIF
   
   // Get todos for this project
   cRefType := "PJ " + Str(STATIC_ProjectNr,6)
   oTodos := todo->(RecordCollection():New("TODO",,{|| cRefType },{|| todo->RefType == "PJ " .AND. todo->Ref == STATIC_ProjectNr },8,"todo"))
   
   oTodos:Each({|oTodo|
      LOCAL hTodo := {=>}
      LOCAL cUserName := ""
      LOCAL dStartDate := CToD("")
      LOCAL oUsr
      
      hTodo["uuid"] := Trim(oTodo:UUID)
      hTodo["task"] := Trim(oTodo:Task)
      hTodo["level"] := oTodo:Level
      hTodo["order"] := oTodo:Order
      hTodo["done"] := oTodo:Done
      hTodo["days"] := oTodo:Days
      hTodo["preId"] := Trim(oTodo:PreID)
      hTodo["preDone"] := oTodo:PreDone

      // Format dates for JavaScript (YYYYMMDD format)
      IF ! Empty(oTodo:Due)
         hTodo["dueDate"] := DToS(oTodo:Due)
      ENDIF

      IF ! Empty(oTodo:DoneDate)
         hTodo["doneDate"] := DToS(oTodo:DoneDate)
      ENDIF

      // Calculate start date
      dStartDate := CalculateTaskStartDate(oTodo, oTodos)
      IF ! Empty(dStartDate)
         hTodo["startDate"] := DToS(dStartDate)
      ENDIF
      
      // Get user name if assigned
      IF oTodo:User != 0
         IF Select("buy") == 0
            NetUse("buyer","buy")
         ENDIF
         oUsr := User():New()
         oUsr:Load(oTodo:User)
         cUserName := oUsr:FirstName
      ENDIF
      hTodo["user"] := cUserName
      
      AAdd(aData, hTodo)
      RETURN .T.
   })
   
   hReturn["todos"] := aData

RETURN hReturn

FUNC CalculateTaskStartDate(oTodo, oTodos)
   LOCAL dStartDate := CToD("")
   LOCAL oPreTask, nRec, nOrder
   LOCAL dPreEndDate := CToD("")
   
   // If task is already done, calculate start date from done date minus days
   IF oTodo:Done .AND. ! Empty(oTodo:DoneDate)
      dStartDate := oTodo:DoneDate - MAX(oTodo:Days, 1)
      RETURN dStartDate
   ENDIF
   
   // If task has a predecessor, find the end date of the predecessor
   IF ! Empty(oTodo:PreID)
      // Find the predecessor task
      nRec := todo->(Recno())
      nOrder := todo->(IndexOrd())
      
      oTodos:Each({|oPreCandidate|
         IF Trim(oPreCandidate:UUID) == Trim(oTodo:PreID)
            oPreTask := oPreCandidate
            RETURN .F. // Stop searching
         ENDIF
         RETURN .T. // Continue searching
      })
      
      todo->(dbGoTo(nRec))
      todo->(dbSetOrder(nOrder))
      
      IF oPreTask != NIL
         // Get the end date of the predecessor
         IF oPreTask:Done .AND. ! Empty(oPreTask:DoneDate)
            dPreEndDate := oPreTask:DoneDate
         ELSEIF ! Empty(oPreTask:Due)
            dPreEndDate := oPreTask:Due
         ELSE
            // Recursively calculate predecessor's start date if needed
            dPreEndDate := CalculateTaskStartDate(oPreTask, oTodos)
            IF ! Empty(dPreEndDate) .AND. oPreTask:Days > 0
               dPreEndDate := dPreEndDate + oPreTask:Days
            ENDIF
         ENDIF
         
         // Start this task the day after predecessor ends
         IF ! Empty(dPreEndDate)
            dStartDate := dPreEndDate + 1
            RETURN dStartDate
         ENDIF
      ENDIF
   ENDIF
   
   // If task has a due date but no predecessor, calculate start from due date minus days
   IF ! Empty(oTodo:Due)
      dStartDate := oTodo:Due - MAX(oTodo:Days, 1)
      RETURN dStartDate
   ENDIF
   
   // No start date can be calculated
   RETURN CToD("")
