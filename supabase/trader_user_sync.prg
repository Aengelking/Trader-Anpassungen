//#include 'trader.ch'

// Comment out the next line to disable logging
#define LOG_ENABLED

/**
 * Trader User Sync to Multiple Supabase Databases
 * 
 * This program synchronizes trader users from the local buy table
 * to multiple configured Supabase databases.
 * 
 * Author: GitHub Copilot
 * Created: 2025-09-20
 */

// Main sync procedure
PROC SYNC_Trader_Users()
   LOCAL aSupabaseConfigs := GetSupabaseConfigs()
   LOCAL cLogFile := CreateLogFile("trader_user_sync_" + DToS(Date()) + "_" + StrTran(Time(), ":", ""))
   LOCAL nSuccess := 0, nErrors := 0
   LOCAL nConfigIndex
   
#ifdef LOG_ENABLED
   WriteLog(cLogFile, "INFO", "Starting Trader User Sync to " + LTrim(Str(Len(aSupabaseConfigs))) + " Supabase databases")
#endif
   
   // Validate all configurations before starting sync
   IF ! ValidateAllConfigs(aSupabaseConfigs, cLogFile)
#ifdef LOG_ENABLED
      WriteLog(cLogFile, "ERROR", "Configuration validation failed. Aborting sync.")
#endif
      RETURN
   ENDIF
   
   // Open trader user database
   IF ! OpenTraderDatabase(cLogFile)
#ifdef LOG_ENABLED
      WriteLog(cLogFile, "ERROR", "Failed to open trader database. Aborting sync.")
#endif
      RETURN
   ENDIF
   
   // Sync to each configured Supabase database
   FOR nConfigIndex := 1 TO Len(aSupabaseConfigs)
#ifdef LOG_ENABLED
      WriteLog(cLogFile, "INFO", "Syncing to database: " + aSupabaseConfigs[nConfigIndex]["name"])
#endif
      
      IF SyncToSupabaseDatabase(aSupabaseConfigs[nConfigIndex], cLogFile)
         nSuccess++
#ifdef LOG_ENABLED
         WriteLog(cLogFile, "INFO", "Successfully synced to: " + aSupabaseConfigs[nConfigIndex]["name"])
#endif
      ELSE
         nErrors++
#ifdef LOG_ENABLED
         WriteLog(cLogFile, "ERROR", "Failed to sync to: " + aSupabaseConfigs[nConfigIndex]["name"])
#endif
      ENDIF
   NEXT
   
#ifdef LOG_ENABLED
   WriteLog(cLogFile, "INFO", "Sync completed. Success: " + LTrim(Str(nSuccess)) + ", Errors: " + LTrim(Str(nErrors)))
#endif
   
   // Close databases
   CloseTraderDatabase()
   
RETURN

/**
 * Get Supabase database configurations
 * Returns an array of configuration hashes
 */
STATIC FUNCTION GetSupabaseConfigs()
   LOCAL aConfigs := {}
   
   // Sales
   AAdd(aConfigs, {;
      "name" => "Sales",;
      "url" => "https://rxaltcsbhcxlczjjczxs.supabase.co/",;
      "service_role_key" => "LOV-SAL-SR",;
      "enabled" => .T.,;
      "sync_mode" => "UPSERT",;
      "create_users" => .T.,;
      "send_email" => .F.;
   })
  
   // Development Database
   AAdd(aConfigs, {;
      "name" => "QM",;
      "url" => "https://gkwtwjvjzdsbejwqfeig.supabase.co/",;
      "service_role_key" => "LOV-QM-SR",;
      "enabled" => .T.,;
      "sync_mode" => "UPSERT",;
      "create_users" => .T.,;
      "send_email" => .F.;
   })
  /* 
   // Backup Database
   AAdd(aConfigs, {;
      "name" => "Backup Auth",;
      "url" => "https://your-backup-project.supabase.co",;
      "service_role_key" => "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9...",;
      "enabled" => .F.,; // Disabled by default
      "sync_mode" => "INSERT",;
      "create_users" => .T.,;
      "send_email" => .F.;
   })
   
   // Analytics Database
   AAdd(aConfigs, {;
      "name" => "Analytics Auth",;
      "url" => "https://your-analytics-project.supabase.co",;
      "service_role_key" => "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9...",;
      "enabled" => .T.,;
      "sync_mode" => "UPSERT",;
      "create_users" => .T.,;
      "send_email" => .F.;
   })
   */
   // Filter only enabled configurations
   aConfigs := AClone(aConfigs, {|x| x["enabled"]})
   
RETURN aConfigs

/**
 * Validate all Supabase configurations
 */
STATIC FUNCTION ValidateAllConfigs(aConfigs, cLogFile)
   LOCAL nIndex, hConfig
   LOCAL lAllValid := .T.
   
   FOR nIndex := 1 TO Len(aConfigs)
      hConfig := aConfigs[nIndex]
      
#ifdef LOG_ENABLED
      WriteLog(cLogFile, "INFO", "Validating config: " + hConfig["name"])
#endif
      
      // Check required fields for auth
      IF Empty(hConfig["url"]) .OR. Empty(hConfig["service_role_key"])
#ifdef LOG_ENABLED
         WriteLog(cLogFile, "ERROR", "Invalid configuration for " + hConfig["name"] + ": Missing required fields")
#endif
         lAllValid := .F.
         LOOP
      ENDIF
      
      // Test connection
      IF ! TestSupabaseAuthConnection(hConfig, cLogFile)
#ifdef LOG_ENABLED
         WriteLog(cLogFile, "ERROR", "Connection test failed for " + hConfig["name"])
#endif
         lAllValid := .F.
      ELSE
#ifdef LOG_ENABLED
         WriteLog(cLogFile, "INFO", "Connection test successful for " + hConfig["name"])
#endif
      ENDIF
   NEXT
   
RETURN lAllValid

/**
 * Test connection to Supabase Auth
 */
STATIC FUNCTION TestSupabaseAuthConnection(hConfig, cLogFile)
   LOCAL oSupa
   LOCAL aResult
   LOCAL lSuccess := .F.
   LOCAL cResult
   
   oSupa := CreateSupabaseClient(hConfig)
   
   // Try to list users to test auth connection
   cResult := oSupa:Execute("auth/v1/admin/users", "GET", {"page" => "1", "per_page" => "1"}, , .T.)
   
   IF ! "error" $ Lower(cResult)
      aResult := HB_JsonDecode(cResult)
      IF ValType(aResult) == "H" .AND. "users" $ aResult
         lSuccess := .T.
      ELSEIF ValType(aResult) == "A"
         lSuccess := .T.
      ENDIF
#ifdef LOG_ENABLED
      WriteLog(cLogFile, "INFO", "Auth connection successful for " + hConfig["name"]+". First user: "+IF(ValType(aResult)=="H" .AND. "users" $ aResult .AND. Len(aResult["users"])>0,aResult["users"][1]["email"],IF(ValType(aResult)=="A" .AND. Len(aResult)>0,aResult[1]["email"],"No users found")))
#endif
   ELSE
#ifdef LOG_ENABLED
      WriteLog(cLogFile, "ERROR", "Auth connection error for " + hConfig["name"] + ": " + cResult)
#endif
   ENDIF
   
RETURN lSuccess

/**
 * Open trader database
 */
STATIC FUNCTION OpenTraderDatabase(cLogFile)
   LOCAL lSuccess := .T.
   
   NetUse("buyer", "buy")
   
   IF Select("buy") == 0
#ifdef LOG_ENABLED
      WriteLog(cLogFile, "ERROR", "Failed to open trader database")
#endif
      lSuccess := .F.
   ELSE
      buy->(dbSetOrder(0)) // Natural order
#ifdef LOG_ENABLED
      WriteLog(cLogFile, "INFO", "Opened trader database with " + LTrim(Str(buy->(LastRec()))) + " user records")
#endif
   ENDIF
   
RETURN lSuccess

/**
 * Close trader database
 */
STATIC PROCEDURE CloseTraderDatabase()
   IF Select("buy") > 0
      buy->(dbCloseArea())
   ENDIF
RETURN

/**
 * Sync users to a specific Supabase database
 */
STATIC FUNCTION SyncToSupabaseDatabase(hConfig, cLogFile)
   LOCAL oSupa
   LOCAL nRecCount, nProcessed := 0, nSkipped := 0, nSynced := 0, nDeleted := 0
   LOCAL hUserData
   LOCAL lSuccess := .T.
   
   oSupa := CreateSupabaseClient(hConfig)
   
   nRecCount := buy->(LastRec())
   buy->(dbGoTop())

#ifdef LOG_ENABLED
   WriteLog(cLogFile, "INFO", "Processing " + LTrim(Str(nRecCount)) + " user records for " + hConfig["name"])
#endif
   
   DO WHILE ! buy->(EOF())
      nProcessed++
      
      // Handle inactive users - delete them from Supabase if they exist
      IF ! buy->aktive .OR. Empty(AllTrim(buy->Email)) // Inactive or users without email
         IF ! Empty(AllTrim(buy->Email)) // Only try to delete if we have an email
#ifdef LOG_ENABLED
            WriteLog(cLogFile, "INFO", "Deleting deactivated user from Supabase: " + AllTrim(buy->Buyer))
#endif
            IF DeleteSupabaseUser(oSupa, AllTrim(buy->Email), cLogFile)
               nDeleted++
#ifdef LOG_ENABLED
               WriteLog(cLogFile, "INFO", "Successfully deleted user: " + AllTrim(buy->Email))
#endif
            ELSE
#ifdef LOG_ENABLED
               WriteLog(cLogFile, "WARNING", "Failed to delete or user not found: " + AllTrim(buy->Email))
#endif
            ENDIF
         ELSE
#ifdef LOG_ENABLED
            WriteLog(cLogFile, "DEBUG", "Skipping inactive user without email: " + AllTrim(buy->Buyer))
#endif
         ENDIF
         nSkipped++
         buy->(dbSkip())
         LOOP
      ENDIF
      
      // Prepare user data for sync
      hUserData := PrepareUserAuthData(hConfig)
      
      IF Empty(hUserData) .OR. Empty(hUserData["email"])
#ifdef LOG_ENABLED
         WriteLog(cLogFile, "WARNING", "No data to sync for user: " + AllTrim(buy->Buyer))
#endif
         nSkipped++
         buy->(dbSkip())
         LOOP
      ENDIF
      
      // Sync user to Supabase Auth
      IF SyncSingleAuthUser(oSupa, hConfig, hUserData, cLogFile)
         nSynced++
      ELSE
         lSuccess := .F.
      ENDIF
      
      buy->(dbSkip())
   ENDDO
   
#ifdef LOG_ENABLED
   WriteLog(cLogFile, "INFO", "Sync summary for " + hConfig["name"] + ": Processed=" + LTrim(Str(nProcessed)) + ;
             ", Synced=" + LTrim(Str(nSynced)) + ", Deleted=" + LTrim(Str(nDeleted)) + ", Skipped=" + LTrim(Str(nSkipped)))
#endif
   
RETURN lSuccess

/**
 * Prepare user data from current record for Supabase Auth
 */
STATIC FUNCTION PrepareUserAuthData(hConfig)
   LOCAL hData := {=>}
   LOCAL cEmail, cPassword
   
   // Generate email if not provided
   cEmail := AllTrim(buy->Email)
   IF Empty(cEmail)
      // Generate email based on initials and domain
      cEmail := Lower(AllTrim(buy->Initials)) + "@trader.local"
   ENDIF
   
   // Generate a default password (should be changed on first login)
   cPassword := "Trader" + LTrim(Str(buy->(Recno()))) + "!"
   
   // Basic auth user information
   hData["email"] := cEmail
   hData["password"] := cPassword
   hData["email_confirm"] := .T. // Skip email confirmation
   
   // User metadata - custom fields
   hData["user_metadata"] := {=>}
   hData["user_metadata"]["trader_user_id"] := buy->(Recno())
   hData["user_metadata"]["full_name"] := hb_strToUtf8(AllTrim(buy->Buyer))
   hData["user_metadata"]["initials"] := AllTrim(buy->Initials)
   hData["user_metadata"]["short_name"] := AllTrim(buy->Short)
   hData["user_metadata"]["phone"] := AllTrim(buy->Telefon)
   hData["user_metadata"]["rate"] := buy->Verrsatz
   hData["user_metadata"]["active"] := buy->aktive
   hData["user_metadata"]["display_name"] := AllTrim(SubStr(buy->Buyer,1,At(" ",buy->Buyer)-1)) // First name
   hData["user_metadata"]["last_sync"] := DToC(Date()) + " " + Time()
   hData["user_metadata"]["sync_timestamp"] := DateTime()
   hData["user_metadata"]["source"] := "trader_sync"
   
   // App metadata - system fields
   hData["app_metadata"] := {=>}
   hData["app_metadata"]["provider"] := "trader"
   hData["app_metadata"]["trader_user_id"] := buy->(Recno())
   hData["app_metadata"]["role"] := IF(buy->aktive, "user", "inactive")
   hData["app_metadata"]["department"] := "trader"
   
   // Only create users if explicitly enabled
   IF ! hConfig["create_users"]
      RETURN NIL
   ENDIF
   
RETURN hData

/**
 * Sync a single user to Supabase Auth
 */
STATIC FUNCTION SyncSingleAuthUser(oSupa, hConfig, hUserData, cLogFile)
   LOCAL cResult, aExisting
   LOCAL lSuccess := .T.
   LOCAL cEndpoint := "auth/v1/admin/users"
   LOCAL cEmail := hUserData["email"]
   LOCAL nTraderUserId := hUserData["user_metadata"]["trader_user_id"]
   LOCAL cUserId, hUpdateData
   
   IF hConfig["sync_mode"] == "UPSERT"
      // Check if user exists by email
      cResult := oSupa:Execute(cEndpoint, "GET", {"filter" => cEmail}, , .T.)
      
      IF ! "error" $ Lower(cResult)
         aExisting := HB_JsonDecode(cResult)
         
         // Check if we got users array or single user
         IF ValType(aExisting) == "H" .AND. "users" $ aExisting .AND. Len(aExisting["users"]) > 0
            IF aExisting["users"][1]["email"] != cEmail
               #ifdef LOG_ENABLED
               WriteLog(cLogFile, "DEBUG", "Email mismatch for existing user: " + aExisting["users"][1]["email"] + " vs " + cEmail)
               #endif
            ELSE

               // Update existing user
               cUserId := aExisting["users"][1]["id"]
               hUpdateData := {=>}
               
               // Only update metadata for existing users
               hUpdateData["user_metadata"] := hUserData["user_metadata"]
               hUpdateData["app_metadata"] := hUserData["app_metadata"]
               
               cResult := oSupa:Execute(cEndpoint + "/" + cUserId, "PUT", hUpdateData, , .T.)
   #ifdef LOG_ENABLED
               WriteLog(cLogFile, "DEBUG", "Updated auth user: " + cEmail+":"+cResult)
   #endif
            ENDIF
         ELSEIF ValType(aExisting) == "A" .AND. Len(aExisting) > 0
            // Update existing user (if returned as array)
            cUserId := aExisting[1]["id"]
            hUpdateData := {=>}
            
            hUpdateData["user_metadata"] := hUserData["user_metadata"]
            hUpdateData["app_metadata"] := hUserData["app_metadata"]
            
            cResult := oSupa:Execute(cEndpoint + "/" + cUserId, "PUT", hUpdateData, , .T.)
#ifdef LOG_ENABLED
            WriteLog(cLogFile, "DEBUG", "Updated auth user: " + cEmail+":"+cResult)
#endif
            
         ELSE
            // Create new user
            cResult := oSupa:Execute(cEndpoint, "POST", hUserData, , .T.)
#ifdef LOG_ENABLED
            WriteLog(cLogFile, "DEBUG", "Created auth user: " + cEmail )
#endif
         ENDIF
      ELSE
#ifdef LOG_ENABLED
         WriteLog(cLogFile, "ERROR", "Failed to check existing auth user " + cEmail + ": " + cResult)
#endif
         lSuccess := .F.
      ENDIF
      
   ELSE // INSERT mode - always create new user
      cResult := oSupa:Execute(cEndpoint, "POST", hUserData, , .T.)
#ifdef LOG_ENABLED
      WriteLog(cLogFile, "DEBUG", "Created auth user: " + cEmail)
#endif
   ENDIF
   
   // Check for errors in response
   IF "error" $ Lower(cResult) .AND. ! "User already registered" $ cResult
#ifdef LOG_ENABLED
      WriteLog(cLogFile, "ERROR", "Supabase auth error for user " + cEmail + ": " + cResult)
#endif
      lSuccess := .F.
   ELSEIF "User already registered" $ cResult
#ifdef LOG_ENABLED
      WriteLog(cLogFile, "WARNING", "Auth user already exists: " + cEmail)
#endif
   ENDIF
   
RETURN lSuccess

/**
 * Delete a user from Supabase Auth by email
 */
STATIC FUNCTION DeleteSupabaseUser(oSupa, cEmail, cLogFile)
   LOCAL cResult, aUsers, cUserId
   LOCAL lSuccess := .F.
   LOCAL cEndpoint := "auth/v1/admin/users"
   
   // First, find the user by email
   cResult := oSupa:Execute(cEndpoint, "GET", {"filter" => cEmail}, , .T.)
   
   IF ! "error" $ Lower(cResult)
      aUsers := HB_JsonDecode(cResult)
      
      // Check if we got users array or single user
      IF ValType(aUsers) == "H" .AND. "users" $ aUsers .AND. Len(aUsers["users"]) > 0 .AND. aUsers["users"][1]["email"] == cEmail
         cUserId := aUsers["users"][1]["id"]
      ELSEIF ValType(aUsers) == "A" .AND. Len(aUsers) > 0 .AND. aUsers[1]["email"] == cEmail
         cUserId := aUsers[1]["id"]
      ELSE
#ifdef LOG_ENABLED
         WriteLog(cLogFile, "DEBUG", "User not found in Supabase: " + cEmail)
#endif
         RETURN .T. // User doesn't exist, so deletion is "successful"
      ENDIF
      
      // Delete the user
      IF ! Empty(cUserId)
         cResult := oSupa:Execute(cEndpoint + "/" + cUserId, "DELETE", {=>}, , .T.)
         
         IF ! "error" $ Lower(cResult)
            lSuccess := .T.
#ifdef LOG_ENABLED
            WriteLog(cLogFile, "INFO", "Successfully deleted user: " + cEmail + " (ID: " + cUserId + ")")
#endif
         ELSE
#ifdef LOG_ENABLED
            WriteLog(cLogFile, "ERROR", "Failed to delete user " + cEmail + ": " + cResult)
#endif
         ENDIF
      ENDIF
   ELSE
#ifdef LOG_ENABLED
      WriteLog(cLogFile, "ERROR", "Failed to find user for deletion " + cEmail + ": " + cResult)
#endif
   ENDIF
   
RETURN lSuccess

/**
 * Create and configure a Supabase object with the given configuration
 */
STATIC FUNCTION CreateSupabaseClient(hConfig)
   LOCAL oSupa
   
   oSupa := Supabase():New()
   oSupa:cBaseUrl := hConfig["url"]
   oSupa:cApiKeyName := hConfig["service_role_key"]
   oSupa:cToken := "$APIKEY$"
   
RETURN oSupa

/**
 * Simple DateTime function if not available
 */
STATIC FUNCTION DateTime()
RETURN DToC(Date()) + "T" + Time() + "Z"

/**
 * Create a log file and return the filename
 */
STATIC FUNCTION CreateLogFile(cBaseName)
   LOCAL cLogDir := "X:\run\supabase\logs\"
   LOCAL cLogFile
   
#ifdef LOG_ENABLED
   // Create logs directory if it doesn't exist
   IF ! File(cLogDir)
      MakeDir(cLogDir)
   ENDIF
   
   cLogFile := cLogDir + cBaseName + ".log"
   
   // Initialize log file
   WriteLog(cLogFile, "INFO", "Log started: " + DToC(Date()) + " " + Time())
#else
   cLogFile := ""
#endif
   
RETURN cLogFile

/**
 * Write a message to the log file
 */
STATIC FUNCTION WriteLog(cLogFile, cLevel, cMessage)
#ifdef LOG_ENABLED
   LOCAL nHandle, cLogLine
   
   cLogLine := "[" + DToC(Date()) + " " + Time() + "] [" + cLevel + "] " + cMessage + Chr(13) + Chr(10)
   
   // Also output to console for immediate feedback
   ? cLogLine
   
   // Write to log file
   nHandle := FOpen(cLogFile, 2) // FO_READWRITE = 2
   IF nHandle == -1
      nHandle := FCreate(cLogFile)
   ENDIF
   
   IF nHandle != -1
      FSeek(nHandle, 0, 2) // FS_END = 2
      FWrite(nHandle, cLogLine)
      FClose(nHandle)
   ENDIF
#endif
   
RETURN NIL

/**
 * Configuration management functions
 */

/**
 * Load configurations from external file
 */
FUNCTION LoadSupabaseConfigsFromFile(cFileName)
   LOCAL aConfigs := {}
   LOCAL cContent
   
   IF File(cFileName)
      cContent := MemoRead(cFileName)
      IF ! Empty(cContent)
         aConfigs := HB_JsonDecode(cContent)
         IF aConfigs == NIL
            Alert("Failed to parse configuration file: " + cFileName)
            aConfigs := {}
         ENDIF
      ENDIF
   ELSE
      Alert("Configuration file not found: " + cFileName)
   ENDIF
   
RETURN aConfigs

/**
 * Save configurations to external file
 */
FUNCTION SaveSupabaseConfigsToFile(aConfigs, cFileName)
   LOCAL cContent := HB_JsonEncode(aConfigs, .T.)
   LOCAL lSuccess := .F.
   
   IF ! Empty(cContent)
      lSuccess := MemoWrit(cFileName, cContent)
      IF ! lSuccess
         Alert("Failed to save configuration file: " + cFileName)
      ENDIF
   ENDIF
   
RETURN lSuccess

#include "x:\run\supabase_api.prg"
