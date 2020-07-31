#define DvArchivePersonalIn	101

#define DvArchivePersonalTextModules	103
#define DvItemIsLess 2
#define DvItemIsGreater 3
#define DvFilterAnd 1
#define DvEMailItem 2      // MailItem Objekt
#define DvMsgSelEMail  1
#define DvRoutingEMail 2

#define ROUTING_REPLY   "TRADER Autoreply"
#define ROUTING_FORWARD "TRADER Forwarder"
#define TEMPLATE_NAME "Autoreply (Trader)"
#define CRLF Chr(13)+Chr(10)

#ifndef __XHARBOUR__
	#xtranslate ThreadSleep( <x> )              => hb_idleSleep( <x> / 1000 )
#endif

PROCEDURE HRBMAIN

   LOCAL getlist := {}
   LOCAL oApp,oAccount,oInbox,lFoundReply,lFoundForward
   LOCAL oReply,oItem,oForward,lIsActive,lRedirect,dUntil,nVertret,oCond
   LOCAL dFrom,hBuyer,oGet,oFilter,oTemplate,lFound,oTemplates,cPerson
   LOCAL cText
   LOCAL nX

   MEMVAR c_four_list,c_one_list

   Head("Out of Office Autoreply")

   NETUSE( "buyer","buy",.F.,0 )




oApp := CreateObject("DVOBJAPILib.DvISEAPI")
oAccount := oApp:Logon("", "", "", "", "", "AUTH")
IF .F. //Tr_MsgBox("Fr Sammy",,{"Nein","Ja"}) == 2
   buy->(dbGoto(37))
   oInbox := oAccount:ArchiveFromID(oAccount:ArchiveRoot:FullPath()+"\USER\"+buy->David_ID+"\IN")
   oTemplates :=  oAccount:ArchiveFromID(oAccount:ArchiveRoot:FullPath()+"\USER\"+buy->David_ID+"\txtmdl")
ELSE
   //oInbox := oAccount:ArchiveFromID("")
   oInbox := oAccount:GetSpecialArchive(DvArchivePersonalIn)
   oTemplates := oAccount:GetSpecialArchive(DvArchivePersonalTextModules)
ENDIF

lFoundReply   := .F.
lFoundForward := .F.
nX            := 0
oReply        := NIL
oForward      := NIL

Do While nX < oInbox:RoutingEntries:Count .AND. ! (lFoundReply .AND. lFoundForward)
   oItem := oInbox:RoutingEntries:Item(nX)
	If oItem:Name == ROUTING_REPLY
		lFoundReply := .T.
		oReply := oItem
	Elseif oItem:Name == ROUTING_FORWARD
		lFoundForward := .T.
		oForward := oItem
	Endif
	nX++
Enddo

lIsActive := .F.
dFrom     := Date()
dUntil    := Date()
nVertret  := 1
lRedirect := .F.

If lFoundReply
	nX := 0
	lIsActive := oReply:Enabled
	Do While nX < oReply:Conditions:Count
		oCond := oReply:Conditions:Item(nX)
		If oCond:Object == 1 //Date
			If oCond:Comparision == DvItemIsGreater
				dFrom := oCond:Value+1
			Elseif oCond:Comparision == DvItemIsLess
				dUntil := oCond:Value-1
			Endif
		Endif
		nX++
	Enddo
	If dUntil < Date()
		lIsActive := .F.
	Endif
Else
	oReply := oInbox:RoutingEntries:Add(ROUTING_REPLY)
	//oReply:ValidFrom
Endif


If ! lFoundForward
	oForward := oInbox:RoutingEntries:Add(ROUTING_FORWARD)
Endif


If lIsActive .AND. Tr_MsgBox(t("Autoreply bereits aktiv"),,{t("deaktivieren"),t("ändern")}) != 2
	If LastKey() == 27
		Return
	Endif
	oReply:Enabled   := .F.
	oForward:Enabled := .F.
	oReply:Commit()
	oForward:Commit()
	Return
Endif

hBuyer := {0=>t("Keine")}

buy->(dbGoTop())
Do While ! buy->(Eof())
	If buy->Aktive .AND. ! Empty(buy->Email) .AND. buy->(Recno()) != Tr_Getini(28)
		hBuyer[buy->(Recno())] := buy->Buyer
		If ! Empty(oForward:ForwardTo) .AND. Trim(oForward:ForwardTo) == Trim(buy->Email)
			nVertret := Len(hBuyer)
		Endif
	Endif
	buy->(dbSkip())
Enddo

lRedirect := oForward:Enabled

//@ 26,00 SAY oReply:ForwardTo

@ 02,00 SAY "Ab"
oGet := Get():new(02,21,{|xValue| IIf( xValue==NIL, dFrom, dFrom := xValue ) },"dFrom")
oGet:Display()
AAdd(GetList,oGet)


@ 03,00 SAY "Bis"
oGet := Get():new(03,21,{|xValue| IIf( xValue==NIL, dUntil, dUntil := xValue ) },"dUntil")
oGet:PostBlock := {|| dUntil >= dFrom }
oGet:Display()
AAdd(GetList,oGet)

@ 04,00 SAY "Vertretung"
oGet := Get():new(04,21,{|xValue| IIf( xValue==NIL, nVertret, nVertret := xValue ) },"nVertret")
oGet:colorSpec := c_four_list
oGet:PostBlock := {|| If(nVertret == 1,lRedirect := .F.,),.T. }
AAdd(GetList,oGet)
ATail(GetList):Control := _ListBox_(ATail(Getlist):row,ATail(Getlist):col,15,49,nVertret,HGetValues(hBuyer),,,,,,.T.,.F. )
ATail(GetList):Control:colorSpec := c_one_list
ATail(GetList):reader := { | a,b,c,d | GuiReader(a,b,c,d ) }
ATail(GetList):Control:Display()

@ 05,00 SAY "Emails weiterleiten?"
oGet := Get():new(05,21,{|xValue| IIf( xValue==NIL, lRedirect, lRedirect := xValue ) },"lRedirect")
oGet:PreBlock := {|| nVertret != 1 }
oGet:Picture := "Y"
oGet:Display()
AAdd(GetList,oGet)

READ

If LastKey() == 27
	Return
Endif

oReply:AutoReply := .T.
oReply:Enabled   := .T.
oReply:OnlySubject := .T. //do not return original message

oForward:Forward := .T.
oForward:Enabled := lRedirect
oForward:ForwardAs := DvRoutingEMail

If nVertret > 1
	buy->(dbGoto( HGetKeyAt(hBuyer,nVertret) ))
	oForward:ForwardTo := Trim(buy->Email)
Else
	oForward:ForwardTo := ""
Endif

//Setup conditions
/*CLS
FOR nX := 1 TO oReply:Conditions:Count()
   ? oReply:Conditions:Item(nX-1):Object,oReply:Conditions:Item(nX-1):Comparision,ValToPrg(oReply:Conditions:Item(nX-1):Value)
NEXT
Sinkey(0)*/
oReply:Conditions:RemoveAll()

oFilter := oReply:Conditions:Add()
oFilter:Object := 1 //date
oFilter:Comparision := DvItemIsGreater
oFilter:Value := dFrom-2 //zwei Tage abziehen da gr”áer und nicht gr”áer gleich
oFilter:Operator := DvFilterAnd

oFilter := oReply:Conditions:Add()
oFilter:Object := 2 //time
oFilter:Comparision := DvItemIsGreater
oFilter:Value := 17*60*60  //zeit wird in sekunden angegeben
oFilter:Operator := DvFilterAnd

oFilter := oReply:Conditions:Add()
oFilter:Object := 1
oFilter:Comparision := DvItemIsLess
oFilter:Value := dUntil+1
oFilter:Operator := DvFilterAnd

oFilter := oReply:Conditions:Add()
oFilter:Object := -2147438510 //Field_ExternalMessage
oFilter:Comparision := 0 //DvItemIsEqual
oFilter:Value := 1 //.T.
oFilter:Operator := DvFilterAnd

oForward:Conditions:RemoveAll()

oFilter := oForward:Conditions:Add()
oFilter:Object := 1
oFilter:Comparision := DvItemIsGreater
oFilter:Value := dFrom-2
oFilter:Operator := DvFilterAnd

oFilter := oForward:Conditions:Add()
oFilter:Object := 2 //time
oFilter:Comparision := DvItemIsGreater
oFilter:Value := 17*60*60  //zeit wird in sekunden angegeben
oFilter:Operator := DvFilterAnd

oFilter := oForward:Conditions:Add()
oFilter:Object := 1
oFilter:Comparision := DvItemIsLess
oFilter:Value := dUntil+1
oFilter:Operator := DvFilterAnd

oFilter := oForward:Conditions:Add()
oFilter:Object := -2147438510 //Field_ExternalMessage
oFilter:Comparision := 0 //DvItemIsEqual
oFilter:Value := 1 //.T.
oFilter:Operator := DvFilterAnd


oForward:Commit()
oReply:Commit()

oTemplate := NIL

/*lTemplate := .F.
If ! Empty(oReply:IncludeBefore)
	If .T. //should be replaced with try...catch
	oTemplate := oTemplates:ItemFromID(oTemplates:GetArchiveEntryByID(oReply:IncludeBefore):_ID,34) //looks complicated, but the only way I found to get the MailItem and not an ImessageItem2
	lTemplate := .T.
	Endif

Endif*/

//If ! lTemplate //Empty(oReply:IncludeBefore)
	lFound := .F.
	nX := 0

	Do While nX < oTemplates:MailItems:Count .AND. ! lFound
		oTemplate := oTemplates:MailItems:Item(nX)
		If oTemplate:Subject == TEMPLATE_NAME
			lFound := .T.
		Endif
		nX++
	Enddo

	If ! lFound
		oTemplate := oTemplates:NewItem(DvEMailItem)
		oTemplate:Subject := TEMPLATE_NAME
	Endif
//Endif

cPerson := ""
If nVertret > 1
	buy->(dbGoto( HGetKeyAt(hBuyer,nVertret) ))
	cPerson := buy->Buyer+CRLF
	If ! Empty(buy->Telefon)
		cPerson += "Tel.: +49-(0)7464-9865"+buy->Telefon+CRLF
	Endif
	cPerson += "Email: "+buy->Email
Endif


cText  := CRLF+"Vielen Dank für Ihre Nachricht."+CRLF+CRLF+"Ich bin "
If dFrom != dUntil
	//cText += "vom "+DToC(dFrom)+" bis einschließlich "+DToC(dUntil)
	cText += "bis einschließlich "+DToC(dUntil)
Else
	cText += "am "+DToC(dFrom)
Endif
cText += " nicht im Büro."
If nVertret > 1
	cText += " Bitte kontaktieren Sie während dieser Zeit"+CRLF+CRLF
	cText += cPerson
Endif
If lRedirect
   cText += CRLF+CRLF+"Ihre Emails werden weitergeleitet."
ELSE
   cText += HB_OemToAnsi(CRLF+CRLF+"Ich werde diese schnellst m”glichst nach meiner Rckkehr bearbeiten.")
Endif
cText += CRLF+CRLF+"Mit freundlichen Grüßen"+CRLF+Buy(TR_getini(28),.T.)+CRLF+CRLF
cText += "_______________________________________________________________________"+CRLF+CRLF
cText += "Thank you for your email."+CRLF+CRLF+"I am out of the office "
If dFrom != dUntil
	//cText += "from "+DToC(dFrom)+" until "+DToC(dUntil)
	cText += "until "+DToC(dUntil)
Else
	cText += "on "+DToC(dFrom)
Endif
cText += "."
If nVertret > 1
	cText += " During this time you can contact"+CRLF+CRLF
	cText += cPerson
Endif
If lRedirect
   cText += CRLF+CRLF+"Your emails will be redirected."
ELSE
   cText += CRLF+CRLF+"I will answer your mail as soon as possible on my return."
Endif
cText += CRLF+CRLF+"Best Regards"+CRLF+Buy(TR_getini(28),.T.)

oTemplate:BodyText:PlainText := t(cText)
oTemplate:BodyText:Charset :=  "windows-1252"
oTemplate:Save(NIL,DvMsgSelEMail)

ThreadSleep(10) //wait a little to let david commit


nX := 0

Do While nX < oTemplates:MailItems:Count .AND. ! lFound
	oTemplate := oTemplates:MailItems:Item(nX)
	If oTemplate:Subject == TEMPLATE_NAME
		lFound := .T.
	Endif
	nX++
Enddo

If ! lFound
	Tr_MsgBox("Autoreply konnte NICHT eingerichtet werden")
	Return
Endif



oReply:IncludeBefore := oTemplate:Fields:Item ("Filename"):Value+".001"
oReply:Commit()

Tr_MsgBox(t("Autoreply wurde eingerichtet und aktiviert"))