#define DV_ADDRESS_EMAIL  0     // DvAddressTypes.DvAddressEMail
#define DV_TEXT_PLAIN     1     // DvTextTypes.DvTextPlain
#define TEST_TAG          "[#EK-ATEST]"
#define AGENT_ADRESSE     "inga@engelking.de"

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
   {cMsgPath, "inga@engelking.de,kollege@engelking.de"}
Aufraeumen (Token wieder entfernen): dritter Parameter "ZURUECK".
Dritter Parameter "VBS" (Kontextaktion TEAMTALKVBS): protokolliert den von
David uebergebenen Pfad samt Dateien gleichen Namens und gibt ihn
unveraendert an david_teamtalk.vbs weiter - ohne Token.
Ausweichweg (falls der ChatManager nicht geht): dritter Parameter
"KOPIE:<Archivpfad>" kopiert die getaggte Mail in dieses Archiv, z. B. in
den Posteingang des Agenten - dort kann er den TeamTalk per WebAPI starten.

Ergebnis: Meldung am Bildschirm und %TEMP%\david_teamtalk_test.log.
Danach in David pruefen:
  - Gibt es an der Mail einen TeamTalk mit Agent (und ggf. Kollegen)?
  - Steht [#EK-ATEST] bei den Teilnehmern im Betreff?
  - Erscheint die Mail im Postfach des Agenten (probe.py --kommentare)?
**/

PROC RUN_TEST_DAVID_TEAMTALK(cMsgPath, cTeilnehmer, cModus)
	LOCAL oAccount, cArchive, oArchive, oMsg, oItem
	LOCAL oManager, oAddresses, oThread, oErr, cAdr
	LOCAL oApi, oApiAccount
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
	TtPfadInfo(cMsgPath, oMsg, aLog)

	// Modus VBS: den von David uebergebenen Pfad unveraendert an
	// david_teamtalk.vbs geben (ohne Token) und dessen Ausgabe protokollieren.
	IF Upper(AllTrim(hb_CStr(cModus))) == "VBS"
		TtVbs(cMsgPath, cTeilnehmer, aLog)
		TtAusgabe(aLog)
		RETURN
	ENDIF

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

	// Ausweichweg testen: getaggte Mail in ein Archiv kopieren, das der
	// Agent per WebAPI sieht (z. B. sein Posteingang oder ein Sammelarchiv
	// "Anliegen"). Dort kann er den TeamTalk selbst starten.
	IF Upper(Left(AllTrim(hb_CStr(cModus)), 6)) == "KOPIE:"
		TtKopie(oAccount, oItem, AllTrim(SubStr(AllTrim(cModus), 7)), aLog)
		TtAusgabe(aLog)
		RETURN
	ENDIF

	// 2) ChatManager erzeugen. Der erste Lauf scheiterte hier mit E_FAIL
	//    (TOLEAUTO:NEW). Deshalb zuerst Versionen protokollieren und dann
	//    mehrere Wege versuchen - u. a. wie im Doku-Beispiel erst die
	//    David-API anmelden und deren Account fuer StartChat nehmen.
	TtVersionen(oAccount, aLog)
	oManager := TtManager("DVOBJAPILib.ChatManager", aLog)
	IF oManager == NIL
		oManager := TtManager("DVOBJAPILib.ChatManager.1", aLog)
	ENDIF
	IF oManager == NIL
		BEGIN SEQUENCE WITH {|e| Break(e)}
			oApi := CreateObject("DVOBJAPILib.DvISEAPI")
			oApiAccount := oApi:GetAccount()
			AAdd(aLog, "2 API:     DvISEAPI:GetAccount ok")
		RECOVER USING oErr
			AAdd(aLog, "2 API:     DvISEAPI FEHLER " + TtFehler(oErr))
		END
		IF oApiAccount != NIL
			oManager := TtManager("DVOBJAPILib.ChatManager", aLog)
			IF oManager != NIL
				oAccount := oApiAccount
			ENDIF
		ENDIF
	ENDIF
	IF oManager == NIL
		AAdd(aLog, "")
		AAdd(aLog, "ChatManager nicht verfuegbar - TeamTalk per COM geht so nicht.")
		AAdd(aLog, "Ausweichweg testen: dritter Parameter KOPIE:<Archivpfad>")
		TtAusgabe(aLog)
		RETURN
	ENDIF

	// Teilnehmerliste
	oAddresses := NIL
	BEGIN SEQUENCE WITH {|e| Break(e)}
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
		FOR nX := 0 TO oArchive:MailItems:Count - 1
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

// Was genau kommt aus dem David-Kontext an? Pfad, Datei, Endung, _ID.
STATIC PROCEDURE TtPfadInfo(cMsgPath, oMsg, aLog)
	LOCAL oErr, aDateien, aDatei, cStamm
	AAdd(aLog, "Pfad-Info: Datei vorhanden " + IF(File(cMsgPath), "ja", "nein") + ;
		", Endung " + SubStr(cMsgPath, RAT(".", cMsgPath)))
	BEGIN SEQUENCE WITH {|e| Break(e)}
		AAdd(aLog, "           _ID " + hb_CStr(oMsg:_ID) + ", Typ " + hb_CStr(oMsg:Type))
	RECOVER USING oErr
		AAdd(aLog, "           _ID nicht lesbar " + TtFehler(oErr))
	END
	// Alle Dateien mit gleichem Stamm (I44DEBA0.*) auflisten
	cStamm := SubStr(cMsgPath, 1, RAT(".", cMsgPath))
	aDateien := Directory(cStamm + "*")
	FOR EACH aDatei IN aDateien
		AAdd(aLog, "           Datei " + aDatei[1] + " (" + hb_ntos(aDatei[2]) + " Bytes)")
	NEXT
RETURN

STATIC PROCEDURE TtVbs(cMsgPath, cTeilnehmer, aLog)
	LOCAL cVbs := Trim(tr_getini(1)) + "\run\david_teamtalk.vbs"
	LOCAL cCmd, cOut := "", cErr := "", nRet, oErr
	IF ! File(cVbs)
		AAdd(aLog, "VBS:       " + cVbs + " nicht gefunden")
		RETURN
	ENDIF
	cCmd := 'C:\Windows\SysWOW64\cscript.exe //nologo "' + cVbs + '" /mail:"' + cMsgPath + '" /an:"' + cTeilnehmer + '" /text:"Test TeamTalk [#EK-ATEST]. Bitte ignorieren."'
	AAdd(aLog, "VBS:       " + cCmd)
	BEGIN SEQUENCE WITH {|e| Break(e)}
		nRet := hb_processRun(cCmd, , @cOut, @cErr)
		AAdd(aLog, "VBS:       Exitcode " + hb_ntos(nRet))
		AAdd(aLog, cOut)
		IF ! Empty(cErr)
			AAdd(aLog, "VBS stderr: " + cErr)
		ENDIF
	RECOVER USING oErr
		AAdd(aLog, "VBS:       FEHLER " + TtFehler(oErr))
	END
RETURN

STATIC PROCEDURE TtVersionen(oAccount, aLog)
	LOCAL oApi, oErr
	BEGIN SEQUENCE WITH {|e| Break(e)}
		AAdd(aLog, "Server:    " + hb_CStr(oAccount:ServerVersion))
	RECOVER USING oErr
		AAdd(aLog, "Server:    Version nicht lesbar " + TtFehler(oErr))
	END
	BEGIN SEQUENCE WITH {|e| Break(e)}
		oApi := CreateObject("DVOBJAPILib.DvISEAPI")
		AAdd(aLog, "DvApi32:   " + hb_CStr(oApi:Majorversion) + "." + hb_CStr(oApi:Minorversion))
	RECOVER USING oErr
		AAdd(aLog, "DvApi32:   Version nicht lesbar " + TtFehler(oErr))
	END
RETURN

STATIC FUNCTION TtManager(cProgId, aLog)
	LOCAL oManager := NIL, oErr
	BEGIN SEQUENCE WITH {|e| Break(e)}
		oManager := CreateObject(cProgId)
		AAdd(aLog, "2 Manager: ok mit " + cProgId)
	RECOVER USING oErr
		AAdd(aLog, "2 Manager: FEHLER mit " + cProgId + " " + TtFehler(oErr))
		oManager := NIL
	END
RETURN oManager

STATIC PROCEDURE TtKopie(oAccount, oItem, cZiel, aLog)
	LOCAL oZiel, oErr
	IF oItem == NIL .OR. Empty(cZiel)
		AAdd(aLog, "Kopie:     kein MailItem oder kein Zielarchiv")
		RETURN
	ENDIF
	BEGIN SEQUENCE WITH {|e| Break(e)}
		oZiel := oAccount:GetArchive(cZiel)
		AAdd(aLog, "Kopie:     Zielarchiv " + hb_CStr(oZiel:DisplayName))
		oItem:Copy(oZiel)
		AAdd(aLog, "Kopie:     ok - jetzt probe.py im Agenten-Container pruefen")
	RECOVER USING oErr
		AAdd(aLog, "Kopie:     FEHLER " + TtFehler(oErr))
	END
RETURN

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
	LOCAL cText
	IF ValType(oErr) != "O"
		RETURN hb_CStr(oErr)
	ENDIF
	cText := hb_CStr(oErr:Description) + " / " + hb_CStr(oErr:Operation) + ;
		" (" + hb_CStr(oErr:SubCode) + "/" + hb_CStr(oErr:OsCode) + ")"
	IF hb_IsFunction("WIN_OLEERRORTEXT")
		cText += " " + hb_CStr(Eval(&("{|| win_oleErrorText()}")))
	ENDIF
RETURN cText

STATIC PROCEDURE TtAusgabe(aLog)
	LOCAL cText := "", cZeile
	FOR EACH cZeile IN aLog
		cText += cZeile + Chr(13) + Chr(10)
	NEXT
	hb_MemoWrit(GetEnv("temp") + "\david_teamtalk_test.log", cText)
	Wapi_MessageBox(, cText, "TeamTalk-Test", 0)
RETURN
