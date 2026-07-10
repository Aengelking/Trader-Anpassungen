#define HB_CALL_FUNC_DIRECT      1

// Thread-local static variables for CRM picker result
THREAD STATIC tcCrmPickerId := ""
THREAD STATIC tcCrmPickerObjectType := ""
THREAD STATIC tlCrmPickerConfirmed := .F.

// Main thread static variables
STATIC gcCrmPickerId := ""
STATIC gcCrmPickerObjectType := ""
STATIC glCrmPickerConfirmed := .F.
STATIC pCrmPickerMutex

PROC RUN_CRM_EMAIL(cMsgPath)
	LOCAL oAccount, cArchive, oArchive, oMsg
	LOCAL cID, cObjectType, nX

	oAccount := DV_GetMailAccount()
	cArchive := SubStr(cMsgPath,1,RAT("\",cMsgPath)-1)
	oArchive := oAccount:GetArchive(cArchive)
	oMsg := oArchive:GetArchiveEntryById(cMsgPath)
	IF oMsg:Type != 2
		Tr_MsgBox("Nur Emails kînnen an das CRM weitergeleitet werden.")
		RETURN
	ENDIF
	
	// Show CRM Picker webview dialog
	IF ! ShowCrmPicker()
		Alert("Die Auswahl wurde abgebrochen. Die E-Mail wurde nicht weitergeleitet.")
		// User cancelled the dialog
		RETURN
	ENDIF
	
	// Get selected values from static variables (set by thread)
	cID := gcCrmPickerId
	cObjectType := gcCrmPickerObjectType
	
	// Validate selected values
	IF Empty(cID) .OR. Empty(cObjectType)
		Tr_MsgBox("UngÅltige Auswahl. Bitte versuchen Sie es erneut.")
		RETURN
	ENDIF
	
	// Forward email to CRM with selected ID and Object Type
	//this is a but cumbersome but otherwise we do not have the MailItem-Interface to call the Forward() method
	FOR nX := 0 TO oArchive:MailItems:Count
		IF oArchive:MailItems:Item(nX):_ID == oMsg:_ID
			BEGIN SEQUENCE
				/*oMsg := oArchive:MailItems:Item(nX)
				oMsg:Subject := oMsg:Subject + " [#EK-LID" + cID + "][OBJ-TYPE:" + cObjectType + "]"
				oMsg:Save()
				
				oMsg:Recipients:Clear()
				oMsg:Recipients:Add("crm@iokronuere.resend.app")
				oMsg:Forward(1,0)*/
				
				Tr_MsgBox({"Email erfolgreich an das CRM weitergeleitet." , "ID: " + cID ,"Object Type: " + cObjectType})
			RECOVER
				Tr_MsgBox("Fehler beim Weiterleiten der E-Mail aus dem CRM.")
			END
			EXIT
		ENDIF
	NEXT

RETURN

FUNCTION ShowCrmPicker()
	LOCAL lResult := .F.

	LOCAL cHtmlPath
			LOCAL cError
			
			MEMVAR nW
			PUBLIC nW
	
	// Initialize result variables
	glCrmPickerConfirmed := .F.
	gcCrmPickerId := ""
	gcCrmPickerObjectType := ""
	
	// Initialize mutex if needed
	IF pCrmPickerMutex == NIL
		pCrmPickerMutex := hb_mutexCreate()
	ENDIF
	
	//BEGIN SEQUENCE
		// Run webview in separate thread to avoid blocking and ensure proper value passing
		//hb_threadStart({||
			
			
			// Avoid screen output issues from webview
			HB_gtSelect(HB_GTCREATE("gtcgi"))
			
			// Create modal webview window
			nW := hb_webview_create(.T.)
			IF nW == NIL
				hb_mutexLock(pCrmPickerMutex)
				glCrmPickerConfirmed := .F.
				hb_mutexUnlock(pCrmPickerMutex)
				RETURN .F.
			ENDIF
			
			ErrorBlock({|oError|
				LOCAL cError := ErrorMessage(oError)
				hb_webview_eval(nW, 'window.alert("' + cError + '")')
				RETURN .T.
			})
			
			// Load this program in thread context so binding functions are available
			LoadPrg(Path("run\crm_email.prg"))
			
			// Set window title and properties
			hb_webview_set_title(nW, "CRM Email Picker")
			
			// Construct path to picker HTML file
			//cHtmlPath := "file:///" + StrTran(Path("\www\CrmPicker\picker.html"), "\", "/")
			cHtmlPath := "https://id-preview--23061844-c6a3-42ea-a609-87742cf168fd.lovable.app/picker"
			
			// Bind Harbour functions for JavaScript callbacks
			hb_webview_bind2(nW, "crmPickerSelect", HB_CALL_FUNC_DIRECT)
			hb_webview_bind2(nW, "crmPickerCancel", HB_CALL_FUNC_DIRECT)
			
			// Navigate to picker HTML
			hb_webview_navigate(nW, cHtmlPath)
			
			// Run modal loop (blocking in this thread)
			hb_webview_run(nW)
			
			// Cleanup webview
			hb_webview_destroy(nW)
			
			RETURN .T.
		//})
			
		// Brief delay to allow thread to start
		inkey(0.5)
		
		// Lock and read result
		hb_mutexLock(pCrmPickerMutex)
		lResult := glCrmPickerConfirmed
		hb_mutexUnlock(pCrmPickerMutex)
		
	/*RECOVER
		lResult := .F.
	END SEQUENCE*/
	
	RETURN lResult
		

// These functions are called from JavaScript via hb_webview_bind2
// They run in the webview thread (thread-local variables)
FUNCTION crmPickerSelect(cID, cObjectType)
	// Store selected values (thread-local first)
	tcCrmPickerId := cID
	tcCrmPickerObjectType := cObjectType
	tlCrmPickerConfirmed := .T.
	
	// Copy to main thread static variables via mutex
	IF pCrmPickerMutex != NIL
		hb_mutexLock(pCrmPickerMutex)
		gcCrmPickerId := tcCrmPickerId
		gcCrmPickerObjectType := tcCrmPickerObjectType
		glCrmPickerConfirmed := .T.
		hb_mutexUnlock(pCrmPickerMutex)
		//hb_webview_destroy(nW)
	ENDIF
	
	RETURN .T.

FUNCTION crmPickerCancel()
	// Mark as cancelled (thread-local)
	tlCrmPickerConfirmed := .F.
	tcCrmPickerId := ""
	tcCrmPickerObjectType := ""
	
	// Update main thread via mutex
	IF pCrmPickerMutex != NIL
		hb_mutexLock(pCrmPickerMutex)
		glCrmPickerConfirmed := .F.
		gcCrmPickerId := ""
		gcCrmPickerObjectType := ""
		hb_mutexUnlock(pCrmPickerMutex)
	ENDIF
	
	RETURN .F.
