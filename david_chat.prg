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
   LOCAL cText,cReplace,cJson,hJson,nPos,cTemp,cCmd
   LOCAL cExt,nF,aData
   LOCAL tStart

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
   tStart := DateTime()

   //? ValToPRg(aMsgs)

   DO WHILE .T.
      //buy->(dbGoTop())
      IF ! LETO_PING() 
         RETURN
         //this does not seem to work.
         /*? "LETO Error: " + LETO_CONNECT_ERR(.T.)
         ? "attempting reconnect"
         DO WHILE LETO_ReConnect() == -1 //getConfigValue("leto_server"),GetWinUser())
            //restart
            ?  "LETO Error: " + LETO_CONNECT_ERR(.T.)
            IF Inkey(10,128) == 27
               RETURN
            ENDIF
            
            //RETURN
         ENDDO*/
      ELSE
         @ 01,50 SAY "Checking for new messages... "
         IF Empty(tLastCheck)
            cLastCheck := "0"
         ELSE
            tDateTime := tLastCheck+1/24 //convert to UTC      
            IF tDateTime >= dLastSunMarch .AND. tDateTime < dLastSunOctober //summer time
               tDateTime := tDateTime + 1/24
            ENDIF
            cLastCheck := LTrim(Str((tDateTime-Stot("160101010200"))*60*60*24*10000000,18,0))
         ENDIF

         cQuery := "SELECT MessageText,MessageTime/10000000 AS MessageTime,SenderID,AttachCount,MessageID FROM messages WHERE ConversationID="+LTrim(Str(nConversationID))+" AND MessageTime > "+cLastCheck+ " ORDER BY MessageTime ASC"

         oDB:SetSQL(cQuery)          
         tLastCheck := DateTime()
         IF ! oDB:Open()
            SQLError( oDB:hEnv, oDB:hDbc, oDB:hStmt, @cErrorClass, @nType, @cErrorMsg )
            Alert("Error " + cErrorClass + " - " + cErrorMsg)
         ELSEIF oDB:RecCount() > 0         
            ?? LTrim(Str(oDB:RecCount())) + " new messages"
            aData := {}
            //save to array so we can do more queries on the DB
            FOR nX := 1 TO oDB:RecCount()
               oDB:LoadData(nX)
               Aadd(aData,{"MessageID"=>oDB:FieldByName("MessageID"):Value,;
                           "MessageTime"=>oDB:FieldByName("MessageTime"):Value,;
                           "SenderID"=>oDB:FieldByName("SenderID"):Value,;
                           "MessageText"=>oDB:FieldByName("MessageText"):Value,;
                           "AttachCount"=>oDB:FieldByName("AttachCount"):Value;
                        })
            NEXT
            FOR nX := 1 TO Len(aData)
               ? aData[nX,"MessageTime"]

               //MessageTime is bigint in nano seconds starting on 01.01.1601, divide by 10000000 to get seconds, in UTC            
               //Snippet for Javascript
               //var utcDate = '2011-06-29T16:52:48.000Z';  // ISO-8601 formatted date returned from server
               //var localDate = new Date(utcDate);
               
               tDateTime := StoT("160101010200")+aData[nX,"MessageTime"]/60/60/24            
               tDateTime := tDateTime - 1/24 //deduct one hour for UTC+1 to convert to MET
               //Sommerzeit                      
               IF tDateTime >= dLastSunMarch .AND. tDateTime < dLastSunOctober
                  tDateTime := tDateTime - 1/24
               ENDIF
                  buy->(dbGoTop())
                  buy->(__dbLocate({|| buy->David_ID == HB_NumToHex(aData[nX,"SenderID"]) }))
                  IF buy->(Found())
                     cUser := Substr(buy->Buyer,1,AT(" ",buy->Buyer)-1)+" ("+HB_NumToHex(aData[nX,"SenderID"])+")"
                  ELSE
                     cUser := HB_NumToHex(aData[nX,"SenderID"])
                  ENDIF            

                  cTimeStamp := Left(TtoC(tDateTime),14)
                  cText := HB_OemToAnsi(StrTran(aData[nX,"MessageText"],Chr(13),"<br>"))
                  IF (nPos := AT('?"',cText)) != 0  //replace special commands  
                     ? cText        
                     
                     cCmd := SubStr(cText,nPos+1)
                     cCmd := SubStr(cCmd,1,AT("?",cCmd)-1)

                     
                     cJson := SubStr(cCmd,AT("{",cCmd))
                     cJson := SubStr(cJson,1,AT('}',cText)-1)
                     hJson := HB_JsonDecode(cJson)
                     cReplace := ""
                     IF HHasKey(hJson,"type")
                        IF hJson["type"] == "hyperlink"
                           cReplace := '<a href="#" onclick="trader.openLink('+"'"+hb_base64decode(hJson["link"])+"'"+')">'+hb_base64decode(hJson["text"])+"</a>"
                        ELSEIF hJson["type"] == "agree"
                           cReplace := "Stimme zu"
                        ENDIF
                     ENDIF

                     cTemp := SubStr(cText,nPos+2)
                     cText := SubStr(cText,1,nPos-1)+cReplace+SubStr(cTemp,AT("?",cTemp)+1)                     

                  ENDIF          
                  IF aData[nX,"AttachCount"] > 0
                     ? "Attachments: "+LTrim(Str(aData[nX,"AttachCount"]))  
                     
                     cQuery := "SELECT FileName,Location FROM attachments WHERE ConversationID="+LTrim(Str(nConversationID))+" AND MessageID="+LTrim(Str(aData[nX,"MessageID"]))

                     oDB:SetSQL(cQuery)
                     IF oDB:Open()
                        FOR nF := 1 TO oDB:RecCount()
                           oDB:LoadData(nF)
                           //? oDB:FieldByName("FileName"):Value,oDB:FieldByName("Location"):Value
                           HB_FnameSplit(oDB:FieldByName("FileName"):Value,,,@cExt)
                           IF Lower(cExt) $ {".jpg",".jpeg",".png",".gif",".bmp"} //it is an image
                              //? "D:\David\Code\Boards\"+oDB:FieldByName("Location"):Value,"=>","x:\www\chatfiles\"+oDB:FieldByName("Location"):Value+"_"+oDB:FieldByName("FileName"):Value
                              COPY FILE ("D:\David\Code\Boards\"+oDB:FieldByName("Location"):Value) TO ("x:\www\chatfiles\"+oDB:FieldByName("Location"):Value+"_"+oDB:FieldByName("FileName"):Value)
                              cText += '<br><img src="chatfiles\'+oDB:FieldByName("Location"):Value+"_"+oDB:FieldByName("FileName"):Value+'" style="max-height: 200px;">'
                           ENDIF
                        NEXT
                     ENDIF

                  ENDIF

               HB_AIns(aMsgs,1,{"TIMESTAMP"=>cTimeStamp,"USER"=>cUser,"TEXT"=>cText},.T.)                     
            NEXT
            ? "Chat updated"
            MemoWrit( cFileName, HB_JsonEncode(aMsgs) )
         ELSE
            ?? "no new messages"
         ENDIF
      ENDIF
      @ 01,50 SAY DtoC(Date())+" "+Time()
      @ 02,50 SAY "waiting..."
      IF Inkey(10,128) == 27
         EXIT
      ENDIF
      @ 02,50 SAY Space(10)
      IF tStart+59/60/24 < DateTime() //close after 59 minutes, as it is restartet every hour
         RETURN
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