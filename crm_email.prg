#include 'hbclass.ch'
#include 'inkey.ch'
#include 'set.ch'

#define HB_CALL_FUNC_DIRECT   1

// Result of the CRM web picker (set by the crmPickerSelect callback)
STATIC gcCrmNewRef  := ""
STATIC gcCrmNewType := ""
STATIC gpCrmWebview

/**
CRM Email Anbindung
�ffnet den CRM-Picker (engelking-crm.lovable.app/picker) in einem Webview.
Der Benutzer w�hlt einen bestehenden Lead / eine Opportunity aus oder legt
einen neuen Eintrag an; die gew�hlte Ref-Nr wird als [#EK-L<ref>] bzw.
[#EK-O<ref>] in den Betreff geschrieben und die E-Mail an das CRM
weitergeleitet (receive-email matcht �ber diesen Token).
**/

PROC RUN_CRM_EMAIL(cMsgPath)
	LOCAL oAccount, cArchive, oArchive, oMsg
	LOCAL cID := "", cObjectType := "", cTypeChar, nX
	LOCAL hSel

	oAccount := DV_GetMailAccount()
	cArchive := SubStr(cMsgPath,1,RAT("\",cMsgPath)-1)
	oArchive := oAccount:GetArchive(cArchive)
	oMsg := oArchive:GetArchiveEntryById(cMsgPath)

	IF oMsg:Type != 2
		Tr_MsgBox("Nur Emails k�nnen an das CRM weitergeleitet werden.")
		RETURN
	ENDIF

	// Open the CRM web picker (select existing or create new) in a webview.
	// It returns the chosen record's ref number and type ("lead"/"opportunity").
	hSel := ShowCrmPicker(CrmMailField(oMsg,"SRFrom"), CrmMailField(oMsg,"Subject"))

	IF hSel == NIL
		Tr_MsgBox("Die Auswahl wurde abgebrochen. Die E-Mail wurde nicht weitergeleitet.")
		RETURN
	ENDIF

	cID         := LTrim(Str(Int(hSel["ref"])))
	cObjectType := hSel["type"]
	cTypeChar   := IF(Lower(cObjectType) == "lead", "L", "O")

	IF Empty(cID)
		Tr_MsgBox("Ung�ltige Auswahl. Bitte versuchen Sie es erneut.")
		RETURN
	ENDIF

	// Forward email to CRM with the selected ref (matched by receive-email via the token)
	//this is a bit cumbersome but otherwise we do not have the MailItem-Interface to call the Forward() method
	FOR nX := 0 TO oArchive:MailItems:Count
		IF oArchive:MailItems:Item(nX):_ID == oMsg:_ID
			BEGIN SEQUENCE
				oMsg := oArchive:MailItems:Item(nX)
				oMsg:Subject := oMsg:Subject + " [#EK-" + cTypeChar + cID + "]"
				oMsg:Save()

				oMsg:Recipients:Clear()
				oMsg:Recipients:Add("crm@iokronuere.resend.app")
				oMsg:Forward(1,0)

				Tr_MsgBox({"Email erfolgreich an das CRM weitergeleitet." , "ID: " + cID , "Typ: " + cObjectType})
			RECOVER
				Tr_MsgBox("Fehler beim Weiterleiten der E-Mail aus dem CRM.")
			END
			EXIT
		ENDIF
	NEXT

RETURN

//---------------------------------------------------------------------------
// Open the CRM web picker (/picker) in a modal webview. The user selects an
// existing Lead/Opportunity or creates a new one; the web app calls
// window.crmPickerSelect(String(ref), type), captured by crmPickerSelect().
// Returns a hash {"ref"=>nRef,"type"=>cType} or NIL if cancelled.
//---------------------------------------------------------------------------
STATIC FUNCTION ShowCrmPicker(cEmail, cSubject)
	LOCAL nW, cUrl

	gcCrmNewRef  := ""
	gcCrmNewType := ""

	cUrl := "https://engelking-crm.lovable.app/picker?"
	IF ! Empty(cEmail)
		cUrl += "email=" + CrmUrlEncode(cEmail) + "&"
	ENDIF
	IF ! Empty(cSubject)
		cUrl += "subject=" + CrmUrlEncode(cSubject)
	ENDIF

	nW := hb_webview_create(.T.)
	IF nW == NIL
		Tr_MsgBox("Das CRM-Fenster konnte nicht ge�ffnet werden.")
		RETURN NIL
	ENDIF
	TxtBox("CRM-Auswahl im neuen Fenster. Warte bis das Fenster geschlossen wird.")
	gpCrmWebview := nW

	ErrorBlock({|oError|
		hb_webview_eval(nW, 'window.alert("' + ErrorMessage(oError) + '")')
		RETURN .T.
	})

	hb_webview_set_title(nW, "CRM - Lead/Opportunity ausw�hlen")

	//JS -> Harbour callbacks (resolved by name via HB_CALL_FUNC_DIRECT)
	hb_webview_bind2(nW, "crmPickerSelect", HB_CALL_FUNC_DIRECT)
	hb_webview_bind2(nW, "crmPickerCancel", HB_CALL_FUNC_DIRECT)

	hb_webview_navigate(nW, cUrl)
	hb_webview_run(nW)          //modal: blocks until the window is closed/terminated

	hb_webview_destroy(nW)
	gpCrmWebview := NIL
	TxtClear()

	IF Empty(gcCrmNewRef)
		RETURN NIL
	ENDIF

RETURN {"ref" => Val(gcCrmNewRef), "type" => gcCrmNewType}

// Called from the web app: window.crmPickerSelect(String(ref), type)
FUNCTION crmPickerSelect(cRef, cType)
	gcCrmNewRef  := IF(ValType(cRef)  == "C", cRef,  LTrim(Str(cRef)))
	gcCrmNewType := IF(ValType(cType) == "C", cType, "")

	CrmCloseWebview()   //stop the modal loop -> ShowCrmPicker continues
RETURN .T.

// Called from the web app when the user cancels/closes without choosing
FUNCTION crmPickerCancel()
	gcCrmNewRef  := ""
	gcCrmNewType := ""
	CrmCloseWebview()
RETURN .F.

// Terminate the modal webview loop if the runtime provides the function;
// otherwise we rely on the web app's window.close().
STATIC FUNCTION CrmCloseWebview()
	IF gpCrmWebview != NIL .AND. hb_IsFunction("HB_WEBVIEW_TERMINATE")
		hb_webview_terminate(gpCrmWebview)
	ENDIF
RETURN NIL

// UTF-8 aware percent-encoding for query parameters
STATIC FUNCTION CrmUrlEncode(cStr)
	LOCAL cOut := "", nI, cCh

	IF ValType(cStr) != "C"
		RETURN ""
	ENDIF

	cStr := hb_strToUtf8(cStr)
	FOR nI := 1 TO Len(cStr)
		cCh := SubStr(cStr, nI, 1)
		IF (cCh >= "A" .AND. cCh <= "Z") .OR. (cCh >= "a" .AND. cCh <= "z") .OR. ;
		   (cCh >= "0" .AND. cCh <= "9") .OR. cCh $ "-_.~"
			cOut += cCh
		ELSE
			cOut += "%" + PadL(Upper(hb_NumToHex(Asc(cCh))), 2, "0")
		ENDIF
	NEXT

RETURN cOut

// Safe read of an e-mail field (returns "" if the field is missing)
STATIC FUNCTION CrmMailField(oMsg, cField)
	LOCAL xVal := ""
	LOCAL bOld := ErrorBlock({|e| Break(e) })

	BEGIN SEQUENCE
		xVal := oMsg:Fields(cField):Value
	RECOVER
		xVal := ""
	END SEQUENCE

	ErrorBlock(bOld)

	IF ValType(xVal) != "C"
		xVal := ""
	ENDIF

RETURN AllTrim(xVal)
