PROC RUN_ALL_PROJECT_TODO
      //LOCAL aList := {}
      LOCAL oBrowse
      LOCAL cFor,nX
      LOCAL hUsers := {=>}

      Head("šberf„llige Aufgaben in Projekten pro Benutzer")

      NetUse("todo","todo")
      NetUse("buyer","buy")
      NetUse("projekte","pj")

      todo->(dbSetOrder( 1 ))


      cFor := "!done .AND. ! Empty(due) .AND. User != 0 .AND. Due < Date()"

      todo->(dbSetFilter( {|| todo->(&(cFor)) }, cFor ))
      IF ! todo->(dbSeek( "PJ " ))
         Tr_MsgBox("Keine berf„lligen Aufgaben in Projekten gefunden")
         todo->(dbClearFilter())
      ELSE
         DO WHILE Trim(todo->Reftype) == "PJ" .AND. ! todo->(EOF())         
            IF ! todo->User $ hUsers
               hUsers[todo->User] := 0
            ENDIF
            hUsers[todo->User]++         
            todo->(dbSkip())
         ENDDO
      ENDIF
      todo->(dbClearFilter())
      

      ? "šberf„llige Aufgaben pro Benutzer:"
      FOR nX := 1 TO Len(hUsers)
         //IF HGetValueAt(hUsers,nX) > 0
            buy->(dbGoto(HGetKeyAt(hUsers,nX)))
            ? buy->Buyer,HGetValueAt(hUsers,nX)            
         //ENDIF
      NEXT

      hUsers := {=>}

      cFor := "status == 0"
      pj->(dbSetFilter({|| pj->(&(cFor))},cFor))

      pj->(dbGoTop())
      todo->(dbSetOrder(3))
      DO WHILE ! pj->(EOF()) 
         IF ! todo->(dbSeek( "PJ "+Str(pj->Nummer,6)+"N" ))
         //nCount := todo->(LETO_SUM("1","","PJ "+Str(pj->Nummer,6)+"N","PJ "+Str(pj->Nummer,6)+"N"))
         //IF nCount > 0
            IF ! pj->Owner $ hUsers
               hUsers[pj->Owner] := 0
            ENDIF
            hUsers[pj->Owner]++
         ENDIF
         pj->(dbSkip())
      ENDDO
      pj->(dbClearFilter())        

      ?
      ? "Offene Projekte ohne Aufgaben pro Benutzer:"
      FOR nX := 1 TO Len(hUsers)         
         buy->(dbGoto(HGetKeyAt(hUsers,nX)))
         ? buy->Buyer,HGetValueAt(hUsers,nX)            
      NEXT

      ? "Weiter mit beliebiger Taste..."
      Sinkey(0)

      todo->(dbCloseArea())

   RETURN
