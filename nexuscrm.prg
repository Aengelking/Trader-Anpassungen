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
         cName := Trim(buy->Buyer)
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
      "Authorization: Bearer $APIKEY$",;
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
