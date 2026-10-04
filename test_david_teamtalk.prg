#define DV_ADDRESS_EMAIL  0     // DvAddressTypes.DvAddressEMail
#define DV_TEXT_PLAIN     1     // DvTextTypes.DvTextPlain
#define TEST_TAG          "[#EK-ATEST]"
#define AGENT_ADRESSE     "anliegen@engelking.de"

/**
Test: Kann eine David-Aktion an einer Mail einen TeamTalk starten?

Fuer "Anliegen eroeffnen" (wie die CRM-Weiterleitung in crm_email.prg, aber
fuer Kundenanliegen) soll die Rechtsklick-Aktion in einem Schritt
  1. den Token an den Betreff des ORIGINALS haengen und
  2. danach einen TeamTalk mit dem Anliegen-Agenten starten,
damit alle Teilnehmer den Betreff schon mit Token bekommen.

Laut DvAPI32-Doku startet IChatManager:StartChat(Account, Addresses, Topic)
mit einem Archiv-Eintrag als Topic einen "LiveComment" an diesem Eintrag -
der Vorlaeufer des TeamTalk. Ob das mit unserer David-Version einen echten
TeamTalk ergibt, prueft dieser Test an einer Testmail.

Aufruf wie die anderen Kontextaktionen (david_context.prg, "TEAMTALKTEST"):
   MBaseRun(Trim(tr_getini(1))+"\run\test_david_teamtalk",{cMsgPath})
Optional weitere Teilnehmer (Komma-getrennt) als zweiter Parameter, z. B.
   {cMsgPath, "anliegen@engelking.de,kollege@engelking.de"}
Aufraeumen (Token wieder entfernen): dritter Parameter "ZURUECK".

Ergebnis: Meldung am Bildschirm und %TEMP%\david_teamtalk_test.log.
Danach in David pruefen:
  - Gibt es an der Mail einen TeamTalk mit Agent (und ggf. Kollegen)?
  - Steht [#EK-ATEST] bei den Teilnehmern im Betreff?
  - Erscheint die Mail im Postfach des Agenten (probe.py --kommentare)?
**/

PROC RUN_TEST_DAVID_TEAMTALK(cMsgPath, cTeilnehmer, cModus)
	LOCAL oAccount, cArchive, oArchive, oMsg, oItem
	LOCAL oManager, oAddresses, oThread, oErr, cAdr
	LOCAL aLog := {}

	IF Empty(cTeilnehmer)
		cTeilnehmer := AGENT_ADRESSE
	ENDIF
	IF Empty(cMsgPath)
		Wapi_MessageBox(,"Bitte aus dem David-Kontextmenue an einer Testmail aufrufen.","TeamTalk-Test",0)
		RETURN
	ENDIF

	oAccount := DV_GetMailAccount()
	cArchive := SubStr(cMsgPath,1,RAT("\",cMsgPath)-1)
	oArchive := oAccount:GetArchive(cArchive)
	oMsg := oArchive:GetArchiveEntryById(cMsgPath)

	IF oMsg:Type != 2
		Wapi_MessageBox(,"Nur an E-Mails testen.","TeamTalk-Test",0)
		RETURN
	ENDIF

	AAdd(aLog, "Mail:      " + cMsgPath)
	AAdd(aLog, "Betreff:   " + oMsg:Subject)

	// 1) Token an den Betreff des Originals (wie crm_email.prg, ueber MailItems)
	oItem := TtMailItem(oArchive, oMsg, aLog)
	IF Upper(AllTrim(hb_CStr(cModus))) == "ZURUECK"
		IF oItem != NIL
			BEGIN SEQUENCE WITH {|e| Break(e)}
				oItem:Subject := AllTrim(StrTran(oItem:Subject, " " + TEST_TAG, ""))
				oItem:Save()
				AAdd(aLog, "Token entfernt: " + oItem:Subject)
			RECOVER USING oErr
				AAdd(aLog, "Token entfernen: FEHLER " + TtFehler(oErr))
			END
		ENDIF
		TtAusgabe(aLog)
		RETURN
	ENDIF
	IF oItem != NIL
		BEGIN SEQUENCE WITH {|e| Break(e)}
			IF ! ( TEST_TAG $ oItem:Subject )
				oItem:Subject := oItem:Subject + " " + TEST_TAG
				oItem:Save()
			ENDIF
			AAdd(aLog, "1 Token:   ok, Betreff jetzt: " + oItem:Subject)
		RECOVER USING oErr
			AAdd(aLog, "1 Token:   FEHLER " + TtFehler(oErr))
		END
	ENDIF

	// 2) Teilnehmerliste
	oAddresses := NIL
	BEGIN SEQUENCE WITH {|e| Break(e)}
		oManager := CreateObject("DVOBJAPILib.ChatManager")
		oAddresses := oAccount:CreateAddressList()
		FOR EACH cAdr IN hb_ATokens(cTeilnehmer, ",")
			cAdr := AllTrim(cAdr)
			IF ! Empty(cAdr)
				oAddresses:Add(cAdr, cAdr, DV_ADDRESS_EMAIL)
			ENDIF
		NEXT
		AAdd(aLog, "2 Liste:   ok, " + hb_ntos(oAddresses:Count) + " Teilnehmer (" + cTeilnehmer + ")")
	RECOVER USING oErr
		AAdd(aLog, "2 Liste:   FEHLER " + TtFehler(oErr))
		oAddresses := NIL
	END
	IF oAddresses == NIL
		TtAusgabe(aLog)
		RETURN
	ENDIF

	// 3) TeamTalk (LiveComment) an der Mail starten - erst mit dem
	//    MessageItem, sonst mit dem MailItem als Topic
	oThread := TtStart(oManager, oAccount, oAddresses, oMsg, "MessageItem", aLog)
	IF oThread == NIL .AND. oItem != NIL
		oThread := TtStart(oManager, oAccount, oAddresses, oItem, "MailItem", aLog)
	ENDIF
	IF oThread == NIL
		TtAusgabe(aLog)
		RETURN
	ENDIF

	// 4) Erste Nachricht senden und den Stream schliessen
	BEGIN SEQUENCE WITH {|e| Break(e)}
		AAdd(aLog, "4 Thread:  ID " + hb_CStr(oThread:ID) + ", LiveComment " + hb_CStr(oThread:InstantComment))
	RECOVER USING oErr
		AAdd(aLog, "4 Thread:  Eigenschaften nicht lesbar " + TtFehler(oErr))
	END
	BEGIN SEQUENCE WITH {|e| Break(e)}
		oThread:SendMessage("Test Anliegen eroeffnen: TeamTalk per COM gestartet " + TEST_TAG + ". Bitte ignorieren.", DV_TEXT_PLAIN)
		AAdd(aLog, "5 Nachr.:  ok")
	RECOVER USING oErr
		AAdd(aLog, "5 Nachr.:  FEHLER " + TtFehler(oErr))
	END
	BEGIN SEQUENCE WITH {|e| Break(e)}
		oThread:CloseThread()
	RECOVER USING oErr
		AAdd(aLog, "6 Close:   FEHLER " + TtFehler(oErr))
	END

	AAdd(aLog, "")
	AAdd(aLog, "Jetzt in David pruefen: TeamTalk an der Mail? Agent/Kollege dabei?")
	AAdd(aLog, "Betreff bei den Teilnehmern mit " + TEST_TAG + "?")
	AAdd(aLog, "Aufraeumen: dritter Parameter ZURUECK.")
	TtAusgabe(aLog)
RETURN

//---------------------------------------------------------------------------
// MailItem zur Mail (fuer Subject/Save), wie in crm_email.prg ueber _ID.
//---------------------------------------------------------------------------
STATIC FUNCTION TtMailItem(oArchive, oMsg, aLog)
	LOCAL nX, oErr, oItem := NIL
	BEGIN SEQUENCE WITH {|e| Break(e)}
		FOR nX := 0 TO oArchive:MailItems:Count
			IF oArchive:MailItems:Item(nX):_ID == oMsg:_ID
				oItem := oArchive:MailItems:Item(nX)
				EXIT
			ENDIF
		NEXT
	RECOVER USING oErr
		AAdd(aLog, "MailItem:  FEHLER " + TtFehler(oErr))
	END
	IF oItem == NIL
		AAdd(aLog, "MailItem:  nicht gefunden - Token wird nicht gesetzt")
	ENDIF
RETURN oItem

STATIC FUNCTION TtStart(oManager, oAccount, oAddresses, oTopic, cArt, aLog)
	LOCAL oThread, oErr
	BEGIN SEQUENCE WITH {|e| Break(e)}
		oThread := oManager:StartChat(oAccount, oAddresses, oTopic)
		AAdd(aLog, "3 Start:   ok mit " + cArt)
	RECOVER USING oErr
		AAdd(aLog, "3 Start:   FEHLER mit " + cArt + " " + TtFehler(oErr))
		oThread := NIL
	END
RETURN oThread

STATIC FUNCTION TtFehler(oErr)
	IF ValType(oErr) != "O"
		RETURN hb_CStr(oErr)
	ENDIF
RETURN hb_CStr(oErr:Description) + " / " + hb_CStr(oErr:Operation) + ;
	" (" + hb_CStr(oErr:SubCode) + "/" + hb_CStr(oErr:OsCode) + ")"

STATIC PROCEDURE TtAusgabe(aLog)
	LOCAL cText := "", cZeile
	FOR EACH cZeile IN aLog
		cText += cZeile + Chr(13) + Chr(10)
	NEXT
	hb_MemoWrit(GetEnv("temp") + "\david_teamtalk_test.log", cText)
	Wapi_MessageBox(, cText, "TeamTalk-Test", 0)
RETURN
