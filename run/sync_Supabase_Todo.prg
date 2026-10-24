PROC RUN_SYNC_Supabase_Todo
   LOCAL oSupa := Supabase():New()
   LOCAL aTodo,aKRs,nUser,aUsers
   LOCAL nKeyResultsListID

   IF ! oSupa:Login()
      Tr_MsgBox("Supabase login failed")
      RETURN
   ENDIF

   CLS

   // Get or create "Key Results" todo list
   nKeyResultsListID := GetOrCreateKeyResultsList()
   IF nKeyResultsListID == 0
      Tr_MsgBox("Failed to create Key Results todo list")
      RETURN
   ENDIF

   //download todos
   aTodo := HB_JsonDecode(oSupa:Execute("rest/v1/kr_todos","GET",{"select"=>"id,title,due_date,trader_uuid,completed,key_result_id"},,.T.))

   aKRs := HB_JsonDecode(oSupa:Execute("rest/v1/key_results","GET",{"select"=>"id,title,user_id,trader_uuid"},,.T.))

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

   // Sync key results and todos from Supabase to Trader
   SyncSupabaseToTrader(aTodo, aKRs, aUsers, nKeyResultsListID, oSupa)
   
   // Clean up orphaned todos in Trader
   CleanupOrphanedTodos(aTodo, aKRs, nKeyResultsListID)
   
   // Sync completed status from Trader to Supabase (todos only, not key results)
   SyncTraderToSupabase(nKeyResultsListID, oSupa)

   Sinkey(0)
 

// Get or create the "Key Results" todo list
STATIC FUNCTION GetOrCreateKeyResultsList()
   LOCAL nListID := 0
   LOCAL nCurrentUserID := SystemUser():Id
   
   NetUse("tl","tl")
   NetUse("tl_acc","tl_acc")
   
   // Look for existing "Key Results" list
   tl->(dbGoTop())
   DO WHILE !tl->(EOF())
      IF Upper(Trim(tl->NAME)) == "KEY RESULTS" .AND. tl->STATUS != "D"
         // Check if current user has access
         tl_acc->(dbSetOrder(1)) // TLUSER
         IF tl_acc->(dbSeek(STR(tl->ID,6)+STR(nCurrentUserID,6)))
            nListID := tl->ID
            EXIT
         ENDIF
      ENDIF
      tl->(dbSkip())
   ENDDO
   
   // Create new list if not found
   IF nListID == 0
      nListID := CreateKeyResultsList()
   ENDIF
   
   tl->(dbCloseArea())
   tl_acc->(dbCloseArea())
   
RETURN nListID

// Create the "Key Results" todo list
STATIC FUNCTION CreateKeyResultsList()
   LOCAL nNewID
   LOCAL nCurrentUserID := SystemUser():Id
   
   NetUse("tl","tl")
   NetUse("tl_acc","tl_acc")
   
   // Create new todo list
   tl->(Add_Rec(0))
   nNewID := __GetNextTLID()
   tl->ID := nNewID
   tl->NAME := "Key Results"
   tl->DESC := "Synchronized Key Results from Supabase"
   tl->CREATEDAT := Date()
   tl->CREATEDBY := nCurrentUserID
   tl->UPDATEDAT := Date()
   tl->UPDATEDBY := nCurrentUserID
   tl->STATUS := "A"
   tl->(dbCommit())
   tl->(dbUnlock())
   
   // Add owner access record if not already present
   AddUserAccessToList(nNewID, nCurrentUserID)
   
   tl->(dbCloseArea())
   tl_acc->(dbCloseArea())
   
RETURN nNewID

// Add user access to a todo list if not already present
STATIC FUNCTION AddUserAccessToList(nListID, nUserID)
   NetUse("tl_acc","tl_acc")
   tl_acc->(dbSetOrder(1)) // TLUSER order: TLID+USERID
   IF ! tl_acc->(dbSeek(STR(nListID,6)+STR(nUserID,6)))
      tl_acc->(Add_Rec(0))
      tl_acc->TLID := nListID
      tl_acc->USERID := nUserID
      tl_acc->ISOWNER := .F.
      tl_acc->CANWRITE := .F.
      tl_acc->GRANTEDAT := Date()
      tl_acc->GRANTEDBY := nUserID
      tl_acc->(dbCommit())
      tl_acc->(dbUnlock())
   ENDIF
   tl_acc->(dbCloseArea())
RETURN NIL

// Sync key results and todos from Supabase to Trader
STATIC FUNCTION SyncSupabaseToTrader(aTodo, aKRs, aUsers, nKeyResultsListID, oSupa)
   LOCAL nKR, nUser, nTodo
   LOCAL oTodo, oKRTodo
   LOCAL hUpdateData
   LOCAL cParentUUID
   
   NetUse("todo","todo")
   
   // First, sync key results as parent todos
   FOR nKR := 1 TO Len(aKRs)
      nUser := AScan(aUsers, {|aUser| aUser["id"] == aKRs[nKR]["user_id"]} )
      IF nUser != 0 .AND. aUsers[nUser]["trader_id"] > 0
         
         IF ! Empty(aKRs[nKR]["trader_uuid"])
            // Update existing key result
            ? "Updating key result: ",hb_utf8tostr(aKRs[nKR]["title"])
            
            oKRTodo := Todo():New()
            IF oKRTodo:Load(aKRs[nKR]["trader_uuid"])
               oKRTodo:Task := "KR: "+hb_utf8tostr(aKRs[nKR]["title"])
               oKRTodo:User := aUsers[nUser]["trader_id"]
               // Don't update Done status for key results
               oKRTodo:Save()
               // Ensure user has access to the list (in case of reassignment)
               AddUserAccessToList(nKeyResultsListID, aUsers[nUser]["trader_id"])
            ELSE
               ? "*** NOT FOUND *** "+aKRs[nKR]["trader_uuid"]
               aKRs[nKR]["trader_uuid"] := ""
            ENDIF
         ENDIF

         IF Empty(aKRs[nKR]["trader_uuid"])
            // Create new key result parent todo
            ? "Creating new key result: ",hb_strtoutf8(aKRs[nKR]["title"])
            
            oKRTodo := Todo():New(.T.)
            oKRTodo:UUID := win_UuidCreateString()
            oKRTodo:RefType := "TL"
            oKRTodo:Ref := nKeyResultsListID
            oKRTodo:Task := "KR: "+hb_utf8tostr(aKRs[nKR]["title"])
            oKRTodo:User := aUsers[nUser]["trader_id"]
            oKRTodo:Level := 0  // Parent level
            oKRTodo:Done := .F.  // Key results are never marked as done automatically
            oKRTodo:Notes := "Supabase KR ID: " + aKRs[nKR]["id"]
            oKRTodo:Save()
            
            // Add user to the list
            AddUserAccessToList(nKeyResultsListID, aUsers[nUser]["trader_id"])
            
            // Update Supabase with trader_uuid
            hUpdateData := {"trader_uuid" => oKRTodo:UUID}                  
            oSupa:Execute("rest/v1/key_results?id=eq." + aKRs[nKR]["id"], "PATCH", hUpdateData,, .T.)
            
            aKRs[nKR]["trader_uuid"] := oKRTodo:UUID
            
         ENDIF
      ENDIF
   NEXT
   
   // Then, sync todos as children under their key results
   FOR nTodo := 1 TO Len(aTodo)
      // Only process incomplete todos or those without trader_uuid
      IF ! aTodo[nTodo]["completed"] .OR. Empty(aTodo[nTodo]["trader_uuid"])
         nKR := AScan(aKRs, {|aKR| aKR["id"] == aTodo[nTodo]["key_result_id"]} )
         IF nKR != 0   
            nUser := AScan(aUsers, {|aUser| aUser["id"] == aKRs[nKR]["user_id"]} )
            IF nUser != 0 .AND. aUsers[nUser]["trader_id"] > 0
               
               // Get parent key result UUID
               cParentUUID := aKRs[nKR]["trader_uuid"]
               
               IF ! Empty(aTodo[nTodo]["trader_uuid"])
                  // Update existing trader todo
                  ? "Updating todo: ",hb_strtoutf8(aTodo[nTodo]["title"]),IF(!Empty(aTodo[nTodo]["due_date"]),DtoC(StoD(StrTran(Left(aTodo[nTodo]["due_date"],10),"-",""))),"")
                                    
                  oTodo := Todo():New()
                  IF oTodo:Load(aTodo[nTodo]["trader_uuid"])
                     oTodo:Task := hb_utf8tostr(aTodo[nTodo]["title"])
                     oTodo:Parent := cParentUUID  // Ensure parent relationship is maintained
                     oTodo:Due := IF(!Empty(aTodo[nTodo]["due_date"]),StoD(StrTran(Left(aTodo[nTodo]["due_date"],10),"-")),StoD(""))
                     oTodo:Done := aTodo[nTodo]["completed"]
                     oTodo:Save()
                  ELSE
                     ?? "**** NOT FOUND *****"
                     aTodo[nTodo]["trader_uuid"] := ""
                  ENDIF
               ENDIF

               IF Empty(aTodo[nTodo]["trader_uuid"])
                  // Create new trader todo as child
                  ? "Creating new todo under KR: ",hb_strtoutf8(aTodo[nTodo]["title"])
                  
                  oTodo := Todo():New(.T.)
                  oTodo:UUID := win_UuidCreateString()
                  oTodo:RefType := "TL"
                  oTodo:Ref := nKeyResultsListID
                  oTodo:Task := hb_utf8tostr(aTodo[nTodo]["title"])
                  oTodo:User := aUsers[nUser]["trader_id"]
                  oTodo:Parent := cParentUUID
                  oTodo:Due := IF(!Empty(aTodo[nTodo]["due_date"]),StoD(StrTran(Left(aTodo[nTodo]["due_date"],10),"-","")),StoD(""))
                  oTodo:Done := aTodo[nTodo]["completed"]
                  oTodo:Notes := "Supabase TODO ID: " + aTodo[nTodo]["id"]
                  oTodo:Save()
                  
                  // Update Supabase with trader_uuid
                  hUpdateData := {"trader_uuid" => oTodo:UUID}                  
                  oSupa:Execute("rest/v1/kr_todos?id=eq." + aTodo[nTodo]["id"], "PATCH", hUpdateData,, .T.)
               ENDIF
            ENDIF
         ELSE
            ? "Key Result not found:",aKRs[nKR]["title"]
         ENDIF
      ENDIF
   NEXT
   
   todo->(dbCloseArea())
   
RETURN .T.

// Clean up orphaned todos in Trader that no longer exist in Supabase
STATIC FUNCTION CleanupOrphanedTodos(aTodo, aKRs, nKeyResultsListID)
   LOCAL cListID := "TL "+Str(nKeyResultsListID,6)
   LOCAL oTodo, nPos
   LOCAL lFound
   LOCAL nDeleted := 0
   
   NetUse("todo","todo")
   
   todo->(dbSetOrder(10)) // RefType+Ref order
   todo->(dbSeek(cListID))
   
   ? "Starting cleanup of orphaned todos..."
   
   DO WHILE todo->RefType+Str(todo->Ref,6) == cListID .AND. !todo->(EOF())
      lFound := .F.
      
      // Check Key Results (Level 0)
      IF todo->Level == 0
         lFound := (AScan(aKRs, {|aKR| aKR["trader_uuid"] == Trim(todo->UUID)}) > 0)
         
      // Check Todos (Level 1)
      ELSEIF todo->Level == 1 
         lFound := (AScan(aTodo, {|aTodoItem| aTodoItem["trader_uuid"] == Trim(todo->UUID)}) > 0)

      ENDIF
      
      // Delete if not found in Supabase
      IF !lFound 
         ? "Deleting orphaned todo:", Left(todo->Task, 50)
         
         oTodo := Todo():New()
         
         oTodo:Delete()
         nDeleted++
      ELSE
         ? "Found "+todo->Task
      ENDIF
      
      todo->(dbSkip())
   ENDDO
   
   todo->(dbCloseArea())
   
   ? "Cleanup completed. Deleted", nDeleted, "orphaned todos."
   
RETURN .T.

// Sync completed status from Trader to Supabase (todos only, not key results)
STATIC FUNCTION SyncTraderToSupabase(nKeyResultsListID, oSupa)
   LOCAL cListID := "TL "+Str(nKeyResultsListID,6)
   LOCAL cSupabaseID, hUpdateData
   LOCAL nPos
   
   NetUse("todo","todo")
   
   todo->(dbSetOrder(10)) // RefType+Ref order
   todo->(dbSeek(cListID))
   
   DO WHILE todo->RefType+Str(todo->Ref,6) == cListID .AND. !todo->(EOF())
      // Only sync todos (Level 1), not key results (Level 0)
      IF todo->Level == 1 .AND. !Empty(todo->Notes) .AND. "Supabase TODO ID:" $ todo->Notes
         // Extract Supabase ID from notes
         nPos := At("Supabase TODO ID:", todo->Notes)
         IF nPos > 0
            cSupabaseID := LTrim(SubStr(todo->Notes, nPos + 17))
            nPos := At(Chr(13), cSupabaseID)
            IF nPos > 0
               cSupabaseID := Left(cSupabaseID, nPos - 1)
            ENDIF
            nPos := At(Chr(10), cSupabaseID)
            IF nPos > 0
               cSupabaseID := Left(cSupabaseID, nPos - 1)
            ENDIF
            cSupabaseID := Trim(cSupabaseID)
            
            IF !Empty(cSupabaseID)
               ? "Syncing completion status for Supabase TODO ID:", cSupabaseID, "Completed:", todo->Done
               
               // Update completion status in Supabase
               hUpdateData := {"completed" => todo->Done}
               oSupa:Execute("rest/v1/kr_todos?id=eq." + cSupabaseID, "PATCH", hUpdateData,, .T.)
            ENDIF
         ENDIF
      ENDIF
      
      todo->(dbSkip())
   ENDDO
   
   todo->(dbCloseArea())
   
RETURN .T.

// Get next available todo list ID (moved from list.prg)
STATIC FUNCTION __GetNextTLID()
   LOCAL nID := 1
   LOCAL aEnv := SaveEnv()
   
   tl->(dbGoTop())
   DO WHILE !tl->(EOF())
      IF tl->ID >= nID
         nID := tl->ID + 1
      ENDIF
      tl->(dbSkip())
   ENDDO
   
   RestEnv(aEnv,.F.)

RETURN nID
   

   #include "x:\run\supabase_api.prg"
