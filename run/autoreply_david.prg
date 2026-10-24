#define ROUTING_REPLY   "TRADER Autoreply"
#define ROUTING_FORWARD "TRADER Forwarder"
#define TEMPLATE_NAME "Autoreply (Trader)"

#define DvArchivePersonalIn	101
#define DvArchivePersonalTextModules	103
#define DvItemIsLess 2
#define DvItemIsGreater 3
#define DvFilterAnd 1
#define DvEMailItem 2      // MailItem Objekt
#define DvMsgSelEMail  1
#define DvRoutingEMail 2

#define CRLF Chr(13)+Chr(10)


#include 'hbclass.ch'

CLASS DavidAutoReply
   METHOD Set
   METHOD New
   METHOD Disable

   DATA lIsActive INIT .F.
   DATA dFrom     INIT Date()
   DATA dUntil    INIT Date()
   DATA nVertreter INIT 0
   DATA lForward INIT .F.
   
   DATA oTemplates
   DATA oReply
   DATA oForward
   DATA cUserName INIT ""

END CLASS

METHOD New(nUser)
   LOCAL oApp := CreateObject("DVOBJAPILib.DvISEAPI")
   LOCAL oAccount := oApp:Logon("", "", "", "", "", "AUTH")
   LOCAL nX
   LOCAL lFoundForward,lFoundReply
   LOCAL oItem,oCond
   LOCAL oInbox

   NetUse("buyer","buy")
   
   ::Super:New()

   IF ! Empty(nUser)
      buy->(dbGoto(nUser))
      ::cUserName := buy->Buyer
      oInbox := oAccount:ArchiveFromID(oAccount:ArchiveRoot:FullPath()+"\USER\"+buy->David_ID+"\IN")
      ::oTemplates :=  oAccount:ArchiveFromID(oAccount:ArchiveRoot:FullPath()+"\USER\"+buy->David_ID+"\txtmdl")
   ELSE      
      oInbox := oAccount:GetSpecialArchive(DvArchivePersonalIn)
      ::oTemplates := oAccount:GetSpecialArchive(DvArchivePersonalTextModules)
   ENDIF

   lFoundReply   := .F.
   lFoundForward := .F.
   nX            := 0
   ::oReply        := NIL
   ::oForward      := NIL

   Do While nX < oInbox:RoutingEntries:Count .AND. ! (lFoundReply .AND. lFoundForward)
      oItem := oInbox:RoutingEntries:Item(nX)
      If oItem:Name == ROUTING_REPLY
         lFoundReply := .T.
         ::oReply := oItem
      Elseif oItem:Name == ROUTING_FORWARD
         lFoundForward := .T.
         ::oForward := oItem
         ::lForward := ::oForward:Enabled
         buy->(dbSetOrder(4))
         IF buy->(dbSeek( ::oForward:ForwardTo ))
            ::nVertreter := buy->(Recno())
         ENDIF
         //::cForwardTo := ::oForward:ForwardTo         
      Endif
      nX++
   Enddo

   If lFoundReply
      nX := 0
      ::lIsActive := ::oReply:Enabled
      Do While nX < ::oReply:Conditions:Count
         oCond := ::oReply:Conditions:Item(nX)
         If oCond:Object == 1 //Date
            If oCond:Comparision == DvItemIsGreater
               ::dFrom := oCond:Value+1
            Elseif oCond:Comparision == DvItemIsLess
               ::dUntil := oCond:Value-1
            Endif
         Endif
         nX++
      Enddo
      If ::dUntil < Date()
         ::lIsActive := .F.
      Endif
   Else
      ::oReply := oInbox:RoutingEntries:Add(ROUTING_REPLY)      
   Endif

   If ! lFoundForward
      ::oForward := oInbox:RoutingEntries:Add(ROUTING_FORWARD)
   Endif
   
RETURN Self

METHOD Disable()
   ::oReply:Enabled := .F.
   ::oForward:Enabled := .F.
   ::oReply:Commit()
   ::oForward:Commit()
RETURN .T.

METHOD Set()
   LOCAL oFilter,oTemplate,lFound
   LOCAL nX
   LOCAL cText,cPerson

   ::oReply:AutoReply := .T.
   ::oReply:Enabled   := .T.
   ::oReply:OnlySubject := .T. //do not return original message

   ::oForward:Forward := .T.
   ::oForward:Enabled := ::lForward
   ::oForward:ForwardAs := DvRoutingEMail
   IF ::nVertreter != 0
      buy->(dbGoto( ::nVertreter ))
      ::oForward:ForwardTo := Trim(buy->Email)
   ENDIF   

   //Setup conditions
   ::oReply:Conditions:RemoveAll()

   oFilter := ::oReply:Conditions:Add()
   oFilter:Object := 1 //date
   oFilter:Comparision := DvItemIsGreater
   oFilter:Value := ::dFrom-1 //ein Tag abziehen da grî·er und nicht grî·er gleich
   oFilter:Operator := DvFilterAnd

   oFilter := ::oReply:Conditions:Add()
   oFilter:Object := 1
   oFilter:Comparision := DvItemIsLess
   oFilter:Value := ::dUntil+1
   oFilter:Operator := DvFilterAnd

   oFilter := ::oReply:Conditions:Add()
   oFilter:Object := -2147438510 //Field_ExternalMessage
   oFilter:Comparision := 0 //DvItemIsEqual
   oFilter:Value := 1 //.T.
   oFilter:Operator := DvFilterAnd

   oFilter := ::oReply:Conditions:Add()
   oFilter:Object := -2147450823 //Field_Sender
   oFilter:Comparision := 1 //DvItemIsNotEqual
   oFilter:Value := "*@marketplace.conrad.com"
   oFilter:Operator := DvFilterAnd


   ::oForward:Conditions:RemoveAll()

   //Setup Forward Message
   oFilter := ::oForward:Conditions:Add()
   oFilter:Object := 1
   oFilter:Comparision := DvItemIsGreater
   oFilter:Value := ::dFrom-1
   oFilter:Operator := DvFilterAnd

   oFilter := ::oForward:Conditions:Add()
   oFilter:Object := 1
   oFilter:Comparision := DvItemIsLess
   oFilter:Value := ::dUntil+1
   oFilter:Operator := DvFilterAnd

   oFilter := ::oForward:Conditions:Add()
   oFilter:Object := -2147438510 //Field_ExternalMessage
   oFilter:Comparision := 0 //DvItemIsEqual
   oFilter:Value := 1 //.T.
   oFilter:Operator := DvFilterAnd

   ::oForward:Commit()
   ::oReply:Commit()

   oTemplate := NIL

	lFound := .F.
	nX := 0

	Do While nX < ::oTemplates:MailItems:Count .AND. ! lFound
		oTemplate := ::oTemplates:MailItems:Item(nX)
		If oTemplate:Subject == TEMPLATE_NAME
			lFound := .T.
		Endif
		nX++
	Enddo

	If ! lFound
		oTemplate := ::oTemplates:NewItem(DvEMailItem)
		oTemplate:Subject := TEMPLATE_NAME
	Endif

   cPerson := ""
   If ::nVertreter > 1
      buy->(dbGoto( ::nVertreter ))
      cPerson := buy->Buyer+CRLF
      If ! Empty(buy->Telefon)
         cPerson += "Tel.: +49-(0)7464-9865"+buy->Telefon+CRLF
      Endif
      cPerson += "Email: "+buy->Email
   Endif


   cText  := CRLF+"Vielen Dank f¸r Ihre Nachricht."+CRLF+CRLF+"Ich bin "
   If ::dFrom != ::dUntil	
	   cText += "bis einschlieﬂlich "+DToC(::dUntil)
   Else
	   cText += "am "+DToC(::dFrom)
   Endif
   cText += " nicht im B¸ro."
   If ::nVertreter > 1
	   cText += " Bitte kontaktieren Sie w‰hrend dieser Zeit"+CRLF+CRLF
	   cText += cPerson
   Endif
   If ::lForward
      cText += CRLF+CRLF+"Ihre Emails werden weitergeleitet."
   ELSE
      cText += HB_OemToAnsi(CRLF+CRLF+"Ich werde diese schnellst mîglichst nach meiner RÅckkehr bearbeiten.")
   Endif
   cText += CRLF+CRLF+"Mit freundlichen Gr¸ﬂen"+CRLF+::cUserName+CRLF+CRLF
   cText += "_______________________________________________________________________"+CRLF+CRLF
   cText += "Thank you for your email."+CRLF+CRLF+"I am out of the office "
   If ::dFrom != ::dUntil	
	   cText += "until "+DToC(::dUntil)
   Else
	   cText += "on "+DToC(::dFrom)
   Endif
   cText += "."
   If ::nVertreter != 0
	   cText += " During this time you can contact"+CRLF+CRLF
	   cText += cPerson
   Endif
   If ::lForward
      cText += CRLF+CRLF+"Your emails will be redirected."
   ELSE
      cText += CRLF+CRLF+"I will answer your mail as soon as possible on my return."
   Endif
   cText += CRLF+CRLF+"Best Regards"+CRLF+::cUserName

   oTemplate:BodyText:PlainText := t(cText)
   oTemplate:BodyText:Charset :=  "windows-1252"
   oTemplate:Save(NIL,DvMsgSelEMail)

   hb_idleSleep( 10 / 1000 ) //wait a little to let david commit

   nX := 0

   Do While nX < ::oTemplates:MailItems:Count .AND. ! lFound
      oTemplate := ::oTemplates:MailItems:Item(nX)
      If oTemplate:Subject == TEMPLATE_NAME
         lFound := .T.
      Endif
      nX++
   Enddo

   If ! lFound
      //Tr_MsgBox("Autoreply konnte NICHT eingerichtet werden")
      Return .F.
   Endif

   ::oReply:IncludeBefore := oTemplate:Fields:Item ("Filename"):Value+".001"
   ::oReply:Commit()

   //Tr_MsgBox(t("Autoreply wurde eingerichtet und aktiviert"))
RETURN .T.