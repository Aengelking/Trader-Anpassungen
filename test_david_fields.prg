#include "y:\harbour\trader\source\include\david.ch"

PROC RUN_TEST_DAVID_FIELDS()
   /*
   
   
   
   
*/
LOCAL aFields := {;
"Status",;
"Options",;
"Flags",;
"FlagsEx",;
"Owner",;
"QID",;
"PageCount",;
"StatusTime",;
"StatusTimeL",;
"SendTime",;
"SendTimeL",;
"TriesDone",;
"ErrorNo",;
"AbortStatus",;
"TotalBroadCastCnt",;
"PagesSent",;
"FaxBoxFlags",;
"RndCount",;
"BaudRate",;
"ActLine",;
"RecNo",;
"UnitsCount",;
"Duration",;
"PrintedOn",;
"MaxRepeats",;
"NoticeType",;
"SysType",;
"NextBroadCastPos",;
"Printing",;
"OutPRNNo",;
"SourceFileName",;
"ExStatusTime",;
"Account",;
"AllowedTLDLine",;
"SenderID",;   
"ScheduleReminderOffset",;
"RoutSign",;
"Application",;
"CurrentNumber",;
"ErrorGroup",;
"LastChangedTime",;
"LastChangedTimeL",;
"ExpireTime",;
"ExpireTimeL",;
"NewDocType",;
"ExtDocType",;
"ArchiveProtocolPrinter",;
"TrackingRecNo",;
"TrackingJobID",;
"Command",;
"SymbolColor",;
"ReminderBits",;
"ServiceID",;
"OrigDuration",;
"RatesNo",;
"StopTime",;
"JobID",;
"Creator",;
"Delivery",;
"SymNumber",;
"SRTo",;
"SRFrom",;
"FileName",;
"Subject",;
"TxCSID",;
"ErrorInfo",;
"AccountKey",;
"RoutingID",;
"DestPath",;
"Contact",;
"Provider",;
"MsgID",;
"FullName",;
"SubAddress",;
"Location",;
"OutgoingCLI",;
"ContentType",;
"SRReplyTo",;
"TckReplyTo",;
"NDSUserName",;
"Priority",;
"Viewed",;
"ReminderTime",;
"AllDayEvent",;
"RecurrencePattern",;
"DocumentType",;
"ExternalMessage",;
"ShowAs",;
"Private",;
"TrackingFlag",;
"UserHold",;
"Received",;
"Completed",;
"TaskStartTime",;
"Rating",;
"AutomationValue",;
"TaskPercentage",;
"TaskStatus",;
"Link",;
"SpamStatus",;
"ExternalExtension",;
"IconNo",;
"SRFromDisplay",;
"HTML",;
"RTF",;
"TrackingReplyAddress",;
"MessageID",;
"HTMLImages",;
"SMTPHeader",;
"OrigMessage",;
"Comment",;
"Communication",;
"AttachCount",;
"ReplyTo",;
"To",;
"Cc",;
"Bcc",;
"FullnameFrom",;
"FullnameTo",;
"Tracking",;
"ExternalAddress",;
"ExternalArchive",;
"SendTimeMsg",;
"ExternalDomain",;
"InfoComment",;
"OCRDone",;
"PDAMessageID",;
"Reference",;
"ForwardReplyAddresses",;
"Attendees",;
"ICalendar",;
"Content",;
"PDAJobRecordID",;
"TaskCompanies",;
"TaskDateCompleted",;
"TaskActualWork",;
"TaskTotalWork",;
"HTMLDisplayContent",;
"Charset",;
"CharsetHtml",;
"Sensitivity",;
"ExclusionDates",;
"Size",;
"AltFaxNumber",;
"Telephone",;
"Partner",;
"Street",;
"City",;
"Country",;
"DisplayName",;
"ShowName",;
"FirstName",;
"MiddleInitial",;
"LastName",;
"Salutation",;
"Title",;
"Company",;
"PostalCode",;
"PhoneOffice",;
"PhonePrivate",;
"PhoneMobile",;
"FaxNumber",;
"FaxNumber2",;
"eMail",;
"VoiceBox",;
"SMSNumber",;
"DayOfBirth",;
"WebSite",;
"State",;
"eMail2",;
"DefaultAddress",;
"AddressCategories",;
"PDACategory",;
"Notes";
}

LOCAL oAccount := DV_GetMailAccount()
LOCAL oArchive  := oAccount:GetSpecialArchive(DvArchivePersonalIn)
LOCAL oItems := oArchive:AllItems
LOCAL oItem,nItem := 1,aItems := {}
LOCAL nX,oField
LOCAL getlist := {}
CLS

FOR nX := 0 TO Min(100,oItems:Count-1)   
   Aadd(aItems,oItems:Item(nX):Subject) //add the first field, which is always the ID, to the list of fields to test
NEXT

@ 01,00,25,50 GET nItem LISTBOX aItems
READ

IF LastKey() == 27 .OR. nItem == 0
   RETURN
ENDIF

CLS

oItem := oItems:Item(nItem-1)

bErrorBlock := ErrorBlock({|e| 
   BREAK    
})

FOR nX := 1 TO Len(aFields)
   ? aFields[nX]+": "
   BEGIN SEQUENCE
      oField := oItem:Fields:Item(aFields[nX])
      IF ValType(oField:Value) == "C"
         cValue := StrTran(oField:Value,Chr(13),"<CR>")
         cValue := StrTran(cValue,Chr(10),"<LF>")
         IF Len(cValue) >= MaxCol()-Col()
            ?? SubStr(cValue,1,MaxCol()-Col()-3)+"..."         
         ELSE
            ?? cValue
         ENDIF
      ELSE
         ?? oField:Value
      ENDIF
      
   RECOVER
      ?? "Error retrieving field"
   END SEQUENCE
   IF Row() >= MaxRow()-1
      ? "Press any key to continue..."
      IF SInkey(0) == 27
         EXIT
      ENDIF
      CLS
   ENDIF

NEXT

ErrorBlock( bErrorBlock )

Sinkey(0)