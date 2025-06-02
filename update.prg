FUNCTION Update()
   	InstallTL()
      InstallTLAccess()
RETURN NIL

FUNCTION InstallTL()
   LOCAL cDataPath := IF(GetConfigValue("FIRMPATH") != ".",GetConfigValue("FIRMPATH")+"\","")
   LOCAL lExists := Leto_File(cDataPath + "tl.dbf")
   
   IF !lExists
      dbCreate(cDataPath + "tl.dbf", CreateTLStructure(),"LETO")
      NetUse("tl", "tl")
      CreateTLIndexes()
      tl->(dbCloseArea())
      Tr_MsgBox("Todo List database created successfully!")
   ELSE
      Tr_MsgBox("Todo List database already exists!")
   ENDIF
   
RETURN NIL

FUNCTION InstallTLAccess()
   LOCAL cDataPath := IF(GetConfigValue("FIRMPATH") != ".",GetConfigValue("FIRMPATH")+"\","")
   LOCAL lExists := Leto_File(cDataPath + "tl_acc.dbf")
   
   IF !lExists
      dbCreate(cDataPath + "tl_acc.dbf", CreateTLAccessStructure(),"LETO")
      NetUse("tl_acc", "tlacc")
      CreateTLAccessIndexes()
      tlacc->(dbCloseArea())
      Tr_MsgBox("Todo List Access database created successfully!")
   ELSE 
      Tr_MsgBox("Todo List Access database already exists!")
   ENDIF
   
RETURN NIL


FUNCTION CreateTLStructure()
   LOCAL aStruct := {}
   
   AADD(aStruct, {"ID",        "N", 6, 0})  // Unique identifier for the todo list
   AADD(aStruct, {"NAME",      "C", 50, 0}) // Name of the todo list
   AADD(aStruct, {"DESC",      "M", 10, 0}) // Description of the todo list
   AADD(aStruct, {"CREATEDAT", "D", 8, 0})  // Creation date
   AADD(aStruct, {"CREATEDBY", "N", 6, 0})  // User ID who created the list
   AADD(aStruct, {"UPDATEDAT", "D", 8, 0})  // Last update date
   AADD(aStruct, {"UPDATEDBY", "N", 6, 0})  // User ID who last updated the list
   AADD(aStruct, {"STATUS",    "C", 1, 0})  // Status (A=Active, C=Completed, D=Deleted)
   
RETURN aStruct

FUNCTION CreateTLIndexes()
   LOCAL cIndexPath := IF(GetConfigValue("FIRMPATH") != ".",GetConfigValue("FIRMPATH")+"\","")
   
   // Create indexes for the TL database
   INDEX ON ID TAG ID TO (cIndexPath + "tl")
   INDEX ON NAME TAG NAME TO (cIndexPath + "tl")
   INDEX ON STATUS TAG STATUS TO (cIndexPath + "tl")
   INDEX ON CREATEDAT TAG CREATEDAT TO (cIndexPath + "tl")
   
RETURN NIL



FUNCTION CreateTLAccessStructure()
   LOCAL aStruct := {}
   
   AADD(aStruct, {"TLID",      "N", 6, 0})  // Todo List ID
   AADD(aStruct, {"USERID",    "N", 6, 0})  // User ID who has access
   AADD(aStruct, {"ISOWNER",   "L", 1, 0})  // Flag indicating if user is the owner
   AADD(aStruct, {"CANWRITE",  "L", 1, 0})  // Flag indicating if user can modify the list
   AADD(aStruct, {"GRANTEDAT", "D", 8, 0})  // Date when access was granted
   AADD(aStruct, {"GRANTEDBY", "N", 6, 0})  // User ID who granted the access
   
RETURN aStruct

FUNCTION CreateTLAccessIndexes()
   LOCAL cIndexPath := IF(GetConfigValue("FIRMPATH") != ".",GetConfigValue("FIRMPATH")+"\","")
   
   // Create indexes for the TL_ACCESS database
   INDEX ON STR(TLID,6)+STR(USERID,6) TAG TLUSER TO (cIndexPath + "tl_acc")
   INDEX ON TLID TAG TLID TO (cIndexPath + "tl_acc")
   INDEX ON USERID TAG USERID TO (cIndexPath + "tl_acc")
   INDEX ON STR(TLID,6)+IF(ISOWNER,"1","0") TAG OWNER TO (cIndexPath + "tl_acc")
   
RETURN NIL






