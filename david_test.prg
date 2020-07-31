#include 'david.ch'

LOCAL oAccount := DV_GetMailAccount()
LOCAL oArchive,oArchives,lFound := .F.

oArchive := DV_GetArchiveByName(oAccount:GetSpecialArchive(DvArchivePersonalIn),"Ablage (automatisch)","2015")
IF oArchive != NIL
   ? "Archive found"
ELSE
   ? "Nothing found"
ENDIF

Inkey(0,128)

RETURN


//mapisendmail()

/*
   MapiSendMail( 0,                    ;   // hWnd
               'This is Subject',      ;   // cSubject
               'And this is text',     ;   // cText
               'Pritpal Bedi',         ;   // Sender's Name
               'vouchcac@hotmail.com', ;   // Sender's Address
               'Pritpal',              ;   // Recipient's Name
               'info@vouchcac.com',    ;   // Recipient's Address
               'c:\autoexec.bat'       )   // File attached

*/

/*
tic://message?Parameterliste

Parameter:
BodyText
To
Cc
Subject
Attachment
Ignoretemplate ( = 1 -> Editor ohne Vorlage öffnen)
Type
"sms"
"tmail"
"email"
"fax"
"ect" -> to gibt dann die Rufnummer an
default ist "auto" 
*/

cLink :=  "tic:/"+"/message?to=amos@engelking.de&BodyText=Hello%20World"

//ShellExecute(NIL, "Open", cLink, "", "", 1)