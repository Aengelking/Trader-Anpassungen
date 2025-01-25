PROC RUN_ALL_PROJECT_TODO
      //LOCAL aList := {}
      LOCAL oBrowse

      Head("Alle offen Aufgaben in Projekten")

      NetUse("todo","todo")
      NetUse("buyer","buy")
      NetUse("projekte","pj")

      todo->(dbSetOrder( 1 ))
      //todo->(dbSeek( Str(SystemUser():Id,2) ))

      IF ! todo->(dbSeek("PJ" ))
         Tr_MsgBox("Keine Aufgaben in Projekten gefunden")
         RETURN
      ENDIF

      /*DO WHILE todo->Reftype == "PJ" .AND. ! todo->(EOF())         
         Aadd(aList,{"pj"=>todo->Ref,"text"=>Trim(todo->Task)+" ("+todo->Reftype+LTrim(Str(todo->Ref))+")","date"=>todo->Due,"ref"=>todo->Ref,"reftyp"=>todo->Reftype})
         todo->(dbSkip())
      ENDDO

      todo->(dbClearFilter())

      ASort(aList,,,{|x,y| x["date"] < y["date"] })*/

      oBrowse := todo->(TBrowseTr():New(01,00, MaxRow(),MaxCol()))
      oBrowse:OneColumn := .T.
      oBrowse:lBox := .F.
      oBrowse:cFor := "!done .AND. ! Empty(due) .AND. User != 0 "
      oBrowse:forBlock := {|| ! todo->Done  .AND. ! Empty(todo->Due) .AND. todo->User != 0 }
      
      oBrowse:WhileBlock := {|| Trim(todo->Reftype) == "PJ" }

      oBrowse:ColorSpec := "N/W*,W+/BG,R+/W*,R/BG"
      
      oBrowse:NewColumn("Proj.",{|| Str(todo->Ref,6) },{|| IF(todo->Due <= Date(),{3,4},{1,2})})
      oBrowse:NewColumn("Verantwortlich",{|| pj->(dbSeeK(Str(todo->Ref,6))), buy->(dbGoTo(pj->Owner)), buy->Initials })
      oBrowse:NewColumn("F„llig",{|| DtoC(todo->Due) } )
      oBrowse:NewColumn("MA",{||
         buy->(dbGoTo(todo->User))
         RETURN buy->Initials
      })

      oBrowse:NewColumn("Aufgabe",{|| todo->Task })
      oBrowse:AddKey(27,{|| .F. })
      oBrowse:AddKey(13,{|| Project_edit(todo->Ref) })

      DO WHILE ! todo->(EOF()) .AND. ! Eval(oBrowse:forBlock)
         todo->(dbSkip())
      ENDDO
      oBrowse:EventLoop()

   RETURN
