PROC RUN_David_Chat
   LOCAL oDB,cErrorClass,nType,cErrorMsg
   LOCAL cQuery,nConversationID,nX
   LOCAL aMsgs := {}
   LOCAL tDateTime,cUser,tLatest
   LOCAL cTimeStamp   
   LOCAL nYear := Year(Date())  
   LOCAL dLastSunMarch := STOD(STR(nYear)+"0331")-(DOW(STOD(STR(nYear)+"0331"))-1)
   LOCAL dLastSunOctober := STOD(STR(nYear)+"1031")-(DOW(STOD(STR(nYear)+"1031"))-1)
   LOCAL tLastCheck,cLastCheck

   LOCAL cFileName := "x:\chat.json"


   oDB := TODBC():New( "David" ,"sa","0gakemur54")
   SQLError( oDB:hEnv, oDB:hDbc, oDB:hStmt, @cErrorClass, @nType, @cErrorMsg )
   IF ! Empty(cErrorclass) .AND. cErrorClass != "00000" .AND.  cErrorClass != "01000"
      //Alert("Fehler bei der Verbindung zur Datenbank. Error " + cErrorClass + " - " + cErrorMsg)
      RETURN
   ENDIF

   NetUse("buyer","buy")

   nConversationID := 354 //(118= Alter Alle mit PC), Fixed to "Alle" Chat (315=Test Chat)
   
   CLS

   IF File(cFileName) 
      aMsgs := HB_JsonDecode(FileStr( cFileName ))
   ENDIF
   IF aMsgs == NIL
      aMsgs := {}
   ENDIF
   tLastCheck := StoT(DtoS(FileDate(cFileName))+StrTran(FileTime(cFileName),":",""))

   ? ValToPRg(aMsgs)

   DO WHILE .T.
      ? "Checking for new messages... "
      IF Empty(tLastCheck)
         cLastCheck := "0"
      ELSE
         tDateTime := tLastCheck+1/24 //convert to UTC      
         IF tDateTime >= dLastSunMarch .AND. tDateTime < dLastSunOctober //summer time
            tDateTime := tDateTime + 1/24
         ENDIF
         cLastCheck := LTrim(Str((tDateTime-Stot("160101010200"))*60*60*24*10000000,18,0))
      ENDIF

      cQuery := "SELECT MessageText,MessageTime/10000000 AS MessageTime,SenderID FROM messages WHERE ConversationID="+LTrim(Str(nConversationID))+" AND MessageTime > "+cLastCheck+ " ORDER BY MessageTime ASC"

      oDB:SetSQL(cQuery) 
      tLastCheck := DateTime()
      IF ! oDB:Open()
         SQLError( oDB:hEnv, oDB:hDbc, oDB:hStmt, @cErrorClass, @nType, @cErrorMsg )
         Alert("Error " + cErrorClass + " - " + cErrorMsg)
      ELSEIF oDB:RecCount() > 0         
         ?? LTrim(Str(oDB:RecCount())) + " new messages"
         FOR nX := 1 TO oDB:RecCount()
            oDB:LoadData(nX)
            ? oDB:FieldByName("MessageTime"):Value

            //MessageTime is bigint in nano seconds starting on 01.01.1601, divide by 10000000 to get seconds, in UTC            
            //Snippet for Javascript
            //var utcDate = '2011-06-29T16:52:48.000Z';  // ISO-8601 formatted date returned from server
            //var localDate = new Date(utcDate);
            
            tDateTime := StoT("160101010200")+oDB:FieldByName("MessageTime"):Value/60/60/24            
            tDateTime := tDateTime - 1/24 //deduct one hour for UTC+1 to convert to MET
            //Sommerzeit                      
            IF tDateTime >= dLastSunMarch .AND. tDateTime < dLastSunOctober
               tDateTime := tDateTime - 1/24
            ENDIF

            buy->(dbGoTop())
            buy->(__dbLocate({|| buy->David_ID == HB_NumToHex(oDB:FieldByName("SenderID"):Value) }))
            IF buy->(Found())
               cUser := Substr(buy->Buyer,1,AT(" ",buy->Buyer)-1)
            ELSE
               cUser := HB_NumToHex(oDB:FieldByName("SenderID"):Value)
            ENDIF            

            cTimeStamp := Left(TtoC(tDateTime),14)
            HB_AIns(aMsgs,1,{"TIMESTAMP"=>cTimeStamp,"USER"=>cUser,"TEXT"=>HB_OemToAnsi(StrTran(oDB:FieldByName("MessageText"):Value,Chr(13),"<br>"))},.T.)                     
         NEXT
         ? "Chat updated"
         MemoWrit( cFileName, HB_JsonEncode(aMsgs) )
      ELSE
         ?? "no new messages"
      ENDIF

      ? "waiting..."
      IF Inkey(10,128) == 27
         EXIT
      ENDIF
   ENDDO
   
   oDB:Close()

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