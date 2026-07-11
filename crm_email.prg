#include 'hbclass.ch'
#include 'inkey.ch'
#include 'set.ch'

#define HB_CALL_FUNC_DIRECT   1

// Result of the "create new" webview flow (set by the crmPickerSelect callback)
STATIC gcCrmNewRef  := ""
STATIC gcCrmNewType := ""
STATIC gpCrmWebview

/**
CRM Email Anbindung
Holt Leads/Opportunities �ber die api-crm-picker Edge Function aus dem
Lovable CRM (engelking-crm / Supabase rxaltcsbhcxlczjjczxs) und erlaubt die
Auswahl in einer durchsuchbaren Liste. Die gew�hlte Ref-Nr wird als
[#EK-L<ref>] bzw. [#EK-O<ref>] in den Betreff geschrieben und die E-Mail an
das CRM weitergeleitet (receive-email matcht �ber diesen Token).
**/

PROC RUN_CRM_EMAIL(cMsgPath)
	LOCAL oAccount, cArchive, oArchive, oMsg
	LOCAL cID := "", cObjectType := "", nX, nType := 1
	LOCAL oApi, hSel

	oAccount := DV_GetMailAccount()
	cArchive := SubStr(cMsgPath,1,RAT("\",cMsgPath)-1)
	oArchive := oAccount:GetArchive(cArchive)
	oMsg := oArchive:GetArchiveEntryById(cMsgPath)

	IF oMsg:Type != 2
		Tr_MsgBox("Nur Emails k�nnen an das CRM weitergeleitet werden.")
		RETURN
	ENDIF

	CRM_Picker_Setup()

	Head("Lead/Opportunity ausw�hlen")

	@ 01,00,05,20 GET nType LISTBOX {"Lead","Opportunity"} STATE {||
		IF nType == 1
			cObjectType := "Lead"
		ELSEIF nType == 2
			cObjectType := "Opportunity"
		ENDIF
	}
	READ

	IF LastKey() == 27
		RETURN
	ENDIF

	cObjectType := IF(nType == 1,"Lead","Opportunity")

	// Fetch Leads/Opportunities from the CRM API and let the user pick one
	oApi := CrmPickerApi():New()
	hSel := oApi:ChooseObject(IF(nType == 1,"lead","opportunity"))

	IF hSel == NIL
		Alert("Die Auswahl wurde abgebrochen. Die E-Mail wurde nicht weitergeleitet.")
		RETURN
	ENDIF

	// "Neu anlegen" chosen: open the CRM web app in a webview to create the
	// record, then receive its new ref number back from the web app.
	IF ValType(hSel) == "H" .AND. HHasKey(hSel,"__new__")
		hSel := ShowCrmCreate(IF(nType == 1,"lead","opportunity"),;
			CrmMailField(oMsg,"SRFrom"), CrmMailField(oMsg,"Subject"))
		IF hSel == NIL
			Alert("Es wurde kein neuer Eintrag angelegt. Die E-Mail wurde nicht weitergeleitet.")
			RETURN
		ENDIF
	ENDIF

	cID := LTrim(Str(Int(hSel["ref"])))

	// Validate selected values
	IF Empty(cID) .OR. Empty(cObjectType)
		Tr_MsgBox("Ung�ltige Auswahl. Bitte versuchen Sie es erneut.")
		RETURN
	ENDIF

	// Forward email to CRM with selected ID and Object Type
	//this is a but cumbersome but otherwise we do not have the MailItem-Interface to call the Forward() method
	FOR nX := 0 TO oArchive:MailItems:Count
		IF oArchive:MailItems:Item(nX):_ID == oMsg:_ID
			BEGIN SEQUENCE
				oMsg := oArchive:MailItems:Item(nX)
				oMsg:Subject := oMsg:Subject + " [#EK-" + IF(nType == 1,"L","O") + cID + "]"
				oMsg:Save()

				oMsg:Recipients:Clear()
				oMsg:Recipients:Add("crm@iokronuere.resend.app")
				oMsg:Forward(1,0)

				Tr_MsgBox({"Email erfolgreich an das CRM weitergeleitet." , "ID: " + cID ,"Object Type: " + cObjectType})
			RECOVER
				Tr_MsgBox("Fehler beim Weiterleiten der E-Mail aus dem CRM.")
			END
			EXIT
		ENDIF
	NEXT

RETURN

FUNCTION CRM_Picker_Setup()
	//setup config values and their defaults.
	//NOTE: the base URL is hardcoded in CrmPickerApi:New() so a mis-set config
	//value cannot break the call; NEXUSCRM (the Bearer token = TRADER_API_KEY)
	//is shared with the NexusCRM connector and is registered there as well.
	GetValue("NEXUSCRM","","API Key f�r das CRM (Bearer Token / TRADER_API_KEY)")
RETURN NIL

STATIC FUNCTION CrmStr(x)
	//null-safe conversion of a decoded JSON value to a (utf8->ansi) string
RETURN IF(ValType(x) == "C", hb_utf8tostr(x), "")

CLASS CrmPickerApi FROM RestApi
	METHOD New
	METHOD Execute
	METHOD List
	METHOD ChooseObject
	
	DATA cErrorText
ENDCLASS

METHOD New() CLASS CrmPickerApi
	// Base URL is hardcoded on purpose. IMPORTANT: RestApi:Execute prepends
	// ::cBaseUrl to the (relative) path it is given, so the base URL MUST end
	// with "/" and Execute() below must pass a RELATIVE path (see nocrm.prg).
	::cBaseUrl := "https://rxaltcsbhcxlczjjczxs.supabase.co/functions/v1/api-crm-picker/"
	::Super:New()
RETURN SELF

METHOD Execute(cMethod, cUrl, cData) CLASS CrmPickerApi
	LOCAL aHeader
	LOCAL cResponse := ""
	LOCAL nResponse := 0
	LOCAL xReturn
	LOCAL cFullUrl

	Default(@cMethod,"GET")
	Default(@cUrl,"")
	Default(@cData,"")

	//cUrl is RELATIVE (e.g. "leads?limit=200&offset=0"); the RestApi base
	//prepends ::cBaseUrl. cFullUrl is only used for error messages.
	cFullUrl := ::cBaseUrl + cUrl

	::cApiKeyName := "NEXUSCRM"

	aHeader := {;
		"Authorization: Bearer $APIKEY$",;
		"Content-Type: application/json",;
		"Accept: application/json";
	}

	cResponse := ::Super:Execute(cUrl, cMethod, cData, aHeader, .F., @nResponse)

	IF Empty(cResponse)
		::cErrorText := "Keine Antwort vom Server (HTTP " + LTrim(Str(nResponse)) + ") - " + cFullUrl
		RETURN NIL
	ENDIF

	xReturn := HB_JsonDecode(cResponse)

	//API-level error {"error": "..."}
	IF ValType(xReturn) == "H" .AND. HHasKey(xReturn,"error")
		::cErrorText := CrmStr(xReturn["error"]) + " (" + cFullUrl + ")"
		RETURN NIL
	ENDIF

	//Supabase gateway error {"code": "NOT_FOUND", "message": "..."}
	IF ValType(xReturn) == "H" .AND. HHasKey(xReturn,"message")
		::cErrorText := CrmStr(xReturn["message"]) + " (" + cFullUrl + ")"
		RETURN NIL
	ENDIF

	IF nResponse >= 400
		::cErrorText := "HTTP " + LTrim(Str(nResponse)) + ": " + cResponse + " (" + cFullUrl + ")"
		RETURN NIL
	ENDIF

RETURN xReturn

METHOD List(cEndpoint) CLASS CrmPickerApi
	//paginated fetch of all (bounded) leads/opportunities, newest ref first
	LOCAL aAll := {}, aPage
	LOCAL nOffset := 0, nLimit := 200, nMax := 1000

	DO WHILE nOffset < nMax
		aPage := ::Execute("GET", cEndpoint + "?limit=" + LTrim(Str(nLimit)) + "&offset=" + LTrim(Str(nOffset)))
		IF ValType(aPage) != "A"
			IF nOffset == 0
				RETURN NIL   //error on first page
			ENDIF
			EXIT
		ENDIF
		AEval(aPage,{|x| Aadd(aAll,x) })
		IF Len(aPage) < nLimit
			EXIT
		ENDIF
		nOffset += nLimit
	ENDDO

RETURN aAll

METHOD ChooseObject(cType) CLASS CrmPickerApi
	LOCAL aData, aItems := {}, aList := {}, hItem, oBrowse
	LOCAL cSearch := ""
	LOCAL cEndpoint := IF(cType == "lead","leads","opportunities")
	LOCAL hResult := NIL
	LOCAL cRef, cTitle, cCompany
	LOCAL nTop := 03, nLeft := 05, nBottom := MaxRow()-2, nRight := MaxCol()-5

	TxtBox("Daten werden aus dem CRM geladen")
	aData := ::List(cEndpoint)
	TxtClear()

	IF aData == NIL
		Tr_MsgBox("Fehler beim Laden aus dem CRM: " + ::cErrorText)
		RETURN NIL
	ENDIF

	//first entry: create a new record (handled by the caller via a webview)
	Aadd(aItems, {"__new__" => .T., "type" => cType})
	Aadd(aList,  "  » Neue(n) " + IF(cType == "lead","Lead","Opportunity") + " anlegen «")

	//remaining entries: existing records (ref is unique per type -> unique rows)
	FOR EACH hItem IN aData
		cRef     := IF(ValType(hItem["ref"]) == "N", LTrim(Str(Int(hItem["ref"]))), "?")
		cTitle   := CrmStr(hItem["title"])
		cCompany := CrmStr(hItem["company"])
		Aadd(aItems, hItem)
		Aadd(aList,  PadR("#" + cRef + "  " + cTitle, 42) + " " + cCompany)
	NEXT

	@ nTop,nLeft TO nBottom,nRight
	@ nTop,nLeft+1 SAY IF(cType == "lead"," Lead w�hlen / anlegen (tippen zum Suchen) "," Opportunity w�hlen / anlegen (tippen zum Suchen) ")

	oBrowse := TABrowse():New(nTop+1,nLeft+1,nBottom-1,nRight-1)
	oBrowse:lBox := .F.
	oBrowse:aData := aList
	oBrowse:HeadSep := ""
	oBrowse:NewColumn(NIL,{||
		IF Len(oBrowse:aData) == 0 .OR. ! Eval(oBrowse:ForBlock)
			RETURN Pad("Keine Eintr�ge ",oBrowse:nRight-oBrowse:nLeft+1)
		ENDIF
		RETURN Pad(oBrowse:CurrentDataRow(),oBrowse:nRight-oBrowse:nLeft+1)
	})
	oBrowse:AddKey(K_ESC,{|| .F. })
	oBrowse:AddKey(K_ENTER,{||
		LOCAL nX
		IF Len(oBrowse:aData) != 0 .AND. Eval(oBrowse:ForBlock)
			nX := AScan(aList,{|s| s == oBrowse:CurrentDataRow() })
			IF nX != 0
				hResult := aItems[nX]
				RETURN .F.
			ENDIF
		ENDIF
		RETURN .T.
	})
	oBrowse:ForBlock := {||
		IF Empty(cSearch)
			RETURN .T.
		ENDIF
		IF oBrowse:CurrentDataRow() == NIL
			RETURN .F.
		ENDIF
		RETURN cSearch $ Upper(oBrowse:CurrentDataRow())
	}
	oBrowse:bRestFun := {||
		LOCAL nKey := LastKey()
		LOCAL lUpdate := .F.
		IF nKey >= 32 .AND. nKey <= 255
			cSearch += Upper(Chr(nKey))
			lUpdate := .T.
		ELSEIF nKey == K_BS
			cSearch := Left(cSearch,Len(cSearch)-1)
			lUpdate := .T.
		ENDIF
		IF lUpdate
			oBrowse:goTop()
			oBrowse:forceStable()
			@ oBrowse:nBottom+1,oBrowse:nLeft+1 TO oBrowse:nBottom+1,oBrowse:nRight
			IF ! Empty(cSearch)
				@ oBrowse:nBottom+1,oBrowse:nLeft+1 SAY Left(cSearch,MaxCol()-4) COLOR HB_ColorIndex(SetColor(),1)
			ENDIF
		ENDIF
		RETURN .T.
	}
	oBrowse:EventLoop()
	oBrowse:Display()

RETURN hResult

//---------------------------------------------------------------------------
// "Create new" flow: open the CRM web app (/picker/create) in a modal webview.
// The web app creates the Lead/Opportunity as the logged-in user and calls
// window.crmPickerSelect(String(ref), type) which lands in crmPickerSelect()
// below. Returns a hash {"ref"=>nRef,"type"=>cType} or NIL if nothing created.
//---------------------------------------------------------------------------
STATIC FUNCTION ShowCrmCreate(cType, cEmail, cSubject)
	LOCAL nW, cUrl, nOldGt

	gcCrmNewRef  := ""
	gcCrmNewType := ""

	cUrl := "https://engelking-crm.lovable.app/picker/create?type=" + cType
	IF ! Empty(cEmail)
		cUrl += "&email=" + CrmUrlEncode(cEmail)
	ENDIF
	IF ! Empty(cSubject)
		cUrl += "&subject=" + CrmUrlEncode(cSubject)
	ENDIF

	//give the webview its own GT so it cannot disturb the text console,
	//and restore the previous GT afterwards
	nOldGt := hb_gtSelect()
	HB_gtSelect(HB_GTCREATE("gtcgi"))

	nW := hb_webview_create(.T.)
	IF nW == NIL
		HB_gtSelect(nOldGt)
		Tr_MsgBox("Das CRM-Fenster konnte nicht ge�ffnet werden.")
		RETURN NIL
	ENDIF
	gpCrmWebview := nW

	ErrorBlock({|oError|
		hb_webview_eval(nW, 'window.alert("' + ErrorMessage(oError) + '")')
		RETURN .T.
	})

	hb_webview_set_title(nW, "CRM - Neuen Eintrag anlegen")

	//JS -> Harbour callbacks (resolved by name via HB_CALL_FUNC_DIRECT)
	hb_webview_bind2(nW, "crmPickerSelect", HB_CALL_FUNC_DIRECT)
	hb_webview_bind2(nW, "crmPickerCancel", HB_CALL_FUNC_DIRECT)

	hb_webview_navigate(nW, cUrl)
	hb_webview_run(nW)          //modal: blocks until the window is closed/terminated
	hb_webview_destroy(nW)
	gpCrmWebview := NIL

	HB_gtSelect(nOldGt)

	IF Empty(gcCrmNewRef)
		RETURN NIL
	ENDIF

RETURN {"ref" => Val(gcCrmNewRef), "type" => gcCrmNewType}

// Called from the web app: window.crmPickerSelect(String(ref), type)
FUNCTION crmPickerSelect(cRef, cType)
	gcCrmNewRef  := IF(ValType(cRef)  == "C", cRef,  LTrim(Str(cRef)))
	gcCrmNewType := IF(ValType(cType) == "C", cType, "")
	CrmCloseWebview()   //stop the modal loop -> ShowCrmCreate continues
RETURN .T.

// Called from the web app when the user cancels/closes without creating
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
