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
ï¿½ffnet den CRM-Picker (engelking-crm.lovable.app/picker) in einem Webview.
Der Benutzer wï¿½hlt einen bestehenden Lead / eine Opportunity aus oder legt
einen neuen Eintrag an; die gewï¿½hlte Ref-Nr wird als [#EK-L<ref>] bzw.
[#EK-O<ref>] in den Betreff geschrieben und die E-Mail an das CRM
weitergeleitet (receive-email matcht ï¿½ber diesen Token).
**/

PROC RUN_CRM_EMAIL(cMsgPath)
	LOCAL oAccount, cArchive, oArchive, oMsg
	LOCAL cID := "", cObjectType := "", cTypeChar, nX
	LOCAL hSel, oItem, cDraft

	oAccount := DV_GetMailAccount()
	cArchive := SubStr(cMsgPath,1,RAT("\",cMsgPath)-1)
	oArchive := oAccount:GetArchive(cArchive)
	oMsg := oArchive:GetArchiveEntryById(cMsgPath)

	IF oMsg:Type != 2
		Wapi_MessageBox(,"Nur Emails kï¿½nnen an das CRM weitergeleitet werden.","CRM Weiterleitung",0)
		RETURN
	ENDIF

	IF hb_regexMatch(".*\[#EK-(L|O)[0-9]{1,}.*", oMsg:Subject)
		Wapi_MessageBox(,"Die E-Mail wurde bereits an das CRM weitergeleitet.","CRM Weiterleitung",0)
		RETURN
	ENDIF

	
	// Formaterkennung: die Mail vorab als Entwurf ins CRM laden. Der Picker
	// bekommt nur die Entwurfs-ID (?draft=) und liest den Mailtext selbst, um
	// bekannte Lead-Formate (ITW-Download, ITW-Registrierung ...) zu erkennen
	// und den Lead-Dialog vorzubefuellen. Best-effort: schlaegt der Upload
	// fehl, oeffnet der Picker wie bisher ohne Vorbefuellung.
	cDraft := CrmUploadDraft(oMsg, cMsgPath)
	
	// Open the CRM web picker (select existing or create new) in a webview.
	// It returns the chosen record's ref number and type ("lead"/"opportunity").
	hSel := ShowCrmPicker(CrmMailField(oMsg,"SRFrom"), CrmMailField(oMsg,"Subject"),,,,,,, cDraft)

	IF hSel == NIL
		Wapi_MessageBox(,"Die Auswahl wurde abgebrochen. Die E-Mail wurde nicht weitergeleitet.","Abbruch",0)
		RETURN
	ENDIF

	cID         := LTrim(Str(Int(hSel["ref"])))
	cObjectType := hSel["type"]

	IF Empty(cID)
		Wapi_MessageBox(,"Ungï¿½ltige Auswahl. Bitte versuche es erneut.","Fehler",0)
		RETURN
	ENDIF

	// 1) Upload this e-mail directly to the CRM (real sender + subject + body),
	//    linked to the chosen record by its ref.
	IF ! CrmUploadEmail(cObjectType, cID, oMsg, cMsgPath, cDraft)
		Wapi_MessageBox(,"Fehler beim Ablegen der E-Mail im CRM.","Fehler",0)
		RETURN
	ENDIF

	// 2) Tag the ORIGINAL mail's subject with the CRM reference. A reply then
	//    carries [#EK-L/O<ref>] in its subject and is auto-BCC'd to the CRM, so
	//    receive-email files the reply under the same record. Best-effort: the
	//    e-mail is already stored, so a tagging error must not abort.
	//    (Needs the MailItem interface, hence the lookup by _ID.)
	cTypeChar := IF(Lower(cObjectType) == "lead", "L", "O")
	FOR nX := 0 TO oArchive:MailItems:Count
		IF oArchive:MailItems:Item(nX):_ID == oMsg:_ID
			BEGIN SEQUENCE
				oItem := oArchive:MailItems:Item(nX)
				IF ! ( "[#EK-" $ oItem:Subject )        // do not tag twice
					oItem:Subject := oItem:Subject + " [#EK-" + cTypeChar + cID + "]"
					oItem:Save()
				ENDIF
			RECOVER
				//non-fatal
			END
			EXIT
		ENDIF
	NEXT

	Wapi_MessageBox(,"Die E-Mail wurde im CRM abgelegt (" + cObjectType + " " + cID + ").","CRM",0)

RETURN

//---------------------------------------------------------------------------
// Open the CRM web picker (/picker) in a modal webview. The user selects an
// existing Lead/Opportunity or creates a new one; the web app calls
// window.crmPickerSelect(String(ref), type), captured by crmPickerSelect().
// Returns a hash {"ref"=>nRef,"type"=>cType} or NIL if cancelled.
//---------------------------------------------------------------------------
STATIC FUNCTION ShowCrmPicker(cEmail, cSubject, cOnly, cErpCustomer, cCompanyName, cValue, cQuote, cName, cDraft)
	LOCAL nW, cUrl

	gcCrmNewRef  := ""
	gcCrmNewType := ""

	cUrl := "https://engelking-crm.lovable.app/picker?"
	IF ! Empty(cEmail)
		cUrl += "email=" + CrmUrlEncode(cEmail) + "&"
	ENDIF
	// Ansprechpartner-Name (APP-288): der Picker matcht bevorzugt ueber die
	// email und faellt sonst auf den Namen zurueck bzw. legt neu an.
	IF ! Empty(cName)
		cUrl += "name=" + CrmUrlEncode(cName) + "&"
	ENDIF
	IF ! Empty(cSubject)
		cUrl += "subject=" + CrmUrlEncode(cSubject) + "&"
	ENDIF
	// Mail-Entwurf (David-Flow): der Picker liest daraus den Mailtext fuer die
	// Formaterkennung und befuellt den Lead-Dialog vor.
	IF ! Empty(cDraft)
		cUrl += "draft=" + CrmUrlEncode(cDraft) + "&"
	ENDIF
	// Restrict to a single record kind ("opportunity" / "lead"), e.g. quotes
	// can only be attached to opportunities.
	IF ! Empty(cOnly)
		cUrl += "only=" + CrmUrlEncode(cOnly) + "&"
	ENDIF
	// Firmenname als Fallback fï¿½r die Firmen-Auflï¿½sung / Vorauswahl bei Neuanlage.
	IF ! Empty(cCompanyName)
		cUrl += "company=" + CrmUrlEncode(cCompanyName) + "&"
	ENDIF
	// Angebotswert: dient als Vorbelegung des Werts bei einer neuen Opportunity.
	IF ! Empty(cValue)
		cUrl += "value=" + CrmUrlEncode(cValue) + "&"
	ENDIF
	// Angebotsnummer: ist sie gesetzt, speichert der Picker die Zuordnung
	// Angebot->Opportunity direkt beim Auswï¿½hlen/Anlegen (kein separater
	// Assign-Aufruf mehr nï¿½tig).
	IF ! Empty(cQuote)
		cUrl += "quote=" + CrmUrlEncode(cQuote) + "&"
	ENDIF
	// ERP-Kundennummer: die Auswahl wird auf die Firma dieses Kunden begrenzt
	// (nur Opportunities, die bereits der Firma zugeordnet sind).
	IF ! Empty(cErpCustomer)
		cUrl += "erp_customer=" + CrmUrlEncode(cErpCustomer)
	ENDIF

	nW := hb_webview_create(.T.)
	IF nW == NIL
		CreateMainWindow()
		wapi_MessageBox(,"Das CRM-Fenster konnte nicht geï¿½ffnet werden.","Fehler",0)
		RETURN NIL
	ENDIF
	TxtBox("CRM-Auswahl im neuen Fenster. Warte bis das Fenster geschlossen wird.")
	gpCrmWebview := nW

	/*ErrorBlock({|oError|
		hb_webview_eval(nW, 'window.alert("' + ErrorMessage(oError) + '")')
		RETURN .T.
	})*/

	hb_webview_set_title(nW, "CRM - Lead/Opportunity ausw„hlen")

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
STATIC FUNCTION CrmUploadEmail(cType, cRef, oMsg, cMsgPath, cDraft)
	LOCAL oApi := CrmEmailApi():New()
	LOCAL hData := {=>}
	LOCAL xResp

	hData["type"]       := Lower(cType)                              // "lead" / "opportunity"
	hData["ref"]        := Val(cRef)
	// stable dedup key: the same mail filed to the same ref twice -> no duplicate
	hData["message_id"] := "erp:" + cRef + ":" + cMsgPath

	// Liegt die Mail schon als Entwurf im CRM, reicht die Entwurfs-ID: der
	// Server uebernimmt Absender, Betreff und Body aus dem Entwurf.
	IF ! Empty(cDraft)
		hData["draft_id"] := cDraft
		xResp := oApi:Execute("POST", "", hData)
		IF xResp != NIL
			RETURN .T.
		ENDIF
		// Entwurf nicht (mehr) da -> wie bisher mit vollem Inhalt senden
		hb_HDel(hData, "draft_id")
	ENDIF

	hData["from_email"] := CrmMailField(oMsg,"SRFrom")              // real sender
	hData["from_name"]  := hb_strToUtf8(CrmMailField(oMsg,"SRName"))
	hData["subject"]    := hb_strToUtf8(CrmMailField(oMsg,"Subject"))
	hData["body_html"]  := hb_strToUtf8(CrmMailField(oMsg,"HTML"))

	xResp := oApi:Execute("POST", "", hData)

RETURN ! (xResp == NIL)

//---------------------------------------------------------------------------
// Mail als Entwurf ins CRM laden (api-email, draft=true), BEVOR der Picker
// oeffnet. Liefert die Entwurfs-ID oder "" (dann ohne Formaterkennung).
//---------------------------------------------------------------------------
STATIC FUNCTION CrmUploadDraft(oMsg, cMsgPath)
	LOCAL oApi := CrmEmailApi():New()
	LOCAL hData := {=>}
	LOCAL xResp
	LOCAL bOld
	LOCAL cResponse,nResponse

	hData["draft"]      := .T.
	hData["from_email"] := CrmMailField(oMsg,"SRFrom")
	hData["from_name"]  := hb_strToUtf8(CrmMailField(oMsg,"SRName"))
	hData["subject"]    := hb_strToUtf8(CrmMailField(oMsg,"Subject"))
	hData["body_html"]  := hb_strToUtf8(CrmMailField(oMsg,"HTML"))
	hData["message_id"] := "draft:" + cMsgPath

	// Ein Fehler hier darf den bisherigen Weg nicht blockieren.
	bOld := ErrorBlock({|e| Break(e) })
	BEGIN SEQUENCE
		xResp := oApi:Execute("POST", "", hData)		
	RECOVER
		xResp := NIL		
	END SEQUENCE
	ErrorBlock(bOld)

	IF ValType(xResp) == "H" .AND. HHasKey(xResp,"draft_id") .AND. ValType(xResp["draft_id"]) == "C"
		RETURN xResp["draft_id"]
	ENDIF

RETURN ""

CLASS CrmEmailApi FROM RestApi
	METHOD New
	METHOD Execute

	DATA cErrorText
ENDCLASS

METHOD New() CLASS CrmEmailApi
	// Base URL ends with "/" â€” RestApi:Execute prepends ::cBaseUrl to the path.
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

//===========================================================================
// Quote -> Opportunity anbindung (api-quote edge function)
//
// Aufruf aus den Hooks ï¿½ber LoadPrg(Path("run\crm_email")) + HB_ExecFromArray:
//   before_print_angebot -> CRM_QuoteAssign(nAngnr, cKunde)
//   after_print_angebot  -> CRM_QuoteReport(nAngnr, nValue, cText)
//
// Die Verknï¿½pfung Angebot<->Opportunity liegt ausschlieï¿½lich im CRM (quotes-
// Tabelle). before_print prï¿½ft, ob das Angebot schon zugeordnet ist; wenn
// nicht, wird der Opportunity-Picker geï¿½ffnet (Auswahl oder Neuanlage) und die
// Zuordnung im CRM gespeichert. after_print hï¿½ngt eine Text-Aktivitï¿½t an die
// Opportunity.
//===========================================================================

// Einheitliche Angebots-Nummer als quote_number (ohne Fï¿½hrende Nullen), damit
// assign / status / report immer denselben Schlï¿½ssel verwenden.
STATIC FUNCTION CrmQuoteNumber(nAngnr)
RETURN LTrim(Str(Int(nAngnr)))

//---------------------------------------------------------------------------
// before_print_angebot: stellt sicher, dass das Angebot einer Opportunity
// zugeordnet ist. Ist es bereits verknï¿½pft, passiert nichts (idempotent).
// Sonst ï¿½ffnet sich der CRM-Picker (nur Opportunities, Neuanlage erlaubt) und
// die Zuordnung wird im CRM gespeichert.
// Gibt .T. zurï¿½ck, wenn eine Zuordnung besteht (alt oder neu), sonst .F.
//---------------------------------------------------------------------------
// cErpNumber = ERP-Kundennummer als String (LTrim(Str(ku->Nummer))),
// cKundenName = ku->Name1. Beide dienen der Firmen-Zuordnung im CRM.
FUNCTION CRM_QuoteAssign(nAngnr, cErpNumber, cKundenName,nRef)
	LOCAL oApi := CrmQuoteApi():New()
	LOCAL cQuoteNo := CrmQuoteNumber(nAngnr)
	LOCAL hStatus, hSel
	LOCAL cType
	LOCAL aValues, nValue := 0
	LOCAL cSubject
	LOCAL cContactName := "", cContactEmail := ""

	Default(@cErpNumber,"")
	Default(@cKundenName,"")

	// 1) Schon zugeordnet? -> nichts zu tun
	hStatus := oApi:Status(cQuoteNo)
	IF ValType(hStatus) == "H" .AND. HHasKey(hStatus,"linked") .AND. hStatus["linked"]
      nRef := hStatus["opportunity"]["ref"]
		RETURN .T.
	ENDIF

	// 2) Wert des Angebots fï¿½r die Anzeige/Speicherung ermitteln
	BEGIN SEQUENCE
		aValues := EnquiryAddUp(nAngnr,.T.)
		IF ValType(aValues) == "A" .AND. Len(aValues) >= 2
			nValue := aValues[2]
		ENDIF
	RECOVER
		nValue := 0
	END SEQUENCE

	// 3) Opportunity auswï¿½hlen oder neu anlegen. Nur Opportunities und nur die,
	//    die bereits der Firma dieses Kunden zugeordnet sind (erp_customer).
	//    Die Angebotsnummer wird mitgegeben: der Picker speichert die Zuordnung
	//    Angebot->Opportunity direkt beim Auswï¿½hlen/Anlegen (kein Assign-Call).
	cSubject := "Angebot " + cQuoteNo
	// Ansprechpartner des Angebots aufloesen und an den Picker mitgeben, damit
	// das CRM den Kontakt vorbefuellen kann (APP-288).
	CrmAngebotContact(nAngnr, @cContactName, @cContactEmail)
	hSel := ShowCrmPicker(cContactEmail, cSubject, "opportunity", AllTrim(cErpNumber), AllTrim(cKundenName), ;
		IF(nValue > 0, LTrim(Str(nValue,18,2)), ""), cQuoteNo, cContactName)
	IF hSel == NIL
		RETURN .F.        // abgebrochen
	ENDIF

	cType := Lower(hSel["type"])
	IF cType != "opportunity"
		Wapi_MessageBox(,"Ein Angebot kann nur einer Opportunity zugeordnet werden.","CRM",0)
		RETURN .F.
	ENDIF
   nRef := hSel["ref"]

	// 4) Die Zuordnung wurde bereits vom Picker im CRM gespeichert (der Webview
	//    liefert die Ref erst nach erfolgreichem Speichern zurï¿½ck). Kein
	//    separater Assign-Aufruf mehr nï¿½tig.

RETURN .T.

//---------------------------------------------------------------------------
// after_print_angebot: hï¿½ngt eine Text-Aktivitï¿½t ("Angebot gedruckt") an die
// zugeordnete Opportunity. Best-effort: schlï¿½gt die Zuordnung/Meldung fehl,
// darf der Druckvorgang nicht abbrechen.
// Gibt .T. zurï¿½ck, wenn die Aktivitï¿½t angelegt wurde.
//---------------------------------------------------------------------------
FUNCTION CRM_QuoteReport(nAngnr, nValue, cText)
	LOCAL oApi := CrmQuoteApi():New()
	LOCAL cQuoteNo := CrmQuoteNumber(nAngnr)
	LOCAL cTitle, xResp
	LOCAL cUserEmail := AllTrim(SystemUser():Email)

	// nValue wird derzeit nicht separat ï¿½bertragen (steht bereits in cText).

	Default(@cText,"")

	cTitle := "Angebot " + cQuoteNo + " gedruckt"
	xResp := oApi:Report(cQuoteNo, cUserEmail, cTitle, cText)

	IF xResp == NIL
		// Fehlerursache sichtbar machen (Transition/Debug). oApi:cErrorText
		// enthï¿½lt die exakte Server-Meldung, z.B. "No linked opportunity for
		// this quote" (Angebot nicht zugeordnet) oder eine User-Auflï¿½sung.
		Tr_MsgBox({"CRM-Meldung zum Angebot fehlgeschlagen:" , ;
			oApi:cErrorText , ;
			"(Angebot " + cQuoteNo + ", User '" + cUserEmail + "')"})
		RETURN .F.
	ENDIF

RETURN .T.

CLASS CrmQuoteApi FROM RestApi
	METHOD New
	METHOD Execute
	METHOD Status
	METHOD Assign
	METHOD Report

	DATA cErrorText INIT ""
ENDCLASS

METHOD New() CLASS CrmQuoteApi
	// Base URL ends with "/" ï¿½ RestApi:Execute prepends ::cBaseUrl to the path.
	::cBaseUrl := "https://rxaltcsbhcxlczjjczxs.supabase.co/functions/v1/api-quote/"
	::Super:New()
RETURN SELF

// GET status by quote_number -> Hash {linked, opportunity, ...} or NIL
METHOD Status(cQuoteNo) CLASS CrmQuoteApi
RETURN ::Execute("GET", "?quote_number=" + CrmUrlEncode(cQuoteNo), NIL)

// POST /assign -> verknï¿½pft quote_number mit Opportunity (per ref). Die
// ERP-Kundennummer/-name dienen dem Server zur Firmen-Prï¿½fung.
METHOD Assign(cQuoteNo, nOppRef, cTitle, nValue, cUserEmail, cErpNumber, cErpName) CLASS CrmQuoteApi
	LOCAL hData := {=>}
	hData["quote_number"]    := cQuoteNo
	hData["opportunity_ref"] := Int(nOppRef)
	hData["title"]           := hb_strToUtf8(cTitle)
	hData["min_amount"]      := nValue
	hData["max_amount"]      := nValue
	hData["user_email"]      := cUserEmail
	IF ! Empty(cErpNumber)
		hData["erp_customer_number"] := cErpNumber
	ENDIF
	IF ! Empty(cErpName)
		hData["erp_customer_name"] := hb_strToUtf8(cErpName)
	ENDIF
RETURN ::Execute("POST", "assign", hData)

// POST /report -> Text-Aktivitï¿½t an die verknï¿½pfte Opportunity
METHOD Report(cQuoteNo, cUserEmail, cTitle, cDescription) CLASS CrmQuoteApi
	LOCAL hData := {=>}
	hData["quote_number"] := cQuoteNo
	hData["user_email"]   := cUserEmail
	hData["title"]        := hb_strToUtf8(cTitle)
	hData["description"]  := hb_strToUtf8(cDescription)
RETURN ::Execute("POST", "report", hData)

METHOD Execute(cMethod, cUrl, hData) CLASS CrmQuoteApi
	LOCAL aHeader
	LOCAL cResponse := ""
	LOCAL nResponse := 0
	LOCAL lPostJson
	LOCAL xReturn

	Default(@cMethod,"POST")
	Default(@cUrl,"")

	::cApiKeyName := "NEXUSCRM"          // Bearer token = TRADER_API_KEY

	aHeader := {;
		"Authorization: Bearer $APIKEY$",;
		"Content-Type: application/json",;
		"Accept: application/json";
	}

	// GET: keine Body-Kodierung (Query steht in cUrl). POST: Hash ï¿½bergeben,
	// RestApi:Execute JSON-kodiert ihn einmal (kein Doppel-Encoding).
	lPostJson := ! (cMethod == "GET")

	cResponse := ::Super:Execute(cUrl, cMethod, hData, aHeader, lPostJson, @nResponse)

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

//---------------------------------------------------------------------------
// Loest den auf dem Angebot hinterlegten Ansprechpartner (ang->person) ueber
// die Kundennummer zu Name/Email auf (fuer die CRM-Vorbefuellung, APP-288).
// Best-effort: liefert bei fehlendem Kontakt leere Strings zurueck.
//---------------------------------------------------------------------------
STATIC PROCEDURE CrmAngebotContact(nAngnr, cName, cEmail)
	LOCAL aEnv := SaveEnv()
	LOCAL nPerson := 0, cKundma := ""
	LOCAL hContact

	cName  := ""
	cEmail := ""

	BEGIN SEQUENCE
		NetUse("angebot", "ang", .F., 0)
		ang->(dbSetOrder(1))
		IF ang->(dbSeek(Str(nAngnr, 6)))
			nPerson := ang->person
			cKundma := ang->Kundma
		ENDIF

		IF nPerson > 0 .AND. ! Empty(cKundma)
			NetUse("engkund", "ku", .F., 0)
			ku->(dbSetOrder(1))
			IF ku->(dbSeek(cKundma + "K"))
				hContact := GetContact(nPerson)
				IF ValType(hContact) == "H"
					cName  := AllTrim(hContact["name"])
					cEmail := AllTrim(hContact["email"])
				ENDIF
			ENDIF
		ENDIF
	RECOVER
		cName  := ""
		cEmail := ""
	END SEQUENCE

	RestEnv(aEnv, .F.)
RETURN
