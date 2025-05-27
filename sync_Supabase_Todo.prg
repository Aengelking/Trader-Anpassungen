PROC RUN_SYNC_Supabase_Todo
   LOCAL oSupa := Supabase():New()
   LOCAL aTodo,aKRs,nKR,nUser,aUsers,nTodo

   IF ! oSupa:Login()
      Tr_MsgBox("Login failed")
      RETURN
   ENDIF

   //download todos
   aTodo := HB_JsonDecode(oSupa:Execute("rest/v1/kr_todos","GET",{"select"=>"id,title,due_date,trader_uuid,completed,key_result_id"},,.T.))

   aKRs := HB_JsonDecode(oSupa:Execute("rest/v1/key_results","GET",{"select"=>"id,title,user_id"},,.T.))

   aUsers := HB_JsonDecode(oSupa:Execute("rest/v1/users","GET",{"select"=>"id,email"},,.T.))

   NetUse("buyer","buy")
   buy->(dbSetOrder( 4 ))
   FOR nUser := 1 TO Len(aUsers)
      IF buy->(dbSeek(aUsers[nUser]["email"]))
         ? aUsers[nUser]["email"],buy->(Recno())
         aUsers[nUser]["trader_id"] := buy->(Recno())
      ELSE
         aUsers[nUser]["trader_id"] := 0
      ENDIF
   NEXT

   FOR nTodo := 1 TO Len(aTodo)
      IF ! aTodo[nTodo]["completed"] .OR. ! Empty(aTodo[nTodo]["trader_uuid"])
         nKR := AScan(aKRs, {|aKR| aKR["id"] == aTodo[nTodo]["key_result_id"]} )
         IF nKR != 0   
            //? hb_utf8tostr(aKRs[nKR]["title"])   
            nUser := AScan(aUsers, {|aUser| aUser["id"] == aKRs[nKR]["user_id"]} )
            IF nUser != 0 .AND. aUsers[nUser]["trader_id"] == 9
               IF Empty(aTodo[nTodo]["trader_uuid"])
                  ? "Create new trader todo ",hb_strtoutf8(aTodo[nTodo]["title"])
               ELSE
                  ? "Update trader todo ",hb_strtoutf8(aTodo[nTodo]["title"])
               ENDIF
            ENDIF
         ENDIF
      ENDIF
   NEXT

   Sinkey(0)

   #include "x:\run\supabase_api.prg"

