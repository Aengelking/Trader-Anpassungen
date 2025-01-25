LOCAL oDB,cErrorClass,nType,cErrorMsg
oDB := TODBC():New( "David" ,"sa","0gakemur54")
SQLError( oDB:hEnv, oDB:hDbc, oDB:hStmt, @cErrorClass, @nType, @cErrorMsg )
IF ! Empty(cErrorclass) .AND. cErrorClass != "00000" .AND.  cErrorClass != "01000"
	Alert("Fehler bei der Verbindung zur Datenbank. Error " + cErrorClass + " - " + cErrorMsg)
	RETURN .F.
ENDIF


/*cQuery := "SELECT TOP 500 arc.Path, msg.srFileName, msg.srSubject, msg.srFrom, msg.srTo, msg.srDocType, msg.srStatusTime, msg.srRecNo, msg.SendRec ";
         +"FROM msg ";
         +"LEFT JOIN arc ";
         +"ON arc.ID=msg.pathID WHERE CONTAINS ((msg.*),N'"+'"bulgin"'+"') ORDER BY msg.srStatusTime DESC"
*/

//cQuery := "SELECT TABLE_NAME, COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH, IS_NULLABLE FROM INFORMATION_SCHEMA.COLUMNS ORDER BY  TABLE_NAME, ORDINAL_POSITION;"
//cQuery := "SELECT TOP 100 MessageText FROM messages"
cQuery := "SELECT ID,Subject,ConversationID FROM convmapping"

oDB:SetSQL(cQuery) //"SELECT TOP 50000 * FROM dbo.msg LEFT JOIN dbo.arc ON arc.ID=msg.pathID WHERE CONTAINS ((msg.srTo),N'bulgin') AND arc.Path LIKE '\\bull\david\archive\user\10004000%' ORDER BY msg.srStatusTime ASC") //[David Archive Database].dbo.msg")
//   oDB:SetSQL("SELECT TOP 50000 * FROM dbo.msg LEFT JOIN dbo.arc ON arc.ID=msg.pathID WHERE CONTAINS (("+cSearchItms+"),N'"+hSettings:cSearchTerm+"') AND arc.Path LIKE '"+cSearchIN+"%' ORDER BY msg.srStatusTime ASC") //[David Archive Database].dbo.msg")
IF ! oDB:Open()
   SQLError( oDB:hEnv, oDB:hDbc, oDB:hStmt, @cErrorClass, @nType, @cErrorMsg )
   Alert("Error " + cErrorClass + " - " + cErrorMsg)
ELSE
   CLS
   FOR nX := 1 TO oDB:RecCount()
      oDB:LoadData(nX)
      
      /*? "Path:",oDB:FieldByName("Path"):Value
      ? "srFileName",oDB:FieldByName("srFileName"):Value
      ? oDB:FieldByName("srSubject"):Value
      ? oDB:FieldByName("srFrom"):Value
      ? oDB:FieldByName("srTo"):Value
      ? oDB:FieldByName("srDocType"):Value
      ? oDB:FieldByName("srStatusTime"):Value
      ? oDB:FieldByName("srRecNo"):Value
      ? oDB:FieldByName("SendRec"):Value*/

      //? oDB:FieldByName("TABLE_NAME"):Value, oDB:FieldByName("COLUMN_NAME"):Value, oDB:FieldByName("DATA_TYPE"):Value

      //? oDB:FieldByName("MessageText"):Value
      //IF Trim(oDB:FieldByName("Subject"):Value) == "Alle"
      IF ! Empty(oDB:FieldByName("Subject"):Value)
         ? oDB:FieldByName("ID"):Value,oDB:FieldByName("Subject"):Value,oDB:FieldByName("ConversationID"):Value
      ENDIF
   NEXT
   Alert("Records: "+Str(oDB:RecCount()))
ENDIF

/* DATABASE STRUCTURE 

attachments ID bigint             
attachments ConversationID int    
attachments MessageID int         
attachments UserID int            
attachments FileTime bigint       
attachments FileSize bigint       
attachments FileName nvarchar     
attachments Description nvarchar  
attachments Location varchar      
attachments CreationTime bigint   
attachments ClientID nvarchar     
conversations ConversationID int  
conversations Attendees varchar   
conversations Owner int           
conversations Detached tinyint    
conversations ChangedBy int       
conversations TimeStampRead bigint
convmapping ID bigint             
convmapping ConversationID int    
convmapping UserID int            
convmapping Subject nvarchar      
convmapping MessageCount int      
convmapping LastMessageTime bigint
convmapping SyncKey bigint        
messages MessageID bigint         
messages ConversationID int       
messages SenderID int             
messages MessageText nvarchar     
messages MessageTime bigint       
messages FromMobileDevice tinyint 
messages Subject nvarchar         
messages AttachCount int          
messages SystemMessage int        
messages ClientID nvarchar        
messages Priority int             
system ID int                     
system Name varchar               
system Value int                  
system StringValue varchar        
usermsg ID int                    
usermsg MessageID int             
usermsg UserID int                
usermsg ConversationID int        
usermsg ReadFlag tinyint          
users ID bigint                   
users UserID int                  
users ChatStatus int              
users ChatLocation nvarchar   

*/