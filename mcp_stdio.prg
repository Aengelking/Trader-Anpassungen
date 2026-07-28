/*
 * MCP (Model Context Protocol) Server for Trader - STDIO Integrated Version
 *
 * This module implements an MCP server that communicates via stdin/stdout
 * with full database integration for Claude Desktop.
 *
 * Copyright 2025 Trader Development Team
 * 
 */

// David InfoCenter archive constants (from david.ch). Defined locally so this
// module compiles independently of the David include path.
#ifndef DvArchiveCommon
   #define DvArchiveCommon      2
#endif
#ifndef DvArchivePersonalIn
   #define DvArchivePersonalIn  101
#endif

//---------------------------------------------------------------------------
// General chat-output channel for hooks and other Trader code that runs
// inside an MCP tool call. The function only exists while this script is
// loaded, so callers must invoke it dynamically:
//
//    IF Type("MCPCHATMESSAGE()") != "U"   //running inside the MCP server?
//       HB_ExecFromArray("MCPChatMessage", {"Sicherheitsdatenblatt abspeichern!"})
//    ELSE
//       ...interactive path (Tr_MsgBox etc.)...
//    ENDIF
//
// Collected messages are appended to the current tool response as additional
// content blocks, so the model sees them alongside the tool result. Text is
// expected in the app codepage (OEM) like all other in-app strings.
// (Deliberately named without the MCP_ prefix so it cannot be invoked as a
// JSON-RPC method via the MCP_<method> dispatch.)
//---------------------------------------------------------------------------
FUNCTION MCPChatMessage(cText)
   IF ValType(cText) == "C" .AND. ! Empty(cText)
      AAdd(MCPChatBuffer(), HB_StrToUTF8(cText))
   ENDIF
RETURN NIL

// Buffer of chat messages for the current tool call. Uses a function-level
// STATIC because mcp_http.prg #includes this file after its own code, where
// a file-wide STATIC declaration would no longer compile (E0004). Pass
// lReset=.T. to clear; the array itself is shared by reference.
STATIC FUNCTION MCPChatBuffer(lReset)
   STATIC aMessages := {}
   IF HB_IsLogical(lReset) .AND. lReset
      ASize(aMessages, 0)
   ENDIF
RETURN aMessages

FUNCTION MCP_StdIO()
   LOCAL cInput, hRequest, cResponse
   LOCAL nStdIn, nStdOut,cChar,nStdErr
   LOCAL cLine := ""
   LOCAL cBuffer := ""
   LOCAL nChar, nPos
   LOCAL bOldError


   // Get stdin and stdout handles
   nStdIn := hb_GetStdIn()
   nStdOut := hb_GetStdOut()
   nStdErr := hb_GetStdErr()

   // No keyboard and no visible window in an MCP process: make sure nothing
   // (MailConnect, error handler, hooks) ever pops a modal Alert/MsgBox that
   // would block the request loop forever.
   SetConfigValue("BATCHMODE", .T.)

   FWrite(nStdErr,"MCP_StdIO: Starting MCP server via STDIO..."+Chr(10))

   //? "MCP STDIO: Started"
   //? "MCP STDIO: Started"
   
   // Set up error handler, changed the main error handler to ouput to stdErr
   /*bOldError := ErrorBlock({|oError| 
      LOCAL cMessage := ErrorMessage(oError)
      LOCAL nX := 1
      DO WHILE ! Empty(ProcName(nX))            
         cMessage += " (" + ProcName(nX) + " "+LTrim(Str(ProcLine(nX))) + ")"
         nX++
      ENDDO
      Break(cMessage)
      RETURN NIL 
   })*/
   

   // Main loop - read JSON-RPC requests from stdin
   DO WHILE .T.
      cLine := ""

      // Read a complete line (terminated by newline) from stdin. Data is read
      // in chunks into cBuffer, which carries any bytes past the newline over
      // to the next request. Reading byte-by-byte with a 0.1s Inkey() delay
      // per byte (the previous version) limited throughput to ~10 bytes/sec,
      // so any larger request (e.g. send_email with a long body) hit the MCP
      // client timeout before the tool was even called.
      DO WHILE .T.
         nPos := At(Chr(10), cBuffer)
         IF nPos > 0
            cLine := Left(cBuffer, nPos - 1)
            cBuffer := SubStr(cBuffer, nPos + 1)
            // Remove carriage return if present
            IF Right(cLine, 1) == Chr(13)
               cLine := Left(cLine, Len(cLine) - 1)
            ENDIF
            EXIT
         ENDIF

         cChar := Space(4096)
         nChar := FRead(nStdIn, @cChar, Len(cChar))
         IF nChar > 0
            cBuffer += Left(cChar, nChar)
         ELSE
            // Nothing read (pipe empty or closed) - wait briefly so we do
            // not busy-spin. FRead on a pipe normally blocks, so this only
            // triggers on EOF or a non-blocking stdin.
            Inkey(0.1)
         ENDIF
      ENDDO
      
      
      IF !Empty(cLine)
         //? "Processing request: " + cLine
         //? "Processing request: " + cLine
         // Parse JSON request
         hRequest := HB_JsonDecode(cLine)
         IF hRequest != NIL .AND. ValType(hRequest) == "H"
            // Validate basic JSON-RPC structure
            IF !HHasKey(hRequest, "jsonrpc") .OR. !HHasKey(hRequest, "method")
               cResponse := CreateErrorResponse("Invalid JSON-RPC request: missing required fields", ;
                  IIF(HHasKey(hRequest, "id"), hRequest["id"], ""))
            ELSE
               // Process MCP request
               cResponse := ProcessMCPRequest(hRequest)
               
               // Check for shutdown
               IF HHasKey(hRequest, "method") .AND. hRequest["method"] == "shutdown"
                  FWrite(nStdOut, cResponse + Chr(10))
                  EXIT
               ENDIF
            ENDIF
         ELSE
            cResponse := CreateErrorResponse("Invalid JSON in request", "")
         ENDIF
         
         // Write response to stdout with newline
         FWrite(nStdOut, cResponse + Chr(10))
      ENDIF
   ENDDO
   
   // Cleanup
   dbCloseAll()

RETURN NIL

// The MCP Streamable HTTP transport (MCP_Http) lives in mcp_http.prg. It
// reuses the ProcessMCPRequest() dispatch below, so both files must be built
// together.

FUNCTION ProcessMCPRequest(hRequest)
   LOCAL cMethod, cResponse, cFunctionName
   LOCAL cJsonrpc := hRequest["jsonrpc"]
   LOCAL xId := IIF(HHasKey(hRequest, "id"), hRequest["id"], "")
   LOCAL cMessage
   
   IF cJsonrpc != "2.0"
      RETURN CreateErrorResponse("Invalid JSON-RPC version", xId)
   ENDIF
   
   cMethod := IIF(HHasKey(hRequest, "method"), hRequest["method"], "")
   
   IF Empty(cMethod)
      RETURN CreateErrorResponse("Missing method field", xId)
   ENDIF
   
   // Convert method name to function name: tools/list -> MCP_Tools_List
   cFunctionName := "MCP_" + StrTran(cMethod, "/", "_")
   
   // Check if function exists and call it dynamically
   IF Type(cFunctionName + "()") != "U"
      BEGIN SEQUENCE
         cResponse := HB_ExecFromArray(cFunctionName, {hRequest, xId})
      RECOVER
         cResponse := CreateErrorResponse("Error executing method: " + cFunctionName,xID)
      END SEQUENCE
   ELSE
      cResponse := CreateErrorResponse("Unknown method: " + cMethod + " (function: " + cFunctionName + ")", xId)
   ENDIF
   
RETURN cResponse

FUNCTION MCP_Initialize(hRequest, xId)
   LOCAL hResult := {=>}
   LOCAL hCapabilities := {=>}
   
   hCapabilities["tools"] := {=>}
   hCapabilities["resources"] := {=>}
   
   hResult["protocolVersion"] := "2024-11-05"
   hResult["capabilities"] := hCapabilities
   hResult["serverInfo"] := {;
      "name"=>"Trader MCP Server (STDIO Integrated)",;
      "version"=>"1.0.0"}
   
RETURN CreateSuccessResponse(hResult, xId)

FUNCTION MCP_Shutdown(hRequest, xId)
   LOCAL hResult := {=>}
   
RETURN CreateSuccessResponse(hResult, xId)

FUNCTION MCP_Tools_List(hRequest, xId)
   LOCAL aTools := {}
   LOCAL aFuncNames, cFuncName, cToolName, hTool, hToolInfo
   
   // Dynamically discover all MCP_Tool_* functions
   aFuncNames := GetFunctionsWithPrefix("MCP_TOOL_")
   
   FOR EACH cFuncName IN aFuncNames
      // Convert MCP_TOOL_GET_CUSTOMER to get_customer
      cToolName := Lower(SubStr(cFuncName, 10))  // Remove "MCP_TOOL_"
      
      // Get schema and description from the tool function itself
      hToolInfo := HB_ExecFromArray(cFuncName, {})
      
      hTool := {=>}
      hTool["name"] := cToolName
      hTool["description"] := hToolInfo["description"]
      hTool["inputSchema"] := hToolInfo["schema"]
      
      AAdd(aTools, hTool)
   NEXT
   
RETURN CreateSuccessResponse({"tools"=>aTools}, xId)

FUNCTION GetFunctionsWithPrefix(cPrefix)
   LOCAL aFunctions := {}
   LOCAL nCount := __dynsCount()
   LOCAL i, cFuncName
   
   cPrefix := Upper(cPrefix)
   
   FOR i := 1 TO nCount
      cFuncName := __dynsGetName(i)
      IF Left(Upper(cFuncName), Len(cPrefix)) == cPrefix
         AAdd(aFunctions, cFuncName)
      ENDIF
   NEXT
   
RETURN aFunctions


FUNCTION MCP_Tools_Call(hRequest, xId)
   LOCAL hParams := hRequest["params"]
   LOCAL cToolName := hParams["name"]
   LOCAL hArguments := IF(HHasKey(hParams,"arguments"),hParams["arguments"],{=>})
   LOCAL cFunctionName, hResult, hToolData, cFormattedText
   LOCAL hToolInfo, aRequired, cRequiredParam
   LOCAL aAnyOfGroups
   LOCAL aGroup, lGroupSatisfied, cParam
   LOCAL cGroupParams,oError
   LOCAL nProvidedCount := 0
   LOCAL cProvidedParams := ""
   LOCAL aContent, cChatMsg

   
   // Convert tool name to function name: get_customer -> MCP_Tool_Get_Customer
   cFunctionName := "MCP_Tool_" + cToolName
   
   // Check if function exists
   IF Type(cFunctionName + "()") != "U"
      // Get tool schema for parameter validation
      
      hToolInfo := HB_ExecFromArray(cFunctionName, {})
      
      // Validate required parameters
      IF HHasKey(hToolInfo["schema"], "required") .AND. HB_IsArray(hToolInfo["schema"]["required"])
         aRequired := hToolInfo["schema"]["required"]
         FOR EACH cRequiredParam IN aRequired
            IF !HHasKey(hArguments, cRequiredParam) .OR. Empty(hArguments[cRequiredParam])
               RETURN CreateErrorResponse("Missing required parameter: " + cRequiredParam, xId)
            ENDIF
         NEXT
      ENDIF
      
      // Validate anyOf requirements (exactly one parameter from the group must be provided)
      IF HHasKey(hToolInfo["schema"], "anyOf") .AND. HB_IsArray(hToolInfo["schema"]["anyOf"])
         aAnyOfGroups := hToolInfo["schema"]["anyOf"]
         FOR EACH aGroup IN aAnyOfGroups
            nProvidedCount := 0
            cProvidedParams := ""
            
            FOR EACH cParam IN aGroup
               IF HHasKey(hArguments, cParam) .AND. !Empty(hArguments[cParam])
                  nProvidedCount++
                  IF Len(cProvidedParams) > 0
                     cProvidedParams += ", "
                  ENDIF
                  cProvidedParams += cParam
               ENDIF
            NEXT
            
            IF nProvidedCount == 0
               cGroupParams := ""
               FOR EACH cParam IN aGroup
                  IF Len(cGroupParams) > 0
                     cGroupParams += " OR "
                  ENDIF
                  cGroupParams += cParam
               NEXT
               RETURN CreateErrorResponse("Exactly one of these parameters is required: " + cGroupParams, xId)
            ELSEIF nProvidedCount > 1
               cGroupParams := ""
               FOR EACH cParam IN aGroup
                  IF Len(cGroupParams) > 0
                     cGroupParams += " OR "
                  ENDIF
                  cGroupParams += cParam
               NEXT
               RETURN CreateErrorResponse("Only one of these parameters is allowed: " + cGroupParams + ". You provided: " + cProvidedParams, xId)
            ENDIF
         NEXT
      ENDIF

      //make sure the tool is not called with no arguments, this would otherwise return the schmema
      IF hArguments == NIL .OR. ValType(hArguments) != "H" .OR. Len(hArguments) == 0
         hArguments := {"DUMMY"=>.T.}
      ENDIF

      MCPChatBuffer(.T.)  // fresh chat-message buffer for this call (see MCPChatMessage)
      hToolData := HB_ExecFromArray(cFunctionName, {hArguments})

      IF ValType(hToolData) == "C" //string returned this is an error message
         RETURN CreateErrorResponse(hToolData, xId)
      ELSE
         // Convert structured data to readable text for MCP content
         //cFormattedText := FormatToolResult(hToolData)
         cFormattedText := HB_JsonEncode(hToolData)  // Use JSON encoding for structured data

         hResult := {=>}
         hResult["type"] := "text"
         hResult["text"] := cFormattedText
      ENDIF
   ELSE
      RETURN CreateErrorResponse("Unknown tool: " + cToolName + " (function: " + cFunctionName + ")", xId)
   ENDIF

   // Append chat messages emitted during the call (via MCPChatMessage) as
   // additional content blocks so the model sees them with the result
   aContent := {hResult}
   FOR EACH cChatMsg IN MCPChatBuffer()
      AAdd(aContent, {"type"=>"text", "text"=>cChatMsg})
   NEXT
   MCPChatBuffer(.T.)

RETURN CreateSuccessResponse({"content"=>aContent}, xId)

FUNCTION MCP_Tool_Get_Customer(hArgs)
   LOCAL nCustomerNumber, cSearchTerm
   LOCAL hResult := {=>}
   LOCAL lFound := .F.
   LOCAL oKunde
   
   // Return schema and description when called without arguments
   IF hArgs == NIL .OR. ValType(hArgs) != "H" .OR. Len(hArgs) == 0
      hResult["schema"] := {;
         "type"=>"object",;
         "properties"=>{;
            "customer"=>{"type"=>"string","description"=>"Customer matchcode"},;
            "customer_number"=>{"type"=>"number","description"=>"Customer number"};
         },;
         "anyOf"=>{{"customer", "customer_number"}};
      }
      hResult["description"] := "Retrieve customer information by customer matchcode or number"
      RETURN hResult
   ENDIF

   IF HHasKey(hArgs, "customer_number") 
      nCustomerNumber := hArgs["customer_number"]
   ENDIF
   IF HHasKey(hArgs, "customer") 
      cSearchTerm := hArgs["customer"]
   ENDIF

   oKunde:= Adresse():New()
   IF nCustomerNumber != NIL .AND. nCustomerNumber > 0
      // Load customer by number
      ku->(DbSetOrder(8))  // Assume order 1 is by customer number
      lFound := oKunde:Load(nCustomerNumber)
   ELSEIF !Empty(cSearchTerm)
      // Search by matchcode
      lFound := oKunde:LoadMatchcode(Pad(Upper(cSearchTerm),8),"K")
   ENDIF
   
   IF lFound
      hResult["number"] := oKunde:nummer
      hResult["name"] := AllTrim(oKunde:cName)
      hResult["street"] := AllTrim(oKunde:street)
      hResult["city"] := AllTrim(oKunde:town)
      hResult["country"] := AllTrim(oKunde:cLand)
      hResult["status"] := "found"
   ELSE
      hResult["status"] := "not_found"
      hResult["message"] := "Customer not found"
   ENDIF
   
RETURN _HashToUtf8(hResult)

FUNCTION MCP_Tool_Search_Customers(hArgs)
   LOCAL hResult := {=>}
   LOCAL aCustomers := {}
   LOCAL hCustomer
   LOCAL cFilter, cNeedle
   LOCAL nMaxResults, nCount := 0
   LOCAL nOldSelect := Select()

   // Return schema and description when called without arguments
   IF hArgs == NIL .OR. ValType(hArgs) != "H" .OR. Len(hArgs) == 0
      hResult["schema"] := {;
         "type"=>"object",;
         "properties"=>{;
            "name"=>{"type"=>"string","description"=>"Case-insensitive text filter applied to customer Name"},;
            "town"=>{"type"=>"string","description"=>"Case-insensitive text filter applied to customer Town"},;
            "max_results"=>{"type"=>"number","description"=>"Maximum number of matching customers to return (default 50, max 200)"};
         },;
         "anyOf"=>{{"name", "town"}};
      }
      hResult["description"] := "Search customers by text in Name or Town"
      RETURN hResult
   ENDIF

   nMaxResults := IIF(HHasKey(hArgs, "max_results") .AND. HB_IsNumeric(hArgs["max_results"]), hArgs["max_results"], 50)
   nMaxResults := Max(1, Min(nMaxResults, 200))

   IF ! HHasKey(hArgs, "name") .AND. !HHasKey(hArgs, "town")
      RETURN "Invalid arguments for Search Customer: filter is required"
   ENDIF

   cFilter := ""
   IF HHasKey(hArgs, "name") .AND. !Empty(hArgs["name"])
      cFilter := '"'+Upper(AllTrim(hArgs["name"]))+'" $ Upper(Trim(name1)+name2)'
   ENDIF
   IF HHasKey(hArgs, "town") .AND. !Empty(hArgs["town"])
      IF !Empty(cFilter)
         cFilter += " .OR. "
      ENDIF
      cFilter += '"'+Upper(AllTrim(hArgs["town"]))+'" $ Upper(Trim(town))'
   ENDIF

   NetUse("engkund","ku")
   ku->(dbSetFilter({|| ku->(&(cFilter))},cFilter))
   ku->(DbSetOrder(2))
   ku->(DbSeek("K"))

   DO WHILE !ku->(Eof()) .AND. ku->Group == "K" .AND. nCount < nMaxResults

      hCustomer := {=>}
      hCustomer["number"] := ku->Nummer
      hCustomer["kunde"] := AllTrim(ku->Kunde)
      hCustomer["name"] := Trim(Trim(ku->Name1)+" "+ku->Name2)      
      hCustomer["town"] := AllTrim(ku->Town)
      hCustomer["street"] := AllTrim(ku->Street)
      hCustomer["countryiso"] := AllTrim(ku->CountryIso)
      AAdd(aCustomers, _HashToUtf8(hCustomer))
      nCount++

         ku->(DbSkip())
   ENDDO

   DbSelectArea(nOldSelect)
   ku->(dbClearFilter())

   hResult["status"] := IIF(Len(aCustomers) > 0, "found", "not_found")
   hResult["count"] := Len(aCustomers)
   hResult["max_results"] := nMaxResults
   //hResult["filter"] := cFilter
   hResult["customers"] := aCustomers

   IF Len(aCustomers) == 0
      hResult["message"] := "No customers found"
   ELSEIF Len(aCustomers) == nMaxResults
      hResult["message"] := "Result limited to " + AllTrim(Str(nMaxResults)) + " customers"
   ENDIF

RETURN _HashToUtf8(hResult)

FUNCTION MCP_Tool_Get_Article(hArgs)
   LOCAL hResult := {=>}
   LOCAL lFound := .F.
   LOCAL hShopwareData, hShopwareOptions

   // Return schema and description when called without arguments
   IF hArgs == NIL .OR. ValType(hArgs) != "H" .OR. Len(hArgs) == 0
      hResult["schema"] := {;
         "type"=>"object",;
         "properties"=>{;
            "matchcode"=>{"type"=>"string","description"=>"Artikel Matchcode"},;
            "partno"=>{"type"=>"string","description"=>"Artikelnummer"};
         },;
         "anyOf"=>{{"matchcode", "partno"}};
      }
      hResult["description"] := "Retrieve detailed information for a single article/product by matchcode or part number. " + ;
                                "Returns comprehensive data including stock, prices, description" + ;
                                "Use this when you need detailed information"
      RETURN hResult
   ENDIF

   IF ValType(hArgs) != "H" .OR. !HHasKey(hArgs, "matchcode") .AND. !HHasKey(hArgs, "partno")
      RETURN "Invalid arguments for Get Article: "+ValType(hArgs) + " " + ;
             IF(ValType(hArgs)=="H" .AND. !HHasKey(hArgs, "matchcode") .AND. !HHasKey(hArgs, "partno"), ;
             "No matchcode or part number provided", "Wrong type of arguments")
   ENDIF

   NetUse("artikel","art")  // Ensure article database is available

   IF HHasKey(hArgs,"matchcode") .AND. !Empty(hArgs["matchcode"])
      // Load by matchcode
      art->(DbSetOrder(1))  // Assume order 1 is by matchcode
      lFound := art->(DbSeek(Pad(hArgs["matchcode"],25)))
   ELSEIF HHasKey(hArgs,"partno") .AND. !Empty(hArgs["partno"])
      // Search by part number
      art->(DbSetOrder(2))  
      lFound := art->(DbSeek(Str(Val(hArgs["partno"]),6)))
   ENDIF

   IF lFound
      hResult["matchcode"] := AllTrim(art->matchcode)
      hResult["description"] := AllTrim(art->artikel)
      hResult["unit"] := AllTrim(art->Me)
      hResult["group"] := AllTrim(art->gruppe)
      //hResult["sell_price"] := art->vkpr
      hResult["stock"] := art->bestand
      
      hResult["status"] := "found"
   ELSE
      hResult["status"] := "not_found"
      hResult["message"] := "Article not found"
   ENDIF
   
RETURN hResult

FUNCTION MCP_Tool_Get_Order_Details(hArgs)
   LOCAL oAuftrag
   LOCAL hResult := {=>}
   LOCAL lFound := .F.
   
   // Return schema and description when called without arguments
   IF hArgs == NIL .OR. ValType(hArgs) != "H" .OR. Len(hArgs) == 0
      hResult["schema"] := {;
         "type"=>"object",;
         "properties"=>{;
            "order_number"=>{"type"=>"number","description"=>"Order number"};
         },;
         "required"=>{"order_number"};
      }
      hResult["description"] := "Retrieve detailed order information by order number, including all line items with " + ;
                                "status, the confirmed delivery week/date, the customer's requested week and - when " + ;
                                "the date was moved - the originally confirmed week"
      RETURN hResult
   ENDIF

   oAuftrag := Auftrag():New()
   IF  oAuftrag:Load(hArgs["order_number"])
      lFound := .T.
      hResult["order_number"] := oAuftrag:abnr
      hResult["customer"] := oAuftrag:Kundma
      hResult["date"] := oAuftrag:Besda
      hResult["completed"] := oAuftrag:Erledigt //auf->Status == 3 .OR. auf->Status == 7
      hResult["total"] := oAuftrag:total
      hResult["lines"] := {}
      oAuftrag:Positions:Each({|oPos|
         LOCAL hPosition := {=>}
         LOCAL dTemp
         hPosition["item"] := oPos:Itmnr
         hPosition["article"] := AllTrim(oPos:Matchcode)
         //hPosition["description"] := AllTrim(oPos:Artikel:Artikel)
         hPosition["blanket_order"] := oPos:IsRahmen
         IF oPos:IsRahmen
            hPosition["quantity"] := oPos:ContrQty
         ELSE
            hPosition["quantity"] := oPos:VkQty
         ENDIF
         hPosition["open_quantity"] := IF(oPos:lErledigt, 0, oPos:VkQty - oPos:GelQty)
         hPosition["delivered_quantity"] := oPos:GelQty
         hPosition["price"] := oPos:VkPr/oPos:Pe
         hPosition["status"] := IF(oPos:lErledigt, "completed", "open")
         hPosition["total"] := oPos:GetLineTotal()

         // Delivery terms are JJWW calendar weeks: Dterm is the delivery week
         // confirmed to the customer (99 = frame/call-off), Wterm the
         // customer's requested week, UBTerm the originally confirmed week
         // kept when the date was moved (see auftrag_print.prg)
         IF HB_IsNumeric(oPos:Dterm) .AND. oPos:Dterm > 0
            hPosition["delivery_week"] := StrZero(oPos:Dterm, 4)
            IF (dTemp := BesWeekDate(oPos:Dterm)) != NIL
               hPosition["delivery_date"] := dTemp
            ENDIF
         ENDIF
         IF HB_IsNumeric(oPos:Wterm) .AND. oPos:Wterm > 0
            hPosition["requested_week"] := StrZero(oPos:Wterm, 4)
            IF (dTemp := BesWeekDate(oPos:Wterm)) != NIL
               hPosition["requested_date"] := dTemp
            ENDIF
         ENDIF
         IF HB_IsNumeric(oPos:UBTerm) .AND. oPos:UBTerm > 0 .AND. oPos:UBTerm != oPos:Dterm
            hPosition["originally_confirmed_week"] := StrZero(oPos:UBTerm, 4)
            IF (dTemp := BesWeekDate(oPos:UBTerm)) != NIL
               hPosition["originally_confirmed_date"] := dTemp
            ENDIF
         ENDIF

         // Add position to order result
         AAdd(hResult["lines"], hPosition)
         RETURN .T.
      })
      hResult["status"] := "found"
   ENDIF
   
   IF !lFound
      hResult["status"] := "not_found"
      hResult["message"] := "Order not found: " + LTrim(Str(hArgs["order_number"]))
   ENDIF
   
RETURN hResult

FUNCTION MCP_Tool_Check_Stock(hArgs)
   LOCAL cMatchcode
   LOCAL hResult := {=>}

   // Return schema and description when called without arguments
   IF hArgs == NIL .OR. ValType(hArgs) != "H" .OR. Len(hArgs) == 0
      hResult["schema"] := {;
         "type"=>"object",;
         "properties"=>{;
            "matchcode"=>{"type"=>"string","description"=>"Article matchcode"};
         },;
         "required"=>{"matchcode"};
      }
      hResult["description"] := "Check current stock levels for an article"
      RETURN hResult
   ENDIF

   cMatchcode := hArgs["matchcode"]
   
   NetUse("artikel","art")  // Ensure article database is available
   NetUse("shopware","shop")  // For Shopware URLs
   
   IF !Empty(cMatchcode)
      art->(DbSetOrder(1))  // Assume order 1 is by matchcode
      IF art->(DbSeek(cMatchcode))
         hResult["matchcode"] := AllTrim(cMatchcode)
         hResult["description"] := AllTrim(art->artikel)
         hResult["current_stock"] := art->bestand
         //hResult["reserved"] := art->reserviert
         hResult["available"] := LagGetStock(art->Artikelnr,2) //art->bestand - art->reserviert
         
         // Check if article has Shopware entry
         IF shop->(dbSeek(Str(art->Artikelnr,6)))
            hResult["shopware_url"] := "https://engelking.de/detail/" + AllTrim(shop->UUID)
         ENDIF
         
         hResult["status"] := "found"
      ELSE
         hResult["status"] := "not_found"
         hResult["message"] := "Article not found: " + cMatchcode
      ENDIF
   ELSE
      hResult["status"] := "error"
      hResult["message"] := "No matchcode provided"
   ENDIF
   
RETURN hResult

FUNCTION MCP_Tool_Search_Articles(hArgs)
   LOCAL hResult := {=>}
   LOCAL aArticles := {}
   LOCAL nCount := 0
   LOCAL hArticle
   LOCAL cMatchcodePrefix, cDescriptionContains, nMaxResults, cGroup
   LOCAL cStockFilter, nMinStock, nMaxStock
   LOCAL lMatches
   LOCAL cEnhancedDescription, cMacroFilter
   LOCAL bMatchAndAdd,cFilter,bFilter
   
   // Return schema and description when called without arguments
   IF hArgs == NIL .OR. ValType(hArgs) != "H" .OR. Len(hArgs) == 0
      hResult["schema"] := {;
         "type"=>"object",;
         "properties"=>{;
            "matchcode_prefix"=>{"type"=>"string","description"=>"Search for articles where matchcode starts with this value"},;
            "description_contains"=>{"type"=>"string","description"=>"Search for articles where description contains text. Supports AND/OR operators and parentheses for grouping (e.g., 'resistor AND 1k', 'capacitor OR inductor', '(resistor OR capacitor) AND (1k OR 2k)')"},;
            "group"=>{"type"=>"string","description"=>"Filter by article group"},;
            "stock_filter"=>{"type"=>"string","description"=>"Filter by stock status: 'in_stock' (>0), 'out_of_stock' (=0), 'low_stock' (<10)"},;
            "min_stock"=>{"type"=>"number","description"=>"Minimum stock quantity"},;
            "max_stock"=>{"type"=>"number","description"=>"Maximum stock quantity"},;
            "max_results"=>{"type"=>"number","description"=>"Maximum number of results to return (default: 30)"};
         };
      }
      hResult["description"] := "Search the INTERNAL article database (not online shop). For online shop product searches, use get_catalogue instead. This tool searches local inventory records."
      RETURN hResult
   ENDIF
   
   // Get filter parameters
   cMatchcodePrefix := IIF(HHasKey(hArgs, "matchcode_prefix"), Upper(AllTrim(hArgs["matchcode_prefix"])), "")
   cDescriptionContains := IIF(HHasKey(hArgs, "description_contains"), Upper(AllTrim(hArgs["description_contains"])), "")
   cGroup := IIF(HHasKey(hArgs, "group"), AllTrim(hArgs["group"]), "")
   cStockFilter := IIF(HHasKey(hArgs, "stock_filter"), Lower(AllTrim(hArgs["stock_filter"])), "")
   nMaxResults := IIF(HHasKey(hArgs, "max_results"), hArgs["max_results"], 50)
   
   NetUse("artikel","art")  // Ensure article database is available
   NetUse("shopware","shop")  // For Shopware URLs

   cMacroFilter := BuildDescriptionFilter(cDescriptionContains)
   bFilter := &("{|cValue| art->(" + cMacroFilter + ")}")

   //Code block to match and add articles
   bMatchAndAdd := {||
      // Description filter (only if needed)
      IF  !Empty(cDescriptionContains)
         // Try basic article description first (fast)
         IF !Upper(cDescriptionContains) $ Upper(art->artikel)
            // Only get enhanced description if basic check fails
            
            IF !Empty(cMacroFilter) 
               // If we have a macro filter, we need to get the enhanced description
               cEnhancedDescription := GetEnhancedDescription(art->artikelnr)
               // Now check enhanced description
               IF ! Eval(bFilter, Upper(cEnhancedDescription) )
                  RETURN .F.
               ENDIF               
            ENDIF
         ENDIF
      ENDIF
      
      hArticle := {=>}
      hArticle["matchcode"] := AllTrim(art->matchcode)
      hArticle["description"] := GetEnhancedDescription(art->artikelnr)
      hArticle["unit"] := AllTrim(art->Me)
      hArticle["group"] := AllTrim(art->gruppe)
      hArticle["group_name"] := GetArtGroupName(AllTrim(art->gruppe))
      hArticle["stock"] := art->bestand
      
      // Check if article has Shopware entry
      IF shop->(dbSeek(Str(art->Artikelnr,6)))
         hArticle["shopware_url"] := "https://engelking.de/detail/" + AllTrim(shop->UUID)
      ENDIF
      
      AAdd(aArticles, hArticle)
      nCount++
      
      RETURN .T.
   }

   cFilter := "! obsolete"
   IF !Empty(cStockFilter)
      IF ! Empty(cFilter)
         cFilter += " .AND. "
      ENDIF

      DO CASE
         CASE cStockFilter == "in_stock"
            cFilter += "bestand > 0"
         CASE cStockFilter == "out_of_stock"
            cFilter += "bestand == 0"
         CASE cStockFilter == "low_stock"
            cFilter += "bestand < 10"
      ENDCASE
   ENDIF
   IF Empty(cStockFilter) .OR. cStockFilter == "in_stock"
      IF HHasKey(hArgs, "min_stock")
         IF ! Empty(cFilter)
            cFilter += " .AND. "
         ENDIF
         cFilter += "bestand > "+LTrim(Str( hArgs["min_stock"] ))
      ENDIF
      IF HHasKey(hArgs, "max_stock")
         IF ! Empty(cFilter)
            cFilter += " .AND. "
         ENDIF
         cFilter += "bestand <= "+LTrim(Str( hArgs["max_stock"] ))
      ENDIF
   ENDIF

   IF !Empty(cGroup)
      IF ! Empty(cFilter)
         cFilter += " .AND. "
      ENDIF
      cFilter += 'AllTrim(gruppe) != "'+cGroup+'"'
   ENDIF
   
   IF ! Empty(cFilter)
      // Apply stock filter to the article database
      art->(DbSetFilter({|| art->(&(cFilter))},cFilter))
   ENDIF
   
   hResult["filter"] := art->(dbFilter() )

   // Search using matchcode prefix if provided
   IF !Empty(cMatchcodePrefix)
      art->(DbSetOrder(1))  // Matchcode index
      hResult["filter_after_order"] := art->(dbFilter() )
      art->(DbSeek(cMatchcodePrefix))
         hResult["filter_after_seek"] := art->(dbFilter() )   
      WHILE !art->(Eof()) .AND. Left(Upper(art->matchcode), Len(cMatchcodePrefix)) == cMatchcodePrefix .AND. nCount < nMaxResults         
         Eval(bMatchAndAdd)
         //AAdd(aArticles, {"bestand"=>art->Bestand,"filter"=>art->(dbFilter())})
         art->(DbSkip())
      ENDDO
   ELSE
      // If no matchcode prefix, scan all articles with filters
      art->(DbGoTop())
      
      WHILE !art->(Eof()) .AND. nCount < nMaxResults
         
         Eval(bMatchAndAdd)
         
         art->(DbSkip())
      ENDDO
   ENDIF

   art->(dbClearFilter())  // Clear any filters applied
   
   hResult["articles"] := aArticles
   hResult["count"] := Len(aArticles)
   hResult["status"] := "found "+cFilter
   
   IF Len(aArticles) == 0
      hResult["message"] := "No articles found matching the criteria "+cMacroFilter
   ELSEIF Len(aArticles) == nMaxResults
      hResult["message"] := "Result limited to " + AllTrim(Str(nMaxResults)) + " articles"
   ENDIF
   
RETURN hResult

FUNCTION GetArtGroupName(cGruppe)
   LOCAL cGroupName := "", nOldSelect := Select()
   
   IF Empty(cGruppe)
      RETURN ""
   ENDIF
   
   NetUse("group","grup",.F.,0)
   IF grup->(DbSeek(cGruppe))
      cGroupName := AllTrim(grup->Name)
   ENDIF
   grup->(DbCloseArea())
   DbSelectArea(nOldSelect)
   
RETURN cGroupName

FUNCTION GetEnhancedDescription(nArtikelnr)
   LOCAL cDescription := "", cExtendedText := "", cVariantOptions := ""
   LOCAL nOldSelect := Select()
   LOCAL oBase, nLen, cBase
   LOCAL aEnv 
   
   // Get basic description
   cDescription := AllTrim(HB_StrToUTF8(art->artikel))
   
   // Get extended text description if available
   IF art->textnr > 0
      NetUse("engtext2","tx",.F.,0)
      cExtendedText := tx->(ReadText(art->textnr))
      IF !Empty(cExtendedText)
         cExtendedText := AllTrim(HB_StrToUTF8(cExtendedText))
         // Limit extended text to reasonable length for API response
         IF Len(cExtendedText) > 200
            cExtendedText := Left(cExtendedText, 197) + "..."
         ENDIF
      ENDIF
      tx->(DbCloseArea())
   ENDIF
   
   // Get variant options if this is a variant article
   IF art->Variant == "V" .AND. art->length > 0
      cBase := SubStr(art->Matchcode, 1, art->length)
      NetUse("optbas","opb",.F.,0)
      NetUse("option","op",.F.,0)
      
      IF opb->(DbSeek(cBase))
         aEnv := SaveEnv()
         oBase := OptionBase():New()
         oBase:Load(cBase)
         nLen := art->Length + 1
         
         oBase:oTables:Each({|oTable|
            LOCAL oKey, cOptionText
            
            oKey := oTable:oKeys:GetRecord(SubStr(art->Matchcode, nLen, oTable:Length))
            IF oKey != NIL .AND. !Empty(oKey:Descript)
               nLen += oTable:Length
               cOptionText := AllTrim(oTable:funktion("DE")) + ": " + AllTrim(oKey:descript("DE"))
               IF !Empty(cVariantOptions)
                  cVariantOptions += " | "
               ENDIF
               cVariantOptions += cOptionText
            ENDIF
            RETURN NIL
         })
         RestEnv(aEnv)
      ENDIF
      
      opb->(DbCloseArea())
      op->(DbCloseArea())
   ENDIF
   
   // Combine all description parts
   IF !Empty(cExtendedText)
      cDescription += " - " + cExtendedText
   ENDIF
   
   IF !Empty(cVariantOptions)
      cDescription += " (" + cVariantOptions + ")"
   ENDIF
   
   DbSelectArea(nOldSelect)
   
RETURN cDescription

/*FUNCTION GetShopwareProductData(cUUID, hOptions)
   LOCAL oSW, hResult := {=>}, hResponse, hData
   LOCAL lIncludePrices, lIncludeMedia, lIncludeCategories
   LOCAL cMessage, hPrice
   LOCAL cParentId, hParentData, hParentResponse, bGetValue
   LOCAL nWeight, nWidth, nHeight, nLength
   LOCAL cMetaTitle, cMetaDescription, cKeywords
   LOCAL hFeatureSet, aProperties, aOptions
   LOCAL aPropertyIds, aParentPropertyIds, cId, lIsVariant
   LOCAL aRelProperties, aFormattedProps, hProp, hPropItem
   LOCAL aRelOptions, aFormattedOptions, hOption, hOptionItem, aOptionIds
   LOCAL hSendData, hProductData, hParentSendData, hParentProductData
   LOCAL aProductProps
   LOCAL aParentProps := {}

   
   // Parse options
   lIncludePrices := IIF(HHasKey(hOptions, "prices"), hOptions["prices"], .F.)
   lIncludeMedia := IIF(HHasKey(hOptions, "media"), hOptions["media"], .F.)
   lIncludeCategories := IIF(HHasKey(hOptions, "categories"), hOptions["categories"], .F.)
   
   // Initialize API
   oSW := ShopwareApi():New(.T.)
   IF !oSW:Auth()
      hResult["error"] := "Shopware authentication failed"
      hResult["status"] := "error"
      RETURN hResult
   ENDIF
   
   // Build search request to include associations
   hSendData := {;
      "filter"=>{;
         {;
            "type"=>"equals",;
            "field"=>"id",;
            "value"=>cUUID;
         };
      },;
      "associations"=>{;             
         "properties"=>{"associations"=>{"group"=>{}}},;         
         "manufacturer"=>{},;
         "unit"=>{},;
         "tax"=>{};
      },;
      "limit"=>1;
   }

         // Add price associations if requested
   IF lIncludePrices
      hSendData["associations"]["prices"] := {}
   ENDIF
   
   // Add media associations if requested  
   IF lIncludeMedia
      hSendData["associations"]["media"] := {}
   ENDIF
   
   // Execute API call with error handling
   BEGIN SEQUENCE
      hResponse := oSW:Execute("search/product", "POST", hSendData)
      
      // Temporary debug: Check if we got a response
      IF !HB_IsHash(hResponse)
         hResult["error"] := "No response from API"
         hResult["status"] := "error"
         //RETURN hResult
      ENDIF
      
      IF HB_IsHash(hResponse) .AND. HHasKey(hResponse, "data") .AND. HB_IsArray(hResponse["data"]) .AND. Len(hResponse["data"]) > 0
         // Search endpoint returns array of results, get first one
         hProductData := hResponse["data"][1]
         
         // Handle different possible response structures
         IF HHasKey(hProductData, "attributes")
            hData := hProductData["attributes"]
         ELSE
            hData := hProductData
         ENDIF
         
         // Check if this is a variant and get parent data if needed
         cParentId := IIF(HHasKey(hData, "parentId") .AND. hData["parentId"] != NIL, hData["parentId"], "")
         hParentData := NIL
         
         IF !Empty(cParentId)
            // Make a separate search call for parent product
            hParentSendData := {;
               "filter"=>{;
                  {;
                     "type"=>"equals",;
                     "field"=>"id",;
                     "value"=>cParentId;
                  };
               },;
               "associations"=>{;                  
                  "properties"=>{"associations"=>{"group"=>{}}};
               },;
               "limit"=>1;
            }
            
            hParentResponse := oSW:Execute("search/product", "POST", hParentSendData)
            
            IF HB_IsHash(hParentResponse) .AND. HHasKey(hParentResponse, "data") .AND. ;
               HB_IsArray(hParentResponse["data"]) .AND. Len(hParentResponse["data"]) > 0
               
               hParentProductData := hParentResponse["data"][1]
               IF HHasKey(hParentProductData, "attributes")
                  hParentData := hParentProductData["attributes"]
               ELSE
                  hParentData := hParentProductData
               ENDIF
            ENDIF
         ENDIF
         
         // Helper function to get value with inheritance
         bGetValue := {|cField, xDefault| 
            LOCAL xValue := IIF(HHasKey(hData, cField), hData[cField], NIL)
            IF xValue == NIL .AND. hParentData != NIL .AND. HHasKey(hParentData, cField)
               xValue := hParentData[cField]
            ENDIF
            RETURN IIF(xValue != NIL, xValue, xDefault)
         }
         
         // Basic product information  
         lIsVariant := !Empty(cParentId)
         hResult["uuid"] := IIF(HHasKey(hProductData, "id"), hProductData["id"], cUUID)
         hResult["parent_id"] := cParentId
         hResult["is_variant"] := lIsVariant
         
         // Get values with inheritance support
         hResult["product_number"] := AllTrim(Eval(bGetValue, "productNumber", ""))
         hResult["name"] := AllTrim(Eval(bGetValue, "name", ""))
         hResult["description"] := AllTrim(Eval(bGetValue, "description", ""))
         hResult["active"] := Eval(bGetValue, "active", .F.)
         hResult["available"] := Eval(bGetValue, "available", .F.)
         hResult["online_stock"] := IIF(HHasKey(hData, "stock") .AND. hData["stock"] != NIL, hData["stock"], 0)  // Stock is usually not inherited
         hResult["ean"] := AllTrim(Eval(bGetValue, "ean", ""))
         hResult["manufacturer_number"] := AllTrim(Eval(bGetValue, "manufacturerNumber", ""))
         hResult["updated_at"] := AllTrim(Eval(bGetValue, "updatedAt", ""))
         //hResult["response"] := hResponse  // Commented out debug info
         //hResult["parentResponse"] := hParentResponse  // Commented out debug info
         
         // Physical attributes with inheritance
         nWeight := Eval(bGetValue, "weight", NIL)
         nWidth := Eval(bGetValue, "width", NIL)
         nHeight := Eval(bGetValue, "height", NIL)
         nLength := Eval(bGetValue, "length", NIL)
         
         IF nWeight != NIL .OR. nWidth != NIL .OR. nHeight != NIL .OR. nLength != NIL
            hResult["physical"] := {;
               "weight" => nWeight,;
               "width" => nWidth,;
               "height" => nHeight,;
               "length" => nLength;
            }
         ENDIF
         
         // Custom fields
         IF HHasKey(hData, "customFields") .AND. hData["customFields"] != NIL
            hResult["custom_fields"] := hData["customFields"]
         ENDIF        
        
         // Product properties collated with parent properties by group name
         aProductProps := GetPropertiesFromIncluded(hResponse)         
         
         // Get parent properties if this is a variant
         IF lIsVariant .AND. !Empty(cParentId) .AND. hParentResponse != NIL
            aParentProps := GetPropertiesFromIncluded(hParentResponse)
         ENDIF
         
         // Collate properties by group name
         hResult["properties"] := CollatePropertiesByGroup(aProductProps, aParentProps)
         
         // Price information
         IF lIncludePrices .AND. HHasKey(hData, "price") .AND. HB_IsArray(hData["price"]) .AND. Len(hData["price"]) > 0
            hResult["prices"] := {}
            FOR EACH hPrice IN hData["price"]
               AAdd(hResult["prices"], {;
                  "net" => IIF(HHasKey(hPrice, "net"), hPrice["net"], 0),;
                  "gross" => IIF(HHasKey(hPrice, "gross"), hPrice["gross"], 0),;
                  "currency" => "EUR",;
                  "linked" => IIF(HHasKey(hPrice, "linked"), hPrice["linked"], .F.);
               })
            NEXT
         ENDIF
         
         // SEO data with inheritance
         cMetaTitle := AllTrim(Eval(bGetValue, "metaTitle", ""))
         cMetaDescription := AllTrim(Eval(bGetValue, "metaDescription", ""))
         cKeywords := AllTrim(Eval(bGetValue, "keywords", ""))
         
         IF !Empty(cMetaTitle) .OR. !Empty(cMetaDescription) .OR. !Empty(cKeywords)
            hResult["seo"] := {;
               "meta_title" => cMetaTitle,;
               "meta_description" => cMetaDescription,;
               "keywords" => cKeywords;
            }
         ENDIF
         
         hResult["status"] := "success"
      ELSE
         // More detailed error information
         IF HB_IsHash(hResponse)
            IF HHasKey(hResponse, "errors") .AND. HB_IsArray(hResponse["errors"]) .AND. Len(hResponse["errors"]) > 0
               hResult["error"] := "API Error: " + IIF(HHasKey(hResponse["errors"][1], "detail"), hResponse["errors"][1]["detail"], "Unknown error")
            ELSEIF HHasKey(hResponse, "data") .AND. HB_IsArray(hResponse["data"]) .AND. Len(hResponse["data"]) == 0
               hResult["error"] := "Product not found with ID: " + cUUID
               hResult["search_filter"] := hSendData["filter"]  // Show what filter was used
            ELSE
               hResult["error"] := "Unexpected response structure"
               hResult["debug_response_keys"] := IIF(HB_IsHash(hResponse), HB_HKeys(hResponse), {})
            ENDIF
         ELSE
            hResult["error"] := "Invalid response from Shopware API"
         ENDIF
         hResult["status"] := "error"
      ENDIF
      
   RECOVER USING cMessage
      hResult["error"] := "API Error: " + cMessage
      hResult["status"] := "error"
   END SEQUENCE
   
RETURN hResult

FUNCTION GetPropertiesFromIncluded(hResponse)
   LOCAL aProperties := {}, aIncluded, hItem, hPropData, hPropItem
   LOCAL hGroups := {=>}, hGroupItem, cGroupId
   
   IF !HB_IsHash(hResponse) .OR. !HHasKey(hResponse, "included") .OR. !HB_IsArray(hResponse["included"])
      RETURN aProperties
   ENDIF
   
   aIncluded := hResponse["included"]
   
   // First pass: collect all property groups
   FOR EACH hItem IN aIncluded
      IF HB_IsHash(hItem) .AND. HHasKey(hItem, "type") .AND. hItem["type"] == "property_group"
         IF HHasKey(hItem, "attributes") .AND. HB_IsHash(hItem["attributes"])
            hGroupItem := hItem["attributes"]
            cGroupId := IIF(HHasKey(hItem, "id"), hItem["id"], "")
            IF !Empty(cGroupId)
               hGroups[cGroupId] := IIF(HHasKey(hGroupItem, "name"), hGroupItem["name"], "")
            ENDIF
         ENDIF
      ENDIF
   NEXT
   
   // Second pass: collect property options and match with groups
   FOR EACH hItem IN aIncluded
      IF HB_IsHash(hItem) .AND. HHasKey(hItem, "type") .AND. hItem["type"] == "property_group_option"
         IF HHasKey(hItem, "attributes") .AND. HB_IsHash(hItem["attributes"])
            hPropData := hItem["attributes"]
         ELSE
            LOOP  // Skip invalid property
         ENDIF
         
         hPropItem := {=>}
         hPropItem["id"] := IIF(HHasKey(hItem, "id"), hItem["id"], "")
         hPropItem["name"] := IIF(HHasKey(hPropData, "name"), hPropData["name"], "")
         hPropItem["group_id"] := IIF(HHasKey(hPropData, "groupId"), hPropData["groupId"], "")
         hPropItem["position"] := IIF(HHasKey(hPropData, "position"), hPropData["position"], 0)
         
         // Add color if available
         IF HHasKey(hPropData, "colorHexCode") .AND. hPropData["colorHexCode"] != NIL
            hPropItem["color"] := hPropData["colorHexCode"]
         ENDIF
         
         // Add group name from our collected groups
         IF !Empty(hPropItem["group_id"]) .AND. HHasKey(hGroups, hPropItem["group_id"])
            hPropItem["group_name"] := hGroups[hPropItem["group_id"]]
         ENDIF
         
         AAdd(aProperties, hPropItem)
      ENDIF
   NEXT
   
RETURN aProperties

FUNCTION GetCombinedPropertiesFromIncluded(hResponse, aPropertyIds)
   LOCAL hCollated := {=>}, aIncluded, hItem, hPropData, hPropItem
   LOCAL hGroups := {=>}, hGroupItem, cGroupId, cGroupName
   LOCAL cItemId, cPropName
   
   IF !HB_IsHash(hResponse) .OR. !HHasKey(hResponse, "included") .OR. !HB_IsArray(hResponse["included"]) .OR. !HB_IsArray(aPropertyIds)
      RETURN hCollated
   ENDIF
   
   aIncluded := hResponse["included"]
   
   // First pass: collect all property groups
   FOR EACH hItem IN aIncluded
      IF HB_IsHash(hItem) .AND. HHasKey(hItem, "type") .AND. hItem["type"] == "property_group"
         IF HHasKey(hItem, "attributes") .AND. HB_IsHash(hItem["attributes"])
            hGroupItem := hItem["attributes"]
            cGroupId := IIF(HHasKey(hItem, "id"), hItem["id"], "")
            IF !Empty(cGroupId)
               hGroups[cGroupId] := IIF(HHasKey(hGroupItem, "name"), hGroupItem["name"], "")
            ENDIF
         ENDIF
      ENDIF
   NEXT
   
   // Second pass: collect and group properties by group name
   FOR EACH hItem IN aIncluded
      IF HB_IsHash(hItem) .AND. HHasKey(hItem, "type") .AND. hItem["type"] == "property_group_option"
         cItemId := IIF(HHasKey(hItem, "id"), hItem["id"], "")
         
         // Only include this property if it's in the product's combined propertyIds
         IF !Empty(cItemId) .AND. AScan(aPropertyIds, cItemId) > 0
            IF HHasKey(hItem, "attributes") .AND. HB_IsHash(hItem["attributes"])
               hPropData := hItem["attributes"]
               
               cGroupId := IIF(HHasKey(hPropData, "groupId"), hPropData["groupId"], "")
               IF !Empty(cGroupId) .AND. HHasKey(hGroups, cGroupId)
                  cGroupName := hb_strToUtf8(hGroups[cGroupId])
                  
                  // Initialize group if not exists
                  IF !HHasKey(hCollated, cGroupName)
                     hCollated[cGroupName] := {}
                  ENDIF
                  
                  // Add property name to group (avoid duplicates)
                  cPropName := hb_strToUtf8(IIF(HHasKey(hPropData, "name"), hPropData["name"], ""))
                  IF AScan(hCollated[cGroupName], cPropName) == 0
                     AAdd(hCollated[cGroupName], cPropName)
                  ENDIF
               ENDIF
            ENDIF
         ENDIF
      ENDIF
   NEXT
   
RETURN hCollated

FUNCTION CollatePropertiesByGroup(aProductProps, aParentProps)
   LOCAL hCollated := {=>}, hProp, cGroupName, cGroupKey
   LOCAL aAllProps := {}, nX
   LOCAL lExists

   
   // Combine all properties (product + parent)
   FOR EACH hProp IN aProductProps
      AAdd(aAllProps, hProp)
   NEXT
   
   FOR EACH hProp IN aParentProps
      AAdd(aAllProps, hProp)
   NEXT
   
   // Group properties by group name
   FOR EACH hProp IN aAllProps
      IF HB_IsHash(hProp) .AND. HHasKey(hProp, "group_name") .AND. !Empty(hProp["group_name"])
         cGroupName := hb_strToUtf8(hProp["group_name"])
         
         // Initialize group if not exists
         IF !HHasKey(hCollated, cGroupName)
            hCollated[cGroupName] := {}
         ENDIF
         
         // Add property to group (avoid duplicates by checking if property with same name already exists)
         lExists := .F.         
         FOR nX := 1 TO Len(hCollated[cGroupName])
            IF hCollated[cGroupName][nX] == hProp["name"]
               lExists := .T.
               EXIT
            ENDIF
         NEXT
         
         IF !lExists
            AAdd(hCollated[cGroupName], hb_strToUtf8(hProp["name"]))
         ENDIF
      ENDIF
   NEXT
   
RETURN hCollated*/

FUNCTION BuildDescriptionFilter(cSearchExpression)
   LOCAL cResult
   
   IF Empty(cSearchExpression)
      RETURN ""
   ENDIF
   
   // Convert to uppercase for case-insensitive search
   cResult := ParseExpression(Upper(AllTrim(cSearchExpression)))
   
RETURN cResult

STATIC FUNCTION ParseExpression(cExpr)
   LOCAL cResult := ""
   LOCAL nPos := 1
   LOCAL nLen := Len(cExpr)
   LOCAL cChar, nParenCount := 0
   LOCAL nStart, cSubExpr
   
   // Handle parentheses by finding matching pairs and recursively parsing
   DO WHILE nPos <= nLen
      cChar := SubStr(cExpr, nPos, 1)
      
      IF cChar == "("
         // Find matching closing parenthesis
         nStart := nPos + 1
         nParenCount := 1
         nPos++
         
         DO WHILE nPos <= nLen .AND. nParenCount > 0
            cChar := SubStr(cExpr, nPos, 1)
            IF cChar == "("
               nParenCount++
            ELSEIF cChar == ")"
               nParenCount--
            ENDIF
            nPos++
         ENDDO
         
         IF nParenCount == 0
            // Extract content inside parentheses and parse recursively
            cSubExpr := SubStr(cExpr, nStart, nPos - nStart - 1)
            cResult += "(" + ParseExpression(cSubExpr) + ")"
         ELSE
            // Unmatched parenthesis - treat as literal
            cResult += "("
            nPos := nStart
         ENDIF
      ELSE
         // Process non-parenthetical content
         nStart := nPos
         DO WHILE nPos <= nLen .AND. SubStr(cExpr, nPos, 1) != "("
            nPos++
         ENDDO
         
         cSubExpr := SubStr(cExpr, nStart, nPos - nStart)
         IF !Empty(AllTrim(cSubExpr))
            cResult += ParseSimpleExpression(cSubExpr)
         ENDIF
      ENDIF
   ENDDO
   
RETURN cResult

STATIC FUNCTION ParseSimpleExpression(cExpr)
   LOCAL cResult := ""
   LOCAL nStart := 1
   LOCAL nAnd, nOr, nNext
   LOCAL cTerm, cOperator
   LOCAL lFirstTerm := .T.
   
   // If no operators, do simple search
   IF !(" AND " $ cExpr) .AND. !(" OR " $ cExpr)
      cTerm := AllTrim(cExpr)
      IF !Empty(cTerm)
         // Escape quotes in the search term
         cTerm := StrTran(cTerm, '"', "'")
         RETURN '"' + cTerm + '" $ cValue'
      ENDIF
      RETURN ""
   ENDIF
   
   // Parse terms with AND/OR operators
   DO WHILE nStart <= Len(cExpr)
      // Find next operator
      nAnd := HB_At(" AND ", cExpr, nStart)
      nOr := HB_At(" OR ", cExpr, nStart)
      
      // Determine which operator comes first
      IF nAnd > 0 .AND. (nOr == 0 .OR. nAnd < nOr)
         nNext := nAnd
         cOperator := "AND"
      ELSEIF nOr > 0
         nNext := nOr
         cOperator := "OR"
      ELSE
         nNext := 0
      ENDIF
      
      // Extract the term
      IF nNext > 0
         cTerm := AllTrim(SubStr(cExpr, nStart, nNext - nStart))
         nStart := nNext + IIF(cOperator == "AND", 5, 4)  // Skip " AND " or " OR "
      ELSE
         cTerm := AllTrim(SubStr(cExpr, nStart))
         nStart := Len(cExpr) + 1
      ENDIF
      
      // Build the filter expression
      IF !Empty(cTerm)
         IF !lFirstTerm
            cResult += IIF(cOperator == "AND", " .AND. ", " .OR. ")
         ENDIF
         
         // Remove quotes in the search term
         cTerm := StrTran(cTerm, '"', "")         
         cResult += '"' + cTerm + '" $ cValue'
         lFirstTerm := .F.
      ENDIF
   ENDDO
   
RETURN cResult

FUNCTION MCP_Tool_Get_Customer_Orders(hArgs)
   LOCAL hResult := {=>}
   LOCAL aOrders := {}
   LOCAL hOrder
   LOCAL cCustomer
   LOCAL oAuftrag,oKunde
   LOCAL cStatus := "all"
  
   // Return schema and description when called without arguments
   IF hArgs == NIL .OR. ValType(hArgs) != "H" .OR. Len(hArgs) == 0
      hResult["schema"] := {;
         "type"=>"object",;
         "properties"=>{;
            "customer_number"=>{"type"=>"number","description"=>"Customer number"},;
            "status_filter"=>{"type"=>"string","description"=>"Filter by status (open, completed, all)"};
         },;
         "required"=>{"customer_number"};
      }
      hResult["description"] := "Get all orders for a specific customer"
      RETURN hResult
   ENDIF

   IF HHasKey(hArgs,"status_filter") .AND. hArgs["status_filter"] $ {"open","completed"}
      cStatus := hArgs["status_filter"]
   ENDIF
   NetUse("auftrag","ab")  // Ensure order database is available
   oKunde := Adresse():New()
   IF HHasKey(hArgs,"customer_number") .AND. ! Empty(hArgs["customer_number"]) .AND. oKunde:Load(hArgs["customer_number"])
      hResult["customer"] := oKunde:Kunde
      
      ab->(DbSetOrder(2))  // Assume order 2 is by customer number
      IF ab->(DbSeek(oKunde:Kunde))
         WHILE ab->kundma == oKunde:Kunde .AND. !ab->(Eof())
            oAuftrag := Auftrag():New(.F.)
            IF cStatus == "all" .OR. (cStatus == "open" .AND. !oAuftrag:Erledigt) .OR. (cStatus == "completed" .AND. oAuftrag:Erledigt)
               hOrder := {=>}
               hOrder["order_number"] := oAuftrag:Abnr
               hOrder["date"] := oAuftrag:Besda
               hOrder["completed"] := oAuftrag:Erledigt
               hOrder["total"] := oAuftrag:total
            
               AAdd(aOrders, hOrder)
            ENDIF
            ab->(DbSkip())
         ENDDO
      ENDIF
      
      hResult["orders"] := aOrders
      hResult["count"] := Len(aOrders)
      hResult["status"] := "found"
   ELSE
      hResult["status"] := "error"
      hResult["message"] := "Invalid customer number"
   ENDIF
   
RETURN hResult

/*FUNCTION MCP_Tool_Get_Property_Groups(hArgs)
   LOCAL hResult := {=>}
   LOCAL oSW, hResponse, hSendData
   LOCAL aIncluded, hItem, hGroupData, hOptionData
   LOCAL hGroups := {=>}, cGroupId, cGroupName
   LOCAL hOptions := {=>}, hOptionItem
   
   // Return schema and description when called without arguments
   IF hArgs == NIL .OR. ValType(hArgs) != "H" .OR. Len(hArgs) == 0
      hResult["schema"] := {;
         "type"=>"object",;
         "properties"=>{=>},;
         "required"=>{};
      }
      hResult["description"] := "Get all available product properties and their options for filtering products. " + ;
                                "Use this BEFORE searching products to discover filterable properties like: " + ;
                                "- Colors (red, blue, green...); " + ;
                                "- Materials (steel, aluminum, plastic...); " + ;
                                "- Sizes (S, M, L, XL...); " + ;
                                "- Technical specifications. " + ;
                                "Example workflow: " + ;
                                "1. Call get_property_groups to see available properties; " + ;
                                "2. Note the property IDs you need; " + ;
                                "3. Use those IDs in get_catalogue with property_ids parameter to filter products. " + ;
                                "Returns a hash where keys are property group names and values are arrays of available options."
      RETURN hResult
   ENDIF
   
   // Initialize API
   oSW := ShopwareApi():New(.T.)
   IF !oSW:Auth()
      hResult["error"] := "Shopware authentication failed"
      hResult["status"] := "error"
      RETURN hResult
   ENDIF
   
   // Build search request for property groups with options
   hSendData := {;
      "associations"=>{;
         "options"=>{};  // Include all options for each group
      },;
      "limit"=>500;  // Get all groups
   }
   
   // Execute API call
   BEGIN SEQUENCE
      hResponse := oSW:Execute("search/property-group", "POST", hSendData)
      
      IF HB_IsHash(hResponse) .AND. HHasKey(hResponse, "data") .AND. HB_IsArray(hResponse["data"])
         // First collect all groups from data
         FOR EACH hItem IN hResponse["data"]
            IF HB_IsHash(hItem) .AND. HHasKey(hItem, "attributes") .AND. HB_IsHash(hItem["attributes"])
               hGroupData := hItem["attributes"]
               cGroupId := IIF(HHasKey(hItem, "id"), hItem["id"], "")
               cGroupName := IIF(HHasKey(hGroupData, "name"), hb_strToUtf8(hGroupData["name"]), "")

               IF !Empty(cGroupId) .AND. !Empty(cGroupName)
                  hGroups[cGroupId] := cGroupName
                  hOptions[cGroupName] := {}
               ENDIF
            ENDIF
         NEXT
         
         // Then collect options from included section
         IF HHasKey(hResponse, "included") .AND. HB_IsArray(hResponse["included"])
            aIncluded := hResponse["included"]
            
            FOR EACH hItem IN aIncluded
               IF HB_IsHash(hItem) .AND. HHasKey(hItem, "type") .AND. hItem["type"] == "property_group_option"
                  IF HHasKey(hItem, "attributes") .AND. HB_IsHash(hItem["attributes"])
                     hOptionData := hItem["attributes"]
                     
                     hOptionItem := {=>}
                     hOptionItem["id"] := IIF(HHasKey(hItem, "id"), hItem["id"], "")
                     hOptionItem["name"] := IIF(HHasKey(hOptionData, "name"), hb_strToUTf8(hOptionData["name"]), "")
                     hOptionItem["position"] := IIF(HHasKey(hOptionData, "position"), hOptionData["position"], 0)
                     
                     // Add color if available
                     IF HHasKey(hOptionData, "colorHexCode") .AND. hOptionData["colorHexCode"] != NIL
                        hOptionItem["color"] := hOptionData["colorHexCode"]
                     ENDIF
                     
                     // Add media ID if available
                     IF HHasKey(hOptionData, "mediaId") .AND. hOptionData["mediaId"] != NIL
                        hOptionItem["media_id"] := hOptionData["mediaId"]
                     ENDIF
                     
                     // Find which group this option belongs to
                     cGroupId := IIF(HHasKey(hOptionData, "groupId"), hOptionData["groupId"], "")
                     IF !Empty(cGroupId) .AND. HHasKey(hGroups, cGroupId)
                        cGroupName := hGroups[cGroupId]
                        IF HHasKey(hOptions, cGroupName)
                           AAdd(hOptions[cGroupName], hOptionItem)
                        ENDIF
                     ENDIF
                  ENDIF
               ENDIF
            NEXT
         ENDIF
         
         // Sort options within each group by position
         FOR EACH cGroupName IN HB_HKeys(hOptions)
            ASort(hOptions[cGroupName],,, {|a,b| a["position"] < b["position"]})
         NEXT
         
         hResult := hOptions
         hResult["status"] := "success"
      ELSE
         hResult["error"] := "Failed to retrieve property groups"
         hResult["status"] := "error"
      ENDIF
      
   RECOVER USING cMessage
      hResult["error"] := "API Error: " + cMessage
      hResult["status"] := "error"
   END SEQUENCE
   
RETURN hResult*/

/*FUNCTION MCP_Tool_Get_Catalogue(hArgs)
   LOCAL hResult := {=>}
   LOCAL oSW, hResponse, hSendData
   LOCAL aFilters := {}, hFilter
   LOCAL nLimit, nPage
   LOCAL aProducts := {}, hProduct, hProductData
   LOCAL cSearchTerm, aPropertyIds, cPropId
   LOCAL hProd := {=>}
   LOCAL cMessage  // For error handling
   LOCAL aCleanPropertyIds
   LOCAL aAllProducts := {}, aParentIds := {}, hParentData := {=>}
   LOCAL aProductProps, aParentProps, aCombinedProps, lHasAllProps
   LOCAL hParentSendData, hParentResponse
   LOCAL aProductProperties, aParentProperties
   LOCAL aCombinedIds, cId
   
   // Return schema and description when called without arguments
   IF hArgs == NIL .OR. ValType(hArgs) != "H" .OR. Len(hArgs) == 0
      hResult["schema"] := {;
         "type"=>"object",;
         "properties"=>{;
            "search"=>{"type"=>"string","description"=>"Search term for product name or number"},;
            "active"=>{"type"=>"boolean","description"=>"Filter by active status"},;
            "available"=>{"type"=>"boolean","description"=>"Filter by availability"},;
            "manufacturer_id"=>{"type"=>"string","description"=>"Filter by manufacturer ID"},;
            "property_ids"=>{"type"=>"array","items"=>{"type"=>"string"},"description"=>"Filter by property option IDs"},;
            "min_price"=>{"type"=>"number","description"=>"Minimum price filter"},;
            "max_price"=>{"type"=>"number","description"=>"Maximum price filter"},;
            "min_stock"=>{"type"=>"integer","description"=>"Minimum stock level filter"},;
            "max_stock"=>{"type"=>"integer","description"=>"Maximum stock level filter"},;
            "in_stock"=>{"type"=>"boolean","description"=>"Filter products that are in stock (stock > 0)"},;
            "limit"=>{"type"=>"integer","description"=>"Number of results to return (default: 50, max: 500)"},;
            "page"=>{"type"=>"integer","description"=>"Page number for pagination (default: 1)"};
         },;
         "required"=>{};
      }
      hResult["description"] := "Search and filter products from our online shop. This is the PRIMARY TOOL for product searches. " + ;
                                "Supports filtering by: " + ;
                                "- Product properties (color, size, material, etc.) - use get_property_groups first to see available options; " + ;
                                "- Search terms (product name/number); " + ;
                                "- Stock levels and availability; " + ;
                                "- Price ranges; " + ;
                                "- Manufacturer. " + ;
                                "Examples: " + ;
                                '- Find products with specific properties: {"property_ids": ["prop-id-1", "prop-id-2"]} (ALL properties must match); ' + ;
                                '- Find products in stock under 50 EUR: {"in_stock": true, "max_price": 50}; ' + ;
                                '- Search by name: {"search": "cable"}; ' + ;
                                '- Combine filters: {"search": "resistor", "property_ids": ["color-red-id"], "in_stock": true}. ' + ;
                                "Always prefer this tool over search_articles for online shop products."
      RETURN hResult
   ENDIF
   
   // Parse parameters
   nLimit := IIF(HHasKey(hArgs, "limit") .AND. HB_IsNumeric(hArgs["limit"]), Min(hArgs["limit"], 500), 50)
   nPage := IIF(HHasKey(hArgs, "page") .AND. HB_IsNumeric(hArgs["page"]), Max(hArgs["page"], 1), 1)
   
   // Initialize API
   oSW := ShopwareApi():New(.T.)
   IF !oSW:Auth()
      hResult["error"] := "Shopware authentication failed"
      hResult["status"] := "error"
      RETURN hResult
   ENDIF
   
   // Build filters
   // Search term filter
   IF HHasKey(hArgs, "search") .AND. !Empty(hArgs["search"])
      cSearchTerm := AllTrim(hArgs["search"])
      AAdd(aFilters, {;
         "type"=>"multi",;
         "operator"=>"or",;
         "queries"=>{;
            {"type"=>"contains", "field"=>"name", "value"=>cSearchTerm},;
            {"type"=>"contains", "field"=>"productNumber", "value"=>cSearchTerm};
         };
      })
   ENDIF
   
   // Active filter
   IF HHasKey(hArgs, "active") .AND. HB_IsLogical(hArgs["active"])
      AAdd(aFilters, {"type"=>"equals", "field"=>"active", "value"=>hArgs["active"]})
   ENDIF
   
   // Available filter
   IF HHasKey(hArgs, "available") .AND. HB_IsLogical(hArgs["available"])
      AAdd(aFilters, {"type"=>"equals", "field"=>"available", "value"=>hArgs["available"]})
   ENDIF
   
   // Manufacturer filter
   IF HHasKey(hArgs, "manufacturer_id") .AND. !Empty(hArgs["manufacturer_id"])
      AAdd(aFilters, {"type"=>"equals", "field"=>"manufacturerId", "value"=>hArgs["manufacturer_id"]})
   ENDIF
   
   // Property filter - combine propertyIds (inherited) and optionIds (product-specific)
   // Store clean property IDs for later use
   aCleanPropertyIds := {}
   IF HHasKey(hArgs, "property_ids") .AND. HB_IsArray(hArgs["property_ids"]) .AND. Len(hArgs["property_ids"]) > 0
      FOR EACH cPropId IN hArgs["property_ids"]
         IF !Empty(cPropId)
            AAdd(aCleanPropertyIds, cPropId)
         ENDIF
      NEXT
   ENDIF
   
   // Price range filter
   IF HHasKey(hArgs, "min_price") .AND. HB_IsNumeric(hArgs["min_price"])
      AAdd(aFilters, {"type"=>"range", "field"=>"price.gross", "parameters"=>{"gte"=>hArgs["min_price"]}})
   ENDIF
   
   IF HHasKey(hArgs, "max_price") .AND. HB_IsNumeric(hArgs["max_price"])
      AAdd(aFilters, {"type"=>"range", "field"=>"price.gross", "parameters"=>{"lte"=>hArgs["max_price"]}})
   ENDIF
   
   // Stock level filters
   IF HHasKey(hArgs, "min_stock") .AND. HB_IsNumeric(hArgs["min_stock"])
      AAdd(aFilters, {"type"=>"range", "field"=>"stock", "parameters"=>{"gte"=>hArgs["min_stock"]}})
   ENDIF
   
   IF HHasKey(hArgs, "max_stock") .AND. HB_IsNumeric(hArgs["max_stock"])
      AAdd(aFilters, {"type"=>"range", "field"=>"stock", "parameters"=>{"lte"=>hArgs["max_stock"]}})
   ENDIF
   
   // In stock filter (stock > 0)
   IF HHasKey(hArgs, "in_stock") .AND. HB_IsLogical(hArgs["in_stock"]) .AND. hArgs["in_stock"]
      AAdd(aFilters, {"type"=>"range", "field"=>"stock", "parameters"=>{"gt"=>0}})
   ENDIF
   
   // Build search request
   hSendData := {;
      "limit"=>nLimit,;
      "page"=>nPage,;
      "associations"=>{;
         "manufacturer"=>{},;
         "properties"=>{"associations"=>{"group"=>{}}},;
         "options"=>{"associations"=>{"group"=>{}}};
      },;
      "includes"=>{;
         "product"=>{;
            "id", "productNumber", "name", "description", "active", "available",;
            "stock", "price", "ean", "manufacturerNumber", "weight", "width", "height", "length",;
            "propertyIds", "optionIds", "parentId";
         };
      };
   }
   
   // Execute search
   BEGIN SEQUENCE
      // Special handling for property filters - need to check ALL properties match
      IF Len(aCleanPropertyIds) > 0
         // Create AND filter for ALL properties - each property must be present
         FOR EACH cPropId IN aCleanPropertyIds
            // Create OR filter to check property in both propertyIds and optionIds
            AAdd(aFilters, {;
               "type"=>"multi",;
               "operator"=>"or",;
               "queries"=>{;
                  {"type"=>"contains", "field"=>"propertyIds", "value"=>cPropId},;
                  {"type"=>"contains", "field"=>"optionIds", "value"=>cPropId};
               };
            })
         NEXT
      ENDIF
      
      // Update filter in send data
      IF Len(aFilters) > 0
         IF Len(aFilters) == 1
            hSendData["filter"] := aFilters
         ELSE
            hSendData["filter"] := {{;
               "type"=>"multi",;
               "operator"=>"and",;
               "queries"=>aFilters;
            }}
         ENDIF
      ENDIF
      
      hResponse := oSW:Execute("search/product", "POST", hSendData)
      
      IF HB_IsHash(hResponse) .AND. HHasKey(hResponse, "data") .AND. HB_IsArray(hResponse["data"])
         
         // Process all products (already filtered by API)
         FOR EACH hProduct IN hResponse["data"]
            IF HB_IsHash(hProduct) .AND. HHasKey(hProduct, "attributes")
               hProductData := hProduct["attributes"]
               
               // Build product result    
               hProd := {=>}           
               hProd["id"] := IIF(HHasKey(hProduct, "id"), hProduct["id"], "")
               hProd["product_number"] := IIF(HHasKey(hProductData, "productNumber"), hProductData["productNumber"], "")
               hProd["name"] := IIF(HHasKey(hProductData, "name"), hb_strtoutf8(hProductData["name"]), "")
               hProd["description"] := IIF(HHasKey(hProductData, "description"), hb_strtoutf8(hProductData["description"]), "")
               hProd["active"] := IIF(HHasKey(hProductData, "active"), hProductData["active"], .F.)
               hProd["available"] := IIF(HHasKey(hProductData, "available"), hProductData["available"], .F.)
               hProd["stock"] := IIF(HHasKey(hProductData, "stock"), hProductData["stock"], 0)
               hProd["ean"] := IIF(HHasKey(hProductData, "ean"), hProductData["ean"], "")
               hProd["parent_id"] := IIF(HHasKey(hProductData, "parentId"), hProductData["parentId"], "")
               hProd["property_ids"] := IIF(HHasKey(hProductData, "propertyIds"), hProductData["propertyIds"], {})
               hProd["option_ids"] := IIF(HHasKey(hProductData, "optionIds").AND.hProductData["optionIds"]!=NIL, hProductData["optionIds"], {})
               
               // Combine propertyIds (inherited) and optionIds (product-specific) for complete property list
               aCombinedIds := AClone(hProd["property_ids"])
               FOR EACH cId IN hProd["option_ids"]
                  IF AScan(aCombinedIds, cId) == 0
                     AAdd(aCombinedIds, cId)
                  ENDIF
               NEXT
               hProd["all_property_ids"] := aCombinedIds
               
               // Price information
               IF HHasKey(hProductData, "price") .AND. HB_IsArray(hProductData["price"]) .AND. Len(hProductData["price"]) > 0
                  hProd["price"] := {;
                     "net" => IIF(HHasKey(hProductData["price"][1], "net"), hProductData["price"][1]["net"], 0),;
                     "gross" => IIF(HHasKey(hProductData["price"][1], "gross"), hProductData["price"][1]["gross"], 0);
                  }
               ENDIF
               
               // Add properties from included section using combined property IDs
               hProd["properties"] := GetCombinedPropertiesFromIncluded(hResponse, hProd["all_property_ids"])
               
               AAdd(aProducts, hProd)
            ENDIF
         NEXT
         
         hResult["products"] := aProducts
         //debugging information
         hResult["respone"] := hResponse  // Include full response for debugging
         IF HHasKey(hSendData, "filter")
            hResult["search_filter"] := hSendData["filter"]  // Show what filter was used
         ENDIF         
         hResult["args"] := hArgs  // Include original arguments for debugging
         //end debugging information
         hResult["total"] := IIF(HHasKey(hResponse, "total"), hResponse["total"], Len(aProducts))
         hResult["page"] := nPage
         hResult["limit"] := nLimit
         hResult["status"] := "success"
      ELSE
         // More detailed error information
         IF HB_IsHash(hResponse)
            IF HHasKey(hResponse, "errors") .AND. HB_IsArray(hResponse["errors"]) .AND. Len(hResponse["errors"]) > 0
               hResult["error"] := "API Error: " + IIF(HHasKey(hResponse["errors"][1], "detail"), hResponse["errors"][1]["detail"], "Unknown error")
               hResult["api_errors"] := hResponse["errors"]
            ELSEIF HHasKey(hResponse, "data") .AND. HB_IsArray(hResponse["data"]) .AND. Len(hResponse["data"]) == 0
               hResult["error"] := "No products found matching the search criteria"
               hResult["search_filter"] := hSendData["filter"]  // Show what filter was used
            ELSE
               hResult["error"] := "Unexpected response structure from API"
               hResult["debug_response_keys"] := IIF(HB_IsHash(hResponse), HB_HKeys(hResponse), {})
            ENDIF
         ELSE
            hResult["error"] := "Invalid response from Shopware API (not a hash)"
            hResult["response_type"] := ValType(hResponse)
         ENDIF
         hResult["status"] := "error"
         hResult["request_data"] := hSendData  // Include the request that was sent
      ENDIF
      
   RECOVER      
      hResult["status"] := "error"
      hResult["request_data"] := hSendData  // Include the request that was sent
   END SEQUENCE
   
RETURN hResult*/

FUNCTION MCP_Resources_List(hRequest, xId)
   LOCAL aResources := {}
   LOCAL aFuncNames, cFuncName, cResourceName, hResource
   
   // Dynamically discover all MCP_Resource_* functions
   aFuncNames := GetFunctionsWithPrefix("MCP_RESOURCE_")
   
   FOR EACH cFuncName IN aFuncNames
      // Convert MCP_RESOURCE_CUSTOMERS to customers
      cResourceName := Lower(SubStr(cFuncName, 14))  // Remove "MCP_RESOURCE_"
      
      hResource := {=>}
      hResource["uri"] := TraderUrl("trader://" + cResourceName)
      hResource["name"] := GetResourceName(cResourceName)
      hResource["description"] := GetResourceDescription(cResourceName)
      hResource["mimeType"] := "application/json"
      
      AAdd(aResources, hResource)
   NEXT
   
RETURN CreateSuccessResponse({"resources"=>aResources}, xId)

FUNCTION GetResourceName(cResourceName)
   LOCAL hNames := {;
      "customers" => "Customer Database",;
      "orders" => "Sales Orders";
   }
   
RETURN IIF(HHasKey(hNames, cResourceName), hNames[cResourceName], cResourceName)

FUNCTION GetResourceDescription(cResourceName)
   LOCAL hDescriptions := {;
      "customers" => "Complete customer database with addresses and contact information",;
      "orders" => "All sales orders in the system";
   }
   
RETURN IIF(HHasKey(hDescriptions, cResourceName), hDescriptions[cResourceName], "Resource: " + cResourceName)

FUNCTION MCP_Resources_Read(hRequest, xId)
   LOCAL hParams := hRequest["params"]
   LOCAL cUri := hParams["uri"]
   LOCAL cResourceName, cFunctionName, cContent, hResourceData
   
   // Extract resource name from URI: trader://customers -> customers
   IF Left(cUri, 9) == "trader://"
      cResourceName := SubStr(cUri, 10)
      // Convert to function name: customers -> MCP_Resource_Customers
      cFunctionName := "MCP_Resource_" + cResourceName
      
      // Check if function exists and call it dynamically
      IF Type(cFunctionName + "()") != "U"
         hResourceData := HB_ExecFromArray(cFunctionName, {})
      
         cContent := HB_JsonEncode(hResourceData)
      ELSE
         RETURN CreateErrorResponse("Resource not found: " + cUri + " (function: " + cFunctionName + ")", xId)
      ENDIF
   ELSE
      RETURN CreateErrorResponse("Invalid resource URI: " + cUri, xId)
   ENDIF

RETURN CreateSuccessResponse({"contents"=>{{"uri"=>cUri,"mimeType"=>"application/json","text"=>cContent}}}, xId)

FUNCTION MCP_Resource_Customers()
   LOCAL hResult := {=>}
   LOCAL aCustomers := {}
   
   LOCAL hCustomer
   NetUse("engkund","ku")  // Ensure customer database is available
   ku->(dbSetOrder( 2 ))
   ku->(dbSeek( "K") )
   
   WHILE !ku->(Eof()) .AND. ku->Group == "K" 
      hCustomer := {=>}
      hCustomer["number"] := ku->nummer
      hCustomer["matchcode"] := Trim(ku->Kunde)
      hCustomer["name"] := AllTrim(ku->name1)
      hCustomer["city"] := AllTrim(ku->town)
      
      AAdd(aCustomers, hCustomer)
      
      ku->(DbSkip())
   ENDDO
   
   hResult["customers"] := aCustomers
   
RETURN hResult

// Removed - converted to MCP_Tool_Search_Articles
/*
FUNCTION MCP_Resource_Articles()
   LOCAL hResult := {=>}
   LOCAL aArticles := {}
   LOCAL nCount := 0
   LOCAL hArticle

   NetUse("artikel","art")  // Ensure article database is available

   art->(DbGoTop())
   
   WHILE !art->(Eof()) //.AND. nCount < 10  // Limit to first 10 for demo
      IF ! art->Obsolete
         hArticle := {=>}
         hArticle["matchcode"] := AllTrim(art->matchcode)
         hArticle["description"] := AllTrim(art->artikel)
         hArticle["stock"] := art->bestand
         
         AAdd(aArticles, hArticle)
         nCount++
      ENDIF
      art->(DbSkip())
   ENDDO
   
   hResult["articles"] := aArticles
   
RETURN hResult
*/

FUNCTION MCP_Resource_Orders()
   LOCAL hResult := {=>}
   LOCAL aOrders := {}
   LOCAL nCount := 0
   LOCAL hOrder,oPos

   NetUse("engauf","auf")
   auf->(DbGoTop())
   WHILE !auf->(Eof()) .AND. nCount < 10  // Limit to first 10 for demo
   
      hOrder := {=>}
      hOrder["order_number"] := auf->abnr
      hOrder["customer"] := auf->kundma
      hOrder["date"] := auf->besda
      hOrder["completed"] := AUF->BESTAT == 3 .OR. auf->bestat == 7
      hOrder["article"] := AllTrim(AUF->Matchcode)      
      hOrder["quantity"] := AUF->VkQty
      hOrder["open_quantity"] := AUF->VkQty - AUF->GelQty
      hOrder["price"] := AUF->VkPr/AUF->Pe
   

      
      AAdd(aOrders, hOrder)
      nCount++
      auf->(DbSkip())
   ENDDO
   
   hResult["orders"] := aOrders
   
RETURN hResult

FUNCTION CreateSuccessResponse(hResult, xId)
   LOCAL hResponse := {=>}
   
   hResponse["jsonrpc"] := "2.0"
   hResponse["id"] := xId
   hResponse["result"] := hResult
   
RETURN HB_JsonEncode(hResponse)

FUNCTION CreateErrorResponse(cMessage, xId)
   LOCAL hResponse := {=>}
   LOCAL hError := {=>}
   
   hError["code"] := -32603  // Internal error code
   hError["message"] := cMessage
   
   hResponse["jsonrpc"] := "2.0"
   hResponse["id"] := xId  // Keep original ID, even if null
   hResponse["error"] := hError
   
RETURN HB_JsonEncode(hResponse)

FUNCTION MCPErrorHandler(oError, nStdOut)
   LOCAL hResponse := {=>}
   LOCAL hError := {=>}
   LOCAL cErrorMsg,cResponse
   
   cResponse := CreateErrorResponse("Invalid JSON in request", "")

   /*// Build error message
   cErrorMsg := "Runtime Error: " + oError:description
   IF !Empty(oError:operation)
      cErrorMsg += " (" + oError:operation + ")"
   ENDIF
   IF !Empty(oError:filename)
      cErrorMsg += " in " + oError:filename + ":" + AllTrim(Str(oError:line))
   ENDIF
   
   // Create JSON-RPC error response
   hError["code"] := -32603  // Internal error
   hError["message"] := cErrorMsg
   hError["data"] := {;
      "subsystem"=>oError:subsystem,;
      "subcode"=>oError:subcode,;
      "severity"=>oError:severity;
   }
   
   hResponse["jsonrpc"] := "2.0"
   hResponse["id"] := ""
   hResponse["error"] := hError
   
   // Write error response to stdout
   FWrite(nStdOut, HB_JsonEncode(hResponse) + Chr(10))*/
   
    FWrite(nStdOut, cResponse + Chr(10))
   
RETURN NIL

//---------------------------------------------------------------------------
// David Inbox tools — read-only access to the Tobit David InfoCenter.
//
// These wrap the David OLE API exposed by source\david.prg (MailConnect /
// DV_GetMailAccount → oAccount) which is linked into the trader binary. All
// OLE access is guarded so a bad item or a missing David connection returns a
// clean status instead of crashing the MCP loop.
//---------------------------------------------------------------------------

// Convert a David (Windows-ANSI) string to UTF-8 for JSON output. Translate
// CP1252 (DEWIN) to UTF-8 directly instead of the old ANSI->OEM->UTF-8 chain,
// which silently depended on the process' selected codepage matching the OS
// OEM codepage.
STATIC FUNCTION DV_Utf8(cStr)
   IF ValType(cStr) != "C"
      RETURN ""
   ENDIF
RETURN hb_Translate(cStr, "DEWIN", "UTF8")

// Serialize a David message time (timestamp, occasionally a date) to a
// sortable ISO-ish string.
STATIC FUNCTION DV_DateStr(xTime)
   LOCAL cResult := ""
   BEGIN SEQUENCE
      DO CASE
      CASE ValType(xTime) == "T"
         cResult := HB_TSToStr(xTime)
      CASE ValType(xTime) == "D" .AND. ! Empty(xTime)
         cResult := StrZero(Year(xTime),4) + "-" + StrZero(Month(xTime),2) + "-" + StrZero(Day(xTime),2)
      OTHERWISE
         cResult := ""
      ENDCASE
   RECOVER
      cResult := ""
   END SEQUENCE
RETURN cResult

// Resolve the David archive object for the requested mailbox, connecting first.
// Returns NIL if David is not available.
STATIC FUNCTION Inbox_Archive(cMailbox)
   LOCAL oAccount, oArchive := NIL, nArchive

   IF ValType(cMailbox) != "C"
      cMailbox := "inbox"
   ENDIF
   nArchive := IIF(Lower(cMailbox) == "common", DvArchiveCommon, DvArchivePersonalIn)

   BEGIN SEQUENCE
      MailConnect()  // idempotent - no-op if already connected
      oAccount := DV_GetMailAccount()
      IF oAccount != NIL
         oArchive := oAccount:GetSpecialArchive(nArchive)
      ENDIF
   RECOVER
      oArchive := NIL
   END SEQUENCE
RETURN oArchive

// Read/unread state of a message via the documented DvApi archive-item
// property Viewed (Viewed = message has been read). Returns NIL when the
// property does not answer - callers then omit the field instead of guessing.
STATIC FUNCTION DV_Unread(oItem)
   LOCAL xVal := NIL

   BEGIN SEQUENCE
      xVal := oItem:Viewed
   RECOVER
      xVal := NIL
   END SEQUENCE
   IF ValType(xVal) == "N"  // numeric representation: 0 = not viewed
      xVal := xVal != 0
   ENDIF
RETURN IIF(ValType(xVal) == "L", ! xVal, NIL)

// Build a one-line summary hash for a single message. Each property read is
// guarded so one malformed item never aborts a listing.
STATIC FUNCTION Inbox_Summary(oItem)
   LOCAL hMsg := {=>}
   LOCAL xUnread

   hMsg["id"] := ""
   hMsg["subject"] := ""
   hMsg["sender"] := ""
   hMsg["date"] := ""
   hMsg["recipient_count"] := 0
   hMsg["attachment_count"] := 0
//oItem:_ID
//
   BEGIN SEQUENCE ; hMsg["id"]      := oItem:Fields:Item("FileName"):Value                  ; RECOVER ; END SEQUENCE
   BEGIN SEQUENCE ; hMsg["subject"] := DV_Utf8(oItem:Subject)        ; RECOVER ; END SEQUENCE
   BEGIN SEQUENCE ; hMsg["sender"] := DV_Utf8(oItem:Fields:Item("SRFrom"):Value); RECOVER; hMsg["sender"] := ""; END SEQUENCE
   BEGIN SEQUENCE ; hMsg["date"]    := DV_DateStr(oItem:StatusTime)  ; RECOVER ; END SEQUENCE
   BEGIN SEQUENCE ; hMsg["recipient_count"]  := oItem:Recipients:Count  ; RECOVER ; END SEQUENCE
   BEGIN SEQUENCE ; hMsg["attachment_count"] := oItem:Attachments:Count ; RECOVER ; END SEQUENCE
   xUnread := DV_Unread(oItem)
   IF xUnread != NIL
      hMsg["unread"] := xUnread
   ENDIF
RETURN hMsg

FUNCTION MCP_Tool_List_Inbox(hArgs)
   LOCAL hResult := {=>}
   LOCAL oArchive, oItem, nI, nCount
   LOCAL cMailbox := "inbox", nLimit := 50, nOffset := 0
   LOCAL nScan, nFirst
   LOCAL lUnreadOnly := .F., lAnyReadState := .F.
   LOCAL hMsg
   LOCAL aMessages := {}, aPage := {}

   // Return schema and description when called without arguments
   IF hArgs == NIL .OR. ValType(hArgs) != "H" .OR. Len(hArgs) == 0
      hResult["schema"] := {;
         "type"=>"object",;
         "properties"=>{;
            "mailbox"=>{"type"=>"string","enum"=>{"inbox","common"},"description"=>"Which mailbox to list: 'inbox' (personal Inbox, default) or 'common' (shared archive)"},;
            "unread_only"=>{"type"=>"boolean","description"=>"If true, return only unread messages (default false)"},;
            "limit"=>{"type"=>"integer","description"=>"Maximum number of messages to return (default 50)"},;
            "offset"=>{"type"=>"integer","description"=>"Number of newest messages to skip (default 0)"},;
            "scan_limit"=>{"type"=>"integer","description"=>"Maximum number of archive entries to inspect, newest end first (default 200, max 1000). Larger values are slower - every entry is a David API round-trip"};
         },;
         "required"=>{};
      }
      hResult["description"] := "List messages in the David Inbox (or Common archive), newest first, optionally unread only. " + ;
                                "Only the newest 'scan_limit' archive entries are inspected, so 'total' refers to the scanned window, not the whole mailbox"
      RETURN hResult
   ENDIF

   IF HHasKey(hArgs, "mailbox") .AND. ! Empty(hArgs["mailbox"])
      cMailbox := Lower(AllTrim(hArgs["mailbox"]))
   ENDIF
   lUnreadOnly := HHasKey(hArgs, "unread_only") .AND. HB_IsLogical(hArgs["unread_only"]) .AND. hArgs["unread_only"]
   IF HHasKey(hArgs, "limit") .AND. HB_IsNumeric(hArgs["limit"]) .AND. hArgs["limit"] > 0
      nLimit := hArgs["limit"]
   ENDIF
   IF HHasKey(hArgs, "offset") .AND. HB_IsNumeric(hArgs["offset"]) .AND. hArgs["offset"] > 0
      nOffset := hArgs["offset"]
   ENDIF

   // Reading a message summary is several OLE round-trips per item, so a full
   // scan of a big mailbox takes minutes and the MCP client times out long
   // before. Only inspect a window at the newest end of the archive (archive
   // entries are appended chronologically) and sort/page within that window.
   nScan := Max(nOffset + nLimit, 200)
   IF HHasKey(hArgs, "scan_limit") .AND. HB_IsNumeric(hArgs["scan_limit"]) .AND. hArgs["scan_limit"] > 0
      nScan := Max(nOffset + nLimit, Min(hArgs["scan_limit"], 1000))
   ENDIF

   oArchive := Inbox_Archive(cMailbox)
   IF oArchive == NIL
      hResult["status"] := "error"
      hResult["message"] := "David not connected"
      RETURN hResult
   ENDIF

   BEGIN SEQUENCE
      nCount := oArchive:MailItems:Count
      nFirst := Max(0, nCount - nScan)
      FOR nI := nCount - 1 TO nFirst STEP -1
         BEGIN SEQUENCE
            oItem := oArchive:MailItems:Item(nI)
            hMsg := Inbox_Summary(oItem)
            IF HHasKey(hMsg, "unread")
               lAnyReadState := .T.
            ENDIF
            // With unread_only, keep a message only when its read state is
            // known AND it is unread
            IF ! lUnreadOnly .OR. (HHasKey(hMsg, "unread") .AND. hMsg["unread"])
               AAdd(aMessages, hMsg)
            ENDIF
         RECOVER
         END SEQUENCE
      NEXT
   RECOVER
      hResult["status"] := "error"
      hResult["message"] := "Failed to read mailbox"
      RETURN hResult
   END SEQUENCE

   // Newest first. The date strings are ISO/timestamp form, so they sort chronologically.
   ASort(aMessages,,,{|x,y| x["date"] > y["date"]})

   // Apply offset/limit
   FOR nI := nOffset + 1 TO Min(nOffset + nLimit, Len(aMessages))
      AAdd(aPage, aMessages[nI])
   NEXT

   hResult["mailbox"]  := cMailbox
   hResult["mailbox_total"] := nCount
   hResult["scanned"]  := Min(nScan, nCount)
   hResult["unread_only"] := lUnreadOnly
   hResult["total"]    := Len(aMessages)
   hResult["count"]    := Len(aPage)
   hResult["messages"] := aPage
   hResult["status"]   := "success"
   IF lUnreadOnly .AND. Len(aMessages) == 0 .AND. ! lAnyReadState .AND. Min(nScan, nCount) > 0
      hResult["message"] := "The David API did not report a read state for any scanned message - " + ;
                            "the unread filter cannot be applied here"
   ELSEIF nFirst > 0
      hResult["message"] := "Scanned the newest " + AllTrim(Str(Min(nScan, nCount))) + " of " + ;
                            AllTrim(Str(nCount)) + " entries. Increase 'scan_limit' to look further back"
   ENDIF
RETURN hResult

FUNCTION MCP_Tool_Get_Inbox_Message(hArgs)
   LOCAL hResult := {=>}
   LOCAL oArchive, oItem, nX
   LOCAL cMailbox := "inbox", cId
   LOCAL aTo := {}, aCc := {}, aAttach := {}
   LOCAL xUnread

   // Return schema and description when called without arguments
   IF hArgs == NIL .OR. ValType(hArgs) != "H" .OR. Len(hArgs) == 0
      hResult["schema"] := {;
         "type"=>"object",;
         "properties"=>{;
            "id"=>{"type"=>"string","description"=>"The David message id (the 'id' returned by list_inbox)"},;
            "mailbox"=>{"type"=>"string","enum"=>{"inbox","common"},"description"=>"Which mailbox the message is in: 'inbox' (default) or 'common'"};
         },;
         "required"=>{"id"};
      }
      hResult["description"] := "Read a single David Inbox message by id, including body, recipients and attachment names"
      RETURN hResult
   ENDIF

   cId := hArgs["id"]
   IF HHasKey(hArgs, "mailbox") .AND. ! Empty(hArgs["mailbox"])
      cMailbox := Lower(AllTrim(hArgs["mailbox"]))
   ENDIF

   oArchive := Inbox_Archive(cMailbox)
   IF oArchive == NIL
      hResult["status"] := "error"
      hResult["message"] := "David not connected"
      RETURN hResult
   ENDIF

   BEGIN SEQUENCE
      oItem := oArchive:GetArchiveEntryByID(cId)
   RECOVER
      oItem := NIL
   END SEQUENCE

   IF oItem == NIL
      hResult["status"] := "not_found"
      hResult["message"] := "Message not found: " + cId
      RETURN hResult
   ENDIF

   hResult["id"]      := cId
   hResult["mailbox"] := cMailbox

   BEGIN SEQUENCE ; hResult["subject"] := DV_Utf8(oItem:Subject)       ; RECOVER ; hResult["subject"] := "" ; END SEQUENCE
   BEGIN SEQUENCE ; hResult["sender"] := DV_Utf8(oItem:Fields:Item("SRFrom"):Value); RECOVER; hResult["sender"] := ""; END SEQUENCE 
   BEGIN SEQUENCE ; hResult["date"]    := DV_DateStr(oItem:StatusTime) ; RECOVER ; hResult["date"]    := "" ; END SEQUENCE
   xUnread := DV_Unread(oItem)
   IF xUnread != NIL
      hResult["unread"] := xUnread
   ENDIF

   // Recipients (To)
   BEGIN SEQUENCE
      FOR nX := 0 TO oItem:Recipients:Count - 1
         AAdd(aTo, {"name"=>DV_Utf8(oItem:Recipients:Item(nX):DisplayName),"email"=>DV_Utf8(oItem:Recipients:Item(nX):Email)})
      NEXT
   RECOVER
   END SEQUENCE
   hResult["to"] := aTo

   // Carbon copies (CC)
   /*BEGIN SEQUENCE
      FOR nX := 0 TO oItem:Fields:Item("Cc"):Count - 1
         AAdd(aCc, {"name"=>DV_Utf8(oItem:Fields:Item("Cc"):Item(nX):DisplayName),"email"=>DV_Utf8(oItem:Fields:Item("Cc"):Item(nX):Email)})
      NEXT
   RECOVER
   END SEQUENCE
   hResult["cc"] := aCc*/

   // Bodies
   BEGIN SEQUENCE ; hResult["plain_body"] := DV_Utf8(oItem:Fields:Item("Content"):Value) ; RECOVER ; hResult["plain_body"] := "" ; END SEQUENCE
   BEGIN SEQUENCE ; hResult["html_body"]  := DV_Utf8(oItem:Fields:Item("HTMLDisplayContent"):Value)  ; RECOVER ; hResult["html_body"]  := "" ; END SEQUENCE

   // Attachment names (property name best-effort; guarded)
   BEGIN SEQUENCE
      FOR nX := 0 TO oItem:Attachments:Count - 1
         AAdd(aAttach, DV_Utf8(oItem:Attachments:Item(nX):FileName))
      NEXT
   RECOVER
   END SEQUENCE
   hResult["attachments"] := aAttach

   hResult["status"] := "found"
RETURN hResult

//---------------------------------------------------------------------------
// Email sending — hands mail to the David InfoCenter via the SendMail()
// procedure from source\david.prg (linked into the trader binary). Requires a
// working David connection (MailConnect), same as the inbox tools above.
//---------------------------------------------------------------------------

// Convert a UTF-8 string (JSON arguments arrive as UTF-8) to the Windows-ANSI
// (CP1252) form the David OLE API expects — the exact inverse of DV_Utf8.
// Characters that do not exist in CP1252 are replaced by "?".
STATIC FUNCTION DV_FromUtf8(cStr)
   IF ValType(cStr) != "C"
      RETURN ""
   ENDIF
RETURN hb_Translate(cStr, "UTF8", "DEWIN")

// Replace every non-ASCII character of an ANSI (CP1252) string with its
// numeric HTML entity, mirroring DV_HtmlEntities() in david.prg. The result
// is pure ASCII, so an HTML body survives whatever codepage conversion
// happens between here and the David OLE layer.
STATIC FUNCTION AnsiToHtmlEntities(cAnsi)
   LOCAL nI
   FOR nI := 128 TO 255
      IF Chr(nI) $ cAnsi
         cAnsi := StrTran(cAnsi, Chr(nI), "&#" + AllTrim(Str(nI)) + ";")
      ENDIF
   NEXT
RETURN cAnsi

STATIC FUNCTION DV_Join(aList, cSep)
   LOCAL cResult := "", cItem
   FOR EACH cItem IN aList
      IF ! Empty(cResult)
         cResult += cSep
      ENDIF
      cResult += cItem
   NEXT
RETURN cResult

// Split a comma/semicolon separated address list, append each address to aTo
// as a {email, name, type} entry (the shape SendMail() expects) and collect
// syntactically invalid addresses in aInvalid. Returns the number added.
STATIC FUNCTION AddRecipients(xList, cType, aTo, aInvalid)
   LOCAL aParts, cAddr, nAt
   LOCAL nAdded := 0

   IF ValType(xList) != "C" .OR. Empty(xList)
      RETURN 0
   ENDIF

   aParts := hb_ATokens(StrTran(xList, ",", ";"), ";")
   FOR EACH cAddr IN aParts
      cAddr := AllTrim(cAddr)
      IF Empty(cAddr)
         LOOP
      ENDIF
      nAt := At("@", cAddr)
      // minimal sanity check: one "@" (not first), a dot in the domain, no spaces
      IF nAt > 1 .AND. "." $ SubStr(cAddr, nAt + 2) .AND. ;
         At("@", SubStr(cAddr, nAt + 1)) == 0 .AND. !(" " $ cAddr)
         AAdd(aTo, {cAddr, "", cType})
         nAdded++
      ELSE
         AAdd(aInvalid, cAddr)
      ENDIF
   NEXT
RETURN nAdded

FUNCTION MCP_Tool_Send_Email(hArgs)
   LOCAL hResult := {=>}
   LOCAL aTo := {}, aInvalid := {}, aAttach := {}, aRecipients := {}
   LOCAL cSubject, cBody, cFrom := "", cFile
   LOCAL lHtml := .F., lDraft := .F.
   LOCAL nToCount := 0
   LOCAL oAccount, aRecipient

   // Return schema and description when called without arguments
   IF hArgs == NIL .OR. ValType(hArgs) != "H" .OR. Len(hArgs) == 0
      hResult["schema"] := {;
         "type"=>"object",;
         "properties"=>{;
            "to"=>{"type"=>"string","description"=>"Recipient email address(es). Multiple addresses separated by comma or semicolon"},;
            "cc"=>{"type"=>"string","description"=>"CC email address(es), separated by comma or semicolon"},;
            "bcc"=>{"type"=>"string","description"=>"BCC email address(es), separated by comma or semicolon"},;
            "subject"=>{"type"=>"string","description"=>"Subject line of the email"},;
            "body"=>{"type"=>"string","description"=>"Body of the email. Plain text by default, HTML when 'html' is true"},;
            "html"=>{"type"=>"boolean","description"=>"Set to true when body contains HTML (default: false = plain text)"},;
            "from"=>{"type"=>"string","description"=>"Sender email address, must be one of the user's configured outgoing addresses. Default: the David account's primary address"},;
            "attachments"=>{"type"=>"array","items"=>{"type"=>"string"},"description"=>"Full file paths (as seen by the Trader server) of files to attach"},;
            "draft"=>{"type"=>"boolean","description"=>"If true the email is saved to the David Drafts folder for manual review instead of being sent immediately (default: false)"};
         },;
         "required"=>{"to","subject","body"};
      }
      hResult["description"] := "Send an email through the David InfoCenter. " + ;
                                "Sends immediately unless 'draft' is true, in which case the mail is placed " + ;
                                "in the Drafts folder for manual review before sending"
      RETURN hResult
   ENDIF

   nToCount := AddRecipients(IIF(HHasKey(hArgs, "to"), hArgs["to"], ""), "TO", aTo, aInvalid)
   AddRecipients(IIF(HHasKey(hArgs, "cc"), hArgs["cc"], ""), "CC", aTo, aInvalid)
   AddRecipients(IIF(HHasKey(hArgs, "bcc"), hArgs["bcc"], ""), "BCC", aTo, aInvalid)

   IF Len(aInvalid) > 0
      RETURN "Invalid email address(es): " + DV_Join(aInvalid, ", ")
   ENDIF
   IF nToCount == 0
      RETURN "No valid 'to' recipient provided"
   ENDIF

   IF ValType(hArgs["subject"]) != "C" .OR. ValType(hArgs["body"]) != "C"
      RETURN "Parameters 'subject' and 'body' must be strings"
   ENDIF

   cSubject := DV_FromUtf8(hArgs["subject"])
   cBody := DV_FromUtf8(hArgs["body"])
   // JSON newlines arrive as LF; SendMail() strips LF and keeps CR, so
   // normalize CRLF/LF to CR to preserve line breaks in the plain body.
   cBody := StrTran(cBody, Chr(13) + Chr(10), Chr(13))
   cBody := StrTran(cBody, Chr(10), Chr(13))

   lHtml := HHasKey(hArgs, "html") .AND. HB_IsLogical(hArgs["html"]) .AND. hArgs["html"]
   lDraft := HHasKey(hArgs, "draft") .AND. HB_IsLogical(hArgs["draft"]) .AND. hArgs["draft"]
   IF HHasKey(hArgs, "from") .AND. ValType(hArgs["from"]) == "C"
      cFrom := AllTrim(hArgs["from"])
   ENDIF

   // Make HTML bodies pure ASCII (entities) so no later codepage conversion
   // can garble them. We pass lHtmlEntities=.F. to SendMail below because its
   // own DV_HtmlEntities() expects OEM input and would mangle our ANSI body.
   IF lHtml
      cBody := AnsiToHtmlEntities(cBody)
   ENDIF

   // Attachments must exist on disk before we hand them to David
   IF HHasKey(hArgs, "attachments") .AND. HB_IsArray(hArgs["attachments"])
      FOR EACH cFile IN hArgs["attachments"]
         IF ValType(cFile) != "C" .OR. Empty(cFile)
            LOOP
         ENDIF
         cFile := DV_FromUtf8(cFile)
         IF ! File(cFile)
            RETURN "Attachment not found: " + cFile
         ENDIF
         AAdd(aAttach, cFile)
      NEXT
   ENDIF

   // Connect to David (idempotent) and make sure we really have an account —
   // SendMail() itself just returns silently when there is no connection.
   BEGIN SEQUENCE
      MailConnect()
      oAccount := DV_GetMailAccount()
   RECOVER
      oAccount := NIL
   END SEQUENCE

   IF oAccount == NIL
      hResult["status"] := "error"
      hResult["message"] := "David not connected - email not sent"
      RETURN hResult
   ENDIF

   BEGIN SEQUENCE
      SendMail(aTo, cSubject, cBody, aAttach, .F., 0, lHtml, cFrom, lDraft, .F.)
   RECOVER
      hResult["status"] := "error"
      hResult["message"] := "Failed to " + IIF(lDraft, "save draft", "send email")
      RETURN hResult
   END SEQUENCE

   FOR EACH aRecipient IN aTo
      AAdd(aRecipients, aRecipient[3] + ": " + aRecipient[1])
   NEXT

   hResult["status"] := "success"
   hResult["mode"] := IIF(lDraft, "draft", "sent")
   hResult["recipients"] := aRecipients
   hResult["subject"] := hArgs["subject"]
   hResult["attachment_count"] := Len(aAttach)
   hResult["message"] := IIF(lDraft, ;
      "Email saved to the David Drafts folder", ;
      "Email handed to David for sending")
RETURN hResult

//---------------------------------------------------------------------------
// Reminder tool — creates a David Wiedervorlage via AddWiedervorlage() from
// source\david.prg, for the current user or another Trader user.
//---------------------------------------------------------------------------

FUNCTION MCP_Tool_Create_Reminder(hArgs)
   LOCAL hResult := {=>}
   LOCAL dDate, cSubject, cMessage
   LOCAL nUser := 0
   LOCAL oAccount, lOk := .F.

   // Return schema and description when called without arguments
   IF hArgs == NIL .OR. ValType(hArgs) != "H" .OR. Len(hArgs) == 0
      hResult["schema"] := {;
         "type"=>"object",;
         "properties"=>{;
            "date"=>{"type"=>"string","description"=>"Reminder date in YYYY-MM-DD format"},;
            "subject"=>{"type"=>"string","description"=>"Subject of the reminder"},;
            "message"=>{"type"=>"string","description"=>"Body text of the reminder (optional)"},;
            "user_number"=>{"type"=>"integer","description"=>"Trader user (buyer) number whose reminder folder receives the entry. Default: the current user"};
         },;
         "required"=>{"date","subject"};
      }
      hResult["description"] := "Create a reminder (Wiedervorlage) in the David InfoCenter that pops up on the given date, " + ;
                                "for the current user or another Trader user"
      RETURN hResult
   ENDIF

   IF ValType(hArgs["date"]) != "C"
      RETURN "Parameter 'date' must be a string in YYYY-MM-DD format"
   ENDIF
   dDate := SToD(StrTran(AllTrim(hArgs["date"]), "-", ""))
   IF Empty(dDate)
      RETURN "Invalid date: " + hArgs["date"] + " (expected YYYY-MM-DD)"
   ENDIF
   IF dDate < Date()
      RETURN "Reminder date " + hArgs["date"] + " is in the past"
   ENDIF

   cSubject := DV_FromUtf8(hArgs["subject"])
   cMessage := IIF(HHasKey(hArgs, "message") .AND. ValType(hArgs["message"]) == "C", DV_FromUtf8(hArgs["message"]), "")
   cMessage := StrTran(cMessage, Chr(13) + Chr(10), Chr(13))
   cMessage := StrTran(cMessage, Chr(10), Chr(13))

   IF HHasKey(hArgs, "user_number") .AND. HB_IsNumeric(hArgs["user_number"]) .AND. hArgs["user_number"] > 0
      nUser := hArgs["user_number"]
   ENDIF

   BEGIN SEQUENCE
      MailConnect()
      oAccount := DV_GetMailAccount()
   RECOVER
      oAccount := NIL
   END SEQUENCE

   IF oAccount == NIL
      hResult["status"] := "error"
      hResult["message"] := "David not connected - reminder not created"
      RETURN hResult
   ENDIF

   BEGIN SEQUENCE
      lOk := AddWiedervorlage(dDate, cSubject, cMessage, NIL, {}, nUser)
   RECOVER
      lOk := .F.
   END SEQUENCE

   IF lOk
      hResult["status"] := "success"
      hResult["date"] := dDate
      hResult["subject"] := hArgs["subject"]
      hResult["user_number"] := nUser
      hResult["message"] := "Reminder created"
   ELSE
      hResult["status"] := "error"
      hResult["message"] := "Failed to create reminder" + ;
         IIF(nUser > 0, " - user " + AllTrim(Str(nUser)) + " may not exist or has no David account linked", "")
   ENDIF
RETURN hResult

//---------------------------------------------------------------------------
// Quote and accounting tools — read-only access to the angebot (quote) and
// englsre (invoice ledger) tables.
//---------------------------------------------------------------------------

// Resolve a customer from the 'customer' (matchcode) / 'customer_number'
// arguments, same lookup as MCP_Tool_Get_Customer. Returns NIL if not found.
STATIC FUNCTION ResolveCustomer(hArgs)
   LOCAL oKunde := Adresse():New()
   LOCAL lFound := .F.

   IF HHasKey(hArgs, "customer_number") .AND. HB_IsNumeric(hArgs["customer_number"]) .AND. hArgs["customer_number"] > 0
      ku->(DbSetOrder(8))
      lFound := oKunde:Load(hArgs["customer_number"])
   ELSEIF HHasKey(hArgs, "customer") .AND. ! Empty(hArgs["customer"])
      lFound := oKunde:LoadMatchcode(Pad(Upper(AllTrim(hArgs["customer"])), 8), "K")
   ENDIF
RETURN IIF(lFound, oKunde, NIL)

// Coarse quote status from ang->Bestat: 0 = enquiry not yet quoted ("off"),
// 1/2 = quoted ("ang"), >= 3 = closed ("erl") - see angebot_browse.prg.
STATIC FUNCTION QuoteStatusLabel(nBestat)
RETURN IIF(nBestat >= 3, "closed", IIF(nBestat == 0, "enquiry", "quoted"))

// Discounted unit price of the current ang line (see angebot_print.prg:
// dis_count := vkpr - vkpr*rabatt/100; Pe is the price unit).
STATIC FUNCTION QuoteLinePrice()
RETURN (ang->VkPr - ang->VkPr * ang->Rabatt / 100) / IIF(ang->Pe == 0, 1, ang->Pe)

FUNCTION MCP_Tool_Get_Quote(hArgs)
   LOCAL hResult := {=>}
   LOCAL nQuote, hLine
   LOCAL aLines := {}
   LOCAL nTotal := 0
   LOCAL nOldSelect := Select()

   // Return schema and description when called without arguments
   IF hArgs == NIL .OR. ValType(hArgs) != "H" .OR. Len(hArgs) == 0
      hResult["schema"] := {;
         "type"=>"object",;
         "properties"=>{;
            "quote_number"=>{"type"=>"number","description"=>"Quote (Angebot) number"};
         },;
         "required"=>{"quote_number"};
      }
      hResult["description"] := "Retrieve a sales quote (Angebot) by number, including all line items, prices and status"
      RETURN hResult
   ENDIF

   IF ! HB_IsNumeric(hArgs["quote_number"])
      RETURN "Parameter 'quote_number' must be a number"
   ENDIF
   nQuote := hArgs["quote_number"]

   NetUse("angebot", "ang")
   ang->(DbSetOrder(1))  // Str(Angnr,6) + Str(Itmnr,3)

   IF ! ang->(DbSeek(Str(nQuote, 6)))
      DbSelectArea(nOldSelect)
      hResult["status"] := "not_found"
      hResult["message"] := "Quote not found: " + AllTrim(Str(nQuote))
      RETURN hResult
   ENDIF

   hResult["quote_number"] := nQuote
   hResult["customer"] := HB_StrToUTF8(AllTrim(ang->Kundma))
   hResult["date"] := ang->Besda
   hResult["buyer"] := HB_StrToUTF8(AllTrim(ang->Buyer))
   hResult["currency"] := IIF(Empty(ang->Money), "EUR", AllTrim(ang->Money))

   DO WHILE ! ang->(Eof()) .AND. ang->Angnr == nQuote
      hLine := {=>}
      hLine["item"] := ang->Itmnr
      hLine["article"] := HB_StrToUTF8(AllTrim(ang->Matchcode))
      hLine["description"] := HB_StrToUTF8(AllTrim(ang->Artikel))
      hLine["quantity"] := ang->VkQty
      hLine["price"] := QuoteLinePrice()
      hLine["discount_percent"] := ang->Rabatt
      hLine["status"] := QuoteStatusLabel(ang->Bestat)
      IF ! Empty(ang->Aufnr)  // character field in angebot
         hLine["order_number"] := HB_StrToUTF8(AllTrim(ang->Aufnr))  // quote line was converted to this order
      ENDIF
      hLine["line_total"] := Round(ang->VkQty * QuoteLinePrice(), 2)
      nTotal += hLine["line_total"]
      AAdd(aLines, hLine)
      ang->(DbSkip())
   ENDDO

   DbSelectArea(nOldSelect)

   hResult["lines"] := aLines
   hResult["total"] := Round(nTotal, 2)
   hResult["status"] := "found"
RETURN hResult

FUNCTION MCP_Tool_Get_Customer_Quotes(hArgs)
   LOCAL hResult := {=>}
   LOCAL oKunde, hQuotes := {=>}, hQuote, cKey
   LOCAL aQuotes := {}
   LOCAL cStatus := "all", cLineStatus
   LOCAL nMaxResults := 50
   LOCAL nOldSelect := Select()

   // Return schema and description when called without arguments
   IF hArgs == NIL .OR. ValType(hArgs) != "H" .OR. Len(hArgs) == 0
      hResult["schema"] := {;
         "type"=>"object",;
         "properties"=>{;
            "customer"=>{"type"=>"string","description"=>"Customer matchcode"},;
            "customer_number"=>{"type"=>"number","description"=>"Customer number"},;
            "status_filter"=>{"type"=>"string","enum"=>{"open","closed","all"},"description"=>"Only quotes with this status (default all). 'open' = enquiry received or quoted but not yet closed"},;
            "max_results"=>{"type"=>"number","description"=>"Maximum number of quotes to return, newest first (default 50)"};
         },;
         "anyOf"=>{{"customer", "customer_number"}};
      }
      hResult["description"] := "List sales quotes (Angebote) for a customer, newest first, with per-quote status and value"
      RETURN hResult
   ENDIF

   IF HHasKey(hArgs, "status_filter") .AND. hArgs["status_filter"] $ {"open", "closed"}
      cStatus := hArgs["status_filter"]
   ENDIF
   IF HHasKey(hArgs, "max_results") .AND. HB_IsNumeric(hArgs["max_results"]) .AND. hArgs["max_results"] > 0
      nMaxResults := Min(hArgs["max_results"], 200)
   ENDIF

   oKunde := ResolveCustomer(hArgs)
   IF oKunde == NIL
      hResult["status"] := "not_found"
      hResult["message"] := "Customer not found"
      RETURN hResult
   ENDIF

   NetUse("angebot", "ang")
   ang->(DbSetOrder(7))  // Kundma

   IF ang->(DbSeek(oKunde:Kunde))
      DO WHILE ! ang->(Eof()) .AND. ang->Kundma == oKunde:Kunde
         cLineStatus := QuoteStatusLabel(ang->Bestat)
         IF cStatus == "all" .OR. ;
            (cStatus == "open" .AND. cLineStatus != "closed") .OR. ;
            (cStatus == "closed" .AND. cLineStatus == "closed")

            cKey := Str(ang->Angnr, 6)
            IF ! HHasKey(hQuotes, cKey)
               hQuote := {=>}
               hQuote["quote_number"] := ang->Angnr
               hQuote["date"] := ang->Besda
               hQuote["buyer"] := ang->Buyer
               hQuote["currency"] := IIF(Empty(ang->Money), "EUR", AllTrim(ang->Money))
               hQuote["status"] := cLineStatus
               hQuote["line_count"] := 0
               hQuote["total"] := 0
               hQuotes[cKey] := hQuote
            ENDIF
            hQuotes[cKey]["line_count"] := hQuotes[cKey]["line_count"] + 1
            hQuotes[cKey]["total"] := Round(hQuotes[cKey]["total"] + ang->VkQty * QuoteLinePrice(), 2)
            // A quote with any line still open counts as open
            IF cLineStatus != "closed"
               hQuotes[cKey]["status"] := cLineStatus
            ENDIF
         ENDIF
         ang->(DbSkip())
      ENDDO
   ENDIF

   DbSelectArea(nOldSelect)

   FOR EACH hQuote IN hQuotes
      AAdd(aQuotes, hQuote)
   NEXT
   ASort(aQuotes,,, {|x, y| x["quote_number"] > y["quote_number"]})
   ASize(aQuotes, Min(Len(aQuotes), nMaxResults))

   hResult["customer"] := HB_StrToUTF8(AllTrim(oKunde:Kunde))
   hResult["customer_number"] := oKunde:Nummer
   hResult["count"] := Len(aQuotes)
   hResult["quotes"] := aQuotes
   hResult["status"] := IIF(Len(aQuotes) > 0, "found", "not_found")
   IF Len(aQuotes) == 0
      hResult["message"] := "No quotes found for this customer"
   ELSEIF Len(aQuotes) == nMaxResults
      hResult["message"] := "Result limited to " + AllTrim(Str(nMaxResults)) + " quotes"
   ENDIF
RETURN hResult

FUNCTION MCP_Tool_Get_Customer_Open_Items(hArgs)
   LOCAL hResult := {=>}
   LOCAL oKunde, cKunde
   LOCAL aItems := {}, hItem
   LOCAL hTotals := {=>}, cCur, nOpen
   LOCAL nOldSelect := Select()

   // Return schema and description when called without arguments
   IF hArgs == NIL .OR. ValType(hArgs) != "H" .OR. Len(hArgs) == 0
      hResult["schema"] := {;
         "type"=>"object",;
         "properties"=>{;
            "customer"=>{"type"=>"string","description"=>"Customer matchcode"},;
            "customer_number"=>{"type"=>"number","description"=>"Customer number"};
         },;
         "anyOf"=>{{"customer", "customer_number"}};
      }
      hResult["description"] := "List open (not fully paid) invoices and credit notes for a customer, " + ;
                                "with amount, paid amount, open balance and age in days. Use before payment reminders"
      RETURN hResult
   ENDIF

   oKunde := ResolveCustomer(hArgs)
   IF oKunde == NIL
      hResult["status"] := "not_found"
      hResult["message"] := "Customer not found"
      RETURN hResult
   ENDIF

   cKunde := Pad(oKunde:Kunde, 8)

   NetUse("englsre", "re", .F., 5)
   re->(DbSetOrder(2))  // Str(Reposnr,3) + Kunde; Reposnr 0 = invoice header

   IF re->(DbSeek("  0" + cKunde))
      DO WHILE ! re->(Eof()) .AND. re->Reposnr == 0 .AND. re->Kunde == cKunde
         // Open = not settled yet, same criteria as GetCustomerTurnover in
         // model/adresse.prg (status 0 and code <= 2)
         IF re->Status == 0 .AND. re->Code <= 2
            nOpen := Round(re->Poswt - re->AoQty - re->PaySkonto, 2)
            IF nOpen != 0
               hItem := {=>}
               hItem["invoice_number"] := re->Rechnr
               hItem["type"] := IIF(re->Poswt < 0, "credit_note", "invoice")
               hItem["date"] := re->Rechdat
               hItem["age_days"] := Date() - re->Rechdat
               hItem["amount"] := re->Poswt
               hItem["paid"] := re->AoQty
               hItem["discount"] := re->PaySkonto
               hItem["open"] := nOpen
               hItem["currency"] := IIF(Empty(re->Money), "EUR", AllTrim(re->Money))
               AAdd(aItems, hItem)

               cCur := hItem["currency"]
               IF ! HHasKey(hTotals, cCur)
                  hTotals[cCur] := 0
               ENDIF
               hTotals[cCur] := Round(hTotals[cCur] + nOpen, 2)
            ENDIF
         ENDIF
         re->(DbSkip())
      ENDDO
   ENDIF

   DbSelectArea(nOldSelect)

   // Oldest first - the order a dunning run would treat them
   ASort(aItems,,, {|x, y| x["date"] < y["date"]})

   hResult["customer"] := HB_StrToUTF8(AllTrim(oKunde:Kunde))
   hResult["customer_number"] := oKunde:Nummer
   hResult["count"] := Len(aItems)
   hResult["open_items"] := aItems
   hResult["open_total_by_currency"] := hTotals
   hResult["status"] := IIF(Len(aItems) > 0, "found", "none")
   IF Len(aItems) == 0
      hResult["message"] := "No open items - nothing unpaid for this customer"
   ENDIF
RETURN hResult

FUNCTION MCP_Tool_Get_Customer_Turnover(hArgs)
   LOCAL hResult := {=>}
   LOCAL oKunde, hTurn
   LOCAL hYears := {=>}, nVal

   // Return schema and description when called without arguments
   IF hArgs == NIL .OR. ValType(hArgs) != "H" .OR. Len(hArgs) == 0
      hResult["schema"] := {;
         "type"=>"object",;
         "properties"=>{;
            "customer"=>{"type"=>"string","description"=>"Customer matchcode"},;
            "customer_number"=>{"type"=>"number","description"=>"Customer number"};
         },;
         "anyOf"=>{{"customer", "customer_number"}};
      }
      hResult["description"] := "Revenue statistics for a customer: total and per-year turnover, current/last year, " + ;
                                "last 12 months and the currently open (unpaid) invoice amount. Net values in EUR"
      RETURN hResult
   ENDIF

   oKunde := ResolveCustomer(hArgs)
   IF oKunde == NIL
      hResult["status"] := "not_found"
      hResult["message"] := "Customer not found"
      RETURN hResult
   ENDIF

   // GetCustomerTurnover() lives in model/adresse.prg and is REQUESTed into
   // the trader binary - the same numbers the application itself shows.
   BEGIN SEQUENCE
      hTurn := GetCustomerTurnover(oKunde:Kunde)
   RECOVER
      hTurn := NIL
   END SEQUENCE

   IF ValType(hTurn) != "H"
      hResult["status"] := "error"
      hResult["message"] := "Failed to calculate turnover"
      RETURN hResult
   ENDIF

   // The years hash is keyed by numeric year - convert to string keys for JSON
   FOR EACH nVal IN hTurn["years"]
      hYears[AllTrim(Str(nVal:__enumKey()))] := Round(nVal, 2)
   NEXT

   hResult["customer"] := HB_StrToUTF8(AllTrim(oKunde:Kunde))
   hResult["customer_number"] := oKunde:Nummer
   hResult["currency"] := "EUR"
   hResult["total"] := Round(hTurn["total"], 2)
   hResult["current_year"] := Round(hTurn["current"], 2)
   hResult["last_year"] := Round(hTurn["last"], 2)
   hResult["year_before_last"] := Round(hTurn["before-last"], 2)
   hResult["last_3_years"] := Round(hTurn["last3"], 2)
   hResult["last_12_months"] := Round(hTurn["12-month"], 2)
   hResult["open_invoices"] := Round(hTurn["open"], 2)
   hResult["by_year"] := hYears
   hResult["status"] := "found"
RETURN hResult

FUNCTION MCP_Tool_Get_Invoice(hArgs)
   LOCAL hResult := {=>}
   LOCAL nRe, hLine
   LOCAL aLines := {}
   LOCAL nOldSelect := Select()

   // Return schema and description when called without arguments
   IF hArgs == NIL .OR. ValType(hArgs) != "H" .OR. Len(hArgs) == 0
      hResult["schema"] := {;
         "type"=>"object",;
         "properties"=>{;
            "invoice_number"=>{"type"=>"number","description"=>"Invoice (Rechnung) number"};
         },;
         "required"=>{"invoice_number"};
      }
      hResult["description"] := "Retrieve an outgoing invoice by number: header with customer, totals, tax, payment and " + ;
                                "dunning status, plus all line items. The sales order number (AB-Nr) is included on the " + ;
                                "header and on each line (collective invoices can bill several orders) and can be passed " + ;
                                "to get_order_details; a line's item number equals the item number in that order"
      RETURN hResult
   ENDIF

   IF ! HB_IsNumeric(hArgs["invoice_number"])
      RETURN "Parameter 'invoice_number' must be a number"
   ENDIF
   nRe := hArgs["invoice_number"]

   NetUse("englsre", "re", .F., 5)
   re->(DbSetOrder(12))  // Str(Rechnr,6) + Str(Reposnr,3); Reposnr 0 = header

   IF ! re->(DbSeek(Str(nRe, 6) + Str(0, 3)))
      DbSelectArea(nOldSelect)
      hResult["status"] := "not_found"
      hResult["message"] := "Invoice not found: " + AllTrim(Str(nRe))
      RETURN hResult
   ENDIF

   // Header row - field meanings per the map in model/rechnung.prg
   // (PosWt=gross total, Preis=tax, Kurs=tax rate, ofqty=shipping,
   //  AoQty=paid amount, Code>=2 printed, Code>=3+Status==3 paid)
   hResult["invoice_number"] := nRe
   hResult["customer"] := HB_StrToUTF8(AllTrim(re->Kunde))
   hResult["date"] := re->Rechdat
   IF re->AbNr > 0
      hResult["order_number"] := re->AbNr
   ENDIF
   hResult["currency"] := IIF(Empty(re->Money), "EUR", AllTrim(re->Money))
   hResult["total_gross"] := re->PosWt
   hResult["tax"] := re->Preis
   hResult["tax_rate"] := re->Kurs
   hResult["total_net"] := Round(re->PosWt - re->Preis, 2)
   hResult["shipping"] := re->OfQty
   hResult["discount_percent"] := re->Rabatt
   hResult["paid_amount"] := re->AoQty
   hResult["paid"] := re->Code >= 3 .AND. re->Status == 3
   hResult["printed"] := re->Code >= 2
   hResult["shipped"] := re->Packed
   IF ! Empty(re->PayDate)
      hResult["payment_date"] := re->PayDate
   ENDIF
   IF ! Empty(re->MaDate)
      hResult["dunning"] := re->Rem
      hResult["dunning_date"] := re->MaDate
   ENDIF

   re->(DbSkip())  // move past the header row
   DO WHILE ! re->(Eof()) .AND. re->Rechnr == nRe
      IF re->Reposnr != 0
         hLine := {=>}
         hLine["item"] := re->Reposnr  // equals the item number in the billed order (model/rechpos.prg)
         hLine["article"] := HB_StrToUTF8(AllTrim(re->Matchcode))
         hLine["description"] := HB_StrToUTF8(AllTrim(re->Artikel))
         hLine["quantity"] := re->AoQty
         hLine["unit"] := HB_StrToUTF8(AllTrim(re->Me))
         hLine["unit_price"] := Round((re->Preis / IIF(re->Pe == 0, 1, re->Pe)) * (1 - re->Rabatt / 100), 4)
         IF re->Zuschlag != 0
            hLine["surcharge"] := re->Zuschlag
         ENDIF
         // Same line total formula as Rechnung:UpdateTotal() in model/rechnung.prg
         hLine["line_total"] := Round((re->AoQty * re->Preis / IIF(re->Pe == 0, 1, re->Pe)) * (1 - re->Rabatt / 100), 2) + re->Zuschlag
         IF re->AbNr > 0
            hLine["order_number"] := re->AbNr
         ENDIF
         AAdd(aLines, hLine)
      ENDIF
      re->(DbSkip())
   ENDDO

   DbSelectArea(nOldSelect)

   hResult["lines"] := aLines
   hResult["line_count"] := Len(aLines)
   hResult["status"] := "found"
RETURN hResult

// Convert a JJWW calendar-week value (as stored in Lterm/Wterm and besdel) to
// the corresponding date via CalWD() from trade065.prg. Special weeks are
// mapped by CalWD (99 = frame call-off -> end of year, 97/98 = unknown -> far
// future). Returns NIL for empty or invalid weeks.
STATIC FUNCTION BesWeekDate(nWeek)
   LOCAL dDate := NIL
   IF HB_IsNumeric(nWeek) .AND. nWeek > 0
      BEGIN SEQUENCE
         dDate := CalWD(nWeek,,, .T.)
      RECOVER
         dDate := NIL
      END SEQUENCE
      IF ValType(dDate) == "D" .AND. Empty(dDate)
         dDate := NIL
      ENDIF
   ENDIF
RETURN dDate

FUNCTION MCP_Tool_Get_Purchase_Order(hArgs)
   LOCAL hResult := {=>}
   LOCAL nPo, hLine, aLines := {}
   LOCAL nTotal := 0, nPriceEur
   LOCAL aSched, hSched, dTemp
   LOCAL nOldSelect := Select()

   // Return schema and description when called without arguments
   IF hArgs == NIL .OR. ValType(hArgs) != "H" .OR. Len(hArgs) == 0
      hResult["schema"] := {;
         "type"=>"object",;
         "properties"=>{;
            "po_number"=>{"type"=>"number","description"=>"Purchase order (Bestellung) number"};
         },;
         "required"=>{"po_number"};
      }
      hResult["description"] := "Retrieve a purchase order (Bestellung) by number, including all line items with " + ;
                                "ordered/delivered quantities, prices, and delivery dates given as calendar week " + ;
                                "(JJWW) plus resolved date. When 'confirmed' is true the delivery date is the " + ;
                                "supplier-confirmed date, otherwise the expected date. Lines with a delivery " + ;
                                "schedule (Liefereinteilungen) list their partial deliveries under 'delivery_schedule'. " + ;
                                "Shipping confirmations appear as 'tracking'/'shipped_date' per line and per schedule " + ;
                                "entry; open lines report 'shipping_confirmed' accordingly"
      RETURN hResult
   ENDIF

   IF ! HB_IsNumeric(hArgs["po_number"])
      RETURN "Parameter 'po_number' must be a number"
   ENDIF
   nPo := hArgs["po_number"]

   NetUse("engbes", "bes")
   NetUse("besdel", "bdel")  // Liefereinteilungen per position
   NetUse("artlief", "ali")  // supplier part numbers
   NetUse("werkauf", "wer")  // production orders (Fremdfertigung)
   ali->(DbSetOrder(1))  // Kunde(supplier) + Str(Artikelnr,6)
   wer->(DbSetOrder(6))  // Str(Besnr,6) + Str(Posnr,3)
   bes->(DbSetOrder(1))  // Str(Besnr,6) + Str(Posnr,3)

   IF ! bes->(DbSeek(Str(nPo, 6)))
      DbSelectArea(nOldSelect)
      hResult["status"] := "not_found"
      hResult["message"] := "Purchase order not found: " + AllTrim(Str(nPo))
      RETURN hResult
   ENDIF

   hResult["po_number"] := nPo
   hResult["supplier"] := HB_StrToUTF8(AllTrim(bes->Liefma))
   hResult["date"] := bes->Besda
   hResult["currency"] := IIF(Empty(bes->Money), "EUR", AllTrim(bes->Money))

   DO WHILE ! bes->(Eof()) .AND. bes->Besnr == nPo
      hLine := {=>}
      hLine["item"] := bes->Posnr
      hLine["article"] := HB_StrToUTF8(AllTrim(bes->Matchcode))
      // Supplier's part number, same lookup as the PO print (bestellung_print.prg)
      IF ali->(DbSeek(bes->Liefma + Str(bes->Artikelnr, 6))) .AND. ! Empty(ali->Artlief)
         hLine["supplier_part_no"] := HB_StrToUTF8(AllTrim(ali->Artlief))
      ENDIF
      hLine["quantity"] := bes->BeQty
      hLine["delivered_quantity"] := bes->GelQty
      hLine["open_quantity"] := IIF(bes->Bestat < 3, bes->BeQty - bes->GelQty, 0)
      // Discounted unit price in the document currency
      hLine["unit_price"] := Round((bes->EkPr / IIF(bes->Pe == 0, 1, bes->Pe)) * (100 - bes->Rabatt) / 100, 4)
      // Effective EUR unit price via BesGetEkPrice() (model/bestellungpos.prg):
      // includes exchange rate and linked surcharge/reference positions
      BEGIN SEQUENCE
         nPriceEur := BesGetEkPrice()
      RECOVER
         nPriceEur := NIL
      END SEQUENCE
      IF nPriceEur != NIL
         hLine["unit_price_eur"] := Round(nPriceEur, 4)
      ENDIF
      // Lterm/Wterm are calendar weeks (JJWW). Lterm is the supplier-confirmed
      // date when Confirmed == "Y", otherwise the expected date (see the GET
      // label logic in bestellung_edit.prg)
      IF HB_IsNumeric(bes->Lterm) .AND. bes->Lterm > 0
         hLine["delivery_week"] := StrZero(bes->Lterm, 4)
         IF (dTemp := BesWeekDate(bes->Lterm)) != NIL
            hLine["delivery_date"] := dTemp
         ENDIF
      ENDIF
      IF HB_IsNumeric(bes->Wterm) .AND. bes->Wterm > 0
         hLine["requested_week"] := StrZero(bes->Wterm, 4)
         IF (dTemp := BesWeekDate(bes->Wterm)) != NIL
            hLine["requested_date"] := dTemp
         ENDIF
      ENDIF
      hLine["confirmed"] := Upper(AllTrim(bes->Confirmed)) == "Y"  // stored as "Y"/"N"
      hLine["status"] := IIF(bes->Bestat < 3, "open", "completed")

      // Shipping confirmation (tracking no / shipped date) per position.
      // The fields are being introduced on branch trader-pain-points - guard
      // with FieldPos so the tool also runs on data files without them.
      IF bes->(FieldPos("TRACKING")) > 0 .AND. ! Empty(bes->Tracking)
         hLine["tracking"] := HB_StrToUTF8(AllTrim(bes->Tracking))
      ENDIF
      IF bes->(FieldPos("SHIPPED")) > 0 .AND. ! Empty(bes->Shipped)
         hLine["shipped_date"] := bes->Shipped
      ENDIF
      IF bes->(FieldPos("CARRIER")) > 0 .AND. ! Empty(bes->Carrier)
         hLine["carrier"] := HB_StrToUTF8(AllTrim(bes->Carrier))
      ENDIF
      IF bes->Bestat < 3 .AND. bes->(FieldPos("TRACKING")) > 0 .AND. bes->(FieldPos("SHIPPED")) > 0
         // Same criterion as the checkstock shipping watchdog: a confirmation
         // exists once a tracking number or a shipped date is recorded
         hLine["shipping_confirmed"] := ! Empty(bes->Tracking) .OR. ! Empty(bes->Shipped)
      ENDIF

      // Delivery schedule (Liefereinteilungen) from besdel, keyed
      // Besnr+Posnr+Lterm as in BestellungConfirm.prg
      aSched := {}
      IF bdel->(DbSeek(Str(bes->Besnr, 6) + Str(bes->Posnr, 3)))
         DO WHILE ! bdel->(Eof()) .AND. bdel->Besnr == bes->Besnr .AND. bdel->Posnr == bes->Posnr
            hSched := {=>}
            hSched["week"] := StrZero(bdel->Lterm, 4)
            IF (dTemp := BesWeekDate(bdel->Lterm)) != NIL
               hSched["date"] := dTemp
            ENDIF
            hSched["quantity"] := bdel->Qty
            IF bdel->(FieldPos("TRACKING")) > 0 .AND. ! Empty(bdel->Tracking)
               hSched["tracking"] := HB_StrToUTF8(AllTrim(bdel->Tracking))
            ENDIF
            IF bdel->(FieldPos("SHIPPED")) > 0 .AND. ! Empty(bdel->Shipped)
               hSched["shipped_date"] := bdel->Shipped
            ENDIF
            IF bdel->(FieldPos("CARRIER")) > 0 .AND. ! Empty(bdel->Carrier)
               hSched["carrier"] := HB_StrToUTF8(AllTrim(bdel->Carrier))
            ENDIF
            AAdd(aSched, hSched)
            bdel->(DbSkip())
         ENDDO
      ENDIF
      IF Len(aSched) > 0
         hLine["delivery_schedule"] := aSched
      ENDIF
      IF ! Empty(bes->AbNr)  // character field in engbes
         // The supplier's order confirmation (AB) number - the reference under
         // which the SUPPLIER runs this order (booked via confirm_purchase_order).
         // Not to be confused with our own sales order numbers.
         hLine["supplier_ab_number"] := HB_StrToUTF8(AllTrim(bes->AbNr))
      ENDIF
      IF bes->ContrNo > 0
         hLine["frame_order"] := bes->ContrNo  // call-off from this blanket PO
      ENDIF
      // Fremdfertigung: the production order this position belongs to
      IF wer->(DbSeek(Str(nPo, 6) + Str(bes->Posnr, 3)))
         hLine["production_order"] := wer->Aufno  // details via get_production_order
      ENDIF
      hLine["line_total"] := Round(bes->BeQty * hLine["unit_price"], 2)
      nTotal += hLine["line_total"]
      AAdd(aLines, hLine)
      bes->(DbSkip())
   ENDDO

   DbSelectArea(nOldSelect)

   hResult["lines"] := aLines
   hResult["total"] := Round(nTotal, 2)
   hResult["status"] := "found"
RETURN hResult

FUNCTION MCP_Tool_Mark_Message_Read(hArgs)
   LOCAL hResult := {=>}
   LOCAL oArchive, oItem
   LOCAL cMailbox := "inbox", cId
   LOCAL lRead := .T., lSet := .F.
   LOCAL xUnread

   // Return schema and description when called without arguments
   IF hArgs == NIL .OR. ValType(hArgs) != "H" .OR. Len(hArgs) == 0
      hResult["schema"] := {;
         "type"=>"object",;
         "properties"=>{;
            "id"=>{"type"=>"string","description"=>"The David message id (the 'id' returned by list_inbox)"},;
            "mailbox"=>{"type"=>"string","enum"=>{"inbox","common"},"description"=>"Which mailbox the message is in: 'inbox' (default) or 'common'"},;
            "read"=>{"type"=>"boolean","description"=>"true (default) marks the message as read, false marks it as unread again"};
         },;
         "required"=>{"id"};
      }
      hResult["description"] := "Mark a David message as read (or unread) via its Viewed state. " + ;
                                "The new state is read back after setting, so success means the change actually took effect"
      RETURN hResult
   ENDIF

   cId := hArgs["id"]
   IF HHasKey(hArgs, "mailbox") .AND. ! Empty(hArgs["mailbox"])
      cMailbox := Lower(AllTrim(hArgs["mailbox"]))
   ENDIF
   IF HHasKey(hArgs, "read") .AND. HB_IsLogical(hArgs["read"])
      lRead := hArgs["read"]
   ENDIF

   oArchive := Inbox_Archive(cMailbox)
   IF oArchive == NIL
      hResult["status"] := "error"
      hResult["message"] := "David not connected"
      RETURN hResult
   ENDIF

   BEGIN SEQUENCE
      oItem := oArchive:GetArchiveEntryByID(cId)
   RECOVER
      oItem := NIL
   END SEQUENCE

   IF oItem == NIL
      hResult["status"] := "not_found"
      hResult["message"] := "Message not found: " + cId
      RETURN hResult
   ENDIF

   BEGIN SEQUENCE
      oItem:Viewed := lRead
      lSet := .T.
   RECOVER
      lSet := .F.
   END SEQUENCE

   IF lSet
      // Persist if the API requires it; ignore failure - the verification
      // read below decides whether the change took effect.
      BEGIN SEQUENCE
         oItem:Save()
      RECOVER
      END SEQUENCE
   ENDIF

   // Verify by reading the state back (DV_Unread: unread = ! Viewed)
   xUnread := DV_Unread(oItem)

   hResult["id"] := cId
   hResult["mailbox"] := cMailbox
   IF lSet .AND. ValType(xUnread) == "L" .AND. xUnread == ! lRead
      hResult["unread"] := xUnread
      hResult["status"] := "success"
      hResult["message"] := "Message marked as " + IIF(lRead, "read", "unread")
   ELSEIF ! lSet
      hResult["status"] := "error"
      hResult["message"] := "Setting the Viewed state failed - the David API rejected the write"
   ELSE
      hResult["status"] := "error"
      hResult["message"] := "Viewed state was set but the change could not be verified"
   ENDIF
RETURN hResult

FUNCTION MCP_Tool_Get_Customer_Invoices(hArgs)
   LOCAL hResult := {=>}
   LOCAL oKunde, cKunde
   LOCAL aInvoices := {}, hInv
   LOCAL cStatus := "all", lPaid
   LOCAL nMaxResults := 50
   LOCAL nOldSelect := Select()

   // Return schema and description when called without arguments
   IF hArgs == NIL .OR. ValType(hArgs) != "H" .OR. Len(hArgs) == 0
      hResult["schema"] := {;
         "type"=>"object",;
         "properties"=>{;
            "customer"=>{"type"=>"string","description"=>"Customer matchcode"},;
            "customer_number"=>{"type"=>"number","description"=>"Customer number"},;
            "status_filter"=>{"type"=>"string","enum"=>{"open","paid","all"},"description"=>"Only invoices with this payment status (default all)"},;
            "max_results"=>{"type"=>"number","description"=>"Maximum number of invoices to return, newest first (default 50, max 200)"};
         },;
         "anyOf"=>{{"customer", "customer_number"}};
      }
      hResult["description"] := "List invoices and credit notes for a customer, newest first, with totals, payment " + ;
                                "status and the linked sales order number. Use get_invoice for the full line items"
      RETURN hResult
   ENDIF

   IF HHasKey(hArgs, "status_filter") .AND. hArgs["status_filter"] $ {"open", "paid"}
      cStatus := hArgs["status_filter"]
   ENDIF
   IF HHasKey(hArgs, "max_results") .AND. HB_IsNumeric(hArgs["max_results"]) .AND. hArgs["max_results"] > 0
      nMaxResults := Min(hArgs["max_results"], 200)
   ENDIF

   oKunde := ResolveCustomer(hArgs)
   IF oKunde == NIL
      hResult["status"] := "not_found"
      hResult["message"] := "Customer not found"
      RETURN hResult
   ENDIF

   cKunde := Pad(oKunde:Kunde, 8)

   NetUse("englsre", "re", .F., 5)
   re->(DbSetOrder(2))  // Str(Reposnr,3) + Kunde; Reposnr 0 = invoice header

   IF re->(DbSeek("  0" + cKunde))
      DO WHILE ! re->(Eof()) .AND. re->Reposnr == 0 .AND. re->Kunde == cKunde
         lPaid := re->Code >= 3 .AND. re->Status == 3
         IF cStatus == "all" .OR. (cStatus == "paid" .AND. lPaid) .OR. (cStatus == "open" .AND. ! lPaid)
            hInv := {=>}
            hInv["invoice_number"] := re->Rechnr
            hInv["type"] := IIF(re->PosWt < 0, "credit_note", "invoice")
            hInv["date"] := re->Rechdat
            hInv["total_gross"] := re->PosWt
            hInv["paid_amount"] := re->AoQty
            hInv["paid"] := lPaid
            hInv["currency"] := IIF(Empty(re->Money), "EUR", AllTrim(re->Money))
            IF re->AbNr > 0
               hInv["order_number"] := re->AbNr
            ENDIF
            IF ! Empty(re->MaDate)
               hInv["dunning"] := re->Rem
               hInv["dunning_date"] := re->MaDate
            ENDIF
            AAdd(aInvoices, hInv)
         ENDIF
         re->(DbSkip())
      ENDDO
   ENDIF

   DbSelectArea(nOldSelect)

   ASort(aInvoices,,, {|x, y| x["date"] > y["date"]})
   ASize(aInvoices, Min(Len(aInvoices), nMaxResults))

   hResult["customer"] := HB_StrToUTF8(AllTrim(oKunde:Kunde))
   hResult["customer_number"] := oKunde:Nummer
   hResult["count"] := Len(aInvoices)
   hResult["invoices"] := aInvoices
   hResult["status"] := IIF(Len(aInvoices) > 0, "found", "not_found")
   IF Len(aInvoices) == 0
      hResult["message"] := "No invoices found for this customer"
   ELSEIF Len(aInvoices) == nMaxResults
      hResult["message"] := "Result limited to " + AllTrim(Str(nMaxResults)) + " invoices"
   ENDIF
RETURN hResult

FUNCTION MCP_Tool_Get_Article_Prices(hArgs)
   LOCAL hResult := {=>}
   LOCAL lFound := .F.
   LOCAL aScale, aPair, aScaleOut := {}
   LOCAL aCustPrices := {}, oKunde, cKundma
   LOCAL nQty := 0, nPrice
   LOCAL nOldSelect := Select()

   // Return schema and description when called without arguments
   IF hArgs == NIL .OR. ValType(hArgs) != "H" .OR. Len(hArgs) == 0
      hResult["schema"] := {;
         "type"=>"object",;
         "properties"=>{;
            "matchcode"=>{"type"=>"string","description"=>"Artikel Matchcode"},;
            "partno"=>{"type"=>"string","description"=>"Artikelnummer"},;
            "customer"=>{"type"=>"string","description"=>"Customer matchcode - adds customer-specific prices, part number and discounts"},;
            "quantity"=>{"type"=>"number","description"=>"Quantity - adds the scale price applicable for this quantity"};
         },;
         "anyOf"=>{{"matchcode", "partno"}};
      }
      hResult["description"] := "Get sell prices for an article: scale prices (Staffelpreise) from the article's price " + ;
                                "table, the last sell price, and optionally customer-specific prices and discounts. " + ;
                                "Prices are net EUR per 'price_unit' units of the article's unit"
      RETURN hResult
   ENDIF

   NetUse("artikel", "art")

   IF HHasKey(hArgs, "matchcode") .AND. ! Empty(hArgs["matchcode"])
      art->(DbSetOrder(1))
      lFound := art->(DbSeek(Upper(AllTrim(hArgs["matchcode"]))))
   ELSEIF HHasKey(hArgs, "partno") .AND. ! Empty(hArgs["partno"])
      art->(DbSetOrder(2))
      lFound := art->(DbSeek(Str(IIF(HB_IsNumeric(hArgs["partno"]), hArgs["partno"], Val(AllTrim(hArgs["partno"]))), 6)))
   ENDIF

   IF ! lFound
      DbSelectArea(nOldSelect)
      hResult["status"] := "not_found"
      hResult["message"] := "Article not found"
      RETURN hResult
   ENDIF

   hResult["matchcode"] := HB_StrToUTF8(AllTrim(art->Matchcode))
   hResult["description"] := HB_StrToUTF8(AllTrim(art->Artikel))
   hResult["unit"] := HB_StrToUTF8(AllTrim(art->Me))
   hResult["price_unit"] := art->VkPe
   hResult["currency"] := "EUR"
   hResult["last_sell_price"] := art->Letzte_VK

   // Scale prices from the article's price table via GetPrices() (preise.prg)
   BEGIN SEQUENCE
      aScale := GetPrices(art->Artikelnr, art->Table)
   RECOVER
      aScale := NIL
   END SEQUENCE

   IF HB_IsArray(aScale)
      IF HHasKey(hArgs, "quantity") .AND. HB_IsNumeric(hArgs["quantity"])
         nQty := hArgs["quantity"]
      ENDIF
      FOR EACH aPair IN aScale
         AAdd(aScaleOut, {"quantity"=>aPair[1], "price"=>Round(aPair[2], 4)})
         IF nQty > 0 .AND. nQty >= aPair[1]
            hResult["price_for_quantity"] := Round(aPair[2], 4)
         ENDIF
      NEXT
      hResult["scale_prices"] := aScaleOut
   ELSE
      hResult["scale_prices_error"] := "Price table could not be evaluated"
   ENDIF

   // Customer-specific data from artkund (same lookups as DispPreis in disppreis.prg)
   IF HHasKey(hArgs, "customer") .AND. ! Empty(hArgs["customer"])
      oKunde := Adresse():New()
      IF oKunde:LoadMatchcode(Pad(Upper(AllTrim(hArgs["customer"])), 8), "K")
         cKundma := Pad(oKunde:Kunde, 8)
         NetUse("artkund", "aku")
         aku->(DbSetOrder(1))  // Kunde + Str(Artikelnr,6)
         IF aku->(DbSeek(cKundma + Str(art->Artikelnr, 6)))
            DO WHILE ! aku->(Eof()) .AND. aku->Kunde == cKundma .AND. aku->Artikelnr == art->Artikelnr
               AAdd(aCustPrices, {;
                  "min_quantity"=>aku->LastMenge,;
                  "price"=>aku->LastPrice,;
                  "price_unit"=>aku->Pe,;
                  "discount_percent"=>aku->Rabatt,;
                  "customer_part_no"=>HB_StrToUTF8(AllTrim(aku->Artlief));
               })
               aku->(DbSkip())
            ENDDO
         ENDIF
         hResult["customer"] := HB_StrToUTF8(AllTrim(oKunde:Kunde))
         hResult["customer_prices"] := aCustPrices
         aku->(DbSetOrder(2))  // Kunde + Gruppe
         IF aku->(DbSeek(cKundma + art->Gruppe))
            hResult["customer_group_discount_percent"] := aku->Rabatt
         ENDIF
      ELSE
         hResult["customer_message"] := "Customer not found: " + hArgs["customer"]
      ENDIF
   ENDIF

   DbSelectArea(nOldSelect)
   hResult["status"] := "found"
RETURN hResult

FUNCTION MCP_Tool_Get_Article_Movements(hArgs)
   LOCAL hResult := {=>}
   LOCAL lFound := .F.
   LOCAL cMatch, cBuArt := ""
   LOCAL aMoves := {}, hMove
   LOCAL nLimit := 100, nCount := 0
   LOCAL nOldSelect := Select()

   // Return schema and description when called without arguments
   IF hArgs == NIL .OR. ValType(hArgs) != "H" .OR. Len(hArgs) == 0
      hResult["schema"] := {;
         "type"=>"object",;
         "properties"=>{;
            "matchcode"=>{"type"=>"string","description"=>"Artikel Matchcode"},;
            "partno"=>{"type"=>"string","description"=>"Artikelnummer"},;
            "booking_type"=>{"type"=>"string","description"=>"Optional filter on the booking type (BuArt), e.g. 'WE' (Wareneingang), 'RE' (Rechnung), 'UMB' (Umbuchung), 'STO' (Storno). Case-insensitive"},;
            "limit"=>{"type"=>"number","description"=>"Maximum number of movements to return, newest first (default 100, max 1000)"};
         },;
         "anyOf"=>{{"matchcode", "partno"}};
      }
      hResult["description"] := "Get the stock movement history (Bewegungskonto) of an article from engabg, newest " + ;
                               "first: goods receipts, issues, invoices, corrections and transfers. Each entry has " + ;
                               "date, booking type (BuArt), quantity, resulting stock, price and the linked " + ;
                               "document/order/supplier/customer"
      RETURN hResult
   ENDIF

   NetUse("artikel", "art")

   // Resolve the article first (validates it exists and yields the canonical
   // matchcode engabg is keyed on)
   IF HHasKey(hArgs, "matchcode") .AND. ! Empty(hArgs["matchcode"])
      art->(DbSetOrder(1))
      lFound := art->(DbSeek(Upper(AllTrim(hArgs["matchcode"]))))
   ELSEIF HHasKey(hArgs, "partno") .AND. ! Empty(hArgs["partno"])
      art->(DbSetOrder(2))
      lFound := art->(DbSeek(Str(IIF(HB_IsNumeric(hArgs["partno"]), hArgs["partno"], Val(AllTrim(hArgs["partno"]))), 6)))
   ENDIF

   IF ! lFound
      DbSelectArea(nOldSelect)
      hResult["status"] := "not_found"
      hResult["message"] := "Article not found"
      RETURN hResult
   ENDIF

   cMatch := AllTrim(art->Matchcode)

   IF HHasKey(hArgs, "booking_type") .AND. ! Empty(hArgs["booking_type"])
      cBuArt := Upper(AllTrim(hArgs["booking_type"]))
   ENDIF
   IF HHasKey(hArgs, "limit") .AND. HB_IsNumeric(hArgs["limit"]) .AND. hArgs["limit"] > 0
      nLimit := Min(Int(hArgs["limit"]), 1000)
   ENDIF

   hResult["matchcode"] := HB_StrToUTF8(cMatch)
   hResult["description"] := HB_StrToUTF8(AllTrim(art->Artikel))
   hResult["unit"] := HB_StrToUTF8(AllTrim(art->Me))
   hResult["current_stock"] := art->Bestand

   NetUse("engabg", "abg")
   abg->(DbSetOrder(3))  // Matchcode + Descend(RecNo()) -> newest first per article

   IF abg->(DbSeek(cMatch))
      DO WHILE ! abg->(Eof()) .AND. AllTrim(abg->Matchcode) == cMatch .AND. nCount < nLimit
         IF ! Empty(cBuArt) .AND. Upper(AllTrim(abg->BuArt)) != cBuArt
            abg->(DbSkip())
            LOOP
         ENDIF
         hMove := {=>}
         hMove["date"] := abg->Datum
         hMove["booking_type"] := HB_StrToUTF8(AllTrim(abg->BuArt))
         hMove["quantity"] := abg->Menge
         hMove["stock_after"] := abg->Bestand
         hMove["price"] := abg->Preis
         hMove["price_unit"] := abg->Pe
         IF ! Empty(abg->Liefma)
            hMove["supplier"] := HB_StrToUTF8(AllTrim(abg->Liefma))
         ENDIF
         IF HB_IsNumeric(abg->Kundennr) .AND. abg->Kundennr > 0
            hMove["customer_no"] := abg->Kundennr
         ENDIF
         IF HB_IsNumeric(abg->Besnr) .AND. abg->Besnr > 0
            hMove["order_no"] := abg->Besnr
            hMove["order_pos"] := abg->BesPos
         ENDIF
         IF ! Empty(abg->Beleg)
            hMove["document"] := HB_StrToUTF8(AllTrim(abg->Beleg))
         ENDIF
         IF ! Empty(abg->Info)
            hMove["info"] := HB_StrToUTF8(AllTrim(abg->Info))
         ENDIF
         AAdd(aMoves, hMove)
         nCount++
         abg->(DbSkip())
      ENDDO
      // More records for this article than the limit returned?
      hResult["truncated"] := nCount >= nLimit .AND. ! abg->(Eof()) .AND. AllTrim(abg->Matchcode) == cMatch
   ENDIF

   hResult["movements"] := aMoves
   hResult["count"] := Len(aMoves)

   DbSelectArea(nOldSelect)
   hResult["status"] := "found"
RETURN hResult

FUNCTION MCP_Tool_Get_Article_Suppliers(hArgs)
   LOCAL hResult := {=>}
   LOCAL lFound := .F.
   LOCAL aSuppliers := {}, hSupplier
   LOCAL nOldSelect := Select()

   // Return schema and description when called without arguments
   IF hArgs == NIL .OR. ValType(hArgs) != "H" .OR. Len(hArgs) == 0
      hResult["schema"] := {;
         "type"=>"object",;
         "properties"=>{;
            "matchcode"=>{"type"=>"string","description"=>"Artikel Matchcode"},;
            "partno"=>{"type"=>"string","description"=>"Artikelnummer"};
         },;
         "anyOf"=>{{"matchcode", "partno"}};
      }
      hResult["description"] := "List the suppliers of an article (sources from artlief), ordered by priority, with " + ;
                                "the supplier's part number, lead time in weeks, minimum order quantity, package unit " + ;
                                "and last purchase price"
      RETURN hResult
   ENDIF

   NetUse("artikel", "art")
   NetUse("artlief", "ali")
   NetUse("engkund", "ku")

   IF HHasKey(hArgs, "matchcode") .AND. ! Empty(hArgs["matchcode"])
      art->(DbSetOrder(1))
      lFound := art->(DbSeek(Upper(AllTrim(hArgs["matchcode"]))))
   ELSEIF HHasKey(hArgs, "partno") .AND. ! Empty(hArgs["partno"])
      art->(DbSetOrder(2))
      lFound := art->(DbSeek(Str(IIF(HB_IsNumeric(hArgs["partno"]), hArgs["partno"], Val(AllTrim(hArgs["partno"]))), 6)))
   ENDIF

   IF ! lFound
      DbSelectArea(nOldSelect)
      hResult["status"] := "not_found"
      hResult["message"] := "Article not found"
      RETURN hResult
   ENDIF

   hResult["matchcode"] := HB_StrToUTF8(AllTrim(art->Matchcode))
   hResult["description"] := HB_StrToUTF8(AllTrim(art->Artikel))
   hResult["unit"] := HB_StrToUTF8(AllTrim(art->Me))

   ali->(DbSetOrder(6))  // Str(Artikelnr,6) + Str(Priority,1)
   ku->(DbSetOrder(1))   // Kunde + Group

   IF ali->(DbSeek(Str(art->Artikelnr, 6)))
      DO WHILE ! ali->(Eof()) .AND. ali->Artikelnr == art->Artikelnr
         hSupplier := {=>}
         hSupplier["supplier"] := HB_StrToUTF8(AllTrim(ali->Kunde))
         IF ku->(DbSeek(ali->Kunde + "L"))
            hSupplier["supplier_name"] := HB_StrToUTF8(Trim(Trim(ku->Name1) + " " + ku->Name2))
            hSupplier["supplier_number"] := ku->Nummer
            hSupplier["currency"] := IIF(Empty(ku->Money), "EUR", AllTrim(ku->Money))
         ENDIF
         IF ! Empty(ali->Artlief)
            hSupplier["supplier_part_no"] := HB_StrToUTF8(AllTrim(ali->Artlief))
         ENDIF
         hSupplier["priority"] := ali->Priority
         hSupplier["lead_time_weeks"] := ali->LZ
         hSupplier["min_order_qty"] := ali->Min
         hSupplier["package_unit"] := ali->VPE
         hSupplier["last_price"] := ali->LastPrice
         hSupplier["last_quantity"] := ali->LastMenge
         AAdd(aSuppliers, hSupplier)
         ali->(DbSkip())
      ENDDO
   ENDIF

   DbSelectArea(nOldSelect)

   hResult["count"] := Len(aSuppliers)
   hResult["suppliers"] := aSuppliers
   hResult["status"] := IIF(Len(aSuppliers) > 0, "found", "not_found")
   IF Len(aSuppliers) == 0
      hResult["message"] := "No suppliers recorded for this article"
   ENDIF
RETURN hResult

FUNCTION MCP_Tool_Get_Bom(hArgs)
   LOCAL hResult := {=>}
   LOCAL lFound := .F.
   LOCAL nArtnr
   LOCAL aParts := {}, hPart
   LOCAL nOldSelect := Select()

   // Return schema and description when called without arguments
   IF hArgs == NIL .OR. ValType(hArgs) != "H" .OR. Len(hArgs) == 0
      hResult["schema"] := {;
         "type"=>"object",;
         "properties"=>{;
            "matchcode"=>{"type"=>"string","description"=>"Artikel Matchcode"},;
            "partno"=>{"type"=>"string","description"=>"Artikelnummer"};
         },;
         "anyOf"=>{{"matchcode", "partno"}};
      }
      hResult["description"] := "Get the bill of materials (Stueckliste) of a manufactured article: components with " + ;
                                "position, quantity per unit, factor, additional/setup quantity and current stock, " + ;
                                "plus the production parameters (scrap, lot size). Components that are manufactured " + ;
                                "themselves are flagged has_bom - call this tool again with their matchcode to descend"
      RETURN hResult
   ENDIF

   NetUse("artikel", "art")
   NetUse("parts", "part")
   NetUse("bom", "bom")

   IF HHasKey(hArgs, "matchcode") .AND. ! Empty(hArgs["matchcode"])
      art->(DbSetOrder(1))
      lFound := art->(DbSeek(Upper(AllTrim(hArgs["matchcode"]))))
   ELSEIF HHasKey(hArgs, "partno") .AND. ! Empty(hArgs["partno"])
      art->(DbSetOrder(2))
      lFound := art->(DbSeek(Str(IIF(HB_IsNumeric(hArgs["partno"]), hArgs["partno"], Val(AllTrim(hArgs["partno"]))), 6)))
   ENDIF

   IF ! lFound
      DbSelectArea(nOldSelect)
      hResult["status"] := "not_found"
      hResult["message"] := "Article not found"
      RETURN hResult
   ENDIF

   nArtnr := art->Artikelnr
   hResult["matchcode"] := HB_StrToUTF8(AllTrim(art->Matchcode))
   hResult["description"] := HB_StrToUTF8(AllTrim(art->Artikel))
   hResult["unit"] := HB_StrToUTF8(AllTrim(art->Me))
   hResult["manufactured"] := art->Bezug >= 5  // procurement type >= 5 = made in-house

   // Production parameters from the bom header, when present
   IF bom->(DbSeek(Str(nArtnr, 6)))
      hResult["scrap"] := bom->Scrap
      hResult["min_scrap"] := bom->MinScrap
      hResult["lot_size"] := bom->Lot
   ENDIF

   // Component lines from parts (Listart = parent). The Pos 0 row is the
   // list header (carries the list factor), not a component.
   art->(DbSetOrder(2))  // by Artikelnr, for component lookups
   IF part->(DbSeek(Str(nArtnr, 6)))
      DO WHILE ! part->(Eof()) .AND. part->Listart == nArtnr
         IF part->Pos != 0
            hPart := {=>}
            hPart["item"] := part->Pos
            hPart["quantity"] := part->Qty
            hPart["factor"] := part->Factor
            hPart["unit"] := HB_StrToUTF8(AllTrim(part->Me))
            IF part->AddQty != 0
               hPart["additional_quantity"] := part->AddQty  // setup/attrition add-on
            ENDIF
            IF part->AddPercent != 0
               hPart["additional_percent"] := part->AddPercent
            ENDIF
            IF ! Empty(part->Notes)
               hPart["notes"] := HB_StrToUTF8(AllTrim(part->Notes))
            ENDIF
            IF art->(DbSeek(Str(part->Partart, 6)))
               hPart["article"] := HB_StrToUTF8(AllTrim(art->Matchcode))
               hPart["description"] := HB_StrToUTF8(AllTrim(art->Artikel))
               hPart["stock"] := art->Bestand
               IF art->Bezug >= 5
                  hPart["has_bom"] := .T.  // manufactured component - recurse with get_bom
               ENDIF
            ELSE
               hPart["article_number"] := part->Partart
               hPart["description"] := "(article record not found)"
            ENDIF
            AAdd(aParts, hPart)
         ENDIF
         part->(DbSkip())
      ENDDO
   ENDIF

   DbSelectArea(nOldSelect)

   hResult["component_count"] := Len(aParts)
   hResult["components"] := aParts
   hResult["status"] := IIF(Len(aParts) > 0, "found", "not_found")
   IF Len(aParts) == 0
      hResult["message"] := "No parts list (Stueckliste) recorded for this article"
   ENDIF
RETURN hResult

FUNCTION MCP_Tool_Get_Article_Where_Used(hArgs)
   LOCAL hResult := {=>}
   LOCAL lFound := .F.
   LOCAL nArtnr
   LOCAL aParents := {}, hParent, aRows := {}, hRow
   LOCAL nLimit := 200, nCount := 0
   LOCAL nOldSelect := Select()

   // Return schema and description when called without arguments
   IF hArgs == NIL .OR. ValType(hArgs) != "H" .OR. Len(hArgs) == 0
      hResult["schema"] := {;
         "type"=>"object",;
         "properties"=>{;
            "matchcode"=>{"type"=>"string","description"=>"Artikel Matchcode"},;
            "partno"=>{"type"=>"string","description"=>"Artikelnummer"},;
            "limit"=>{"type"=>"number","description"=>"Maximum number of parent articles to return (default 200, max 2000)"};
         },;
         "anyOf"=>{{"matchcode", "partno"}};
      }
      hResult["description"] := "Where-used (Teileverwendungsnachweis): list the articles whose parts list " + ;
                                "(Stueckliste) consumes this article as a direct component, each with the position " + ;
                                "and quantity per parent. Parents flagged used_elsewhere are themselves a component " + ;
                                "in a higher-level list - call this tool again with their matchcode to ascend"
      RETURN hResult
   ENDIF

   NetUse("artikel", "art")
   NetUse("parts", "part")

   IF HHasKey(hArgs, "matchcode") .AND. ! Empty(hArgs["matchcode"])
      art->(DbSetOrder(1))
      lFound := art->(DbSeek(Upper(AllTrim(hArgs["matchcode"]))))
   ELSEIF HHasKey(hArgs, "partno") .AND. ! Empty(hArgs["partno"])
      art->(DbSetOrder(2))
      lFound := art->(DbSeek(Str(IIF(HB_IsNumeric(hArgs["partno"]), hArgs["partno"], Val(AllTrim(hArgs["partno"]))), 6)))
   ENDIF

   IF ! lFound
      DbSelectArea(nOldSelect)
      hResult["status"] := "not_found"
      hResult["message"] := "Article not found"
      RETURN hResult
   ENDIF

   nArtnr := art->Artikelnr
   hResult["matchcode"] := HB_StrToUTF8(AllTrim(art->Matchcode))
   hResult["description"] := HB_StrToUTF8(AllTrim(art->Artikel))
   hResult["unit"] := HB_StrToUTF8(AllTrim(art->Me))

   IF HHasKey(hArgs, "limit") .AND. HB_IsNumeric(hArgs["limit"]) .AND. hArgs["limit"] > 0
      nLimit := Min(Int(hArgs["limit"]), 2000)
   ENDIF

   // Pass 1: collect the parts rows that consume this article. parts index 2 is
   // keyed on Partart (component), so seeking the article number and iterating
   // while Partart matches yields every parent. Only the parts cursor is
   // touched here so its position survives the loop.
   part->(DbSetOrder(2))  // Str(Partart,6) + ...
   IF part->(DbSeek(Str(nArtnr, 6), .T.))
      DO WHILE ! part->(Eof()) .AND. part->Partart == nArtnr .AND. nCount < nLimit
         IF part->Pos != 0  // skip the list header row (not a real consumption)
            hRow := {=>}
            hRow["listart"]  := part->Listart
            hRow["item"]     := part->Pos
            hRow["quantity"] := part->Qty
            hRow["factor"]   := part->Factor
            hRow["unit"]     := HB_StrToUTF8(AllTrim(part->Me))
            IF part->AddQty != 0
               hRow["additional_quantity"] := part->AddQty
            ENDIF
            IF part->AddPercent != 0
               hRow["additional_percent"] := part->AddPercent
            ENDIF
            IF ! Empty(part->Notes)
               hRow["notes"] := HB_StrToUTF8(AllTrim(part->Notes))
            ENDIF
            AAdd(aRows, hRow)
            nCount++
         ENDIF
         part->(DbSkip())
      ENDDO
      hResult["truncated"] := nCount >= nLimit .AND. ! part->(Eof()) .AND. part->Partart == nArtnr
   ENDIF

   // Pass 2: resolve each parent article and flag whether it is itself consumed
   // higher up (its Artikelnr appears as a Partart somewhere). Safe to seek the
   // parts cursor now that pass 1 has finished iterating it.
   art->(DbSetOrder(2))  // by Artikelnr
   FOR EACH hRow IN aRows
      hParent := {=>}
      IF art->(DbSeek(Str(hRow["listart"], 6)))
         hParent["article"]      := HB_StrToUTF8(AllTrim(art->Matchcode))
         hParent["description"]  := HB_StrToUTF8(AllTrim(art->Artikel))
         hParent["stock"]        := art->Bestand
         hParent["manufactured"] := art->Bezug >= 5
      ELSE
         hParent["article_number"] := hRow["listart"]
         hParent["description"]    := "(article record not found)"
      ENDIF
      hParent["used_at_item"] := hRow["item"]
      hParent["quantity_per"] := hRow["quantity"]
      hParent["factor"]       := hRow["factor"]
      hParent["unit"]         := hRow["unit"]
      IF HHasKey(hRow, "additional_quantity")
         hParent["additional_quantity"] := hRow["additional_quantity"]
      ENDIF
      IF HHasKey(hRow, "additional_percent")
         hParent["additional_percent"] := hRow["additional_percent"]
      ENDIF
      IF HHasKey(hRow, "notes")
         hParent["notes"] := hRow["notes"]
      ENDIF
      // Does this parent itself flow into a higher-level list?
      hParent["used_elsewhere"] := part->(DbSeek(Str(hRow["listart"], 6)))
      AAdd(aParents, hParent)
   NEXT

   DbSelectArea(nOldSelect)

   hResult["used_in_count"] := Len(aParents)
   hResult["used_in"] := aParents
   hResult["status"] := IIF(Len(aParents) > 0, "found", "not_found")
   IF Len(aParents) == 0
      hResult["message"] := "This article is not used as a component in any parts list (Stueckliste)"
   ENDIF
RETURN hResult

// Resolve a supplier from the 'supplier' (matchcode) / 'supplier_number'
// arguments - suppliers are group "L" addresses. Returns NIL if not found.
STATIC FUNCTION ResolveSupplier(hArgs)
   LOCAL oLief := Adresse():New()
   LOCAL lFound := .F.

   IF HHasKey(hArgs, "supplier_number") .AND. HB_IsNumeric(hArgs["supplier_number"]) .AND. hArgs["supplier_number"] > 0
      ku->(DbSetOrder(8))
      lFound := oLief:Load(hArgs["supplier_number"])
   ELSEIF HHasKey(hArgs, "supplier") .AND. ! Empty(hArgs["supplier"])
      lFound := oLief:LoadMatchcode(Pad(Upper(AllTrim(hArgs["supplier"])), 8), "L")
   ENDIF
RETURN IIF(lFound, oLief, NIL)

FUNCTION MCP_Tool_Get_Supplier_Orders(hArgs)
   LOCAL hResult := {=>}
   LOCAL oLief, hOrders := {=>}, hOrder, cKey
   LOCAL aOrders := {}
   LOCAL cStatus := "open", lOpen
   LOCAL nMaxResults := 50
   LOCAL dTemp
   LOCAL nOldSelect := Select()

   // Return schema and description when called without arguments
   IF hArgs == NIL .OR. ValType(hArgs) != "H" .OR. Len(hArgs) == 0
      hResult["schema"] := {;
         "type"=>"object",;
         "properties"=>{;
            "supplier"=>{"type"=>"string","description"=>"Supplier matchcode"},;
            "supplier_number"=>{"type"=>"number","description"=>"Supplier number"},;
            "status_filter"=>{"type"=>"string","enum"=>{"open","completed","all"},"description"=>"Only purchase orders with this status (default open)"},;
            "max_results"=>{"type"=>"number","description"=>"Maximum number of purchase orders to return, newest first (default 50, max 200)"};
         },;
         "anyOf"=>{{"supplier", "supplier_number"}};
      }
      hResult["description"] := "List purchase orders (Bestellungen) for a supplier, newest first, with value, open " + ;
                                "quantities and the next expected delivery date. Use get_purchase_order for line details"
      RETURN hResult
   ENDIF

   IF HHasKey(hArgs, "status_filter") .AND. hArgs["status_filter"] $ {"completed", "all"}
      cStatus := hArgs["status_filter"]
   ENDIF
   IF HHasKey(hArgs, "max_results") .AND. HB_IsNumeric(hArgs["max_results"]) .AND. hArgs["max_results"] > 0
      nMaxResults := Min(hArgs["max_results"], 200)
   ENDIF

   oLief := ResolveSupplier(hArgs)
   IF oLief == NIL
      hResult["status"] := "not_found"
      hResult["message"] := "Supplier not found"
      RETURN hResult
   ENDIF

   NetUse("engbes", "bes")
   bes->(DbSetOrder(2))  // Liefma + Str(Bestat) + ... (see GetSupplierOpenOrders)

   IF bes->(DbSeek(oLief:Kunde))
      DO WHILE ! bes->(Eof()) .AND. bes->Liefma == oLief:Kunde
         lOpen := bes->Bestat < 3
         IF cStatus == "all" .OR. (cStatus == "open" .AND. lOpen) .OR. (cStatus == "completed" .AND. ! lOpen)
            cKey := Str(bes->Besnr, 6)
            IF ! HHasKey(hOrders, cKey)
               hOrder := {=>}
               hOrder["po_number"] := bes->Besnr
               hOrder["date"] := bes->Besda
               hOrder["currency"] := IIF(Empty(bes->Money), "EUR", AllTrim(bes->Money))
               hOrder["status"] := IIF(lOpen, "open", "completed")
               hOrder["line_count"] := 0
               hOrder["open_quantity"] := 0
               hOrder["value"] := 0
               hOrder["next_delivery_week"] := NIL
               hOrders[cKey] := hOrder
            ENDIF
            hOrders[cKey]["line_count"] := hOrders[cKey]["line_count"] + 1
            hOrders[cKey]["value"] := Round(hOrders[cKey]["value"] + ;
               bes->BeQty * (bes->EkPr / IIF(bes->Pe == 0, 1, bes->Pe)) * (100 - bes->Rabatt) / 100, 2)
            IF lOpen
               hOrders[cKey]["status"] := "open"
               hOrders[cKey]["open_quantity"] := hOrders[cKey]["open_quantity"] + (bes->BeQty - bes->GelQty)
               // Lterm is a JJWW calendar week - numeric comparison sorts chronologically
               IF HB_IsNumeric(bes->Lterm) .AND. bes->Lterm > 0 .AND. ;
                  (hOrders[cKey]["next_delivery_week"] == NIL .OR. bes->Lterm < hOrders[cKey]["next_delivery_week"])
                  hOrders[cKey]["next_delivery_week"] := bes->Lterm
               ENDIF
            ENDIF
         ENDIF
         bes->(DbSkip())
      ENDDO
   ENDIF

   DbSelectArea(nOldSelect)

   FOR EACH hOrder IN hOrders
      IF hOrder["next_delivery_week"] != NIL
         IF (dTemp := BesWeekDate(hOrder["next_delivery_week"])) != NIL
            hOrder["next_delivery_date"] := dTemp
         ENDIF
         hOrder["next_delivery_week"] := StrZero(hOrder["next_delivery_week"], 4)
      ENDIF
      AAdd(aOrders, hOrder)
   NEXT
   ASort(aOrders,,, {|x, y| x["po_number"] > y["po_number"]})
   ASize(aOrders, Min(Len(aOrders), nMaxResults))

   hResult["supplier"] := HB_StrToUTF8(AllTrim(oLief:Kunde))
   hResult["supplier_number"] := oLief:Nummer
   hResult["count"] := Len(aOrders)
   hResult["purchase_orders"] := aOrders
   hResult["status"] := IIF(Len(aOrders) > 0, "found", "not_found")
   IF Len(aOrders) == 0
      hResult["message"] := "No " + IIF(cStatus == "all", "", cStatus + " ") + "purchase orders found for this supplier"
   ELSEIF Len(aOrders) == nMaxResults
      hResult["message"] := "Result limited to " + AllTrim(Str(nMaxResults)) + " purchase orders"
   ENDIF
RETURN hResult

FUNCTION MCP_Tool_Book_Shipping_Confirmation(hArgs)
   LOCAL hResult := {=>}
   LOCAL nPo, nPos, nWeek := 0, nWeekRec := 0
   LOCAL cTracking := "", dShipped := NIL, cCarrier := ""
   LOCAL aWeeks := {}
   LOCAL lHasPlan := .F.
   LOCAL nOldSelect := Select()

   // Return schema and description when called without arguments
   IF hArgs == NIL .OR. ValType(hArgs) != "H" .OR. Len(hArgs) == 0
      hResult["schema"] := {;
         "type"=>"object",;
         "properties"=>{;
            "po_number"=>{"type"=>"number","description"=>"Purchase order (Bestellung) number"},;
            "item"=>{"type"=>"number","description"=>"Position number within the purchase order"},;
            "tracking"=>{"type"=>"string","description"=>"Carrier tracking number reported by the supplier"},;
            "shipped_date"=>{"type"=>"string","description"=>"Date the supplier shipped, YYYY-MM-DD"},;
            "carrier"=>{"type"=>"string","description"=>"Shipping company / carrier reported by the supplier (e.g. UPS, DHL, Schenker)"},;
            "week"=>{"type"=>"string","description"=>"JJWW calendar week of the delivery-schedule entry to book on. Required when the position has a Liefereinteilung; must be omitted otherwise"};
         },;
         "required"=>{"po_number","item"};
      }
      hResult["description"] := "Book a supplier shipping confirmation (tracking number, shipped date and/or carrier) " + ;
                                "on a purchase order position - or, when the position has a delivery schedule " + ;
                                "(Liefereinteilung), on the schedule entry of the given week. At least one of " + ;
                                "'tracking', 'shipped_date' or 'carrier' is required. Existing values are only " + ;
                                "overwritten by non-empty inputs, never cleared"
      RETURN hResult
   ENDIF

   IF ! HB_IsNumeric(hArgs["po_number"]) .OR. ! HB_IsNumeric(hArgs["item"])
      RETURN "Parameters 'po_number' and 'item' must be numbers"
   ENDIF
   nPo := hArgs["po_number"]
   nPos := hArgs["item"]

   IF HHasKey(hArgs, "tracking") .AND. ValType(hArgs["tracking"]) == "C"
      cTracking := HB_UTF8ToStr(AllTrim(hArgs["tracking"]))
   ENDIF
   IF HHasKey(hArgs, "shipped_date") .AND. ValType(hArgs["shipped_date"]) == "C" .AND. ! Empty(hArgs["shipped_date"])
      dShipped := SToD(StrTran(AllTrim(hArgs["shipped_date"]), "-", ""))
      IF Empty(dShipped)
         RETURN "Invalid shipped_date: " + hArgs["shipped_date"] + " (expected YYYY-MM-DD)"
      ENDIF
   ENDIF
   IF HHasKey(hArgs, "carrier") .AND. ValType(hArgs["carrier"]) == "C"
      cCarrier := HB_UTF8ToStr(AllTrim(hArgs["carrier"]))
   ENDIF
   IF Empty(cTracking) .AND. Empty(dShipped) .AND. Empty(cCarrier)
      RETURN "Provide at least one of 'tracking', 'shipped_date' or 'carrier'"
   ENDIF
   IF HHasKey(hArgs, "week") .AND. ! Empty(hArgs["week"])
      nWeek := IIF(HB_IsNumeric(hArgs["week"]), hArgs["week"], Val(AllTrim(hArgs["week"])))
   ENDIF

   NetUse("engbes", "bes")
   NetUse("besdel", "bdel")

   IF bes->(FieldPos("TRACKING")) == 0 .OR. bes->(FieldPos("SHIPPED")) == 0
      DbSelectArea(nOldSelect)
      RETURN "The TRACKING/SHIPPED fields are not present in the database yet - deploy the Bestellbestaetigung update first"
   ENDIF

   bes->(DbSetOrder(1))  // Str(Besnr,6) + Str(Posnr,3)
   IF ! bes->(DbSeek(Str(nPo, 6) + Str(nPos, 3)))
      DbSelectArea(nOldSelect)
      hResult["status"] := "not_found"
      hResult["message"] := "Purchase order position not found: " + AllTrim(Str(nPo)) + "/" + AllTrim(Str(nPos))
      RETURN hResult
   ENDIF

   // Positions with a delivery schedule must be booked per schedule entry -
   // the same rule the Bestellbestaetigung mask enforces (WHEN ! lHasPlan).
   // The besdel index covers Besnr+Posnr only (not the week), so the entry
   // for a week is located by iterating, remembering its RecNo.
   bdel->(DbSetOrder(1))  // Str(Besnr,6) + Str(Posnr,3)
   IF bdel->(DbSeek(Str(nPo, 6) + Str(nPos, 3)))
      lHasPlan := .T.
      DO WHILE ! bdel->(Eof()) .AND. bdel->Besnr == nPo .AND. bdel->Posnr == nPos
         AAdd(aWeeks, StrZero(bdel->Lterm, 4))
         IF nWeek > 0 .AND. bdel->Lterm == nWeek .AND. nWeekRec == 0
            nWeekRec := bdel->(RecNo())
         ENDIF
         bdel->(DbSkip())
      ENDDO
   ENDIF

   IF lHasPlan
      IF bdel->(FieldPos("TRACKING")) == 0 .OR. bdel->(FieldPos("SHIPPED")) == 0
         DbSelectArea(nOldSelect)
         RETURN "The TRACKING/SHIPPED fields are not present on the delivery schedule yet - deploy the Bestellbestaetigung update first"
      ENDIF
      IF nWeek == 0
         DbSelectArea(nOldSelect)
         RETURN "This position has a delivery schedule (Liefereinteilung) - specify 'week' to book the " + ;
                "confirmation on a schedule entry. Available weeks: " + DV_Join(aWeeks, ", ")
      ENDIF
      IF nWeekRec == 0
         DbSelectArea(nOldSelect)
         RETURN "No delivery-schedule entry in week " + StrZero(nWeek, 4) + ". Available weeks: " + DV_Join(aWeeks, ", ")
      ENDIF
      bdel->(DbGoto(nWeekRec))
      IF ! bdel->(Rec_Lock(0))
         DbSelectArea(nOldSelect)
         hResult["status"] := "error"
         hResult["message"] := "Delivery-schedule record is locked by another user - try again later"
         RETURN hResult
      ENDIF
      IF ! Empty(cTracking)
         bdel->Tracking := cTracking
      ENDIF
      IF ! Empty(dShipped)
         bdel->Shipped := dShipped
      ENDIF
      IF ! Empty(cCarrier)
         IF bdel->(FieldPos("CARRIER")) > 0
            bdel->Carrier := cCarrier
         ELSE
            hResult["carrier_message"] := "CARRIER field not present on besdel yet - carrier not stored"
         ENDIF
      ENDIF
      bdel->(dbUnlock())

      hResult["level"] := "schedule"
      hResult["week"] := StrZero(nWeek, 4)
      hResult["tracking"] := HB_StrToUTF8(AllTrim(bdel->Tracking))
      IF ! Empty(bdel->Shipped)
         hResult["shipped_date"] := bdel->Shipped
      ENDIF
      IF bdel->(FieldPos("CARRIER")) > 0 .AND. ! Empty(bdel->Carrier)
         hResult["carrier"] := HB_StrToUTF8(AllTrim(bdel->Carrier))
      ENDIF
   ELSE
      IF nWeek > 0
         DbSelectArea(nOldSelect)
         RETURN "This position has no delivery schedule - omit 'week'"
      ENDIF
      IF ! bes->(Rec_Lock(0))
         DbSelectArea(nOldSelect)
         hResult["status"] := "error"
         hResult["message"] := "Purchase order record is locked by another user - try again later"
         RETURN hResult
      ENDIF
      IF ! Empty(cTracking)
         bes->Tracking := cTracking
      ENDIF
      IF ! Empty(dShipped)
         bes->Shipped := dShipped
      ENDIF
      IF ! Empty(cCarrier)
         IF bes->(FieldPos("CARRIER")) > 0
            bes->Carrier := cCarrier
         ELSE
            hResult["carrier_message"] := "CARRIER field not present on engbes yet - carrier not stored"
         ENDIF
      ENDIF
      bes->(dbUnlock())

      hResult["level"] := "position"
      hResult["tracking"] := HB_StrToUTF8(AllTrim(bes->Tracking))
      IF ! Empty(bes->Shipped)
         hResult["shipped_date"] := bes->Shipped
      ENDIF
      IF bes->(FieldPos("CARRIER")) > 0 .AND. ! Empty(bes->Carrier)
         hResult["carrier"] := HB_StrToUTF8(AllTrim(bes->Carrier))
      ENDIF
   ENDIF

   hResult["po_number"] := nPo
   hResult["item"] := nPos
   hResult["supplier"] := HB_StrToUTF8(AllTrim(bes->Liefma))
   hResult["article"] := HB_StrToUTF8(AllTrim(bes->Matchcode))
   hResult["confirmed"] := Upper(AllTrim(bes->Confirmed)) == "Y"

   DbSelectArea(nOldSelect)

   hResult["status"] := "success"
   hResult["message"] := "Shipping confirmation booked on " + ;
      IIF(lHasPlan, "delivery-schedule entry week " + StrZero(nWeek, 4), "position " + AllTrim(Str(nPos))) + ;
      " of purchase order " + AllTrim(Str(nPo))
RETURN hResult

FUNCTION MCP_Tool_Confirm_Purchase_Order(hArgs)
   LOCAL hResult := {=>}
   LOCAL nPo, nPos, nWeek := 0, nWk
   LOCAL cAbNr := ""
   LOCAL lHasPlan := .F.
   LOCAL nUpdated := 0
   LOCAL dTemp
   LOCAL nOldSelect := Select()

   // Return schema and description when called without arguments
   IF hArgs == NIL .OR. ValType(hArgs) != "H" .OR. Len(hArgs) == 0
      hResult["schema"] := {;
         "type"=>"object",;
         "properties"=>{;
            "po_number"=>{"type"=>"number","description"=>"Purchase order (Bestellung) number"},;
            "item"=>{"type"=>"number","description"=>"Position number within the purchase order"},;
            "ab_number"=>{"type"=>"string","description"=>"The supplier's order confirmation (AB) number"},;
            "week"=>{"type"=>"string","description"=>"Confirmed delivery week in JJWW format (e.g. 2634 = week 34 of 2026). Not allowed when the position has a Liefereinteilung - the week is maintained on the schedule there"};
         },;
         "required"=>{"po_number","item"};
      }
      hResult["description"] := "Book a supplier order confirmation (Bestellbestaetigung) on a purchase order position: " + ;
                                "marks the position as confirmed and optionally stores the supplier's AB number and the " + ;
                                "confirmed delivery week. Follow-up (Folge) positions are updated along, as in the Trader " + ;
                                "confirmation mask. Quantity or price deviations on the confirmation cannot be booked " + ;
                                "here - maintain those in Trader and report them to the user"
      RETURN hResult
   ENDIF

   IF ! HB_IsNumeric(hArgs["po_number"]) .OR. ! HB_IsNumeric(hArgs["item"])
      RETURN "Parameters 'po_number' and 'item' must be numbers"
   ENDIF
   nPo := hArgs["po_number"]
   nPos := hArgs["item"]

   IF HHasKey(hArgs, "ab_number") .AND. ValType(hArgs["ab_number"]) == "C"
      cAbNr := HB_UTF8ToStr(AllTrim(hArgs["ab_number"]))
   ENDIF
   IF HHasKey(hArgs, "week") .AND. ! Empty(hArgs["week"])
      nWeek := IIF(HB_IsNumeric(hArgs["week"]), hArgs["week"], Val(AllTrim(hArgs["week"])))
      nWk := Val(Right(StrZero(nWeek, 4), 2))
      IF nWeek < 1000 .OR. nWeek > 9999 .OR. nWk < 1 .OR. (nWk > 53 .AND. nWk < 97)
         RETURN "Invalid week: " + AllTrim(Str(nWeek)) + " (expected JJWW, e.g. 2634; weeks 01-53 or 97-99)"
      ENDIF
   ENDIF

   NetUse("engbes", "bes")
   NetUse("besdel", "bdel")

   bes->(DbSetOrder(1))  // Str(Besnr,6) + Str(Posnr,3)
   IF ! bes->(DbSeek(Str(nPo, 6) + Str(nPos, 3)))
      DbSelectArea(nOldSelect)
      hResult["status"] := "not_found"
      hResult["message"] := "Purchase order position not found: " + AllTrim(Str(nPo)) + "/" + AllTrim(Str(nPos))
      RETURN hResult
   ENDIF

   // With a delivery schedule the position's delivery week is maintained via
   // the schedule entries (the mask blocks the Lterm GET in that case)
   bdel->(DbSetOrder(1))
   lHasPlan := bdel->(DbSeek(Str(nPo, 6) + Str(nPos, 3)))
   IF lHasPlan .AND. nWeek > 0
      DbSelectArea(nOldSelect)
      RETURN "This position has a delivery schedule (Liefereinteilung) - its delivery week is maintained " + ;
             "on the schedule entries. Book the confirmation without 'week' or adjust the schedule in Trader"
   ENDIF

   // Update the position and its follow-up (Folge) positions - same loop as
   // the Bestellbestaetigung mask in BestellungConfirm.prg
   DO WHILE ! bes->(Eof()) .AND. bes->Besnr == nPo .AND. (bes->Posnr == nPos .OR. bes->FolgeTo == nPos)
      IF ! bes->(Rec_Lock(0))
         DbSelectArea(nOldSelect)
         hResult["status"] := "error"
         hResult["message"] := "Record is locked by another user - " + ;
            IIF(nUpdated == 0, "nothing was booked", AllTrim(Str(nUpdated)) + " position(s) were already updated") + ;
            ". Try again later"
         RETURN hResult
      ENDIF
      IF ! Empty(cAbNr)
         bes->AbNr := cAbNr
      ENDIF
      IF nWeek > 0
         bes->Lterm := nWeek
      ENDIF
      bes->Confirmed := "Y"
      bes->(dbUnlock())
      nUpdated++
      bes->(DbSkip())
   ENDDO

   // Re-read the main position for the response
   bes->(DbSeek(Str(nPo, 6) + Str(nPos, 3)))

   // Fremdfertigung: when the position belongs to a production order
   // (werkauf, index 6 = Besnr+Posnr), the confirmed week also sets the
   // production order's end week: confirmed week plus the position's transit
   // time (ShipTime); special weeks (>52) are taken verbatim and frame
   // production orders (end week 99) are never touched. Same logic as
   // BestellungConfirm.prg, but with bes repositioned on the main position
   // first so ShipTime is read from the correct record.
   IF nWeek > 0
      NetUse("werkauf", "wer")
      wer->(DbSetOrder(6))  // Str(Besnr,6) + Str(Posnr,3)
      IF wer->(DbSeek(Str(nPo, 6) + Str(nPos, 3))) .AND. Right(Str(wer->End, 4), 2) != "99"
         IF wer->(Rec_Lock(0))
            wer->End := IIF(Val(Right(Str(nWeek, 4), 2)) <= 52, AddWeeks(nWeek, bes->ShipTime), nWeek)
            wer->(dbUnlock())
            hResult["production_order_updated"] := .T.
            hResult["production_order_end_week"] := StrZero(wer->End, 4)
            IF (dTemp := BesWeekDate(wer->End)) != NIL
               hResult["production_order_end_date"] := dTemp
            ENDIF
         ELSE
            hResult["production_order_updated"] := .F.
            hResult["production_order_message"] := "Production order record is locked by another user - its end week was NOT updated"
         ENDIF
      ENDIF
   ENDIF

   // Run the after-confirmation hook exactly like the mask. BATCHMODE is set
   // at server start, so the hook takes its non-interactive path there.
   // IMPORTANT deploy order: the batch-safe version of after_confirm_bes_pos
   // (Trader-Hooks) must be live before this server version - the original
   // hook shows a Tr_MsgBox loop that would block the headless server.
   BEGIN SEQUENCE
      Hook("after_confirm_bes_pos", {BestellungPos():New()})
      hResult["hook_executed"] := .T.
   RECOVER
      hResult["hook_executed"] := .F.
      hResult["hook_message"] := "after_confirm_bes_pos hook raised an error - check its batch-mode path"
   END SEQUENCE

   hResult["po_number"] := nPo
   hResult["item"] := nPos
   hResult["supplier"] := HB_StrToUTF8(AllTrim(bes->Liefma))
   hResult["article"] := HB_StrToUTF8(AllTrim(bes->Matchcode))
   hResult["confirmed"] := Upper(AllTrim(bes->Confirmed)) == "Y"
   IF ! Empty(bes->AbNr)
      hResult["supplier_ab_number"] := HB_StrToUTF8(AllTrim(bes->AbNr))
   ENDIF
   IF HB_IsNumeric(bes->Lterm) .AND. bes->Lterm > 0
      hResult["delivery_week"] := StrZero(bes->Lterm, 4)
      IF (dTemp := BesWeekDate(bes->Lterm)) != NIL
         hResult["delivery_date"] := dTemp
      ENDIF
   ENDIF
   hResult["positions_updated"] := nUpdated
   hResult["has_delivery_schedule"] := lHasPlan

   DbSelectArea(nOldSelect)

   hResult["status"] := "success"
   hResult["message"] := "Order confirmation booked on position " + AllTrim(Str(nPos)) + ;
      " of purchase order " + AllTrim(Str(nPo)) + ;
      IIF(nUpdated > 1, " (including " + AllTrim(Str(nUpdated - 1)) + " follow-up position(s))", "")
RETURN hResult

FUNCTION MCP_Tool_Send_SMS(hArgs)
   LOCAL hResult := {=>}
   LOCAL aPhones := {}, aInvalid := {}
   LOCAL aParts, cPhone, cChar, nDigits
   LOCAL cMessage
   LOCAL oAccount
   LOCAL nX

   // Return schema and description when called without arguments
   IF hArgs == NIL .OR. ValType(hArgs) != "H" .OR. Len(hArgs) == 0
      hResult["schema"] := {;
         "type"=>"object",;
         "properties"=>{;
            "to"=>{"type"=>"string","description"=>"Recipient phone number(s), multiple numbers separated by comma or semicolon. International format preferred (e.g. +491711234567)"},;
            "message"=>{"type"=>"string","description"=>"Text of the SMS"};
         },;
         "required"=>{"to","message"};
      }
      hResult["description"] := "Send an SMS through the David InfoCenter via SendSMS()"
      RETURN hResult
   ENDIF

   IF ValType(hArgs["to"]) != "C" .OR. ValType(hArgs["message"]) != "C"
      RETURN "Parameters 'to' and 'message' must be strings"
   ENDIF

   aParts := hb_ATokens(StrTran(hArgs["to"], ",", ";"), ";")
   FOR EACH cPhone IN aParts
      cPhone := AllTrim(cPhone)
      IF Empty(cPhone)
         LOOP
      ENDIF
      // minimal sanity check: only phone characters, at least 5 digits
      nDigits := 0
      FOR nX := 1 TO Len(cPhone)
         cChar := SubStr(cPhone, nX, 1)
         IF IsDigit(cChar)
            nDigits++
         ELSEIF ! cChar $ "+-/() "
            nDigits := -1
            EXIT
         ENDIF
      NEXT
      IF nDigits >= 5
         AAdd(aPhones, cPhone)
      ELSE
         AAdd(aInvalid, cPhone)
      ENDIF
   NEXT

   IF Len(aInvalid) > 0
      RETURN "Invalid phone number(s): " + DV_Join(aInvalid, ", ")
   ENDIF
   IF Len(aPhones) == 0
      RETURN "No valid phone number provided"
   ENDIF

   cMessage := DV_FromUtf8(hArgs["message"])
   cMessage := StrTran(cMessage, Chr(13) + Chr(10), Chr(13))
   cMessage := StrTran(cMessage, Chr(10), Chr(13))

   BEGIN SEQUENCE
      MailConnect()
      oAccount := DV_GetMailAccount()
   RECOVER
      oAccount := NIL
   END SEQUENCE

   IF oAccount == NIL
      hResult["status"] := "error"
      hResult["message"] := "David not connected - SMS not sent"
      RETURN hResult
   ENDIF

   BEGIN SEQUENCE
      SendSMS(aPhones, cMessage)
   RECOVER
      hResult["status"] := "error"
      hResult["message"] := "Failed to send SMS"
      RETURN hResult
   END SEQUENCE

   hResult["status"] := "success"
   hResult["recipients"] := aPhones
   hResult["message"] := "SMS handed to David for sending"
RETURN hResult

FUNCTION MCP_Tool_Get_Article_Options(hArgs)
   LOCAL hResult := {=>}
   LOCAL cBase := "", cMatch := "", cLang := "DE"
   LOCAL oBase, aEnv
   LOCAL aTables := {}
   LOCAL aKeys   // function-level: nested codeblocks cannot reach outer-block locals (E0005)
   LOCAL nPos := 0
   LOCAL nOldSelect := Select()

   // Return schema and description when called without arguments
   IF hArgs == NIL .OR. ValType(hArgs) != "H" .OR. Len(hArgs) == 0
      hResult["schema"] := {;
         "type"=>"object",;
         "properties"=>{;
            "base"=>{"type"=>"string","description"=>"Option base/model code - the fixed matchcode prefix of the variant family"},;
            "matchcode"=>{"type"=>"string","description"=>"Full matchcode of a variant article - resolves the base and additionally decodes which option is selected per table"},;
            "language"=>{"type"=>"string","description"=>"Language for table names and option descriptions (e.g. DE, EN; default DE)"};
         },;
         "anyOf"=>{{"base", "matchcode"}};
      }
      hResult["description"] := "Read the article variant option tables (Optionen/Varianten): per option table its " + ;
                                "function name, character position and length within the matchcode, and all keys with " + ;
                                "their descriptions. Given a full variant matchcode, the selected key per table is " + ;
                                "decoded as well - useful to configure or explain a variant article"
      RETURN hResult
   ENDIF

   IF HHasKey(hArgs, "language") .AND. ! Empty(hArgs["language"])
      cLang := Upper(AllTrim(hArgs["language"]))
   ENDIF

   NetUse("artikel", "art")
   NetUse("optbas", "opb")
   NetUse("option", "op")

   IF HHasKey(hArgs, "matchcode") .AND. ! Empty(hArgs["matchcode"])
      art->(DbSetOrder(1))
      IF ! art->(DbSeek(Upper(AllTrim(HB_UTF8ToStr(hArgs["matchcode"])))))
         DbSelectArea(nOldSelect)
         hResult["status"] := "not_found"
         hResult["message"] := "Article not found"
         RETURN hResult
      ENDIF
      IF ! (art->Variant == "V" .AND. art->Length > 0)
         DbSelectArea(nOldSelect)
         hResult["status"] := "error"
         hResult["message"] := "Article is not a variant article - pass 'base' if you meant an option family code"
         RETURN hResult
      ENDIF
      cMatch := art->Matchcode
      cBase := SubStr(art->Matchcode, 1, art->Length)
      hResult["matchcode"] := HB_StrToUTF8(AllTrim(cMatch))
   ELSE
      cBase := Upper(AllTrim(HB_UTF8ToStr(hArgs["base"])))
   ENDIF

   aEnv := SaveEnv()
   oBase := OptionBase():New()
   IF ! oBase:Load(cBase)
      RestEnv(aEnv)
      DbSelectArea(nOldSelect)
      hResult["status"] := "not_found"
      hResult["message"] := "Option base not found: " + AllTrim(cBase)
      RETURN hResult
   ENDIF

   hResult["base"] := HB_StrToUTF8(AllTrim(cBase))
   hResult["language"] := cLang

   // Tables in matchcode order; nPos walks the character position within the
   // matchcode (base prefix first), same decoding as GetEnhancedDescription
   nPos := oBase:GetLength(0) + 1  // model length only (no tables yet)
   oBase:oTables:Each({|oTable|
      LOCAL hTable := {=>}
      LOCAL oSel, cCode
      aKeys := {}
      hTable["table"] := oTable:Table
      hTable["function"] := HB_StrToUTF8(AllTrim(oTable:Funktion(cLang)))
      hTable["position"] := nPos
      hTable["length"] := oTable:Length
      oTable:oKeys:Each({|oKey|
         AAdd(aKeys, {;
            "code"=>HB_StrToUTF8(oKey:TabKey),;
            "description"=>HB_StrToUTF8(AllTrim(oKey:Descript(cLang)));
         })
         RETURN .T.
      })
      hTable["keys"] := aKeys
      IF ! Empty(cMatch)
         cCode := SubStr(cMatch, nPos, oTable:Length)
         hTable["selected_code"] := HB_StrToUTF8(cCode)
         oSel := oTable:oKeys:GetRecord(cCode)
         IF oSel != NIL
            hTable["selected"] := HB_StrToUTF8(AllTrim(oSel:Descript(cLang)))
         ENDIF
      ENDIF
      nPos += oTable:Length
      AAdd(aTables, hTable)
      RETURN .T.
   })

   RestEnv(aEnv)
   DbSelectArea(nOldSelect)

   hResult["table_count"] := Len(aTables)
   hResult["tables"] := aTables
   hResult["status"] := "found"
RETURN hResult

FUNCTION MCP_Tool_Get_Production_Order(hArgs)
   LOCAL hResult := {=>}
   LOCAL nFa, hComp, dTemp
   LOCAL aComponents := {}
   LOCAL nRequired
   LOCAL nForecast := 0, lProducible
   LOCAL cMissing, cForecastMissing, aMissing, aForecastMissing
   LOCAL hMiss, hMissOut, aMissOut
   LOCAL nOldSelect := Select()

   // Return schema and description when called without arguments
   IF hArgs == NIL .OR. ValType(hArgs) != "H" .OR. Len(hArgs) == 0
      hResult["schema"] := {;
         "type"=>"object",;
         "properties"=>{;
            "fa_number"=>{"type"=>"number","description"=>"Production order (Fertigungsauftrag) number"};
         },;
         "required"=>{"fa_number"};
      }
      hResult["description"] := "Retrieve a production order (Fertigungsauftrag) by number: article, quantities, " + ;
                                "status, end week/date, and for external manufacturing (Fremdfertigung) the supplier " + ;
                                "and linked purchase order. Includes the material list (required/booked/missing per " + ;
                                "component) and a producibility check: 'producible' (with current stock, incl. " + ;
                                "blocks and approvals), 'due' (start date reached), and for future starts " + ;
                                "'producible_by_start' considering expected receipts"
      RETURN hResult
   ENDIF

   IF ! HB_IsNumeric(hArgs["fa_number"])
      RETURN "Parameter 'fa_number' must be a number"
   ENDIF
   nFa := hArgs["fa_number"]

   NetUse("werkauf", "wer")
   NetUse("werks", "we")
   NetUse("artikel", "art")

   wer->(DbSetOrder(1))  // Aufno
   IF ! wer->(DbSeek(Str(nFa, 6)))
      DbSelectArea(nOldSelect)
      hResult["status"] := "not_found"
      hResult["message"] := "Production order not found: " + AllTrim(Str(nFa))
      RETURN hResult
   ENDIF

   art->(DbSetOrder(2))  // Artikelnr

   hResult["fa_number"] := nFa
   hResult["article"] := HB_StrToUTF8(AllTrim(wer->Matchcode))
   IF art->(DbSeek(Str(wer->Artno, 6)))
      hResult["description"] := HB_StrToUTF8(AllTrim(art->Artikel))
   ENDIF
   hResult["quantity"] := wer->Qty
   hResult["produced_quantity"] := wer->GelQty
   hResult["open_quantity"] := Max(wer->Qty - wer->GelQty, 0)
   hResult["fa_status"] := wer->Status
   hResult["active"] := wer->Status < 4  // < 4 = not yet completed (see werkauf browses)
   hResult["frame"] := Right(Str(wer->End, 4), 2) == "99"  // Rahmen-FA (see model/wa.prg)

   IF HB_IsNumeric(wer->End) .AND. wer->End > 0
      hResult["end_week"] := StrZero(wer->End, 4)
      IF (dTemp := BesWeekDate(wer->End)) != NIL
         hResult["end_date"] := dTemp
      ENDIF
   ENDIF
   IF ! Empty(wer->StartDate)
      hResult["start_date"] := wer->StartDate
   ENDIF

   // External manufacturing (Fremdfertigung): supplier and linked PO
   IF ! Empty(wer->Liefma)
      hResult["external"] := .T.
      hResult["supplier"] := HB_StrToUTF8(AllTrim(wer->Liefma))
      IF wer->Besnr > 0
         hResult["purchase_order"] := wer->Besnr
         hResult["purchase_order_item"] := wer->BesPos
      ENDIF
   ELSE
      hResult["external"] := .F.
   ENDIF

   // Material list from werks: required = Qty * Factor, booked = BookQty
   // (same arithmetic as the shortage checks in model/artikel.prg)
   we->(DbSetOrder(1))  // Aufno (+ Pos)
   IF we->(DbSeek(Str(nFa, 6)))
      DO WHILE ! we->(Eof()) .AND. we->Aufno == nFa
         hComp := {=>}
         hComp["item"] := we->Pos
         IF art->(DbSeek(Str(we->PartArt, 6)))
            hComp["article"] := HB_StrToUTF8(AllTrim(art->Matchcode))
            hComp["description"] := HB_StrToUTF8(AllTrim(art->Artikel))
            hComp["stock"] := art->Bestand
         ELSE
            hComp["article_number"] := we->PartArt
         ENDIF
         nRequired := we->Qty * we->Factor
         hComp["required_quantity"] := nRequired
         hComp["booked_quantity"] := we->BookQty
         hComp["missing_quantity"] := Max(nRequired - we->BookQty, 0)
         AAdd(aComponents, hComp)
         we->(DbSkip())
      ENDDO
   ENDIF

   // Producibility via WAStatus() (fertigung_edit.prg) - the same routine the
   // Fertigung screens and RUN_FIND_FA_PRODUCABLE use. The return value
   // reflects the CURRENT stock; with a future start date the forecast lists
   // additionally consider expected receipts up to the start (working days).
   IF wer->Status < 4 .AND. ! hResult["frame"]
      wer->(DbSetOrder(1))
      wer->(DbSeek(Str(nFa, 6)))  // WAStatus works on the current wer record
      hResult["due"] := Empty(wer->StartDate) .OR. wer->StartDate <= Date()
      nForecast := 0
      IF ! Empty(wer->StartDate) .AND. wer->StartDate > Date()
         BEGIN SEQUENCE
            nForecast := CountWorkingDays(Date(), wer->StartDate, GetConfigValue("STATE"), .T.)
         RECOVER
            nForecast := 0
         END SEQUENCE
      ENDIF
      BEGIN SEQUENCE
         lProducible := WAStatus(NIL, @cMissing, nForecast, @cForecastMissing, @aMissing, @aForecastMissing)
         hResult["producible"] := lProducible
         aMissOut := {}
         FOR EACH hMiss IN aMissing
            IF HB_IsHash(hMiss)
               hMissOut := {=>}
               hMissOut["type"] := hMiss["TYPE"]
               hMissOut["message"] := HB_StrToUTF8(hMiss["MESSAGE"])
               IF HHasKey(hMiss, "DATA")
                  hMissOut["data"] := _HashToUtf8(hMiss["DATA"])
               ENDIF
               AAdd(aMissOut, hMissOut)
            ENDIF
         NEXT
         hResult["missing"] := aMissOut
         IF nForecast > 0
            hResult["forecast_working_days"] := nForecast
            hResult["producible_by_start"] := Len(aForecastMissing) == 0
            aMissOut := {}
            FOR EACH hMiss IN aForecastMissing
               IF HB_IsHash(hMiss)
                  hMissOut := {=>}
                  hMissOut["type"] := hMiss["TYPE"]
                  hMissOut["message"] := HB_StrToUTF8(hMiss["MESSAGE"])
                  IF HHasKey(hMiss, "DATA")
                     hMissOut["data"] := _HashToUtf8(hMiss["DATA"])
                  ENDIF
                  AAdd(aMissOut, hMissOut)
               ENDIF
            NEXT
            hResult["missing_by_start"] := aMissOut
         ENDIF
      RECOVER
         hResult["producible_message"] := "Producibility check failed"
      END SEQUENCE
   ENDIF

   DbSelectArea(nOldSelect)

   hResult["component_count"] := Len(aComponents)
   hResult["components"] := aComponents
   hResult["status"] := "found"
RETURN hResult

FUNCTION MCP_Tool_Get_Current_User(hArgs)
   LOCAL hResult := {=>}
   LOCAL nUser
   LOCAL aRoles := {}, aMail := {}
   LOCAL cAddr
   LOCAL nOldSelect := Select()

   // Return schema and description when called without arguments
   IF hArgs == NIL .OR. ValType(hArgs) != "H" .OR. Len(hArgs) == 0
      hResult["schema"] := {;
         "type"=>"object",;
         "properties"=>{=>},;
         "required"=>{};
      }
      hResult["description"] := "Information about the Trader user the current request runs as: number, name, email, " + ;
                                "active flag, David link and roles. With HTTP API-key authentication this reflects " + ;
                                "the authenticated key's user; via STDIO it is the user the server was started as"
      RETURN hResult
   ENDIF

   nUser := Tr_GetIni(28)
   hResult["user_number"] := nUser

   IF ! HB_IsNumeric(nUser) .OR. nUser <= 0
      hResult["status"] := "none"
      hResult["message"] := "No user context - server started without a user (-U) and no authenticated API key"
      RETURN hResult
   ENDIF

   NetUse("buyer", "buy")
   buy->(DbGoTo(nUser))
   IF buy->(Eof())
      DbSelectArea(nOldSelect)
      hResult["status"] := "not_found"
      hResult["message"] := "User " + AllTrim(Str(nUser)) + " not found in the user file"
      RETURN hResult
   ENDIF

   hResult["name"] := HB_StrToUTF8(AllTrim(buy->Buyer))
   hResult["email"] := HB_StrToUTF8(AllTrim(buy->Email))
   hResult["initials"] := HB_StrToUTF8(AllTrim(buy->Initials))
   hResult["phone"] := HB_StrToUTF8(AllTrim(buy->Telefon))
   hResult["active"] := buy->Aktive
   hResult["david_linked"] := ! Empty(buy->David_ID)

   // Roles via the user model; guarded - a missing roles file must not fail
   // the whole call
   BEGIN SEQUENCE
      SystemUser():oRoles:Each({|oRole|
         AAdd(aRoles, HB_StrToUTF8(AllTrim(oRole:Name)))
         RETURN .T.
      })
   RECOVER
   END SEQUENCE
   hResult["roles"] := aRoles

   // Outgoing mail addresses are known once the David connection was made
   BEGIN SEQUENCE
      FOR EACH cAddr IN SystemUser():aOutMailAddresses
         AAdd(aMail, DV_Utf8(cAddr))
      NEXT
   RECOVER
   END SEQUENCE
   IF Len(aMail) > 0
      hResult["mail_addresses"] := aMail
   ENDIF

   DbSelectArea(nOldSelect)
   hResult["status"] := "found"
RETURN hResult


//---------------------------------------------------------------------------
// Archive tools - store documents/emails on a business transaction (Vorgang)
// through the existing archive hooks (AddFileToArchive / GetArchiveFiles in
// source\archive.prg -> Trader-Hooks). Valid doc types come from
// Trader-Hooks/archive.ch - keep the list below in sync with it.
//---------------------------------------------------------------------------

//#define ARCHIVE_DOC_TYPES "AB,AUF,ANG,ANF,BA,BES,BB,LS,RE,PI,TA,NT,KA,KAM,INV,ER,COC,QT,PP"

// Replace characters that are invalid in file names
STATIC FUNCTION SafeFileName(cName)
   LOCAL cOut := "", nX, cChar
   FOR nX := 1 TO Len(cName)
      cChar := SubStr(cName, nX, 1)
      IF cChar $ '\/:*?"<>|' + Chr(13) + Chr(10) + Chr(9)
         cOut += "_"
      ELSE
         cOut += cChar
      ENDIF
   NEXT
RETURN AllTrim(cOut)

FUNCTION MCP_Tool_Archive_Document(hArgs)
   LOCAL hResult := {=>}
   LOCAL cTyp, nNo, cFile, cId, cMailbox := "inbox"
   LOCAL cAttFilter := ""
   LOCAL oArchive, oItem, nAtt := 0, nX, oAtt, cName
   LOCAL cTempDir, cTarget, cArchived
   LOCAL aArchived := {}, aAvailable := {}
   LOCAL cSubject, cSender, cBody, cText
   LOCAL hDocType
   #include '..\hooks\archive.ch'

   // Return schema and description when called without arguments
   IF hArgs == NIL .OR. ValType(hArgs) != "H" .OR. Len(hArgs) == 0
      hResult["schema"] := {;
         "type"=>"object",;
         "properties"=>{;
            "doc_type"=>{"type"=>"string","enum"=>{},"description"=>"Transaction type: "},;      
            "number"=>{"type"=>"number","description"=>"Number of the transaction (e.g. the Bestellnummer for BES/BB)"},;
            "file"=>{"type"=>"string","description"=>"Full path (as seen by the Trader server) of a file to archive"},;
            "message_id"=>{"type"=>"string","description"=>"David message id (from list_inbox) - archives the message's attachments, or the mail text when it has none"},;
            "mailbox"=>{"type"=>"string","enum"=>{"inbox","common"},"description"=>"Mailbox of message_id (default inbox)"},;
            "attachment"=>{"type"=>"string","description"=>"Archive only the attachment with this file name (default: all attachments)"};
         },;
         "required"=>{"doc_type","number"},;
         "anyOf"=>{{"file", "message_id"}};
      }
            //"AB","AUF","ANG","ANF","BA","BES","BB","LS","RE","PI","TA","NT","KA","KAM","INV","ER","COC","QT","PP"},"description"=>"Transaction type: AB=Auftragsbestaetigung, AUF=Auftrag, ANG=Angebot, ANF=Anfrage, BES=Bestellung, BB=Bestellbestaetigung, LS=Lieferschein, RE=Rechnung, ER=Eingangsrechnung, QT=Einkaufsangebot, NT=Notiz, COC=Werksbescheinigung, PP=Pruefprotokoll, ..."},;
      FOR EACH hDocType IN hTypes
         Aadd(hResult["schema"]["properties"]["doc_type"]["enum"],hDocType:__enumKey)
         hResult["schema"]["properties"]["doc_type"]["description"] += IF(hDocType:__eNumIndex>1,",","")+hDocType:__enumKey+"="+HB_StrToUtf8(hDocType["NAME"])
      NEXT
      hResult["description"] := "Archive a document or a David email to a business transaction (Vorgang), e.g. a " + ;
                                "supplier's order confirmation PDF to purchase order BB/4711. Files are stored via " + ;
                                "the standard Trader archive (same location the archive browser shows). Source is " + ;
                                "either a file path or an inbox message (its attachments; the mail text as .txt when " + ;
                                "there are none)"
      RETURN hResult
   ENDIF

   

   IF ValType(hArgs["doc_type"]) != "C" .OR. ! Upper(AllTrim(hArgs["doc_type"])) $ hTypes
      RETURN "Invalid doc_type. Valid types: " + DV_Join(HGetKeys(hTypes), ", ")
   ENDIF
   IF ! HB_IsNumeric(hArgs["number"])
      RETURN "Parameter 'number' must be a number"
   ENDIF
   cTyp := Upper(AllTrim(hArgs["doc_type"]))
   nNo := hArgs["number"]

   IF HHasKey(hArgs, "attachment") .AND. ValType(hArgs["attachment"]) == "C"
      cAttFilter := Upper(AllTrim(hArgs["attachment"]))
   ENDIF

   IF HHasKey(hArgs, "file") .AND. ! Empty(hArgs["file"])
      // ---- archive a file from disk ----
      cFile := HB_UTF8ToStr(AllTrim(hArgs["file"]))
      IF ! File(cFile)
         RETURN "File not found: " + cFile
      ENDIF
      BEGIN SEQUENCE
         cArchived := AddFileToArchive(cTyp, nNo, cFile, .T.)
      RECOVER
         cArchived := ""
      END SEQUENCE
      IF Empty(cArchived)
         hResult["status"] := "error"
         hResult["message"] := "Archiving failed - the archive hook returned no target file"
         RETURN hResult
      ENDIF
      AAdd(aArchived, {"source"=>HB_StrToUTF8(cFile), "archived_as"=>HB_StrToUTF8(cArchived)})
   ELSE
      // ---- archive a David message (attachments, or the text body) ----
      cId := hArgs["message_id"]
      IF HHasKey(hArgs, "mailbox") .AND. ! Empty(hArgs["mailbox"])
         cMailbox := Lower(AllTrim(hArgs["mailbox"]))
      ENDIF
      oArchive := Inbox_Archive(cMailbox)
      IF oArchive == NIL
         hResult["status"] := "error"
         hResult["message"] := "David not connected"
         RETURN hResult
      ENDIF
      BEGIN SEQUENCE
         oItem := oArchive:GetArchiveEntryByID(cId)
      RECOVER
         oItem := NIL
      END SEQUENCE
      IF oItem == NIL
         hResult["status"] := "not_found"
         hResult["message"] := "Message not found: " + cId
         RETURN hResult
      ENDIF

      cTempDir := hb_DirTemp()
      BEGIN SEQUENCE ; nAtt := oItem:Attachments:Count ; RECOVER ; nAtt := 0 ; END SEQUENCE

      FOR nX := 0 TO nAtt - 1
         cName := ""
         BEGIN SEQUENCE
            oAtt := oItem:Attachments:Item(nX)
            cName := oAtt:FileName
         RECOVER
            oAtt := NIL
         END SEQUENCE
         IF oAtt == NIL .OR. Empty(cName)
            LOOP
         ENDIF
         AAdd(aAvailable, DV_Utf8(cName))
         IF ! Empty(cAttFilter) .AND. Upper(AllTrim(cName)) != cAttFilter
            LOOP
         ENDIF
         cTarget := cTempDir + SafeFileName(cName)
         cArchived := ""
         BEGIN SEQUENCE
            oAtt:SaveAs(cTarget)
            IF File(cTarget)
               cArchived := AddFileToArchive(cTyp, nNo, cTarget, .T.)
               FErase(cTarget)
            ENDIF
         RECOVER
            cArchived := ""
         END SEQUENCE
         IF ! Empty(cArchived)
            AAdd(aArchived, {"source"=>DV_Utf8(cName), "archived_as"=>HB_StrToUTF8(cArchived)})
         ELSE
            AAdd(aArchived, {"source"=>DV_Utf8(cName), "error"=>"could not be saved/archived"})
         ENDIF
      NEXT

      IF ! Empty(cAttFilter) .AND. Len(aArchived) == 0
         RETURN "Attachment not found: " + hArgs["attachment"] + ". Available: " + DV_Join(aAvailable, ", ")
      ENDIF

      // No attachments (and no filter): archive the mail text itself
      IF Len(aArchived) == 0
         BEGIN SEQUENCE ; cSubject := oItem:Subject ; RECOVER ; cSubject := "" ; END SEQUENCE
         BEGIN SEQUENCE ; cSender := oItem:Fields:Item("SRFrom"):Value ; RECOVER ; cSender := "" ; END SEQUENCE
         BEGIN SEQUENCE ; cBody := oItem:Fields:Item("Content"):Value ; RECOVER ; cBody := "" ; END SEQUENCE
         cText := "Von: " + cSender + Chr(13) + Chr(10) + ;
                  "Betreff: " + cSubject + Chr(13) + Chr(10) + ;
                  Replicate("-", 60) + Chr(13) + Chr(10) + cBody
         cTarget := cTempDir + SafeFileName(IIF(Empty(cSubject), "email", cSubject)) + ".txt"
         cArchived := ""
         BEGIN SEQUENCE
            hb_MemoWrit(cTarget, cText)
            cArchived := AddFileToArchive(cTyp, nNo, cTarget, .T.)
            FErase(cTarget)
         RECOVER
            cArchived := ""
         END SEQUENCE
         IF Empty(cArchived)
            hResult["status"] := "error"
            hResult["message"] := "Archiving the mail text failed"
            RETURN hResult
         ENDIF
         AAdd(aArchived, {"source"=>"mail text: " + DV_Utf8(cSubject), "archived_as"=>HB_StrToUTF8(cArchived)})
      ENDIF
   ENDIF

   hResult["doc_type"] := cTyp
   hResult["number"] := nNo
   hResult["archived"] := aArchived
   hResult["count"] := Len(aArchived)
   hResult["status"] := "success"
RETURN hResult

FUNCTION MCP_Tool_Archive_Incoming_Invoice(hArgs)
   LOCAL hResult := {=>}
   LOCAL cFile := "", cId, cMailbox := "inbox", cAttFilter := ""
   LOCAL cLiefma := "", nLiefnr := 0, nKonto := 0
   LOCAL cBeleg, cBelegKurz := "", cKS := ""
   LOCAL nBetrag, dEingang := Date()
   LOCAL nApprover := 0
   LOCAL lFound := .F., lBooked := .F.
   LOCAL nID := 0, nRev := 0, nYear := Year(Date())
   LOCAL oArchive, oItem, oAtt, nAtt := 0, nX, cName
   LOCAL aNames := {}, cTarget := "", lTempFile := .F.
   LOCAL cArchived
   LOCAL oKu
   LOCAL nOldSelect := Select()

   // Return schema and description when called without arguments
   IF hArgs == NIL .OR. ValType(hArgs) != "H" .OR. Len(hArgs) == 0
      hResult["schema"] := {;
         "type"=>"object",;
         "properties"=>{;
            "file"=>{"type"=>"string","description"=>"Full path (on the Trader server) of the invoice document"},;
            "message_id"=>{"type"=>"string","description"=>"David message id (from list_inbox) - archives the invoice attachment of that mail"},;
            "mailbox"=>{"type"=>"string","enum"=>{"inbox","common"},"description"=>"Mailbox of message_id (default inbox)"},;
            "attachment"=>{"type"=>"string","description"=>"File name of the attachment to use; required when the message has more than one attachment"},;
            "supplier"=>{"type"=>"string","description"=>"Supplier matchcode (Kreditor with address record)"},;
            "konto"=>{"type"=>"number","description"=>"Kreditor account number - for creditors without a supplier address (e.g. utilities)"},;
            "beleg"=>{"type"=>"string","description"=>"The supplier's invoice number as printed on the document"},;
            "beleg_short"=>{"type"=>"string","description"=>"Short form of the invoice number when the bookkeeping uses a truncated one"},;
            "amount"=>{"type"=>"number","description"=>"Gross invoice amount (negative for credit notes)"},;
            "date"=>{"type"=>"string","description"=>"Receipt date YYYY-MM-DD (default today)"},;
            "cost_center"=>{"type"=>"string","description"=>"Cost center (Kostenstelle), e.g. 000, 100, ... 800"},;
            "approver_user"=>{"type"=>"number","description"=>"Trader user number who must approve the invoice. Required for NEW invoices that are not booked yet - ask the user if unknown"};
         },;
         "required"=>{"beleg","amount"},;
         "anyOf"=>{{"file","message_id"},{"supplier","konto"}};
      }
      hResult["description"] := "Archive an incoming supplier invoice (Eingangsrechnung): registers it in the invoice " + ;
                                "register (reb) with a new ER number - or books a new revision when the same supplier " + ;
                                "invoice number already exists - writes the receipt/archive protocol and files the " + ;
                                "document under ER in the archive. Unbooked new invoices go to the approval workflow " + ;
                                "and need 'approver_user'. Lexware booking-text tagging and the auto-approval rules " + ;
                                "of the interactive mask are NOT applied here"
      RETURN hResult
   ENDIF

   // ---- validate arguments ----
   IF ValType(hArgs["beleg"]) != "C" .OR. Empty(AllTrim(hArgs["beleg"]))
      RETURN "Parameter 'beleg' must be a non-empty string"
   ENDIF
   IF ! HB_IsNumeric(hArgs["amount"])
      RETURN "Parameter 'amount' must be a number"
   ENDIF
   cBeleg := Pad(HB_UTF8ToStr(AllTrim(hArgs["beleg"])), 30)
   nBetrag := hArgs["amount"]
   IF HHasKey(hArgs, "beleg_short") .AND. ValType(hArgs["beleg_short"]) == "C"
      cBelegKurz := HB_UTF8ToStr(AllTrim(hArgs["beleg_short"]))
   ENDIF
   IF HHasKey(hArgs, "cost_center") .AND. ValType(hArgs["cost_center"]) == "C"
      cKS := AllTrim(hArgs["cost_center"])
   ENDIF
   IF HHasKey(hArgs, "date") .AND. ValType(hArgs["date"]) == "C" .AND. ! Empty(hArgs["date"])
      dEingang := SToD(StrTran(AllTrim(hArgs["date"]), "-", ""))
      IF Empty(dEingang)
         RETURN "Invalid date: " + hArgs["date"] + " (expected YYYY-MM-DD)"
      ENDIF
   ENDIF
   nYear := Year(dEingang)
   IF HHasKey(hArgs, "approver_user") .AND. HB_IsNumeric(hArgs["approver_user"])
      nApprover := hArgs["approver_user"]
   ENDIF

   NetUse("reb", "reb")
   NetUse("rebprot", "rebp")
   NetUse("idx", "idx")
   NetUse("engkund", "ku")
   NetUse("engrech", "rech")
   NetUse("buyer", "buy")

   // ---- resolve creditor ----
   IF HHasKey(hArgs, "supplier") .AND. ! Empty(hArgs["supplier"])
      oKu := Adresse():New()
      IF ! oKu:LoadMatchcode(Pad(Upper(AllTrim(hArgs["supplier"])), 8), "L")
         DbSelectArea(nOldSelect)
         hResult["status"] := "not_found"
         hResult["message"] := "Supplier not found: " + hArgs["supplier"]
         RETURN hResult
      ENDIF
      cLiefma := oKu:Kunde
      nLiefnr := oKu:Nummer
   ELSE
      IF ! HB_IsNumeric(hArgs["konto"]) .OR. hArgs["konto"] <= 0
         DbSelectArea(nOldSelect)
         RETURN "Parameter 'konto' must be a positive number"
      ENDIF
      nKonto := hArgs["konto"]
   ENDIF

   // ---- resolve the document file ----
   IF HHasKey(hArgs, "file") .AND. ! Empty(hArgs["file"])
      cFile := HB_UTF8ToStr(AllTrim(hArgs["file"]))
      IF ! File(cFile)
         DbSelectArea(nOldSelect)
         RETURN "File not found: " + cFile
      ENDIF
   ELSE
      cId := hArgs["message_id"]
      IF HHasKey(hArgs, "mailbox") .AND. ! Empty(hArgs["mailbox"])
         cMailbox := Lower(AllTrim(hArgs["mailbox"]))
      ENDIF
      IF HHasKey(hArgs, "attachment") .AND. ValType(hArgs["attachment"]) == "C"
         cAttFilter := Upper(AllTrim(hArgs["attachment"]))
      ENDIF
      oArchive := Inbox_Archive(cMailbox)
      IF oArchive == NIL
         DbSelectArea(nOldSelect)
         hResult["status"] := "error"
         hResult["message"] := "David not connected"
         RETURN hResult
      ENDIF
      BEGIN SEQUENCE
         oItem := oArchive:GetArchiveEntryByID(cId)
      RECOVER
         oItem := NIL
      END SEQUENCE
      IF oItem == NIL
         DbSelectArea(nOldSelect)
         hResult["status"] := "not_found"
         hResult["message"] := "Message not found: " + cId
         RETURN hResult
      ENDIF
      BEGIN SEQUENCE ; nAtt := oItem:Attachments:Count ; RECOVER ; nAtt := 0 ; END SEQUENCE
      FOR nX := 0 TO nAtt - 1
         cName := ""
         BEGIN SEQUENCE
            oAtt := oItem:Attachments:Item(nX)
            cName := oAtt:FileName
         RECOVER
            oAtt := NIL
         END SEQUENCE
         IF oAtt == NIL .OR. Empty(cName)
            LOOP
         ENDIF
         AAdd(aNames, DV_Utf8(cName))
         IF Empty(cTarget) .AND. ( Empty(cAttFilter) .OR. Upper(AllTrim(cName)) == cAttFilter )
            cTarget := hb_DirTemp() + SafeFileName(cName)
            BEGIN SEQUENCE
               oAtt:SaveAs(cTarget)
               IF File(cTarget)
                  cFile := cTarget
                  lTempFile := .T.
               ELSE
                  cTarget := ""
               ENDIF
            RECOVER
               cTarget := ""
            END SEQUENCE
         ENDIF
      NEXT
      IF Empty(cFile)
         DbSelectArea(nOldSelect)
         RETURN IIF(Len(aNames) == 0, "The message has no attachments", ;
            "Attachment could not be resolved. Available: " + DV_Join(aNames, ", "))
      ENDIF
      IF Empty(cAttFilter) .AND. Len(aNames) > 1
         FErase(cFile)
         DbSelectArea(nOldSelect)
         RETURN "The message has " + AllTrim(Str(Len(aNames))) + " attachments - specify 'attachment'. Available: " + DV_Join(aNames, ", ")
      ENDIF
   ENDIF

   // ---- duplicate / revision detection (same as the mask, skipping STORNs) ----
   rebp->(DbSetOrder(2))  // Str(ID,9) + Type
   IF nLiefnr > 0
      reb->(DbSetOrder(6))  // Str(Liefnr,6) + Beleg
      IF reb->(DbSeek(Str(nLiefnr, 6) + cBeleg))
         DO WHILE reb->Liefnr == nLiefnr .AND. reb->Beleg == cBeleg .AND. rebp->(DbSeek(Str(reb->ID, 9) + "STORN"))
            reb->(DbSkip())
         ENDDO
         IF reb->Liefnr == nLiefnr .AND. reb->Beleg == cBeleg
            lFound := .T.
            nID := reb->ID
         ENDIF
      ENDIF
      // booked already? (goods-receipt invoice register)
      rech->(DbSetOrder(2))
      IF rech->(DbSeek(cLiefma + IIF(Empty(cBelegKurz), cBeleg, cBelegKurz)))
         lBooked := rech->Booked
      ENDIF
   ELSE
      reb->(DbSetOrder(7))  // Str(Konto,6) + Beleg
      IF reb->(DbSeek(Str(nKonto, 6) + cBeleg))
         DO WHILE reb->Konto == nKonto .AND. reb->Beleg == cBeleg .AND. rebp->(DbSeek(Str(reb->ID, 9) + "STORN"))
            reb->(DbSkip())
         ENDDO
         IF reb->Konto == nKonto .AND. reb->Beleg == cBeleg
            lFound := .T.
            nID := reb->ID
         ENDIF
      ENDIF
   ENDIF

   // New, unbooked invoices enter the approval workflow and need an approver
   IF ! lFound .AND. ! lBooked
      IF nApprover <= 0
         IF lTempFile
            FErase(cFile)
         ENDIF
         DbSelectArea(nOldSelect)
         RETURN "This is a new, not yet booked invoice - 'approver_user' is required so it enters the approval workflow"
      ENDIF
      buy->(DbGoTo(nApprover))
      IF buy->(Eof()) .OR. ! buy->Aktive
         IF lTempFile
            FErase(cFile)
         ENDIF
         DbSelectArea(nOldSelect)
         RETURN "approver_user " + AllTrim(Str(nApprover)) + " is unknown or inactive"
      ENDIF
   ENDIF

   // ---- register in reb/rebp inside a transaction (same as the mask) ----
   LETO_BEGINTRANSACTION()
   BEGIN SEQUENCE
      IF ! lFound
         // New ER number: YY + type(0 = no barcode) + idx counter
         IF ! idx->(DbSeek(Pad("REB", 5) + Right(Str(nYear, 4), 2) + Str(0, 1)))
            idx->(Add_Rec(0))
            idx->Alias := "REB"
            idx->Type := 0
            idx->Year := nYear
         ELSE
            idx->(Rec_Lock())
         ENDIF
         idx->ID++
         nID := Val(Right(Str(nYear, 4), 2) + Str(0, 1) + StrZero(idx->ID, 6))

         reb->(Add_Rec(0))
         reb->ID := nID
         IF nLiefnr > 0
            reb->Liefnr := nLiefnr
            reb->Name := Trim(ku->Name1) + " " + Trim(ku->Name2)
         ELSE
            reb->Konto := nKonto
         ENDIF
         reb->Beleg := cBeleg
         IF ! Empty(cBelegKurz)
            reb->Beleg_Kurz := cBelegKurz
         ENDIF
         reb->Status := IIF(lBooked, 9, 0)
         IF ! lBooked
            reb->Person := nApprover
         ENDIF
         nRev := 0
      ELSE
         reb->(Rec_Lock(0))
         reb->Rev++
         nRev := reb->Rev
         rebp->(Add_Rec(0))
         rebp->ID := nID
         rebp->Type := "NEW"
         rebp->DateTime := TtoS(DateTime())
         rebp->Person := Tr_Getini(28)
         rebp->Rev := nRev
      ENDIF

      reb->Betrag := nBetrag
      IF ! Empty(cKS)
         reb->KS := cKS
      ENDIF

      rebp->(Add_Rec(0))
      rebp->ID := nID
      rebp->DateTime := DtoS(dEingang)
      rebp->Type := "RECV"
      rebp->Person := Tr_Getini(28)
      rebp->Rev := nRev

      rebp->(Add_Rec(0))
      rebp->ID := nID
      rebp->DateTime := TtoS(DateTime())
      rebp->Type := "ARCHIV"
      rebp->Person := Tr_Getini(28)
      rebp->Rev := nRev

      IF ! LETO_COMMITTRANSACTION()
         LETO_ROLLBACK()
         BREAK
      ENDIF
   RECOVER
      BEGIN SEQUENCE ; LETO_ROLLBACK() ; RECOVER ; END SEQUENCE
      IF lTempFile
         FErase(cFile)
      ENDIF
      DbSelectArea(nOldSelect)
      hResult["status"] := "error"
      hResult["message"] := "Registering the invoice failed - nothing was saved"
      RETURN hResult
   END SEQUENCE

   // ---- file the document (after the commit, like the mask) ----
   BEGIN SEQUENCE
      cArchived := AddFileToArchive("ER", nID, cFile)
   RECOVER
      cArchived := ""
   END SEQUENCE
   IF lTempFile
      FErase(cFile)
   ENDIF

   DbSelectArea(nOldSelect)

   hResult["er_number"] := nID
   hResult["revision"] := nRev
   IF nLiefnr > 0
      hResult["supplier"] := HB_StrToUTF8(AllTrim(cLiefma))
   ELSE
      hResult["konto"] := nKonto
   ENDIF
   hResult["beleg"] := HB_StrToUTF8(AllTrim(cBeleg))
   hResult["amount"] := nBetrag
   hResult["receipt_date"] := dEingang
   hResult["booked"] := lBooked
   IF ! lFound .AND. ! lBooked
      hResult["approver_user"] := nApprover
      hResult["approval"] := "pending"
   ENDIF
   IF Empty(cArchived)
      hResult["status"] := "warning"
      hResult["message"] := "Invoice registered as ER" + AllTrim(Str(nID)) + ;
         " but filing the document in the archive FAILED - archive the file manually"
   ELSE
      hResult["archived_as"] := HB_StrToUTF8(cArchived)
      hResult["status"] := "success"
      hResult["message"] := IIF(lFound, ;
         "New revision " + AllTrim(Str(nRev)) + " archived on existing ER" + AllTrim(Str(nID)), ;
         "Invoice registered and archived as ER" + AllTrim(Str(nID)))
   ENDIF
RETURN hResult

FUNCTION MCP_Tool_List_Archive_Documents(hArgs)
   LOCAL hResult := {=>}
   LOCAL cTyp, nNo
   LOCAL aFiles, aFile, hDoc
   LOCAL aDocs := {}
   LOCAL hDocType
   #include '..\hooks\archive.ch'

   // Return schema and description when called without arguments
   IF hArgs == NIL .OR. ValType(hArgs) != "H" .OR. Len(hArgs) == 0
      hResult["schema"] := {;
         "type"=>"object",;
         "properties"=>{;
            "doc_type"=>{"type"=>"string","enum"=>{},"description"=>"Transaction type: "},; //"AB","AUF","ANG","ANF","BA","BES","BB","LS","RE","PI","TA","NT","KA","KAM","INV","ER","COC","QT","PP"},"description"=>"Transaction type (same codes as archive_document)"},;
            "number"=>{"type"=>"number","description"=>"Number of the transaction"};
         },;
         "required"=>{"doc_type","number"};
      }
      FOR EACH hDocType IN hTypes
         Aadd(hResult["schema"]["properties"]["doc_type"]["enum"],hDocType:__enumKey)
         hResult["schema"]["properties"]["doc_type"]["description"] += IF(hDocType:__eNumIndex>1,",","")+hDocType:__enumKey+"="+HB_StrToUtf8(hDocType["NAME"])
      NEXT
      hResult["description"] := "List the documents archived on a business transaction (Vorgang), oldest first, " + ;
                                "with name, date and file path - e.g. everything filed on Bestellung 4711 under BES/BB"
      RETURN hResult
   ENDIF

   IF ValType(hArgs["doc_type"]) != "C" .OR. ! Upper(AllTrim(hArgs["doc_type"])) $ hTypes
      RETURN "Invalid doc_type. Valid types: " + DV_Join(HGetKeys(hTypes), ", ")
   ENDIF
   IF ! HB_IsNumeric(hArgs["number"])
      RETURN "Parameter 'number' must be a number"
   ENDIF
   cTyp := Upper(AllTrim(hArgs["doc_type"]))
   nNo := hArgs["number"]

   BEGIN SEQUENCE
      aFiles := GetArchiveFiles({cTyp => nNo})
   RECOVER
      aFiles := NIL
   END SEQUENCE

   IF ! HB_IsArray(aFiles)
      hResult["status"] := "error"
      hResult["message"] := "Archive lookup failed"
      RETURN hResult
   ENDIF

   // Directory()-style entries: [1] display name, [2] size, [3] date,
   // [4] time, [6] full path (see Trader-Hooks/get_archive_files.prg)
   FOR EACH aFile IN aFiles
      IF HB_IsArray(aFile) .AND. Len(aFile) >= 6
         hDoc := {=>}
         hDoc["name"] := HB_StrToUTF8(AllTrim(aFile[1]))
         IF HB_IsNumeric(aFile[2])
            hDoc["size"] := aFile[2]
         ENDIF
         hDoc["date"] := aFile[3]
         hDoc["time"] := aFile[4]
         hDoc["path"] := HB_StrToUTF8(aFile[6])
         AAdd(aDocs, hDoc)
      ENDIF
   NEXT

   hResult["doc_type"] := cTyp
   hResult["number"] := nNo
   hResult["count"] := Len(aDocs)
   hResult["documents"] := aDocs
   hResult["status"] := IIF(Len(aDocs) > 0, "found", "not_found")
   IF Len(aDocs) == 0
      hResult["message"] := "No documents archived on this transaction"
   ENDIF
RETURN hResult

// Convert all string values in a hash from OEM to ANSI
STATIC FUNCTION _HashToUtf8(hHash)
   LOCAL cKey, xValue
   IF ValType(hHash) != "H"
      RETURN hHash
   ENDIF
   FOR EACH cKey IN HB_HKeys(hHash)
      xValue := hHash[cKey]
      IF ValType(xValue) == "C"
         hHash[cKey] := Hb_StrToUtf8(xValue)               
      ENDIF
   NEXT
RETURN hHash


//#include "shopware_api.prg"  // Include Shopware API class