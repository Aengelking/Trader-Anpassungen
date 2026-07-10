#include 'hbclass.ch'
#include 'inkey.ch'
#include 'set.ch'

#command @ <top>,<left>,<bottom>,<right> GET <var> LISTBOX <hash> ASSOCIATIVE ;  
	[VALID <valid>];
	[WHEN <when>];
	[COLOR <color>];
=> GET_AssociativeListBox(getlist,<top>,<left>,<bottom>,<right>,{|v| If(v==NIL,<var>,<var>:=v)},<hash>,<{valid}>, <{when}>,<color>)

#define CRLF Chr(13)+Chr(10)

/**
API Dokumentation: https://rxaltcsbhcxlczjjczxs.supabase.co/functions/v1/api-opportunities
**/

FUNCTION NEXUSCRM_Edit(cType)
   LOCAL nNummer := 0
   LOCAL getlist := {}

   NexusCRM_Setup()

   Default(@cType,"ANG")
   
   NetUse("engkund","ku")
   NetUse("buyer","buy")
   IF cType == "ANG"      
      Head("NexusCRM - Opportunity aus Angebot erstellen")
      NetUse("angebot","ang")
      @ 01,00 SAY "Angebot" GET nNummer VALID ang->(dbSeek( Str(nNummer,6) )) PICTURE "999999"
   ELSE
      Head("NexusCRM - Opportunity aus Muster erstellen")
      NetUse("muster","mus")
      @ 01,00 SAY "Muster" GET nNummer VALID mus->(dbSeek( nNummer )) PICTURE "999999"
   ENDIF
   READ

   IF LastKey() == 27
      RETURN .F.
   ENDIF

   NexusCRM_Interface(.F.,cType)
RETURN NIL

FUNCTION NexusCRM_Setup()
   //this will setup the values and their defaults
   GetValue("NEXUSCRM","","API Key fr NexusCRM (Bearer Token)")
   GetValue("NEXUSCRM_PROBABILITY",60,"Standardwahrscheinlichkeit fr neue Opportunities (0-100)")
   GetValue("NEXUSCRM_PRIORITY","medium","Priorit„t: low, medium, high")
   GetValue("NEXUSCRM_URL","https://rxaltcsbhcxlczjjczxs.supabase.co/functions/v1/api-opportunities","URL der NexusCRM API")   
   GetValue("NEXUSCRM_DAYS_VALID",30,"Tage bis Angebot gltig (fr valid_until)")
RETURN NIL

FUNCTION NexusCRM_Interface(lComment,cType)
   LOCAL oNexusCrm := NexusCrmApi():New()
   LOCAL nX,lAdded
   LOCAL cContent,aContact
   LOCAL bExit
   LOCAL nProbability
   LOCAL cPriority
   LOCAL hLeadData := {=>}
   LOCAL getList := {}
   LOCAL cDescription
   LOCAL cUsrEmail
   LOCAL oExtra
   LOCAL hResponse
   LOCAL nNummer,cKunde,cTypeName
   LOCAL cOpportunityId, cOpportunityTitle
   LOCAL nValue, nDaysValid
   LOCAL lCreateNew   
   LOCAL cCompanyId := ""
   LOCAL lLoop := .T.
   LOCAL hUsers
   LOCAL cAssignedTo := ""
   LOCAL aValues

   Default(@lComment,.T.)
   Default(@cType,"ANG")

   NexusCRM_Setup()

   IF cType == "MUS"
      cTypeName := "Muster"
      nNummer := mus->Nummer
      cKunde  := mus->Kunde
      nValue := 0  //mus->Wert
   ELSEIF cType == "ANG"
      cTypeName := "Angebot"
      nNummer := ang->Angnr
      cKunde  := ang->Kundma
      
      aValues := EnquiryAddUp(ang->Angnr,.T.)  

      nValue := aValues[2] 
   ENDIF

   Head("NexusCRM - "+cTypeName+" "+LTrim(Str(nNummer)))

   //NetUse("nexuscrm","nxc")

   //get buyer email
   //buy->(dbGoto( SystemUser():Id ))
   cUsrEmail := Trim(SystemUser():Email)

   //Check if connection is working
   IF ! oNexusCrm:Connect()
      TR_MsgBox("Verbindung zu NexusCRM fehlgeschlagen!")
      RETURN NIL
   ENDIF

   //get users for assignment
   hUsers := oNexusCrm:GetUsers()
   cAssignedTo := cUsrEmail  //pre-select current user
   
   //go to the customer
   ku->(dbSetOrder( 1 ))
   IF ! ku->(dbSeek( cKunde ))
      TR_MsgBox("Kunde nicht gefunden: "+cKunde)
      RETURN NIL      
   ENDIF

   //get the extradata if exists
   oExtra := ExtraData():New(ku->Nummer)

   //Check if customer has nexuscrm id or company_id
   IF oExtra:NexusCRMId != 0      
      cCompanyId := oExtra:NexusCRMId
   ENDIF

   //Basic input dialog
   cOpportunityTitle := cTypeName+" "+LTrim(Str(nNummer))+" - "+Trim(ku->Matchcode)
   nProbability := GetValue("NEXUSCRM_PROBABILITY")
   cPriority := GetValue("NEXUSCRM_PRIORITY")
   nDaysValid := GetValue("NEXUSCRM_DAYS_VALID")
   cDescription := ""
   lCreateNew := .T.

   DO WHILE lLoop
      CLS
      bExit := {|| Inkey(0, 128) }
      
      @ 01,00 SAY "NexusCRM Opportunity/Quote erstellen"
      @ 02,00 SAY REPLICATE("=",60)
      @ 04,00 SAY cTypeName+" Nummer" GET nNummer PICTURE "999999" VALID .T.
      @ 05,00 SAY "Kunde" GET cKunde PICTURE "@!" VALID .T.
      @ 07,00 SAY "Opportunity Titel" GET cOpportunityTitle PICTURE "@!"
      @ 08,00 SAY "Wert (EUR)" GET nValue PICTURE "999999.99"
      @ 09,00 SAY "Wahrscheinlichkeit %" GET nProbability PICTURE "999" VALID (nProbability >= 0 .AND. nProbability <= 100)
      @ 10,00 SAY "Priorit„t (low/medium/high)" GET cPriority PICTURE "@!"
      @ 11,00 SAY "Gltig bis (Tage)" GET nDaysValid PICTURE "999"
      @ 12,00 SAY "Beschreibung" GET cDescription PICTURE "@!"
      @ 13,00 SAY "Zugewiesen an "
      @ 13,15,20,50 GET cAssignedTo LISTBOX hUsers ASSOCIATIVE
      @ 15,00 SAY "C-Opportunity neu erstellen  L-Zu bestehender hinzufgen  S-Speichern  Esc-Abbruch"
      
      READ
      
      DO CASE
      CASE LastKey() == 27  // ESC
         lLoop := .F.
         RETURN NIL
         
      CASE LastKey() == ASC("C")  // Create New
         lCreateNew := .T.
         EXIT
         
      CASE LastKey() == ASC("L")  // Link to Existing
         lCreateNew := .F.
         EXIT
         
      CASE LastKey() == ASC("S") .OR. LastKey() == 13  // Save
         EXIT
      ENDCASE
   ENDDO

   //Create or link opportunity
   IF lCreateNew
      hResponse := oNexusCrm:CreateOpportunity(;
         cOpportunityTitle,;
         nValue,;
         nProbability,;
         cPriority,;
         cDescription,;
         cCompanyId,;
         cAssignedTo;
      )
      
      IF hResponse == NIL
         TR_MsgBox("Fehler beim Erstellen der Opportunity")
         RETURN NIL
      ENDIF
      
      cOpportunityId := hResponse["id"]
   ELSE
      //Choose existing opportunity
      cOpportunityId := oNexusCrm:ChooseOpportunity(cCompanyId)
      
      IF Empty(cOpportunityId)
         TR_MsgBox("Keine Opportunity ausgew„hlt")
         RETURN NIL
      ENDIF
   ENDIF

   //Attach quote to opportunity
   hResponse := oNexusCrm:AttachQuote(;
      cOpportunityId,;
      cTypeName+" "+LTrim(Str(nNummer)),;
      Str(nNummer,6),;
      nValue,;
      nValue * 1.1,;
      Date() + nDaysValid;
   )
   
   IF hResponse == NIL
      TR_MsgBox("Fehler beim Erstellen des Angebots")
      RETURN NIL
   ENDIF

   //Save to local tracking table
   /*nxc->(dbSetOrder( 1 ))
   IF ! nxc->(dbSeek( Str(nNummer,6) ))
      nxc->(dbAppend())
   ELSE
      nxc->(rec_lock(0))
   ENDIF

   IF cType == "MUS"
      nxc->Muster := nNummer
   ELSE
      nxc->Angebot := nNummer
   ENDIF
   nxc->OpportunityId := cOpportunityId
   nxc->QuoteId := hResponse["id"]
   nxc->SyncDate := Date()
   nxc->SyncTime := Time()
   nxc->(dbUnlock())*/

   TR_MsgBox("Opportunity und Quote erfolgreich erstellt/aktualisiert!")
   
RETURN NIL

CLASS NexusCrmApi FROM RestApi
   METHOD New
   METHOD Connect
   METHOD CreateOpportunity
   METHOD AttachQuote
   METHOD ChooseOpportunity
   METHOD ListOpportunities
   METHOD MarkAsWon
   METHOD FindByQuoteNumber
   METHOD GetUsers
   METHOD Execute

   DATA cApiKeyName INIT "NEXUSCRM"
   DATA cUserEmail
ENDCLASS

METHOD New() CLASS NexusCrmApi
   ::cBaseUrl := GetValue("NEXUSCRM_URL","https://rxaltcsbhcxlczjjczxs.supabase.co/functions/v1/api-opportunities")
   
   ::Super:New()
RETURN SELF

METHOD Connect() CLASS NexusCrmApi
   LOCAL hResponse


   //Test connection by getting opportunities
   hResponse := ::Execute("GET", "")
   
   IF hResponse == NIL
      RETURN .F.
   ENDIF

RETURN .T.

METHOD ListOpportunities(cCompanyId) CLASS NexusCrmApi
   LOCAL cUrl := ""
   LOCAL aData

   IF ! Empty(cCompanyId)
      cUrl := "?company_id="+cCompanyId
   ENDIF

   aData := ::Execute("GET", cUrl)
   
RETURN If(aData == NIL, {}, aData)

METHOD ChooseOpportunity(cCompanyId) CLASS NexusCrmApi
   LOCAL aOpportunities := ::ListOpportunities(cCompanyId)
   LOCAL oBrowse, nOpp := 1
   LOCAL nTop := 3, nLeft := 5, nBottom := 20, nRight := 75
   LOCAL aFields, aData := {}
   LOCAL nX

   IF Len(aOpportunities) == 0
      Alert("Keine Opportunities gefunden")
      RETURN ""
   ENDIF

   //Build array for browse
   FOR nX := 1 TO Len(aOpportunities)
      Aadd(aData, {;
         aOpportunities[nX]["id"],;
         aOpportunities[nX]["title"],;
         aOpportunities[nX]["stage"],;
         aOpportunities[nX]["value"],;
         aOpportunities[nX]["probability"];
      })
   NEXT

   aFields := {;
      {5, 100, "ID",{||aData[nOpp,1]}},;
      {50, 100, "Title",{||aData[nOpp,2]}},;
      {14, 100, "Status",{||aData[nOpp,3]}},;
      {10, 100, "Value",{||Str(aData[nOpp,4],10,2)}},;
      {5, 100, "%",{||Str(aData[nOpp,5])}};
   }

   oBrowse := TBrowseTr():New(nTop, nLeft, nBottom, nRight)
   oBrowse:aFields := aFields
   oBrowse:aData := aData
   
   oBrowse:Stabilize()
   
   DO WHILE .T.
      nKey := Inkey(0, 128)
      
      DO CASE
      CASE nKey == 27  // ESC
         RETURN ""
      CASE nKey == 13  // ENTER
         RETURN aData[nOpp, 1]
      CASE nKey == K_UP
         nOpp := If(nOpp > 1, nOpp - 1, nOpp)
         oBrowse:Stabilize()
      CASE nKey == K_DOWN
         nOpp := If(nOpp < Len(aData), nOpp + 1, nOpp)
         oBrowse:Stabilize()
      CASE nKey == K_PGUP
         nOpp := If(nOpp > 10, nOpp - 10, 1)
         oBrowse:Stabilize()
      CASE nKey == K_PGDN
         nOpp := If(nOpp + 10 <= Len(aData), nOpp + 10, Len(aData))
         oBrowse:Stabilize()
      ENDCASE
   ENDDO

RETURN aData[nOpp, 1]

METHOD GetUsers() CLASS NexusCrmApi
   LOCAL hUsers := {=>}
   LOCAL cName

   //build user list from local buyer table
   NetUse("buyer","buy")
   buy->(dbSetOrder(1))
   buy->(dbGoTop())
   DO WHILE ! buy->(Eof())
      IF ! Empty(buy->Email)
         cName := Trim(buy->Name)
         IF Empty(cName)
            cName := Trim(buy->Email)
         ENDIF
         hUsers[cName] := Trim(buy->Email)
      ENDIF
      buy->(dbSkip())
   ENDDO

RETURN hUsers

METHOD CreateOpportunity(cTitle, nValue, nProbability, cPriority, cDescription, cCompanyId, cAssignedTo) CLASS NexusCrmApi
   LOCAL hData := {=>}
   LOCAL cData, hResponse
   LOCAL aHeader

   IF Empty(cCompanyId)
      ::cErrorText := "Company ID erforderlich"
      ::nError := 10
      RETURN NIL
   ENDIF

   hData["title"] := cTitle
   hData["company_id"] := cCompanyId
   hData["user_email"] := SystemUser():Email
   hData["value"] := nValue
   hData["probability"] := nProbability
   hData["priority"] := cPriority

   IF ! Empty(cAssignedTo)
      hData["assigned_to"] := cAssignedTo
   ENDIF
   
   IF ! Empty(cDescription)
      hData["description"] := cDescription
   ENDIF

   cData := HB_JsonEncode(hData)

   hResponse := ::Execute("POST", "", cData)

RETURN hResponse

METHOD AttachQuote(cOpportunityId, cTitle, cQuoteNumber, nMinAmount, nMaxAmount, dValidUntil) CLASS NexusCrmApi
   LOCAL hData := {=>}
   LOCAL cData, hResponse
   LOCAL cUrl

   hData["title"] := cTitle
   hData["user_email"] := SystemUser():Email 
   hData["quote_number"] := cQuoteNumber
   hData["min_amount"] := nMinAmount
   hData["max_amount"] := nMaxAmount
   
   IF ValType(dValidUntil) == "D"
      hData["valid_until"] := DToC(dValidUntil) + "T00:00:00Z"
   ENDIF

   cData := HB_JsonEncode(hData)
   cUrl := cOpportunityId + "/quotes"

   hResponse := ::Execute("POST", cUrl, cData)

RETURN hResponse

METHOD MarkAsWon(cOpportunityId, nFinalValue) CLASS NexusCrmApi
   LOCAL hData := {=>}
   LOCAL cData, hResponse
   LOCAL cUrl

   IF ! Empty(nFinalValue)
      hData["value"] := nFinalValue
   ENDIF

   cData := HB_JsonEncode(hData)
   cUrl := cOpportunityId + "/won"

   hResponse := ::Execute("PUT", cUrl, cData)

RETURN hResponse

METHOD FindByQuoteNumber(cQuoteNumber) CLASS NexusCrmApi
   LOCAL cUrl := "by-quote/" + cQuoteNumber
   LOCAL hResponse

   hResponse := ::Execute("GET", cUrl)

RETURN hResponse

METHOD Execute(cMethod, cUrl, cData) CLASS NexusCrmApi
   LOCAL aHeader
   LOCAL cResponse := ""
   LOCAL nResponse := 0
   LOCAL hReturn
   LOCAL oErr

   Default(@cMethod, "GET")
   Default(@cUrl, "")
   Default(@cData, "")

   //Setup headers with Bearer token
   aHeader := {;
      "Authorization: Bearer " + GetValue("NEXUSCRM"),;
      "Content-Type: application/json",;
      "Accept: application/json";
   }

   //Call parent Execute method
   cResponse := ::Super:Execute(::cBaseUrl + (IF(Empty(cUrl), "", "/" + cUrl)), cMethod, cData, aHeader, .T., @nResponse)

   IF Empty(cResponse)
      RETURN {=>}
   ENDIF


   hReturn := HB_JsonDecode(cResponse)

   //Check for API error
   IF ValType(hReturn) == "H" .AND. HHasKey(hReturn, "error")
      RETURN NIL
   ENDIF

RETURN hReturn
