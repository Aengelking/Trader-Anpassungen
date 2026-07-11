#include 'hbclass.ch'
#include 'inkey.ch'
#include 'set.ch'

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
	//setup config values and their defaults
	GetValue("CRM_PICKER_URL","https://rxaltcsbhcxlczjjczxs.supabase.co/functions/v1/api-crm-picker","URL der CRM Picker API (api-crm-picker)")
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
	::cBaseUrl := GetValue("CRM_PICKER_URL","https://rxaltcsbhcxlczjjczxs.supabase.co/functions/v1/api-crm-picker")
	::Super:New()
RETURN SELF

METHOD Execute(cMethod, cUrl, cData) CLASS CrmPickerApi
	LOCAL aHeader
	LOCAL cResponse := ""
	LOCAL nResponse := 0
	LOCAL xReturn

	Default(@cMethod,"GET")
	Default(@cUrl,"")
	Default(@cData,"")

	aHeader := {;
		"Authorization: Bearer " + GetValue("NEXUSCRM"),;
		"Content-Type: application/json",;
		"Accept: application/json";
	}

	cResponse := ::Super:Execute(::cBaseUrl + IF(Empty(cUrl),"","/"+cUrl), cMethod, cData, aHeader, .F., @nResponse)

	IF Empty(cResponse)
		::cErrorText := "Keine Antwort vom Server (HTTP " + LTrim(Str(nResponse)) + ")"
		RETURN NIL
	ENDIF

	xReturn := HB_JsonDecode(cResponse)

	IF ValType(xReturn) == "H" .AND. HHasKey(xReturn,"error")
		::cErrorText := xReturn["error"]
		RETURN NIL
	ENDIF

	IF nResponse >= 400
		::cErrorText := "HTTP " + LTrim(Str(nResponse)) + ": " + cResponse
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
	LOCAL aData, aList := {}, hItem, oBrowse
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
	IF Len(aData) == 0
		Tr_MsgBox("Keine Eintr�ge gefunden.")
		RETURN NIL
	ENDIF

	//build display strings (ref is unique per type -> unique rows)
	FOR EACH hItem IN aData
		cRef     := IF(ValType(hItem["ref"]) == "N", LTrim(Str(Int(hItem["ref"]))), "?")
		cTitle   := CrmStr(hItem["title"])
		cCompany := CrmStr(hItem["company"])
		Aadd(aList, PadR("#" + cRef + "  " + cTitle, 42) + " " + cCompany)
	NEXT

	@ nTop,nLeft TO nBottom,nRight
	@ nTop,nLeft+1 SAY IF(cType == "lead"," Lead w�hlen (tippen zum Suchen) "," Opportunity w�hlen (tippen zum Suchen) ")

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
				hResult := aData[nX]
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
