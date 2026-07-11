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
	LOCAL cID := "", cObjectType := ""
	LOCAL hSel

	oAccount := DV_GetMailAccount()
	cArchive := SubStr(cMsgPath,1,RAT("\",cMsgPath)-1)
	oArchive := oAccount:GetArchive(cArchive)
	oMsg := oArchive:GetArchiveEntryById(cMsgPath)

	IF oMsg:Type != 2
		Wapi_MessageBox(,"Nur Emails k�nnen an das CRM weitergeleitet werden.","CRM Weiterleitung",0)
		RETURN
	ENDIF

	
	// Open the CRM web picker (select existing or create new) in a webview.
	// It returns the chosen record's ref number and type ("lead"/"opportunity").
	hSel := ShowCrmPicker(CrmMailField(oMsg,"SRFrom"), CrmMailField(oMsg,"Subject"))

	IF hSel == NIL
		Wapi_MessageBox("Die Auswahl wurde abgebrochen. Die E-Mail wurde nicht weitergeleitet.","Abbruch",0)
		RETURN
	ENDIF

	cID         := LTrim(Str(Int(hSel["ref"])))
	cObjectType := hSel["type"]

	IF Empty(cID)
		Wapi_MessageBox(,"Ung�ltige Auswahl. Bitte versuche es erneut.","Fehler",0)
		RETURN
	ENDIF

	// Upload the e-mail directly to the CRM, linked to the chosen record by its
	// ref. Trader sends the REAL sender + subject + body (no lossy resend forward).
	IF CrmUploadEmail(cObjectType, cID, oMsg, cMsgPath)
		Wapi_MessageBox(,"Die E-Mail wurde im CRM abgelegt (" + cObjectType + " " + cID + ").","CRM",0)
	ELSE
		Wapi_MessageBox(,"Fehler beim Ablegen der E-Mail im CRM.","Fehler",0)
	ENDIF

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
		CreateMainWindow()
		wapi_MessageBox(,"Das CRM-Fenster konnte nicht ge�ffnet werden.","Fehler",0)
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

//---------------------------------------------------------------------------
// Upload the e-mail directly to the CRM (api-email edge function), linked to
// the chosen Lead/Opportunity by its ref. Sends the REAL sender + subject +
// HTML body. Returns .T. on success.
//---------------------------------------------------------------------------
STATIC FUNCTION CrmUploadEmail(cType, cRef, oMsg, cMsgPath)
	LOCAL oApi := CrmEmailApi():New()
	LOCAL hData := {=>}
	LOCAL xResp

	hData["type"]       := Lower(cType)                              // "lead" / "opportunity"
	hData["ref"]        := Val(cRef)
	hData["from_email"] := CrmMailField(oMsg,"SRFrom")              // real sender
	hData["from_name"]  := hb_strToUtf8(CrmMailField(oMsg,"SRName"))
	hData["subject"]    := hb_strToUtf8(CrmMailField(oMsg,"Subject"))
	hData["body_html"]  := hb_strToUtf8(CrmMailField(oMsg,"HTML"))
	// stable dedup key: the same mail filed to the same ref twice -> no duplicate
	hData["message_id"] := "erp:" + cRef + ":" + cMsgPath

	xResp := oApi:Execute("POST", "", hData)

RETURN ! (xResp == NIL)

CLASS CrmEmailApi FROM RestApi
	METHOD New
	METHOD Execute

	DATA cErrorText
ENDCLASS

METHOD New() CLASS CrmEmailApi
	// Base URL ends with "/" — RestApi:Execute prepends ::cBaseUrl to the path.
	::cBaseUrl := "https://rxaltcsbhcxlczjjczxs.supabase.co/functions/v1/api-email/"
	::Super:New()
RETURN SELF

METHOD Execute(cMethod, cUrl, hData) CLASS CrmEmailApi
	LOCAL aHeader
	LOCAL cResponse := ""
	LOCAL nResponse := 0
	LOCAL xReturn

	Default(@cMethod,"POST")
	Default(@cUrl,"")

	::cApiKeyName := "NEXUSCRM"          // Bearer token = TRADER_API_KEY

	aHeader := {;
		"Authorization: Bearer $APIKEY$",;
		"Content-Type: application/json",;
		"Accept: application/json";
	}

	// Pass the HASH (not a pre-encoded string): RestApi:Execute JSON-encodes it
	// once for non-GET when lPostJson=.T. (see nocrm.prg). Pre-encoding here would
	// double-encode it into a JSON string literal, so the server would receive a
	// string with no fields ("type/ref required"). cUrl is RELATIVE; the RestApi
	// base prepends ::cBaseUrl.
	cResponse := ::Super:Execute(cUrl, cMethod, hData, aHeader, .T., @nResponse)

	IF Empty(cResponse)
		::cErrorText := "Keine Antwort vom Server (HTTP " + LTrim(Str(nResponse)) + ")"
		RETURN NIL
	ENDIF

	xReturn := HB_JsonDecode(cResponse)

	IF ValType(xReturn) == "H" .AND. HHasKey(xReturn,"error")
		::cErrorText := IF(ValType(xReturn["error"]) == "C", hb_utf8tostr(xReturn["error"]), "Fehler")
		RETURN NIL
	ENDIF

	IF nResponse >= 400
		::cErrorText := "HTTP " + LTrim(Str(nResponse)) + ": " + cResponse
		RETURN NIL
	ENDIF

RETURN xReturn
