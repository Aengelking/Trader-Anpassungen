PROC RUN_SYNC_Supabase_Todo
   LOCAL oSupa := Supabase():New()
   LOCAL aTodo,aKRs,nKR,nUser,aUsers,nTodo
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

   // Sync todos from Supabase to Trader
   SyncSupabaseToTrader(aTodo, aKRs, aUsers, nKeyResultsListID, oSupa)
   
   // Sync completed status from Trader to Supabase
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
   LOCAL nNewID := 0
   LOCAL nCurrentUserID := SystemUser():Id
   
   NetUse("tl","tl")
   NetUse("tl_acc","tl_acc")
   
   // Create new todo list
   tl->(dbAppend())
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
   
   // Add owner access record
   tl_acc->(dbAppend())
   tl_acc->TLID := nNewID
   tl_acc->USERID := nCurrentUserID
   tl_acc->ISOWNER := .F.
   tl_acc->CANWRITE := .F.
   tl_acc->GRANTEDAT := Date()
   tl_acc->GRANTEDBY := nCurrentUserID
   tl_acc->(dbCommit())
   
   tl->(dbCloseArea())
   tl_acc->(dbCloseArea())
   
RETURN nNewID

// Sync todos from Supabase to Trader
STATIC FUNCTION SyncSupabaseToTrader(aTodo, aKRs, aUsers, nKeyResultsListID, oSupa)
   LOCAL nTodo, nKR, nUser
   LOCAL oTodo
   LOCAL hUpdateData
   
   NetUse("todo","todo")
   
   FOR nTodo := 1 TO Len(aTodo)
      // Only process incomplete todos or those without trader_uuid
      IF ! aTodo[nTodo]["completed"] .OR. Empty(aTodo[nTodo]["trader_uuid"])
         nKR := AScan(aKRs, {|aKR| aKR["id"] == aTodo[nTodo]["key_result_id"]} )
         IF nKR != 0   
            nUser := AScan(aUsers, {|aUser| aUser["id"] == aKRs[nKR]["user_id"]} )
            IF nUser != 0 .AND. aUsers[nUser]["trader_id"] > 0
               
               IF Empty(aTodo[nTodo]["trader_uuid"])
                  // Create new trader todo
                  ? "Creating new trader todo: ",hb_strtoutf8(aTodo[nTodo]["title"])
                  
                  oTodo := Todo():New(.T.)
                  oTodo:UUID := win_UuidCreateString()
                  oTodo:RefType := "TL"
                  oTodo:Ref := nKeyResultsListID
                  oTodo:Task := hb_utf8tostr(aTodo[nTodo]["title"])
                  oTodo:User := aUsers[nUser]["trader_id"]
                  oTodo:Due := IF(!Empty(aTodo[nTodo]["due_date"]),StoD(StrTran(Left(aTodo[nTodo]["due_date"],10),"-","")),StoD(""))
                  oTodo:Done := aTodo[nTodo]["completed"]
                  oTodo:Notes := "Supabase ID: " + aTodo[nTodo]["id"]
                  oTodo:Save()
                  
                  // Update Supabase with trader_uuid
                  hUpdateData := {"trader_uuid" => oTodo:UUID}                  
                  oSupa:Execute("rest/v1/kr_todos?id=eq." + aTodo[nTodo]["id"], "PATCH", hUpdateData,, .T.)
                  
               ELSE
                  // Update existing trader todo
                  ? "Updating trader todo: ",hb_utf8tostr(aTodo[nTodo]["title"]),IF(!Empty(aTodo[nTodo]["due_date"]),DtoC(StoD(StrTran(Left(aTodo[nTodo]["due_date"],10),"-",""))),"")
                  
                  oTodo := Todo():New()
                  IF oTodo:Load(aTodo[nTodo]["trader_uuid"])
                     oTodo:Task := hb_utf8tostr(aTodo[nTodo]["title"])
                     oTodo:Due := IF(!Empty(aTodo[nTodo]["due_date"]),StoD(StrTran(Left(aTodo[nTodo]["due_date"],10),"-","")),StoD(""))
                     oTodo:Done := aTodo[nTodo]["completed"]
                     oTodo:Save()
                  ENDIF
               ENDIF
            ENDIF
         ENDIF
      ENDIF
   NEXT
   
   todo->(dbCloseArea())
   
RETURN .T.

// Sync completed status from Trader to Supabase
STATIC FUNCTION SyncTraderToSupabase(nKeyResultsListID, oSupa)
   LOCAL cListID := "TL "+Str(nKeyResultsListID,6)
   LOCAL cSupabaseID, hUpdateData
   LOCAL nPos
   
   NetUse("todo","todo")
   
   todo->(dbSetOrder(10)) // RefType+Ref order
   todo->(dbSeek(cListID))
   
   DO WHILE todo->RefType+Str(todo->Ref,6) == cListID .AND. !todo->(EOF())
      IF todo->Level == 0 .AND. !Empty(todo->Notes) .AND. "Supabase ID:" $ todo->Notes
         // Extract Supabase ID from notes
         nPos := At("Supabase ID:", todo->Notes)
         IF nPos > 0
            cSupabaseID := LTrim(SubStr(todo->Notes, nPos + 12))
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
               ? "Syncing completion status for Supabase ID:", cSupabaseID, "Completed:", todo->Done
               
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

