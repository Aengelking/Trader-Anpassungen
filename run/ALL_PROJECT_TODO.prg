#include 'inkey.ch'
PROC RUN_ALL_PROJECT_TODO
      //LOCAL aList := {}
      LOCAL oBrowse,oFilter,cFor
      LOCAL hUsers := GetUsers()

      MEMVAR c_five

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

      oFilter := InteractiveFilter():New(00,02,05)
      //oFilter:AddValue("Kunde",'kunde',Space(8))      
      oFilter:AddValue("F„llig",'due',Date())
      oFilter:AddValue("Verantwortlich",{|nOwner| 'pj->(dbSeeK(Str(todo->Ref,6))) .AND. pj->Owner == '+LTrim(Str(nOwner))},hUsers)
      oFilter:AddValue("Vertrieb",{|nOwner| 'pj->(dbSeeK(Str(todo->Ref,6))) .AND. pj->Owner == '+LTrim(Str(nOwner))},hUsers)
      oFilter:AddValue("Mitarbeiter","user",hUsers)


      oBrowse := todo->(TBrowseTr():New(01,00, MaxRow(),MaxCol()))
      oBrowse:OneColumn := .T.
      oBrowse:lBox := .F.
      cFor := "!done .AND. ! Empty(due) .AND. User != 0 "
      //oBrowse:forBlock := {|| ! todo->Done  .AND. ! Empty(todo->Due) .AND. todo->User != 0 }
      
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
      oBrowse:AddKey(K_F11,{||
         LOCAL cCol := SetColor(c_five)
         oFilter:Dialog()
         oBrowse:SetFilter(oFilter,cFor)
         SetColor(cCol)
         RETURN .T.
      })
      /*oBrowse:AddKey(K_F10,{||  //the oBrowse:SaveAsCSV needs adapting for arrays
         oBrowse:SaveAsCSV({;
            "Projekt"=>{|| todo->Ref },;
            "Verantwortlich"=>{|| pj->(dbSeeK(Str(todo->Ref,6))), buy->(dbGoTo(pj->Owner)), buy->Initials },;
            "F„llig"=>{|| DtoC(todo->Due) },;
            "MA"=>{||
               buy->(dbGoTo(todo->User))
               RETURN buy->Initials
            },;
            "Aufgabe"=>{|| todo->Task };
         })
         RETURN .T.
      })*/

      DO WHILE ! todo->(EOF()) .AND. ! Eval(oBrowse:forBlock)
         todo->(dbSkip())
      ENDDO
      oBrowse:SetFilter(NIL,cFor)
      oBrowse:EventLoop()

   RETURN
