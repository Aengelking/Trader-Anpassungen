/*
 * MCP (Model Context Protocol) Server for Trader - STDIO Integrated Version
 *
 * This module implements an MCP server that communicates via stdin/stdout
 * with full database integration for Claude Desktop.
 *
 * Copyright 2025 Trader Development Team
 * 
 */

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
   // (error handler, hooks) ever pops a modal Alert/MsgBox that
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
   LOCAL oError
   
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
      BEGIN SEQUENCE WITH {|oErr| Break(oErr)}
         cResponse := HB_ExecFromArray(cFunctionName, {hRequest, xId})
      RECOVER USING oError
         cMessage := "Error executing method: " + cFunctionName
         IF HB_IsObject(oError)
            cMessage += " [" + ;
               IIF(Empty(oError:SubSystem), "?", oError:SubSystem) + "/" + ;
               LTrim(Str(IIF(HB_IsNumeric(oError:GenCode), oError:GenCode, 0))) + ;
               IIF(Empty(oError:Description), "", " " + oError:Description) + ;
               IIF(Empty(oError:Operation), "", " (" + oError:Operation + ")") + "]"
         ENDIF
         cResponse := CreateErrorResponse(cMessage, xID)
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

FUNCTION MCP_Tool_Get_Supplier(hArgs)
   LOCAL hResult := {=>}
   LOCAL oLief

   // Return schema and description when called without arguments
   IF hArgs == NIL .OR. ValType(hArgs) != "H" .OR. Len(hArgs) == 0
      hResult["schema"] := {;
         "type"=>"object",;
         "properties"=>{;
            "supplier"=>{"type"=>"string","description"=>"Supplier matchcode"},;
            "supplier_number"=>{"type"=>"number","description"=>"Supplier number"};
         },;
         "anyOf"=>{{"supplier", "supplier_number"}};
      }
      hResult["description"] := "Retrieve supplier (Lieferant) information by supplier matchcode or number - the " + ;
                                "supplier equivalent of get_customer"
      RETURN hResult
   ENDIF

   NetUse("engkund", "ku")
   oLief := ResolveSupplier(hArgs)   // group "L" address, by supplier / supplier_number
   IF oLief == NIL
      hResult["status"] := "not_found"
      hResult["message"] := "Supplier not found"
      RETURN hResult
   ENDIF

   hResult["number"] := oLief:nummer
   hResult["name"] := AllTrim(oLief:cName)
   hResult["street"] := AllTrim(oLief:street)
   hResult["city"] := AllTrim(oLief:town)
   hResult["country"] := AllTrim(oLief:cLand)
   hResult["status"] := "found"
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
      // Load by matchcode (tolerate a client sending it as a JSON number)
      art->(DbSetOrder(1))  // Assume order 1 is by matchcode
      lFound := art->(DbSeek(Pad(HB_CStr(hArgs["matchcode"]),25)))
   ELSEIF HHasKey(hArgs,"partno") .AND. !Empty(hArgs["partno"])
      // Search by part number (tolerate string or numeric input)
      art->(DbSetOrder(2))
      lFound := art->(DbSeek(Str(IIF(HB_IsNumeric(hArgs["partno"]), hArgs["partno"], Val(HB_CStr(hArgs["partno"]))),6)))
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

RETURN _HashToUtf8(hResult)

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
      hResult["description"] := "Retrieve detailed order information by order number. The customer's own order " + ;
                                "number (Kundenauftragsnummer) is per line item (customer_order_number on each line); " + ;
                                "the header value is the first line's. Line items include status, the confirmed " + ;
                                "delivery week/date, the customer's requested week and - when the date was moved - " + ;
                                "the originally confirmed week"
      RETURN hResult
   ENDIF

   oAuftrag := Auftrag():New()
   IF  oAuftrag:Load(hArgs["order_number"])
      lFound := .T.
      hResult["order_number"] := oAuftrag:abnr
      hResult["customer"] := HB_StrToUTF8(AllTrim(oAuftrag:Kundma))
      hResult["customer_order_number"] := HB_StrToUTF8(AllTrim(oAuftrag:Aufnr))  // header = first line's; per-line values are on each line
      hResult["date"] := oAuftrag:Besda
      hResult["completed"] := oAuftrag:Erledigt //auf->Status == 3 .OR. auf->Status == 7
      hResult["total"] := oAuftrag:total
      hResult["lines"] := {}
      oAuftrag:Positions:Each({|oPos|
         LOCAL hPosition := {=>}
         LOCAL dTemp
         hPosition["item"] := oPos:Itmnr
         hPosition["article"] := HB_StrToUTF8(AllTrim(oPos:Matchcode))
         hPosition["customer_order_number"] := HB_StrToUTF8(AllTrim(oPos:Aufnr))  // the customer PO no is per position
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
         hResult["matchcode"] := HB_StrToUTF8(AllTrim(cMatchcode))
         hResult["description"] := HB_StrToUTF8(AllTrim(art->artikel))
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
   cMatchcodePrefix := IIF(HHasKey(hArgs, "matchcode_prefix"), AllTrim(hArgs["matchcode_prefix"]), "")  // matchcode is case-sensitive
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
      hArticle["matchcode"] := HB_StrToUTF8(AllTrim(art->matchcode))
      hArticle["description"] := GetEnhancedDescription(art->artikelnr)
      hArticle["unit"] := HB_StrToUTF8(AllTrim(art->Me))
      hArticle["group"] := HB_StrToUTF8(AllTrim(art->gruppe))
      hArticle["group_name"] := HB_StrToUTF8(GetArtGroupName(AllTrim(art->gruppe)))
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
      WHILE !art->(Eof()) .AND. Left(art->matchcode, Len(cMatchcodePrefix)) == cMatchcodePrefix .AND. nCount < nMaxResults
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

STATIC FUNCTION DV_Join(aList, cSep)
   LOCAL cResult := "", cItem
   FOR EACH cItem IN aList
      IF ! Empty(cResult)
         cResult += cSep
      ENDIF
      cResult += cItem
   NEXT
RETURN cResult

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
   LOCAL aSched, hSched, dTemp, nArr
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
                                "(JJWW) plus resolved date. delivery_week is the supplier's ship/ready week; " + ;
                                "ship_time is the transit (weeks) and expected_arrival_week/date = delivery + transit " + ;
                                "(when the goods arrive at us). When 'confirmed' is true the delivery date is the " + ;
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
      IF HB_IsNumeric(bes->ShipTime) .AND. bes->ShipTime > 0
         hLine["ship_time"] := bes->ShipTime   // transit time (weeks) supplier -> us
      ENDIF
      IF HB_IsNumeric(bes->Lterm) .AND. bes->Lterm > 0
         hLine["delivery_week"] := StrZero(bes->Lterm, 4)
         IF (dTemp := BesWeekDate(bes->Lterm)) != NIL
            hLine["delivery_date"] := dTemp
         ENDIF
         // Expected arrival at us = delivery week + transit time (ShipTime).
         // Only real calendar weeks (WW<=52) get the transit added; special
         // weeks (99 frame, 97/98 unknown) are taken verbatim - same rule as
         // BestellungConfirm.prg.
         nArr := IIF(Val(Right(Str(bes->Lterm, 4), 2)) <= 52, AddWeeks(bes->Lterm, bes->ShipTime), bes->Lterm)
         hLine["expected_arrival_week"] := StrZero(nArr, 4)
         IF (dTemp := BesWeekDate(nArr)) != NIL
            hLine["expected_arrival_date"] := dTemp
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
            nArr := IIF(Val(Right(Str(bdel->Lterm, 4), 2)) <= 52, AddWeeks(bdel->Lterm, bes->ShipTime), bdel->Lterm)
            hSched["expected_arrival_week"] := StrZero(nArr, 4)
            IF (dTemp := BesWeekDate(nArr)) != NIL
               hSched["expected_arrival_date"] := dTemp
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
         hLine["production_order_status"] := wer->Status
         // The finished-goods receipt (Wareneingang) of an external-production
         // position can only be booked once the FA material has been withdrawn
         // (and the papers printed) - FA status 3 (see fertigung_wareneingang.prg:
         // "STATUS <> 3 -> LOOP"; werkback.prg blocks < 3 with "Ware noch nicht
         // entnommen"). Status 4 means it is already fully received.
         hLine["goods_receipt_bookable"] := wer->Status == 3
         IF wer->Status < 3
            hLine["goods_receipt_block_reason"] := "production order material not yet withdrawn (FA status " + AllTrim(Str(wer->Status)) + ")"
         ELSEIF wer->Status > 3
            hLine["goods_receipt_block_reason"] := "production order already completed (FA status " + AllTrim(Str(wer->Status)) + ")"
         ENDIF
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
      lFound := art->(DbSeek(AllTrim(hArgs["matchcode"])))  // matchcode is case-sensitive - do NOT upper
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
      lFound := art->(DbSeek(AllTrim(hArgs["matchcode"])))  // matchcode is case-sensitive - do NOT upper
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

FUNCTION MCP_Tool_Get_Customer_Part_Number(hArgs)
   LOCAL hResult := {=>}
   LOCAL oKunde, cKundma, lFound := .F.
   LOCAL lReverse := .F.
   LOCAL cWanted, cArtlief := ""
   LOCAL aMatches := {}, hMatch
   LOCAL nOldSelect := Select()

   // Return schema and description when called without arguments
   IF hArgs == NIL .OR. ValType(hArgs) != "H" .OR. Len(hArgs) == 0
      hResult["schema"] := {;
         "type"=>"object",;
         "properties"=>{;
            "customer"=>{"type"=>"string","description"=>"Customer matchcode"},;
            "customer_number"=>{"type"=>"number","description"=>"Customer number"},;
            "matchcode"=>{"type"=>"string","description"=>"Forward lookup: our article matchcode - returns the customer's part number for it"},;
            "partno"=>{"type"=>"string","description"=>"Forward lookup: our article number - returns the customer's part number for it"},;
            "customer_part_no"=>{"type"=>"string","description"=>"Reverse lookup: the customer's own part number - returns our matching article(s)"};
         },;
         "anyOf"=>{{"customer", "customer_number"}, {"matchcode", "partno", "customer_part_no"}};
      }
      hResult["description"] := "Map an article to a customer's own part number (Kundenartikelnummer) in both " + ;
                                "directions, from artkund. Forward: our article (matchcode/partno) + customer -> the " + ;
                                "customer's part number. Reverse: customer_part_no + customer -> our matching " + ;
                                "article(s). A customer identifier (customer or customer_number) is always required"
      RETURN hResult
   ENDIF

   NetUse("engkund", "ku")
   NetUse("artikel", "art")
   NetUse("artkund", "aku")

   // Resolve the customer (matchcode or number) - both directions need it
   oKunde := Adresse():New()
   IF HHasKey(hArgs, "customer_number") .AND. HB_IsNumeric(hArgs["customer_number"]) .AND. hArgs["customer_number"] > 0
      ku->(DbSetOrder(8))
      lFound := oKunde:Load(hArgs["customer_number"])
   ELSEIF HHasKey(hArgs, "customer") .AND. ! Empty(hArgs["customer"])
      lFound := oKunde:LoadMatchcode(Pad(Upper(AllTrim(hArgs["customer"])), 8), "K")
   ENDIF
   IF ! lFound
      DbSelectArea(nOldSelect)
      hResult["status"] := "not_found"
      hResult["message"] := "Customer not found"
      RETURN hResult
   ENDIF
   cKundma := Pad(oKunde:Kunde, 8)
   hResult["customer"] := HB_StrToUTF8(AllTrim(oKunde:Kunde))
   hResult["customer_number"] := oKunde:Nummer

   lReverse := HHasKey(hArgs, "customer_part_no") .AND. ! Empty(hArgs["customer_part_no"])

   IF lReverse
      // Reverse: iterate this customer's artkund rows (index 1 = Kunde +
      // Artikelnr; there is no index on Artlief) and match the part number.
      cWanted := Upper(AllTrim(hArgs["customer_part_no"]))
      hResult["direction"] := "reverse"
      hResult["customer_part_no"] := HB_StrToUTF8(AllTrim(hArgs["customer_part_no"]))
      art->(DbSetOrder(2))  // by Artikelnr
      aku->(DbSetOrder(1))  // Kunde + Str(Artikelnr,6)
      IF aku->(DbSeek(cKundma, .T.))
         DO WHILE ! aku->(Eof()) .AND. aku->Kunde == cKundma
            IF ! Empty(aku->Artlief) .AND. Upper(AllTrim(aku->Artlief)) == cWanted
               hMatch := {=>}
               hMatch["partno"] := aku->Artikelnr
               IF art->(DbSeek(Str(aku->Artikelnr, 6)))
                  hMatch["article"]     := HB_StrToUTF8(AllTrim(art->Matchcode))
                  hMatch["description"] := HB_StrToUTF8(AllTrim(art->Artikel))
                  hMatch["stock"]       := art->Bestand
               ELSE
                  hMatch["description"] := "(article record not found)"
               ENDIF
               AAdd(aMatches, hMatch)
            ENDIF
            aku->(DbSkip())
         ENDDO
      ENDIF
      hResult["matches"] := aMatches
      hResult["match_count"] := Len(aMatches)
      hResult["status"] := IIF(Len(aMatches) > 0, "found", "not_found")
      IF Len(aMatches) == 0
         hResult["message"] := "No article found for customer part number " + AllTrim(hArgs["customer_part_no"])
      ENDIF
   ELSE
      // Forward: resolve our article, then read the customer's part number
      hResult["direction"] := "forward"
      IF HHasKey(hArgs, "matchcode") .AND. ! Empty(hArgs["matchcode"])
         art->(DbSetOrder(1))
         lFound := art->(DbSeek(AllTrim(hArgs["matchcode"])))  // matchcode is case-sensitive - do NOT upper
      ELSEIF HHasKey(hArgs, "partno") .AND. ! Empty(hArgs["partno"])
         art->(DbSetOrder(2))
         lFound := art->(DbSeek(Str(IIF(HB_IsNumeric(hArgs["partno"]), hArgs["partno"], Val(AllTrim(hArgs["partno"]))), 6)))
      ELSE
         lFound := .F.
      ENDIF
      IF ! lFound
         DbSelectArea(nOldSelect)
         hResult["status"] := "not_found"
         hResult["message"] := "Article not found"
         RETURN hResult
      ENDIF
      hResult["article"] := HB_StrToUTF8(AllTrim(art->Matchcode))
      hResult["partno"] := art->Artikelnr
      hResult["description"] := HB_StrToUTF8(AllTrim(art->Artikel))

      aku->(DbSetOrder(1))  // Kunde + Str(Artikelnr,6)
      IF aku->(DbSeek(cKundma + Str(art->Artikelnr, 6)))
         DO WHILE ! aku->(Eof()) .AND. aku->Kunde == cKundma .AND. aku->Artikelnr == art->Artikelnr
            IF ! Empty(aku->Artlief)
               cArtlief := AllTrim(aku->Artlief)
               EXIT
            ENDIF
            aku->(DbSkip())
         ENDDO
      ENDIF
      IF ! Empty(cArtlief)
         hResult["customer_part_no"] := HB_StrToUTF8(cArtlief)
         hResult["status"] := "found"
      ELSE
         hResult["status"] := "not_found"
         hResult["message"] := "No customer part number recorded for this article"
      ENDIF
   ENDIF

   DbSelectArea(nOldSelect)
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
      lFound := art->(DbSeek(AllTrim(hArgs["matchcode"])))  // matchcode is case-sensitive - do NOT upper
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
      lFound := art->(DbSeek(AllTrim(hArgs["matchcode"])))  // matchcode is case-sensitive - do NOT upper
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
      lFound := art->(DbSeek(AllTrim(hArgs["matchcode"])))  // matchcode is case-sensitive - do NOT upper
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

FUNCTION MCP_Tool_Set_Supplier_Holiday(hArgs)
   LOCAL hResult := {=>}
   LOCAL oLief
   LOCAL lClear := .F.
   LOCAL dFrom, dUntil, xSaved
   LOCAL nOldSelect := Select()

   // Return schema and description when called without arguments
   IF hArgs == NIL .OR. ValType(hArgs) != "H" .OR. Len(hArgs) == 0
      hResult["schema"] := {;
         "type"=>"object",;
         "properties"=>{;
            "supplier"=>{"type"=>"string","description"=>"Supplier matchcode"},;
            "supplier_number"=>{"type"=>"number","description"=>"Supplier number"},;
            "from"=>{"type"=>"string","description"=>"First day of the holiday / company closure (YYYY-MM-DD)"},;
            "until"=>{"type"=>"string","description"=>"Last day of the holiday (YYYY-MM-DD); the supplier counts as away while this date is today or later"},;
            "clear"=>{"type"=>"boolean","description"=>"Set true to remove a recorded holiday instead of setting one"};
         },;
         "anyOf"=>{{"supplier", "supplier_number"}};
      }
      hResult["description"] := "Record or clear a supplier's holiday / company closure (Betriebsurlaub) on the " + ;
                               "supplier master (St_Holiday/En_Holiday). Purchasing treats a supplier whose end " + ;
                               "date is today or later as currently away"
      RETURN hResult
   ENDIF

   IF HHasKey(hArgs, "clear") .AND. HB_IsLogical(hArgs["clear"])
      lClear := hArgs["clear"]
   ENDIF

   IF ! lClear
      IF ! HHasKey(hArgs, "from") .OR. Empty(hArgs["from"]) .OR. ! HHasKey(hArgs, "until") .OR. Empty(hArgs["until"])
         RETURN "Provide both 'from' and 'until' (YYYY-MM-DD), or set 'clear' to remove the holiday"
      ENDIF
      dFrom  := SToD(StrTran(AllTrim(hArgs["from"]), "-", ""))
      dUntil := SToD(StrTran(AllTrim(hArgs["until"]), "-", ""))
      IF Empty(dFrom)
         RETURN "Invalid 'from' date - expected YYYY-MM-DD"
      ENDIF
      IF Empty(dUntil)
         RETURN "Invalid 'until' date - expected YYYY-MM-DD"
      ENDIF
      IF dUntil < dFrom
         RETURN "'until' (" + DToC(dUntil) + ") is before 'from' (" + DToC(dFrom) + ")"
      ENDIF
   ENDIF

   NetUse("engkund", "ku")
   oLief := ResolveSupplier(hArgs)   // group "L" address, by supplier / supplier_number
   IF oLief == NIL
      DbSelectArea(nOldSelect)
      hResult["status"] := "not_found"
      hResult["message"] := "Supplier not found"
      RETURN hResult
   ENDIF

   // Write through the Adresse model (ResolveSupplier already loaded it) rather
   // than straight into the work area, so the model's own locking/logic runs.
   // All DBF fields are reachable as object members.
   IF lClear
      oLief:St_Holiday := SToD("")   // empty date - no longer on holiday
      oLief:En_Holiday := SToD("")
   ELSE
      oLief:St_Holiday := dFrom
      oLief:En_Holiday := dUntil
   ENDIF
   BEGIN SEQUENCE
      xSaved := oLief:Save()
   RECOVER
      xSaved := .F.
   END SEQUENCE
   IF HB_IsLogical(xSaved) .AND. ! xSaved
      DbSelectArea(nOldSelect)
      hResult["status"] := "error"
      hResult["message"] := "Saving the supplier failed (record locked by another user or model error) - try again later"
      RETURN hResult
   ENDIF

   DbSelectArea(nOldSelect)

   hResult["supplier"] := HB_StrToUTF8(AllTrim(oLief:Kunde))
   hResult["supplier_number"] := oLief:Nummer
   IF lClear
      hResult["cleared"] := .T.
      hResult["message"] := "Supplier holiday removed"
   ELSE
      hResult["holiday_from"] := dFrom
      hResult["holiday_until"] := dUntil
      hResult["currently_on_holiday"] := dFrom <= Date() .AND. dUntil >= Date()
      hResult["message"] := "Supplier holiday recorded from " + DToC(dFrom) + " until " + DToC(dUntil)
   ENDIF
   hResult["status"] := "success"
RETURN hResult

FUNCTION MCP_Tool_Get_Supplier_Orders(hArgs)
   LOCAL hResult := {=>}
   LOCAL oLief, hOrders := {=>}, hOrder, cKey
   LOCAL aOrders := {}
   LOCAL cStatus := "open", lOpen
   LOCAL nMaxResults := 50
   LOCAL nScanned := 0, nScanCap := 20000, lScanLimited := .F.
   LOCAL dTemp, nArr
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
                                "quantities, the next delivery week and next_arrival_week/date (delivery + transit " + ;
                                "time). Use get_purchase_order for line details"
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
         // Index 2 groups a supplier's lines by Bestat ascending, so for the
         // open view we can stop at the first completed line instead of reading
         // the supplier's whole (potentially years-long) history.
         IF cStatus == "open" .AND. bes->Bestat >= 3
            EXIT
         ENDIF
         // Hard safety bound so a very large history can never hit a timeout.
         IF ++nScanned > nScanCap
            lScanLimited := .T.
            EXIT
         ENDIF
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
               hOrder["next_ship_time"] := 0
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
                  hOrders[cKey]["next_ship_time"] := bes->ShipTime   // transit of the earliest line
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
         // Expected arrival of the earliest delivery = its week + transit time;
         // real weeks (WW<=52) only, special weeks verbatim.
         nArr := IIF(Val(Right(Str(hOrder["next_delivery_week"], 4), 2)) <= 52, ;
            AddWeeks(hOrder["next_delivery_week"], hOrder["next_ship_time"]), hOrder["next_delivery_week"])
         hOrder["next_arrival_week"] := StrZero(nArr, 4)
         IF (dTemp := BesWeekDate(nArr)) != NIL
            hOrder["next_arrival_date"] := dTemp
         ENDIF
         hOrder["next_delivery_week"] := StrZero(hOrder["next_delivery_week"], 4)
      ENDIF
      IF hOrder["next_ship_time"] > 0
         hOrder["ship_time"] := hOrder["next_ship_time"]
      ENDIF
      HDel(hOrder, "next_ship_time")   // internal accumulator - not part of the output
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
   IF lScanLimited
      hResult["scan_limited"] := .T.
      hResult["message"] := "Scan stopped after " + AllTrim(Str(nScanCap)) + " lines - the result may be " + ;
         "incomplete. Use status_filter=open (much faster) or query specific orders with get_purchase_order"
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

FUNCTION MCP_Tool_Add_Delivery_Schedule(hArgs)
   LOCAL hResult := {=>}
   LOCAL nPo, nPos, aEntries, xE, hE
   LOCAL nBeQty, nExisting := 0, nNewSum := 0, nLastWeek := 0, nWk, nQty, nCurLterm := 0
   LOCAL aParsed := {}, aOut := {}
   LOCAL lHasFolge := .F., dTemp, lOk := .F., cErr := ""
   LOCAL oErr
   LOCAL nOldSelect := Select()

   // Return schema and description when called without arguments
   IF hArgs == NIL .OR. ValType(hArgs) != "H" .OR. Len(hArgs) == 0
      hResult["schema"] := {;
         "type"=>"object",;
         "properties"=>{;
            "po_number"=>{"type"=>"number","description"=>"Purchase order number (Bestellnummer)"},;
            "item"=>{"type"=>"number","description"=>"Position number within the purchase order"},;
            "entries"=>{"type"=>"array","description"=>"Delivery-schedule entries to ADD, each an object {week, quantity}",;
               "items"=>{"type"=>"object","properties"=>{;
                  "week"=>{"type"=>"string","description"=>"Calendar week JJWW (e.g. 2634)"},;
                  "quantity"=>{"type"=>"number","description"=>"Quantity to deliver in that week"}},;
                  "required"=>{"week","quantity"}}};
         },;
         "required"=>{"po_number","item","entries"};
      }
      hResult["description"] := "Add delivery-schedule entries (Liefereinteilungen) to a purchase-order position. " + ;
                              "Entries are appended to any existing schedule; the total scheduled quantity may not " + ;
                              "exceed the ordered quantity (Bestellmenge); the position's delivery week (Lterm) is set " + ;
                              "to the latest scheduled week, so any remaining quantity is delivered then. Positions " + ;
                              "with follow-up (Folge) positions must be edited in Trader instead"
      RETURN hResult
   ENDIF

   IF ! HB_IsNumeric(hArgs["po_number"]) .OR. ! HB_IsNumeric(hArgs["item"])
      RETURN "Parameters 'po_number' and 'item' must be numbers"
   ENDIF
   IF ! HB_IsArray(hArgs["entries"]) .OR. Len(hArgs["entries"]) == 0
      RETURN "Parameter 'entries' must be a non-empty array of {week, quantity}"
   ENDIF
   nPo := Int(hArgs["po_number"])
   nPos := Int(hArgs["item"])
   aEntries := hArgs["entries"]

   // Validate and normalise the entries up front.
   FOR EACH xE IN aEntries
      IF ! HB_IsHash(xE) .OR. ! HHasKey(xE, "week") .OR. ! HHasKey(xE, "quantity")
         RETURN "Each entry needs 'week' (JJWW) and 'quantity'"
      ENDIF
      nWk := IIF(HB_IsNumeric(xE["week"]), Int(xE["week"]), Val(AllTrim(xE["week"])))
      IF ! HB_IsNumeric(xE["quantity"]) .OR. xE["quantity"] <= 0
         RETURN "Entry 'quantity' must be a positive number"
      ENDIF
      nQty := xE["quantity"]
      IF nWk <= 0 .OR. Val(Right(StrZero(nWk, 4), 2)) < 1 .OR. Val(Right(StrZero(nWk, 4), 2)) > 53
         RETURN "Invalid week '" + AllTrim(Str(nWk)) + "' - expected a calendar week JJWW (WW 01-53)"
      ENDIF
      AAdd(aParsed, {nWk, nQty})
      nNewSum += nQty
      nLastWeek := Max(nLastWeek, nWk)
   NEXT

   NetUse("engbes", "bes")
   NetUse("besdel", "bdel")

   bes->(DbSetOrder(1))  // Str(Besnr,6) + Str(Posnr,3)
   IF ! bes->(DbSeek(Str(nPo, 6) + Str(nPos, 3)))
      DbSelectArea(nOldSelect)
      hResult["status"] := "not_found"
      hResult["message"] := "Purchase order position not found: " + AllTrim(Str(nPo)) + "/" + AllTrim(Str(nPos))
      RETURN hResult
   ENDIF
   IF bes->Bestat >= 3
      DbSelectArea(nOldSelect)
      RETURN "Position is completed or cancelled (Bestat " + AllTrim(Str(bes->Bestat)) + ") - no schedule can be added"
   ENDIF
   nBeQty := bes->BeQty
   nCurLterm := bes->Lterm   // the position's current delivery week (before any change)

   // Follow-up (Folge) positions keep their schedules in sync via the mask
   // (__SyncSubPlans in BestellungConfirm.prg); this tool does not, so refuse.
   bes->(DbSeek(Str(nPo, 6)))
   DO WHILE ! bes->(Eof()) .AND. bes->Besnr == nPo
      IF bes->FolgeTo == nPos
         lHasFolge := .T.
         EXIT
      ENDIF
      bes->(DbSkip())
   ENDDO
   IF lHasFolge
      DbSelectArea(nOldSelect)
      RETURN "Position has follow-up (Folge) positions - edit its delivery schedule in Trader so they stay in sync"
   ENDIF

   // Existing schedule: total already scheduled + latest week so far.
   bdel->(DbSetOrder(1))  // Besnr + Posnr
   IF bdel->(DbSeek(Str(nPo, 6) + Str(nPos, 3)))
      DO WHILE ! bdel->(Eof()) .AND. bdel->Besnr == nPo .AND. bdel->Posnr == nPos
         nExisting += bdel->Qty
         nLastWeek := Max(nLastWeek, bdel->Lterm)
         bdel->(DbSkip())
      ENDDO
   ENDIF

   IF nExisting + nNewSum > nBeQty
      DbSelectArea(nOldSelect)
      RETURN "Total scheduled quantity (" + AllTrim(Str(nExisting + nNewSum)) + ") would exceed the ordered quantity (" + ;
             AllTrim(Str(nBeQty)) + "); already scheduled: " + AllTrim(Str(nExisting))
   ENDIF

   // Delivery week = the latest scheduled week. But when a remainder is left
   // (scheduled < ordered) that remainder is delivered on the position's
   // existing Lterm, so keep it if it is a real week later than the schedule.
   IF nExisting + nNewSum < nBeQty .AND. HB_IsNumeric(nCurLterm) .AND. ;
      Val(Right(StrZero(nCurLterm, 4), 2)) >= 1 .AND. Val(Right(StrZero(nCurLterm, 4), 2)) <= 53
      nLastWeek := Max(nLastWeek, nCurLterm)
   ENDIF

   // Write the entries and set the position's delivery week to the latest one
   // (same as BestellungConfirm.prg). Wrapped in a transaction for atomicity.
   LETO_BEGINTRANSACTION()
   BEGIN SEQUENCE
      // Inside a LETO transaction the records must stay locked until commit -
      // LETO_COMMITTRANSACTION() unlocks them (and LETO_ROLLBACK() on error).
      // Calling dbUnLock() here would release them mid-transaction and the
      // save would fail; that was the bug behind the generic error.
      FOR EACH hE IN aParsed
         bdel->(Add_Rec(0))   // append + lock (canonical usage: called as a statement)
         bdel->Besnr := nPo
         bdel->Posnr := nPos
         bdel->Lterm := hE[1]
         bdel->Qty   := hE[2]
         AAdd(aOut, {"week"=>StrZero(hE[1], 4), "quantity"=>hE[2]})
      NEXT
      bes->(DbSeek(Str(nPo, 6) + Str(nPos, 3)))
      IF ! bes->(Rec_Lock(0))
         cErr := "Could not lock the purchase-order position (bes Rec_Lock returned .F.)"
         Break( NIL )
      ENDIF
      bes->Lterm := nLastWeek
      IF LETO_COMMITTRANSACTION()
         lOk := .T.
      ELSE
         LETO_ROLLBACK()
         cErr := "Saving the delivery schedule failed (LETO commit returned .F.) - nothing was saved"
      ENDIF
   RECOVER USING oErr
      BEGIN SEQUENCE ; LETO_ROLLBACK() ; RECOVER ; END SEQUENCE
      // Surface the real error instead of a generic message (the previous
      // "record locked or model error" hid the actual cause).
      IF Empty( cErr )
         cErr := "Saving the delivery schedule failed: " + _MCP_ErrText( oErr ) + " - nothing was saved"
      ENDIF
   END SEQUENCE

   IF ! lOk
      DbSelectArea(nOldSelect)
      hResult["status"] := "error"
      hResult["message"] := cErr
      RETURN hResult
   ENDIF

   DbSelectArea(nOldSelect)

   hResult["po_number"] := nPo
   hResult["item"] := nPos
   hResult["added"] := aOut
   hResult["added_count"] := Len(aOut)
   hResult["total_scheduled"] := nExisting + nNewSum
   hResult["ordered_quantity"] := nBeQty
   hResult["delivery_week"] := StrZero(nLastWeek, 4)
   IF (dTemp := BesWeekDate(nLastWeek)) != NIL
      hResult["delivery_date"] := dTemp
   ENDIF
   hResult["status"] := "success"
   hResult["message"] := AllTrim(Str(Len(aOut))) + " delivery-schedule entry(ies) added; delivery week set to " + StrZero(nLastWeek, 4)
RETURN hResult

FUNCTION MCP_Tool_Get_Supplier_Quote(hArgs)
   LOCAL hResult := {=>}
   LOCAL cLiefma := "", cQuoteno := ""
   LOCAL nNoLen, nQnoLen, lFound := .F.
   LOCAL nNo, cLief, cQno, nBuyer := 0
   LOCAL aPos := {}, hPos
   LOCAL oLief
   LOCAL nOldSelect := Select()

   // Return schema and description when called without arguments
   IF hArgs == NIL .OR. ValType(hArgs) != "H" .OR. Len(hArgs) == 0
      hResult["schema"] := {;
         "type"=>"object",;
         "properties"=>{;
            "reference_number"=>{"type"=>"number","description"=>"Quote reference number (the 'reference_number' returned by add_supplier_quote)"},;
            "supplier"=>{"type"=>"string","description"=>"Supplier matchcode (use together with quote_number)"},;
            "supplier_number"=>{"type"=>"number","description"=>"Supplier number (alternative to 'supplier')"},;
            "quote_number"=>{"type"=>"string","description"=>"The supplier's quote number (use together with supplier/supplier_number)"};
         },;
         "anyOf"=>{{"reference_number"}, {"quote_number"}};
      }
      hResult["description"] := "Retrieve a supplier quote (Einkaufsangebot) by reference number, or by supplier plus " + ;
                              "quote_number, with its QUOTE price positions (buyprice): article, quantity, price, price " + ;
                              "unit and validity"
      RETURN hResult
   ENDIF

   NetUse("engkund", "ku")
   NetUse("artikel", "art")
   NetUse("buyprice", "bpr")
   NetUse("quote", "qt")

   IF HHasKey(hArgs, "reference_number") .AND. HB_IsNumeric(hArgs["reference_number"]) .AND. hArgs["reference_number"] > 0
      qt->(DbSetOrder(1))   // No
      nNoLen := qt->(FieldLen(FieldPos("NO")))
      lFound := qt->(DbSeek(Str(Int(hArgs["reference_number"]), nNoLen)))
   ELSE
      IF ! HHasKey(hArgs, "quote_number") .OR. Empty(AllTrim(HB_CStr(hArgs["quote_number"])))
         DbSelectArea(nOldSelect)
         RETURN "Provide 'reference_number', or 'quote_number' together with 'supplier'/'supplier_number'"
      ENDIF
      cQuoteno := AllTrim(HB_CStr(hArgs["quote_number"]))
      IF HHasKey(hArgs, "supplier_number") .AND. HB_IsNumeric(hArgs["supplier_number"]) .AND. hArgs["supplier_number"] > 0
         ku->(DbSetOrder(8))
         IF ku->(DbSeek(Str(Int(hArgs["supplier_number"]), 6)))
            cLiefma := Pad(AllTrim(ku->Kunde), 8)
         ENDIF
      ELSEIF HHasKey(hArgs, "supplier") .AND. ! Empty(hArgs["supplier"])
         ku->(DbSetOrder(1))
         IF ku->(DbSeek(Pad(Upper(AllTrim(HB_CStr(hArgs["supplier"]))), 8) + "L"))
            cLiefma := Pad(AllTrim(ku->Kunde), 8)
         ENDIF
      ELSE
         DbSelectArea(nOldSelect)
         RETURN "Provide 'supplier' or 'supplier_number' together with 'quote_number'"
      ENDIF
      IF Empty(cLiefma)
         DbSelectArea(nOldSelect)
         hResult["status"] := "not_found"
         hResult["message"] := "Supplier not found"
         RETURN hResult
      ENDIF
      qt->(DbSetOrder(2))   // Liefma + Quoteno
      nQnoLen := qt->(FieldLen(FieldPos("QUOTENO")))
      lFound := qt->(DbSeek(cLiefma + Pad(cQuoteno, nQnoLen)))
   ENDIF

   IF ! lFound
      DbSelectArea(nOldSelect)
      hResult["status"] := "not_found"
      hResult["message"] := "Supplier quote not found"
      RETURN hResult
   ENDIF

   // Snapshot the header before walking the positions (the loop only moves bpr).
   nNo    := qt->No
   cLief  := qt->Liefma
   cQno   := qt->Quoteno
   IF qt->(FieldPos("BUYER")) > 0
      nBuyer := qt->Buyer
   ENDIF

   // Positions: buyprice index 4 = Liefma + Pad(Type,10) + Number, filtered to
   // this supplier's QUOTE rows with the matching quote number (as Quote_edit).
   bpr->(DbSetOrder(4))
   IF bpr->(DbSeek(cLief + Pad("QUOTE", 10) + cQno))
      DO WHILE ! bpr->(Eof()) .AND. bpr->Liefma == cLief .AND. Trim(bpr->Type) == "QUOTE" .AND. bpr->Number == cQno
         hPos := {=>}
         hPos["article_number"] := bpr->Artikelnr
         art->(DbSetOrder(2))
         IF art->(DbSeek(Str(bpr->Artikelnr, 6)))
            hPos["article"]     := HB_StrToUTF8(AllTrim(art->Matchcode))
            hPos["description"] := HB_StrToUTF8(AllTrim(art->Artikel))
         ENDIF
         hPos["quantity"]   := bpr->Qty
         hPos["price"]      := bpr->Price
         hPos["price_unit"] := bpr->Pe
         hPos["unit_price"] := Round(bpr->Price / IIF(bpr->Pe == 0, 1, bpr->Pe), 4)
         IF ! Empty(bpr->StartDate)
            hPos["valid_from"] := bpr->StartDate
         ENDIF
         IF ! Empty(bpr->EndDate)
            hPos["valid_to"] := bpr->EndDate
         ENDIF
         AAdd(aPos, hPos)
         bpr->(DbSkip())
      ENDDO
   ENDIF

   // Supplier name / number for context.
   oLief := Adresse():New()
   IF oLief:LoadMatchcode(Pad(AllTrim(cLief), 8), "L")
      hResult["supplier_name"]   := HB_StrToUTF8(AllTrim(oLief:cName))
      hResult["supplier_number"] := oLief:nummer
   ENDIF

   DbSelectArea(nOldSelect)

   hResult["reference_number"] := nNo
   hResult["supplier"]         := HB_StrToUTF8(AllTrim(cLief))
   hResult["quote_number"]     := HB_StrToUTF8(AllTrim(cQno))
   IF nBuyer > 0
      hResult["buyer"] := nBuyer
   ENDIF
   hResult["positions"]        := aPos
   hResult["positions_count"]  := Len(aPos)
   hResult["status"]           := "found"
RETURN hResult

FUNCTION MCP_Tool_Add_Supplier_Quote(hArgs)
   LOCAL hResult := {=>}
   LOCAL cLiefma := "", cQuoteno
   LOCAL aPos, xP, hP, aResolved := {}, hRes, hR
   LOCAL dFrom, dTo, nDays, nArt, nPe
   LOCAL nRef := 0, lNewQuote := .F.
   LOCAL oQuote, oAli, oBpr
   LOCAL aOut := {}, hOut
   LOCAL oErr, cErr := "", lOk := .F.
   LOCAL nOldSelect := Select()
   LOCAL nQnoLen

   // Return schema and description when called without arguments
   IF hArgs == NIL .OR. ValType(hArgs) != "H" .OR. Len(hArgs) == 0
      hResult["schema"] := {;
         "type"=>"object",;
         "properties"=>{;
            "supplier"=>{"type"=>"string","description"=>"Supplier matchcode (Lieferant)"},;
            "supplier_number"=>{"type"=>"number","description"=>"Supplier number (alternative to 'supplier')"},;
            "quote_number"=>{"type"=>"string","description"=>"The supplier's own offer/quote number (Angebotsnr) - used as the reference linking the positions"},;
            "valid_from"=>{"type"=>"string","description"=>"Validity start date YYYY-MM-DD (default today)"},;
            "valid_to"=>{"type"=>"string","description"=>"Validity end date YYYY-MM-DD (default valid_from + valid_days)"},;
            "valid_days"=>{"type"=>"number","description"=>"Validity in days when valid_to is not given (default 30)"},;
            "positions"=>{"type"=>"array","description"=>"Quote positions",;
               "items"=>{"type"=>"object","properties"=>{;
                  "article"=>{"type"=>"string","description"=>"Article matchcode"},;
                  "part_number"=>{"type"=>"number","description"=>"Internal article number (alternative to 'article')"},;
                  "quantity"=>{"type"=>"number","description"=>"Quantity / price-break the price applies to"},;
                  "price"=>{"type"=>"number","description"=>"Unit price in the supplier's price unit"},;
                  "price_unit"=>{"type"=>"number","description"=>"Price unit (Preiseinheit, Pe) the price refers to (default 1)"},;
                  "supplier_part_no"=>{"type"=>"string","description"=>"Supplier's part number (only used when the article-supplier link is created)"},;
                  "lead_time_weeks"=>{"type"=>"number","description"=>"Delivery time in weeks (only used when the article-supplier link is created)"}},;
                  "required"=>{"quantity","price"}}};
         },;
         "required"=>{"quote_number","positions"};
      }
      hResult["description"] := "Create a supplier quote (Einkaufsangebot / Lieferantenangebot): a quote header " + ;
                              "(quote) for the supplier plus one QUOTE price row (buyprice) per position, keyed by the " + ;
                              "supplier's quote number. If a quote with the same supplier and quote_number already " + ;
                              "exists, the positions are appended to it. The article-supplier link (artlief) is created " + ;
                              "automatically when it does not exist yet. Mirrors the Trader 'Einkaufsangebot' mask"
      RETURN hResult
   ENDIF

   IF ! HHasKey(hArgs, "quote_number") .OR. Empty(AllTrim(HB_CStr(hArgs["quote_number"])))
      RETURN "Parameter 'quote_number' (the supplier's offer number) is required"
   ENDIF
   cQuoteno := AllTrim(HB_CStr(hArgs["quote_number"]))

   IF ! HB_IsArray(hArgs["positions"]) .OR. Len(hArgs["positions"]) == 0
      RETURN "Parameter 'positions' must be a non-empty array of {article|part_number, quantity, price}"
   ENDIF
   aPos := hArgs["positions"]

   NetUse("engkund", "ku")
   NetUse("artikel", "art")
   NetUse("artlief", "ali")
   NetUse("buyprice", "bpr")
   NetUse("quote", "qt")

   // Resolve the supplier to the 8-char matchcode key (ku->Kunde) that Liefma /
   // Kunde hold in artlief/buyprice/quote - same resolution as _WeResolveLiefma
   // in wareneingang_web.prg.
   IF HHasKey(hArgs, "supplier_number") .AND. HB_IsNumeric(hArgs["supplier_number"]) .AND. hArgs["supplier_number"] > 0
      ku->(DbSetOrder(8))   // by supplier number
      IF ku->(DbSeek(Str(Int(hArgs["supplier_number"]), 6)))
         cLiefma := Pad(AllTrim(ku->Kunde), 8)
      ENDIF
   ELSEIF HHasKey(hArgs, "supplier") .AND. ! Empty(hArgs["supplier"])
      ku->(DbSetOrder(1))   // by matchcode + group
      IF ku->(DbSeek(Pad(Upper(AllTrim(HB_CStr(hArgs["supplier"]))), 8) + "L"))
         cLiefma := Pad(AllTrim(ku->Kunde), 8)
      ENDIF
   ELSE
      DbSelectArea(nOldSelect)
      RETURN "Provide 'supplier' (matchcode) or 'supplier_number'"
   ENDIF
   IF Empty(cLiefma)
      DbSelectArea(nOldSelect)
      hResult["status"] := "not_found"
      hResult["message"] := "Supplier not found"
      RETURN hResult
   ENDIF

   // Validity dates
   dFrom := Date()
   IF HHasKey(hArgs, "valid_from") .AND. ! Empty(hArgs["valid_from"])
      dFrom := StoD(StrTran(AllTrim(HB_CStr(hArgs["valid_from"])), "-", ""))
      IF Empty(dFrom)
         DbSelectArea(nOldSelect)
         RETURN "Invalid 'valid_from' - expected YYYY-MM-DD"
      ENDIF
   ENDIF
   IF HHasKey(hArgs, "valid_to") .AND. ! Empty(hArgs["valid_to"])
      dTo := StoD(StrTran(AllTrim(HB_CStr(hArgs["valid_to"])), "-", ""))
      IF Empty(dTo)
         DbSelectArea(nOldSelect)
         RETURN "Invalid 'valid_to' - expected YYYY-MM-DD"
      ENDIF
   ELSE
      nDays := IIF(HHasKey(hArgs, "valid_days") .AND. HB_IsNumeric(hArgs["valid_days"]) .AND. hArgs["valid_days"] > 0, Int(hArgs["valid_days"]), 30)
      dTo := dFrom + nDays
   ENDIF
   IF dTo < dFrom
      DbSelectArea(nOldSelect)
      RETURN "'valid_to' must not be before 'valid_from'"
   ENDIF

   // Validate and resolve every position BEFORE writing anything, so a bad
   // position does not leave a half-created quote behind.
   FOR EACH xP IN aPos
      IF ! HB_IsHash(xP)
         DbSelectArea(nOldSelect)
         RETURN "Each position must be an object {article|part_number, quantity, price}"
      ENDIF
      hP := xP
      nArt := 0
      IF HHasKey(hP, "part_number") .AND. HB_IsNumeric(hP["part_number"]) .AND. hP["part_number"] > 0
         art->(DbSetOrder(2))   // by article number
         IF art->(DbSeek(Str(Int(hP["part_number"]), 6)))
            nArt := art->Artikelnr
         ENDIF
      ELSEIF HHasKey(hP, "article") .AND. ! Empty(hP["article"])
         art->(DbSetOrder(1))   // by matchcode
         IF art->(DbSeek(Pad(Upper(AllTrim(HB_CStr(hP["article"]))), 25)))
            nArt := art->Artikelnr
         ENDIF
      ENDIF
      IF nArt == 0
         DbSelectArea(nOldSelect)
         hResult["status"] := "not_found"
         hResult["message"] := "Article not found for a position: " + ;
            HB_CStr(IIF(HHasKey(hP, "article"), hP["article"], IIF(HHasKey(hP, "part_number"), hP["part_number"], "?")))
         RETURN hResult
      ENDIF
      IF ! HB_IsNumeric(hP["quantity"]) .OR. hP["quantity"] <= 0
         DbSelectArea(nOldSelect)
         RETURN "Each position needs a positive 'quantity'"
      ENDIF
      IF ! HB_IsNumeric(hP["price"]) .OR. hP["price"] <= 0
         DbSelectArea(nOldSelect)
         RETURN "Each position needs a positive 'price'"
      ENDIF
      nPe := IIF(HHasKey(hP, "price_unit") .AND. HB_IsNumeric(hP["price_unit"]) .AND. hP["price_unit"] > 0, hP["price_unit"], 1)
      hRes := {=>}
      hRes["art"]        := nArt
      hRes["matchcode"]  := AllTrim(art->Matchcode)
      hRes["zeichnung"]  := art->Zeichnung
      hRes["zeichindex"] := art->Zeichindex
      hRes["qty"]        := hP["quantity"]
      hRes["price"]      := hP["price"]
      hRes["pe"]         := nPe
      hRes["part_no"]    := IIF(HHasKey(hP, "supplier_part_no"), AllTrim(HB_CStr(hP["supplier_part_no"])), "")
      hRes["lz"]         := IIF(HHasKey(hP, "lead_time_weeks") .AND. HB_IsNumeric(hP["lead_time_weeks"]), Int(hP["lead_time_weeks"]), -1)
      AAdd(aResolved, hRes)
   NEXT

   // Create (or reuse) the quote header and write the positions. The Quote /
   // Record ORM handles auto-numbering and record locking (Save() locks and
   // unlocks per record), so no explicit LETO transaction here - mirrors the
   // Quote_edit mask.
   BEGIN SEQUENCE WITH {|oE| Break(oE)}
      qt->(DbSetOrder(2))   // Liefma + Quoteno
      nQnoLen := qt->(FieldLen(FieldPos("QUOTENO")))
      IF qt->(DbSeek(cLiefma + Pad(cQuoteno, nQnoLen)))
         nRef := qt->No
      ELSE
         // Quote (model/quote.prg) is a Record subclass with "ID no INDEXORDER 1",
         // so New(.T.) + Save() auto-numbers qt->No.
         oQuote := Quote():New(.T.)
         oQuote:Liefma  := cLiefma
         oQuote:Quoteno := cQuoteno
         oQuote:Save()
         nRef := oQuote:No
         lNewQuote := .T.
      ENDIF

      FOR EACH hR IN aResolved
         // Ensure the article-supplier link (artlief) exists.
         ali->(DbSetOrder(1))   // Kunde + Str(Artikelnr,6)
         IF ! ali->(DbSeek(cLiefma + Str(hR["art"], 6)))
            oAli := ali->(Record():New(.T.))
            oAli:Kunde     := cLiefma
            oAli:Artikelnr := hR["art"]
            oAli:Matchcode := hR["matchcode"]
            oAli:Priority  := 8
            IF ! Empty(hR["part_no"])
               oAli:ArtLief := hR["part_no"]
            ENDIF
            IF hR["lz"] >= 0
               oAli:LZ := hR["lz"]
            ENDIF
            oAli:Save()
         ENDIF

         // Add the QUOTE price row (buyprice), keyed by the supplier quote no.
         oBpr := bpr->(Record():New(.T.))
         oBpr:Liefma     := cLiefma
         oBpr:Artikelnr  := hR["art"]
         oBpr:Qty        := hR["qty"]
         oBpr:Price      := hR["price"]
         oBpr:Pe         := hR["pe"]
         oBpr:Number     := cQuoteno
         oBpr:Type       := "QUOTE"
         oBpr:StartDate  := dFrom
         oBpr:EndDate    := dTo
         oBpr:Lots       := 1
         oBpr:LotSize    := hR["qty"]
         oBpr:Zeichnung  := hR["zeichnung"]
         oBpr:ZeichIndex := hR["zeichindex"]
         oBpr:Save()

         hOut := {=>}
         hOut["article"]    := HB_StrToUTF8(hR["matchcode"])
         hOut["quantity"]   := hR["qty"]
         hOut["price"]      := hR["price"]
         hOut["price_unit"] := hR["pe"]
         AAdd(aOut, hOut)
      NEXT
      lOk := .T.
   RECOVER USING oErr
      cErr := "Saving the supplier quote failed: " + _MCP_ErrText(oErr) + " - it may be partially saved"
   END SEQUENCE

   DbSelectArea(nOldSelect)

   IF ! lOk
      hResult["status"] := "error"
      hResult["message"] := cErr
      RETURN hResult
   ENDIF

   // Top-level string fields are left raw; _HashToUtf8() (applied on RETURN)
   // encodes them. Only nested strings (aOut) are pre-encoded above, since
   // _HashToUtf8() does not recurse into arrays.
   hResult["reference_number"] := nRef
   hResult["supplier"]         := AllTrim(cLiefma)
   hResult["quote_number"]     := cQuoteno
   hResult["valid_from"]       := dFrom
   hResult["valid_to"]         := dTo
   hResult["new_quote"]        := lNewQuote
   hResult["positions"]        := aOut
   hResult["positions_added"]  := Len(aOut)
   hResult["status"]           := "success"
   hResult["message"]          := IIF(lNewQuote, "Supplier quote created", "Positions appended to existing supplier quote") + ;
      " (reference " + AllTrim(Str(nRef)) + ") with " + AllTrim(Str(Len(aOut))) + " position(s)"
RETURN _HashToUtf8(hResult)

// ---------------------------------------------------------------------------
// Projects (Projekte) - read/manage. Ported from projekt_web.prg (the web
// master-detail port of Project_Browse / Project_Edit), sharing its defensive
// field access so a renamed field degrades gracefully instead of crashing.
// ---------------------------------------------------------------------------

STATIC FUNCTION _McpPjNum(x)
   DO CASE
   CASE ValType(x) == "N" ; RETURN x
   CASE ValType(x) == "C" ; RETURN Val(x)
   ENDCASE
RETURN 0

STATIC FUNCTION _McpPjStr(x)
   DO CASE
   CASE ValType(x) == "M" ; RETURN x
   CASE ValType(x) == "C" ; RETURN x
   CASE ValType(x) == "N" ; RETURN AllTrim(Str(x))
   CASE ValType(x) == "D" ; RETURN DtoC(x)
   CASE ValType(x) == "L" ; RETURN IIF(x, ".T.", ".F.")
   ENDCASE
RETURN ""

// Defensive field read: unknown field -> default (never crashes on a rename).
STATIC FUNCTION _McpPjF(cAlias, cField, xDef)
   LOCAL nFP := (cAlias)->(FieldPos(cField))
   IF nFP == 0
      RETURN xDef
   ENDIF
RETURN (cAlias)->(FieldGet(nFP))

STATIC FUNCTION _McpPjStatusName(nStat)
   LOCAL h := GetProjectStatusNames()
   IF ValType(h) == "H" .AND. HB_HHasKey(h, nStat)
      RETURN AllTrim(_McpPjStr(h[nStat]))
   ENDIF
RETURN "?"

// User id -> initials (buyer table), like Project_Browse.
STATIC FUNCTION _McpPjInitials(nId)
   LOCAL c := ""
   IF _McpPjNum(nId) == 0
      RETURN ""
   ENDIF
   NetUse("buyer", "buy")
   buy->(DbSetOrder(0))
   IF buy->(DbGoto(nId)) == NIL .AND. ! buy->(Eof())
      c := AllTrim(_McpPjStr(_McpPjF("buy", "INITIALS", "")))
      IF Empty(c)
         c := AllTrim(_McpPjStr(_McpPjF("buy", "BUYER", "")))
      ENDIF
   ENDIF
RETURN c

STATIC FUNCTION _McpPjKundeName(nKunde)
   LOCAL c := ""
   IF nKunde == 0
      RETURN ""
   ENDIF
   NetUse("engkund", "ku")
   ku->(DbSetOrder(8))
   IF ku->(DbSeek(Str(nKunde, 6)))
      c := AllTrim(_McpPjStr(_McpPjF("ku", "NAME1", "")))
   ENDIF
RETURN c

// Open-task count for a project (todo order 3: REFTYPE+Str(REF,6)+DONE).
STATIC FUNCTION _McpPjOpenTasks(nNummer)
   LOCAL n := 0
   BEGIN SEQUENCE WITH {|e| Break(e)}
      NetUse("todo", "todo")
      todo->(DbSetOrder(3))
      IF todo->(DbSeek("PJ " + Str(nNummer, 6) + "N"))
         DO WHILE ! todo->(Eof()) .AND. AllTrim(_McpPjStr(_McpPjF("todo", "REFTYPE", ""))) == "PJ" .AND. ;
                  _McpPjNum(_McpPjF("todo", "REF", 0)) == nNummer
            IF ! _McpPjF("todo", "DONE", .F.)
               n++
            ENDIF
            todo->(DbSkip())
         ENDDO
      ENDIF
   RECOVER
      n := 0
   END SEQUENCE
RETURN n

// Project articles (projart/pjart order 1: Str(Nummer,6)); resolve name/drawing.
STATIC FUNCTION _McpPjArticles(nNummer)
   LOCAL a := {}
   BEGIN SEQUENCE WITH {|e| Break(e)}
      NetUse("projart", "pjart")
      NetUse("artikel", "art")
      art->(DbSetOrder(2))
      pjart->(DbSetOrder(1))
      IF pjart->(DbSeek(Str(nNummer, 6)))
         DO WHILE ! pjart->(Eof()) .AND. _McpPjNum(_McpPjF("pjart", "NUMMER", 0)) == nNummer
            art->(DbSeek(Str(_McpPjNum(_McpPjF("pjart", "ARTIKELNR", 0)), 6)))
            AAdd(a, { ;
               "article_number" => _McpPjNum(_McpPjF("pjart", "ARTIKELNR", 0)), ;
               "article"        => HB_StrToUTF8(AllTrim(_McpPjStr(_McpPjF("pjart", "MATCHCODE", "")))), ;
               "description"    => HB_StrToUTF8(AllTrim(_McpPjStr(_McpPjF("art", "ARTIKEL", "")))), ;
               "drawing"        => HB_StrToUTF8(AllTrim(_McpPjStr(_McpPjF("art", "ZEICHNUNG", "")))), ;
               "revision"       => HB_StrToUTF8(AllTrim(_McpPjStr(_McpPjF("art", "ZEICHINDEX", "")))) })
            pjart->(DbSkip())
         ENDDO
      ENDIF
   RECOVER
      a := {}
   END SEQUENCE
RETURN a

// Costs (projcost/pjcst): planned vs. calculated per entry.
STATIC FUNCTION _McpPjCosts(nNummer)
   LOCAL a := {}, nPlan, nCalc
   BEGIN SEQUENCE WITH {|e| Break(e)}
      NetUse("projcost", "pjcst")
      NetUse("engbes", "bes")
      NetUse("engauf", "auf")
      NetUse("reb", "reb")
      NetUse("rechpos", "rpos")
      NetUse("engrech", "rech")
      NetUse("artikel", "art")
      pjcst->(DbSeek(Str(nNummer, 6)))
      DO WHILE ! pjcst->(Eof()) .AND. _McpPjNum(_McpPjF("pjcst", "PROJEKT", 0)) == nNummer
         nPlan := 0 ; nCalc := 0
         BEGIN SEQUENCE WITH {|e| Break(e)}
            nPlan := _McpPjNum(GetProjectCostValue(.T.))
            nCalc := _McpPjNum(GetProjectCostValue(.F.))
         RECOVER
            nPlan := 0 ; nCalc := 0
         END SEQUENCE
         AAdd(a, { ;
            "date"    => _McpPjF("pjcst", "DATUM", CToD("")), ;
            "type"    => AllTrim(_McpPjStr(_McpPjF("pjcst", "TYP", ""))), ;
            "planned" => Round(nPlan, 2), ;
            "calculated" => Round(nCalc, 2) })
         pjcst->(DbSkip())
      ENDDO
   RECOVER
      a := {}
   END SEQUENCE
RETURN a

// Resolve a customer to its 8-char matchcode key (engkund Kunde, group "K"),
// padded to 8 so Project:_cKunde's "ku->(DbSeek(cKunde + 'K'))" (fixed-width
// index: matchcode(8) + group) matches.
STATIC FUNCTION _McpPjResolveCustomer(hArgs)
   LOCAL cKu := ""
   NetUse("engkund", "ku")
   IF HHasKey(hArgs, "customer_number") .AND. HB_IsNumeric(hArgs["customer_number"]) .AND. hArgs["customer_number"] > 0
      ku->(DbSetOrder(8))
      IF ku->(DbSeek(Str(Int(hArgs["customer_number"]), 6))) .AND. AllTrim(_McpPjStr(_McpPjF("ku", "GROUP", ""))) == "K"
         cKu := Pad(AllTrim(_McpPjStr(_McpPjF("ku", "KUNDE", ""))), 8)
      ENDIF
   ELSEIF HHasKey(hArgs, "customer") .AND. ! Empty(hArgs["customer"])
      ku->(DbSetOrder(1))
      IF ku->(DbSeek(Pad(Upper(AllTrim(HB_CStr(hArgs["customer"]))), 8) + "K"))
         cKu := Pad(AllTrim(_McpPjStr(_McpPjF("ku", "KUNDE", ""))), 8)
      ENDIF
   ENDIF
RETURN cKu

FUNCTION MCP_Tool_Get_Project(hArgs)
   LOCAL hResult := {=>}
   LOCAL nNummer, nStat
   LOCAL nOldSelect := Select()

   // Return schema and description when called without arguments
   IF hArgs == NIL .OR. ValType(hArgs) != "H" .OR. Len(hArgs) == 0
      hResult["schema"] := {;
         "type"=>"object",;
         "properties"=>{;
            "number"=>{"type"=>"number","description"=>"Project number (Projektnummer)"};
         },;
         "required"=>{"number"};
      }
      hResult["description"] := "Retrieve a project (Projekt) by number: header (customer, contact, status, owner, " + ;
                              "sales, description, value, budget, specification, notes) plus its articles and cost " + ;
                              "entries (planned vs. calculated)"
      RETURN hResult
   ENDIF

   IF ! HB_IsNumeric(hArgs["number"])
      RETURN "Parameter 'number' must be a number"
   ENDIF
   nNummer := Int(hArgs["number"])

   NetUse("projekte", "pj")
   pj->(DbSetOrder(1))
   IF nNummer <= 0 .OR. ! pj->(DbSeek(Str(nNummer, 6)))
      DbSelectArea(nOldSelect)
      hResult["status"] := "not_found"
      hResult["message"] := "Project not found: " + AllTrim(Str(nNummer))
      RETURN hResult
   ENDIF

   nStat := _McpPjNum(_McpPjF("pj", "STATUS", 0))
   hResult["number"]         := nNummer
   hResult["customer"]       := HB_StrToUTF8(AllTrim(_McpPjStr(_McpPjF("pj", "KUNDMA", ""))))
   hResult["customer_name"]  := HB_StrToUTF8(_McpPjKundeName(_McpPjNum(_McpPjF("pj", "KUNDE", 0))))
   hResult["customer_number"] := _McpPjNum(_McpPjF("pj", "KUNDE", 0))
   hResult["contact"]        := _McpPjNum(_McpPjF("pj", "CONTACT", 0))
   hResult["state"]          := nStat
   hResult["state_name"]     := HB_StrToUTF8(_McpPjStatusName(nStat))
   hResult["active"]         := (nStat < 7)
   hResult["owner"]          := _McpPjNum(_McpPjF("pj", "OWNER", 0))
   hResult["owner_initials"] := HB_StrToUTF8(_McpPjInitials(_McpPjNum(_McpPjF("pj", "OWNER", 0))))
   hResult["sales"]          := _McpPjNum(_McpPjF("pj", "SALES", 0))
   hResult["sales_initials"] := HB_StrToUTF8(_McpPjInitials(_McpPjNum(_McpPjF("pj", "SALES", 0))))
   hResult["description"]    := HB_StrToUTF8(AllTrim(_McpPjStr(_McpPjF("pj", "BESCHREIBU", ""))))
   hResult["value"]          := _McpPjNum(_McpPjF("pj", "VALUE", 0))
   hResult["budget"]         := _McpPjNum(_McpPjF("pj", "BUDGET", 0))
   hResult["specification"]  := HB_StrToUTF8(AllTrim(_McpPjStr(_McpPjF("pj", "SPEC", ""))))
   hResult["notes"]          := HB_StrToUTF8(AllTrim(_McpPjStr(_McpPjF("pj", "NOTES", ""))))
   hResult["open_tasks"]     := _McpPjOpenTasks(nNummer)
   hResult["articles"]       := _McpPjArticles(nNummer)
   hResult["costs"]          := _McpPjCosts(nNummer)
   hResult["status"]         := "found"

   DbSelectArea(nOldSelect)
RETURN hResult

FUNCTION MCP_Tool_Search_Projects(hArgs)
   LOCAL hResult := {=>}
   LOCAL cSearch := "", lOpenOnly := .T.
   LOCAL nMax, nCount := 0
   LOCAL aRows := {}, nStat, cKu, cBe, lHit, nNummer
   LOCAL nOldSelect := Select()

   // Return schema and description when called without arguments
   IF hArgs == NIL .OR. ValType(hArgs) != "H" .OR. Len(hArgs) == 0
      hResult["schema"] := {;
         "type"=>"object",;
         "properties"=>{;
            "search"=>{"type"=>"string","description"=>"Case-insensitive substring matched against project number, customer matchcode or description"},;
            "open_only"=>{"type"=>"boolean","description"=>"Only active projects (status < 7 paused/cancelled/archived). Default true"},;
            "max_results"=>{"type"=>"number","description"=>"Maximum number of projects to return (default 50, max 200)"};
         };
      }
      hResult["description"] := "Search projects (Projekte) by number, customer matchcode or description; returns a " + ;
                              "compact list with status name, owner/sales initials and open-task count"
      RETURN hResult
   ENDIF

   IF HHasKey(hArgs, "search") .AND. ! Empty(hArgs["search"])
      cSearch := Upper(AllTrim(HB_CStr(hArgs["search"])))
   ENDIF
   IF HHasKey(hArgs, "open_only") .AND. ValType(hArgs["open_only"]) == "L"
      lOpenOnly := hArgs["open_only"]
   ENDIF
   nMax := IIF(HHasKey(hArgs, "max_results") .AND. HB_IsNumeric(hArgs["max_results"]), Int(hArgs["max_results"]), 50)
   nMax := Max(1, Min(nMax, 200))

   NetUse("projekte", "pj")
   pj->(DbSetOrder(1))
   pj->(DbGoTop())
   DO WHILE ! pj->(Eof())
      nStat := _McpPjNum(_McpPjF("pj", "STATUS", 0))
      IF lOpenOnly .AND. nStat >= 7
         pj->(DbSkip()) ; LOOP
      ENDIF
      nNummer := _McpPjNum(_McpPjF("pj", "NUMMER", 0))
      IF ! Empty(cSearch)
         cKu := Upper(AllTrim(_McpPjStr(_McpPjF("pj", "KUNDMA", ""))))
         cBe := Upper(AllTrim(_McpPjStr(_McpPjF("pj", "BESCHREIBU", ""))))
         lHit := (cSearch $ cKu) .OR. (cSearch $ cBe) .OR. (cSearch $ AllTrim(Str(nNummer, 6)))
         IF ! lHit
            pj->(DbSkip()) ; LOOP
         ENDIF
      ENDIF
      IF nCount >= nMax
         EXIT
      ENDIF
      AAdd(aRows, { ;
         "number"      => nNummer, ;
         "customer"    => HB_StrToUTF8(AllTrim(_McpPjStr(_McpPjF("pj", "KUNDMA", "")))), ;
         "state"       => nStat, ;
         "state_name"  => HB_StrToUTF8(_McpPjStatusName(nStat)), ;
         "owner"       => HB_StrToUTF8(_McpPjInitials(_McpPjNum(_McpPjF("pj", "OWNER", 0)))), ;
         "sales"       => HB_StrToUTF8(_McpPjInitials(_McpPjNum(_McpPjF("pj", "SALES", 0)))), ;
         "open_tasks"  => _McpPjOpenTasks(nNummer), ;
         "description" => HB_StrToUTF8(AllTrim(_McpPjStr(_McpPjF("pj", "BESCHREIBU", "")))) })
      nCount++
      pj->(DbSkip())
   ENDDO

   DbSelectArea(nOldSelect)
   hResult["projects"] := aRows
   hResult["count"] := Len(aRows)
   hResult["status"] := "found"
RETURN hResult

// Apply the optional header fields present in hArgs onto a Project model
// object (only fields whose DB column exists are set, like projekt_web.prg).
STATIC FUNCTION _McpPjSet(oProj, cProp, xVal)
   IF pj->(FieldPos(Upper(cProp))) > 0
      __objSendMsg(oProj, "_" + cProp, xVal)
   ENDIF
RETURN NIL

STATIC FUNCTION _McpPjApplyFields(oProj, hArgs)
   IF HHasKey(hArgs, "description")   ; _McpPjSet(oProj, "Beschreibu", AllTrim(HB_CStr(hArgs["description"])))   ; ENDIF
   IF HHasKey(hArgs, "status")        ; _McpPjSet(oProj, "Status",     _McpPjNum(hArgs["status"]))                ; ENDIF
   IF HHasKey(hArgs, "contact")       ; _McpPjSet(oProj, "Contact",    _McpPjNum(hArgs["contact"]))               ; ENDIF
   IF HHasKey(hArgs, "owner")         ; _McpPjSet(oProj, "Owner",      _McpPjNum(hArgs["owner"]))                 ; ENDIF
   IF HHasKey(hArgs, "sales")         ; _McpPjSet(oProj, "Sales",      _McpPjNum(hArgs["sales"]))                 ; ENDIF
   IF HHasKey(hArgs, "value")         ; _McpPjSet(oProj, "Value",      _McpPjNum(hArgs["value"]))                 ; ENDIF
   IF HHasKey(hArgs, "budget")        ; _McpPjSet(oProj, "Budget",     _McpPjNum(hArgs["budget"]))                ; ENDIF
   IF HHasKey(hArgs, "specification") ; _McpPjSet(oProj, "Spec",       AllTrim(HB_CStr(hArgs["specification"])))  ; ENDIF
   IF HHasKey(hArgs, "notes")         ; _McpPjSet(oProj, "Notes",      AllTrim(HB_CStr(hArgs["notes"])))          ; ENDIF
   IF HHasKey(hArgs, "closed_for")    ; _McpPjSet(oProj, "ClosedFor",  AllTrim(HB_CStr(hArgs["closed_for"])))     ; ENDIF
RETURN NIL

FUNCTION MCP_Tool_Create_Project(hArgs)
   LOCAL hResult := {=>}
   LOCAL cKunde, oProj, nNummer := 0
   LOCAL oErr, cErr := "", lOk := .F.
   LOCAL nOldSelect := Select()

   // Return schema and description when called without arguments
   IF hArgs == NIL .OR. ValType(hArgs) != "H" .OR. Len(hArgs) == 0
      hResult["schema"] := {;
         "type"=>"object",;
         "properties"=>{;
            "customer"=>{"type"=>"string","description"=>"Customer matchcode (required, or customer_number)"},;
            "customer_number"=>{"type"=>"number","description"=>"Customer number (alternative to 'customer')"},;
            "description"=>{"type"=>"string","description"=>"Project description (Beschreibung)"},;
            "status"=>{"type"=>"number","description"=>"Status: 0 open, 1 closed, 7 paused, 8 cancelled, 9 archived (default 0)"},;
            "contact"=>{"type"=>"number","description"=>"Contact id at the customer"},;
            "owner"=>{"type"=>"number","description"=>"Owner user id (Verantwortlich)"},;
            "sales"=>{"type"=>"number","description"=>"Sales user id (Vertrieb)"},;
            "value"=>{"type"=>"number","description"=>"Project value (Wert)"},;
            "budget"=>{"type"=>"number","description"=>"Project budget"},;
            "specification"=>{"type"=>"string","description"=>"Specification text (Spezifikation)"},;
            "notes"=>{"type"=>"string","description"=>"Notes"};
         },;
         "anyOf"=>{{"customer"}, {"customer_number"}};
      }
      hResult["description"] := "Create a project (Projekt) for a customer via the Project model (auto-numbered). " + ;
                              "Provide 'customer' (matchcode) or 'customer_number'; all other header fields are optional"
      RETURN hResult
   ENDIF

   NetUse("projekte", "pj")
   cKunde := _McpPjResolveCustomer(hArgs)
   IF Empty(cKunde)
      DbSelectArea(nOldSelect)
      hResult["status"] := "not_found"
      hResult["message"] := "Customer not found - provide 'customer' (matchcode) or 'customer_number' of an existing customer"
      RETURN hResult
   ENDIF

   BEGIN SEQUENCE WITH {|e| Break(e)}
      oProj := Project():New(.T.)
      oProj:cKunde := cKunde
      _McpPjApplyFields(oProj, hArgs)
      oProj:Save()
      nNummer := _McpPjNum(oProj:Nummer)
      lOk := .T.
   RECOVER USING oErr
      cErr := "Creating the project failed: " + _MCP_ErrText(oErr)
   END SEQUENCE

   DbSelectArea(nOldSelect)
   IF ! lOk
      hResult["status"] := "error"
      hResult["message"] := cErr
      RETURN hResult
   ENDIF
   hResult["number"] := nNummer
   hResult["customer"] := HB_StrToUTF8(AllTrim(cKunde))
   hResult["status"] := "success"
   hResult["message"] := "Project " + AllTrim(Str(nNummer)) + " created"
RETURN hResult

FUNCTION MCP_Tool_Update_Project(hArgs)
   LOCAL hResult := {=>}
   LOCAL nNummer, cKunde, oProj
   LOCAL oErr, cErr := "", lOk := .F.
   LOCAL nOldSelect := Select()

   // Return schema and description when called without arguments
   IF hArgs == NIL .OR. ValType(hArgs) != "H" .OR. Len(hArgs) == 0
      hResult["schema"] := {;
         "type"=>"object",;
         "properties"=>{;
            "number"=>{"type"=>"number","description"=>"Project number to update"},;
            "customer"=>{"type"=>"string","description"=>"Change the customer (matchcode)"},;
            "customer_number"=>{"type"=>"number","description"=>"Change the customer (by number)"},;
            "description"=>{"type"=>"string","description"=>"Project description"},;
            "status"=>{"type"=>"number","description"=>"Status: 0 open, 1 closed, 7 paused, 8 cancelled, 9 archived"},;
            "contact"=>{"type"=>"number","description"=>"Contact id"},;
            "owner"=>{"type"=>"number","description"=>"Owner user id"},;
            "sales"=>{"type"=>"number","description"=>"Sales user id"},;
            "value"=>{"type"=>"number","description"=>"Project value"},;
            "budget"=>{"type"=>"number","description"=>"Project budget"},;
            "specification"=>{"type"=>"string","description"=>"Specification text"},;
            "notes"=>{"type"=>"string","description"=>"Notes"},;
            "closed_for"=>{"type"=>"string","description"=>"Closed-for reason"};
         },;
         "required"=>{"number"};
      }
      hResult["description"] := "Update an existing project's header. Only the fields you pass are changed " + ;
                              "(partial update)"
      RETURN hResult
   ENDIF

   IF ! HB_IsNumeric(hArgs["number"])
      RETURN "Parameter 'number' must be a number"
   ENDIF
   nNummer := Int(hArgs["number"])

   NetUse("projekte", "pj")
   pj->(DbSetOrder(1))
   IF nNummer <= 0 .OR. ! pj->(DbSeek(Str(nNummer, 6)))
      DbSelectArea(nOldSelect)
      hResult["status"] := "not_found"
      hResult["message"] := "Project not found: " + AllTrim(Str(nNummer))
      RETURN hResult
   ENDIF

   cKunde := ""
   IF HHasKey(hArgs, "customer") .OR. HHasKey(hArgs, "customer_number")
      cKunde := _McpPjResolveCustomer(hArgs)
      IF Empty(cKunde)
         DbSelectArea(nOldSelect)
         hResult["status"] := "not_found"
         hResult["message"] := "Customer not found"
         RETURN hResult
      ENDIF
   ENDIF

   BEGIN SEQUENCE WITH {|e| Break(e)}
      oProj := pj->(Project():New())
      oProj:Load(nNummer)
      IF ! Empty(cKunde)
         oProj:cKunde := cKunde
      ENDIF
      _McpPjApplyFields(oProj, hArgs)
      oProj:Save()
      lOk := .T.
   RECOVER USING oErr
      cErr := "Updating the project failed: " + _MCP_ErrText(oErr)
   END SEQUENCE

   DbSelectArea(nOldSelect)
   IF ! lOk
      hResult["status"] := "error"
      hResult["message"] := cErr
      RETURN hResult
   ENDIF
   hResult["number"] := nNummer
   hResult["status"] := "success"
   hResult["message"] := "Project " + AllTrim(Str(nNummer)) + " updated"
RETURN hResult

FUNCTION MCP_Tool_Add_Project_Article(hArgs)
   LOCAL hResult := {=>}
   LOCAL nNummer, nArtnr := 0, cMc := ""
   LOCAL oRec, oErr, cErr := "", lOk := .F.
   LOCAL nOldSelect := Select()

   // Return schema and description when called without arguments
   IF hArgs == NIL .OR. ValType(hArgs) != "H" .OR. Len(hArgs) == 0
      hResult["schema"] := {;
         "type"=>"object",;
         "properties"=>{;
            "number"=>{"type"=>"number","description"=>"Project number"},;
            "article"=>{"type"=>"string","description"=>"Article matchcode to add"},;
            "part_number"=>{"type"=>"number","description"=>"Internal article number (alternative to 'article')"};
         },;
         "required"=>{"number"};
      }
      hResult["description"] := "Add an article to a project (projart). Provide 'article' (matchcode) or 'part_number'"
      RETURN hResult
   ENDIF

   IF ! HB_IsNumeric(hArgs["number"])
      RETURN "Parameter 'number' must be a number"
   ENDIF
   nNummer := Int(hArgs["number"])

   NetUse("projekte", "pj")
   NetUse("artikel", "art")
   NetUse("projart", "pjart")

   pj->(DbSetOrder(1))
   IF ! pj->(DbSeek(Str(nNummer, 6)))
      DbSelectArea(nOldSelect)
      hResult["status"] := "not_found"
      hResult["message"] := "Project not found: " + AllTrim(Str(nNummer))
      RETURN hResult
   ENDIF

   IF HHasKey(hArgs, "part_number") .AND. HB_IsNumeric(hArgs["part_number"]) .AND. hArgs["part_number"] > 0
      art->(DbSetOrder(2))
      IF art->(DbSeek(Str(Int(hArgs["part_number"]), 6)))
         nArtnr := art->Artikelnr
         cMc := AllTrim(art->Matchcode)
      ENDIF
   ELSEIF HHasKey(hArgs, "article") .AND. ! Empty(hArgs["article"])
      art->(DbSetOrder(1))
      IF art->(DbSeek(Pad(Upper(AllTrim(HB_CStr(hArgs["article"]))), 25)))
         nArtnr := art->Artikelnr
         cMc := AllTrim(art->Matchcode)
      ENDIF
   ELSE
      DbSelectArea(nOldSelect)
      RETURN "Provide 'article' (matchcode) or 'part_number'"
   ENDIF
   IF nArtnr == 0
      DbSelectArea(nOldSelect)
      hResult["status"] := "not_found"
      hResult["message"] := "Article not found"
      RETURN hResult
   ENDIF

   pjart->(DbSetOrder(1))
   IF pjart->(DbSeek(Str(nNummer, 6) + Str(nArtnr, 6)))
      DbSelectArea(nOldSelect)
      hResult["status"] := "exists"
      hResult["message"] := "Article is already part of the project"
      hResult["articles"] := _McpPjArticles(nNummer)
      RETURN hResult
   ENDIF

   BEGIN SEQUENCE WITH {|e| Break(e)}
      oRec := pjart->(Record():New(.T.))
      __objSendMsg(oRec, "_Nummer", nNummer)
      __objSendMsg(oRec, "_Artikelnr", nArtnr)
      __objSendMsg(oRec, "_Matchcode", cMc)
      oRec:Save()
      lOk := .T.
   RECOVER USING oErr
      cErr := "Adding the project article failed: " + _MCP_ErrText(oErr)
   END SEQUENCE

   DbSelectArea(nOldSelect)
   IF ! lOk
      hResult["status"] := "error"
      hResult["message"] := cErr
      RETURN hResult
   ENDIF
   hResult["number"] := nNummer
   hResult["articles"] := _McpPjArticles(nNummer)
   hResult["status"] := "success"
   hResult["message"] := "Article " + cMc + " added to project " + AllTrim(Str(nNummer))
RETURN _HashToUtf8(hResult)

FUNCTION MCP_Tool_Remove_Project_Article(hArgs)
   LOCAL hResult := {=>}
   LOCAL nNummer, nArtnr := 0
   LOCAL oErr, cErr := "", lOk := .F.
   LOCAL nOldSelect := Select()

   // Return schema and description when called without arguments
   IF hArgs == NIL .OR. ValType(hArgs) != "H" .OR. Len(hArgs) == 0
      hResult["schema"] := {;
         "type"=>"object",;
         "properties"=>{;
            "number"=>{"type"=>"number","description"=>"Project number"},;
            "part_number"=>{"type"=>"number","description"=>"Internal article number to remove"},;
            "article"=>{"type"=>"string","description"=>"Article matchcode to remove (alternative to 'part_number')"};
         },;
         "required"=>{"number"};
      }
      hResult["description"] := "Remove an article from a project (projart)"
      RETURN hResult
   ENDIF

   IF ! HB_IsNumeric(hArgs["number"])
      RETURN "Parameter 'number' must be a number"
   ENDIF
   nNummer := Int(hArgs["number"])

   NetUse("artikel", "art")
   NetUse("projart", "pjart")

   IF HHasKey(hArgs, "part_number") .AND. HB_IsNumeric(hArgs["part_number"]) .AND. hArgs["part_number"] > 0
      nArtnr := Int(hArgs["part_number"])
   ELSEIF HHasKey(hArgs, "article") .AND. ! Empty(hArgs["article"])
      art->(DbSetOrder(1))
      IF art->(DbSeek(Pad(Upper(AllTrim(HB_CStr(hArgs["article"]))), 25)))
         nArtnr := art->Artikelnr
      ENDIF
   ELSE
      DbSelectArea(nOldSelect)
      RETURN "Provide 'part_number' or 'article' (matchcode)"
   ENDIF
   IF nArtnr == 0
      DbSelectArea(nOldSelect)
      hResult["status"] := "not_found"
      hResult["message"] := "Article not found"
      RETURN hResult
   ENDIF

   pjart->(DbSetOrder(1))
   IF ! pjart->(DbSeek(Str(nNummer, 6) + Str(nArtnr, 6)))
      DbSelectArea(nOldSelect)
      hResult["status"] := "not_found"
      hResult["message"] := "Article is not part of the project"
      RETURN hResult
   ENDIF

   BEGIN SEQUENCE WITH {|e| Break(e)}
      pjart->(Rec_Lock())
      pjart->(dbDelete())
      pjart->(dbUnLock())
      lOk := .T.
   RECOVER USING oErr
      cErr := "Removing the project article failed: " + _MCP_ErrText(oErr)
   END SEQUENCE

   DbSelectArea(nOldSelect)
   IF ! lOk
      hResult["status"] := "error"
      hResult["message"] := cErr
      RETURN hResult
   ENDIF
   hResult["number"] := nNummer
   hResult["articles"] := _McpPjArticles(nNummer)
   hResult["status"] := "success"
   hResult["message"] := "Article removed from project " + AllTrim(Str(nNummer))
RETURN _HashToUtf8(hResult)

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

FUNCTION MCP_Tool_Get_Stock_Withdrawal(hArgs)
   LOCAL hResult := {=>}
   LOCAL nNummer
   LOCAL aRows := {}, hRow, aLines := {}, hLine
   LOCAL nFremdDel, nFremdTaken
   LOCAL nTotMenge := 0, nTotFremd := 0, nTotDeliv := 0, nTotTaken := 0
   LOCAL aLoc, hLoc
   LOCAL lHeader := .F.
   LOCAL nOldSelect := Select()

   // Return schema and description when called without arguments
   IF hArgs == NIL .OR. ValType(hArgs) != "H" .OR. Len(hArgs) == 0
      hResult["schema"] := {;
         "type"=>"object",;
         "properties"=>{;
            "number"=>{"type"=>"number","description"=>"Entnahme-Nummer (the Lagerentnahme / goods-issue document number)"};
         },;
         "required"=>{"number"};
      }
      hResult["description"] := "Get a stock withdrawal (Lagerentnahme) by its number: header (date, customer, " + ;
                                "group) plus each position with article, quantity issued from own stock (menge), the " + ;
                                "quantity assigned to the external warehouse (fremd_quantity), the quantity actually " + ;
                                "delivered to the external warehouse / Fremdlager (fremd_delivered), and the quantity " + ;
                                "taken FROM the external warehouse (fremd_taken) with the per-location split"
      RETURN hResult
   ENDIF

   IF ! HB_IsNumeric(hArgs["number"])
      RETURN "Parameter 'number' must be a number"
   ENDIF
   nNummer := Int(hArgs["number"])

   NetUse("lagerne", "lne")
   NetUse("artikel", "art")
   NetUse("lagent", "lage")     // per-position storage-location breakdown of the withdrawal
   NetUse("lagerort", "lago")   // location master - carries the Fremd (external) flag

   lne->(DbSetOrder(1))  // numeric Nummer
   IF ! lne->(DbSeek(nNummer))
      DbSelectArea(nOldSelect)
      hResult["status"] := "not_found"
      hResult["message"] := "Stock withdrawal (Lagerentnahme) not found: " + AllTrim(Str(nNummer))
      RETURN hResult
   ENDIF

   hResult["number"] := nNummer

   // Pass 1: collect the positions with a clean lne iteration - no external
   // calls here that could move a cursor. The header fields are shared across
   // the positions, so take them from the first row.
   DO WHILE ! lne->(Eof()) .AND. lne->Nummer == nNummer
      IF ! lHeader
         hResult["date"] := lne->Datum
         IF ValType(lne->Kunde) == "C"
            IF ! Empty(lne->Kunde)
               hResult["customer"] := HB_StrToUTF8(AllTrim(lne->Kunde))
            ENDIF
         ELSEIF HB_IsNumeric(lne->Kunde) .AND. lne->Kunde > 0
            hResult["customer_no"] := lne->Kunde
         ENDIF
         IF ! Empty(lne->Gruppe)
            hResult["group"] := HB_StrToUTF8(AllTrim(lne->Gruppe))
         ENDIF
         IF HB_IsNumeric(lne->Buyer) .AND. lne->Buyer > 0
            hResult["buyer"] := lne->Buyer
         ENDIF
         IF HB_IsNumeric(lne->Person)
            IF lne->Person != 0
               hResult["person"] := lne->Person  // buyer/contact id
            ENDIF
         ELSEIF ValType(lne->Person) == "C" .AND. ! Empty(lne->Person)
            hResult["person"] := HB_StrToUTF8(AllTrim(lne->Person))
         ENDIF
         lHeader := .T.
      ENDIF
      hRow := {=>}
      hRow["pos"]       := lne->Pos
      hRow["artikelnr"] := lne->Artikelnr
      hRow["matchcode"] := HB_StrToUTF8(AllTrim(lne->Matchcode))
      hRow["menge"]     := lne->Menge
      hRow["fremd"]     := lne->Fremd
      hRow["me"]        := HB_StrToUTF8(AllTrim(lne->Me))
      hRow["reftyp"]    := HB_StrToUTF8(AllTrim(lne->RefTyp))
      hRow["refbeleg"]  := lne->RefBeleg
      hRow["refpos"]    := lne->RefPos
      IF ! Empty(lne->Zweck)
         hRow["zweck"]  := HB_StrToUTF8(AllTrim(lne->Zweck))
      ENDIF
      hRow["packed"]    := lne->Packed
      AAdd(aRows, hRow)
      lne->(DbSkip())
   ENDDO

   // Pass 2: the quantity actually delivered to the external warehouse per
   // position via GetEntFremdLagerQty(Nummer, Pos), plus the article
   // description. The helper lives in the app runtime and may touch other
   // work areas, so it runs guarded and after pass 1 finished iterating lne;
   // the art order is re-asserted each iteration for the same reason.
   FOR EACH hRow IN aRows
      hLine := {=>}
      hLine["item"] := hRow["pos"]
      hLine["article"] := hRow["matchcode"]
      art->(DbSetOrder(2))  // by Artikelnr
      IF art->(DbSeek(Str(hRow["artikelnr"], 6)))
         hLine["description"] := HB_StrToUTF8(AllTrim(art->Artikel))
      ENDIF
      hLine["unit"] := hRow["me"]
      hLine["quantity"] := hRow["menge"]         // issued from own stock
      hLine["fremd_quantity"] := hRow["fremd"]   // assigned to the external warehouse

      nFremdDel := NIL
      BEGIN SEQUENCE
         nFremdDel := GetEntFremdLagerQty(nNummer, hRow["pos"])
      RECOVER
         nFremdDel := NIL
      END SEQUENCE
      IF HB_IsNumeric(nFremdDel)
         hLine["fremd_delivered"] := nFremdDel                  // delivered to Fremdlager
         hLine["fremd_open"] := hRow["fremd"] - nFremdDel       // still to deliver
         nTotDeliv += nFremdDel
      ELSE
         hLine["fremd_delivered_error"] := "GetEntFremdLagerQty could not be evaluated"
      ENDIF

      // How much was taken FROM the external warehouse: walk this position's
      // storage-location breakdown (lagent) and sum the quantity at locations
      // flagged Fremd in the location master (lagerort), plus the per-location
      // split. Done last with self-contained seeks, so the external
      // GetEntFremdLagerQty call above cannot disturb the lage/lago cursors;
      // the orders are re-asserted here for the same reason.
      nFremdTaken := 0
      aLoc := {}
      lage->(DbSetOrder(1))  // Str(Nummer,6) + Str(Pos,3)
      lago->(DbSetOrder(1))  // Lagerort
      IF lage->(DbSeek(Str(nNummer, 6) + Str(hRow["pos"], 3)))
         DO WHILE ! lage->(Eof()) .AND. lage->Nummer == nNummer .AND. lage->Pos == hRow["pos"]
            hLoc := {=>}
            hLoc["location"] := HB_StrToUTF8(AllTrim(lage->Lagerort))
            hLoc["quantity"] := lage->Lagermenge
            hLoc["external"] := .F.
            IF lago->(DbSeek(lage->Lagerort)) .AND. lago->Fremd
               hLoc["external"] := .T.
               nFremdTaken += lage->Lagermenge
            ENDIF
            AAdd(aLoc, hLoc)
            lage->(DbSkip())
         ENDDO
      ENDIF
      IF Len(aLoc) > 0
         hLine["locations"] := aLoc
      ENDIF
      hLine["fremd_taken"] := nFremdTaken    // withdrawn FROM the external warehouse
      nTotTaken += nFremdTaken

      IF ! Empty(hRow["reftyp"]) .OR. hRow["refbeleg"] != 0
         hLine["reference"] := {"type"=>hRow["reftyp"], "document"=>hRow["refbeleg"], "position"=>hRow["refpos"]}
      ENDIF
      IF HHasKey(hRow, "zweck")
         hLine["purpose"] := hRow["zweck"]
      ENDIF
      hLine["packed"] := hRow["packed"]

      nTotMenge += hRow["menge"]
      nTotFremd += hRow["fremd"]
      AAdd(aLines, hLine)
   NEXT

   DbSelectArea(nOldSelect)

   hResult["positions"] := aLines
   hResult["position_count"] := Len(aLines)
   hResult["total_quantity"] := nTotMenge
   hResult["total_fremd_quantity"] := nTotFremd
   hResult["total_fremd_delivered"] := nTotDeliv
   hResult["total_fremd_taken"] := nTotTaken
   hResult["status"] := "found"
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
      IF ! art->(DbSeek(AllTrim(HB_UTF8ToStr(hArgs["matchcode"]))))  // matchcode is case-sensitive - do NOT upper
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

FUNCTION MCP_Tool_Get_Article_Orders(hArgs)
   LOCAL hResult := {=>}
   LOCAL lFound := .F.
   LOCAL nArtnr, cMatch
   LOCAL cStatus := "open"
   LOCAL aFA := {}, hFA, aPO := {}, hPO
   LOCAL nLimit := 200, nFa := 0, nPo := 0
   LOCAL lFaTrunc := .F., lPoTrunc := .F.
   LOCAL dTemp, nArr
   LOCAL nOldSelect := Select()

   // Return schema and description when called without arguments
   IF hArgs == NIL .OR. ValType(hArgs) != "H" .OR. Len(hArgs) == 0
      hResult["schema"] := {;
         "type"=>"object",;
         "properties"=>{;
            "matchcode"=>{"type"=>"string","description"=>"Artikel Matchcode"},;
            "partno"=>{"type"=>"string","description"=>"Artikelnummer"},;
            "status_filter"=>{"type"=>"string","enum"=>{"open","all"},"description"=>"open = only active production orders (Status<4) and open purchase orders (Bestat<3); all = everything (default open)"},;
            "limit"=>{"type"=>"number","description"=>"Maximum entries per list (default 200, max 1000)"};
         },;
         "anyOf"=>{{"matchcode", "partno"}};
      }
      hResult["description"] := "List the production orders (Fertigungsauftraege, from werkauf) and purchase orders " + ;
                               "(Bestellungen, from engbes) for an article - each with quantities, open quantity, " + ;
                               "status and the end/delivery week (purchase orders also carry ship_time and " + ;
                               "expected_arrival_week/date = delivery + transit); external production orders show " + ;
                               "their supplier and linked purchase order. Defaults to only active/open orders"
      RETURN hResult
   ENDIF

   IF HHasKey(hArgs, "status_filter") .AND. hArgs["status_filter"] == "all"
      cStatus := "all"
   ENDIF
   IF HHasKey(hArgs, "limit") .AND. HB_IsNumeric(hArgs["limit"]) .AND. hArgs["limit"] > 0
      nLimit := Min(Int(hArgs["limit"]), 1000)
   ENDIF

   NetUse("artikel", "art")
   NetUse("werkauf", "wer")
   NetUse("engbes", "bes")

   IF HHasKey(hArgs, "matchcode") .AND. ! Empty(hArgs["matchcode"])
      art->(DbSetOrder(1))
      lFound := art->(DbSeek(AllTrim(hArgs["matchcode"])))   // matchcode is case-sensitive
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
   cMatch := AllTrim(art->Matchcode)
   hResult["matchcode"] := HB_StrToUTF8(cMatch)
   hResult["partno"] := nArtnr
   hResult["description"] := HB_StrToUTF8(AllTrim(art->Artikel))
   hResult["stock"] := art->Bestand

   // Production orders: werkauf index 2 is keyed on Artno (see ChangeDrawingRevision).
   wer->(DbSetOrder(2))
   IF wer->(DbSeek(Str(nArtnr, 6)))
      DO WHILE ! wer->(Eof()) .AND. wer->Artno == nArtnr .AND. nFa < nLimit
         IF cStatus == "all" .OR. wer->Status < 4
            hFA := {=>}
            hFA["fa_number"] := wer->Aufno
            hFA["quantity"] := wer->Qty
            hFA["produced_quantity"] := wer->GelQty
            hFA["open_quantity"] := Max(wer->Qty - wer->GelQty, 0)
            hFA["status"] := wer->Status
            hFA["active"] := wer->Status < 4
            IF HB_IsNumeric(wer->End) .AND. wer->End > 0
               hFA["end_week"] := StrZero(wer->End, 4)
               IF (dTemp := BesWeekDate(wer->End)) != NIL
                  hFA["end_date"] := dTemp
               ENDIF
            ENDIF
            IF ! Empty(wer->Liefma)   // Fremdfertigung
               hFA["external"] := .T.
               hFA["supplier"] := HB_StrToUTF8(AllTrim(wer->Liefma))
               IF HB_IsNumeric(wer->Besnr) .AND. wer->Besnr > 0
                  hFA["purchase_order"] := wer->Besnr
                  hFA["purchase_order_item"] := wer->BesPos
               ENDIF
            ENDIF
            AAdd(aFA, hFA)
            nFa++
         ENDIF
         wer->(DbSkip())
      ENDDO
      lFaTrunc := nFa >= nLimit .AND. ! wer->(Eof()) .AND. wer->Artno == nArtnr
   ENDIF

   // Purchase orders: engbes index 3 is keyed on Matchcode.
   bes->(DbSetOrder(3))
   IF bes->(DbSeek(cMatch))
      DO WHILE ! bes->(Eof()) .AND. AllTrim(bes->Matchcode) == cMatch .AND. nPo < nLimit
         IF cStatus == "all" .OR. bes->Bestat < 3
            hPO := {=>}
            hPO["po_number"] := bes->Besnr
            hPO["item"] := bes->Posnr
            IF ! Empty(bes->Liefma)
               hPO["supplier"] := HB_StrToUTF8(AllTrim(bes->Liefma))
            ENDIF
            hPO["quantity"] := bes->BeQty
            hPO["delivered_quantity"] := bes->GelQty
            hPO["open_quantity"] := Max(bes->BeQty - bes->GelQty, 0)
            hPO["status"] := IIF(bes->Bestat < 3, "open", "completed")
            hPO["confirmed"] := Upper(AllTrim(bes->Confirmed)) == "Y"
            IF HB_IsNumeric(bes->ShipTime) .AND. bes->ShipTime > 0
               hPO["ship_time"] := bes->ShipTime   // transit time (weeks) supplier -> us
            ENDIF
            IF HB_IsNumeric(bes->Lterm) .AND. bes->Lterm > 0
               hPO["delivery_week"] := StrZero(bes->Lterm, 4)
               IF (dTemp := BesWeekDate(bes->Lterm)) != NIL
                  hPO["delivery_date"] := dTemp
               ENDIF
               // Expected arrival = delivery week + transit (only real weeks WW<=52)
               nArr := IIF(Val(Right(Str(bes->Lterm, 4), 2)) <= 52, AddWeeks(bes->Lterm, bes->ShipTime), bes->Lterm)
               hPO["expected_arrival_week"] := StrZero(nArr, 4)
               IF (dTemp := BesWeekDate(nArr)) != NIL
                  hPO["expected_arrival_date"] := dTemp
               ENDIF
            ENDIF
            IF ! Empty(bes->AbNr)
               hPO["supplier_ab_number"] := HB_StrToUTF8(AllTrim(bes->AbNr))
            ENDIF
            AAdd(aPO, hPO)
            nPo++
         ENDIF
         bes->(DbSkip())
      ENDDO
      lPoTrunc := nPo >= nLimit .AND. ! bes->(Eof()) .AND. AllTrim(bes->Matchcode) == cMatch
   ENDIF

   DbSelectArea(nOldSelect)

   hResult["production_orders"] := aFA
   hResult["production_order_count"] := Len(aFA)
   hResult["purchase_orders"] := aPO
   hResult["purchase_order_count"] := Len(aPO)
   IF lFaTrunc .OR. lPoTrunc
      hResult["truncated"] := .T.
   ENDIF
   hResult["status"] := "found"
RETURN hResult

FUNCTION MCP_Tool_Get_Article_Schedule(hArgs)
   LOCAL hResult := {=>}
   LOCAL lFound := .F.
   LOCAL nArtnr
   LOCAL aAvail, aRow, hRow, aOut := {}
   LOCAL lConfirmOnly := .F., lUseMelde := .F., lTBAasLT := .F., lBlanketReq := .T.
   LOCAL dTemp
   LOCAL nOldSelect := Select()

   // Return schema and description when called without arguments
   IF hArgs == NIL .OR. ValType(hArgs) != "H" .OR. Len(hArgs) == 0
      hResult["schema"] := {;
         "type"=>"object",;
         "properties"=>{;
            "matchcode"=>{"type"=>"string","description"=>"Artikel Matchcode"},;
            "partno"=>{"type"=>"string","description"=>"Artikelnummer"},;
            "confirmed_only"=>{"type"=>"boolean","description"=>"Only count confirmed purchase orders as incoming (default false)"},;
            "use_reorder_point"=>{"type"=>"boolean","description"=>"Include the reorder point (Meldebestand) in the demand (default false)"},;
            "tba_as_leadtime"=>{"type"=>"boolean","description"=>"Schedule TBA orders (week xx97) at the standard lead time instead of listing them as 'unknown' (default false)"},;
            "blanket_use_requested_week"=>{"type"=>"boolean","description"=>"For blanket call-offs (week 99) use the customer's requested week; false lists them as 'unknown' (default true)"};
         },;
         "anyOf"=>{{"matchcode", "partno"}};
      }
      hResult["description"] := "The article's date/availability overview (Terminuebersicht, the F3 view in the " + ;
                               "article master), computed with GetKwQty (the same engine, same default flags, as the " + ;
                               "F3 screen). One row per calendar week with the running available stock and the " + ;
                               "movements that week: customer_orders (demand), purchase_orders (incoming), " + ;
                               "production_requirement/production_receipt (Fertigung), plus available (verfuegbar). " + ;
                               "kind is 'week', 'backlog' (Rueckstand, overdue) or 'unknown' (TBA); zero movement " + ;
                               "columns are omitted. Optional flags mirror GetKwQty's parameters"
      RETURN hResult
   ENDIF

   NetUse("artikel", "art")

   IF HHasKey(hArgs, "matchcode") .AND. ! Empty(hArgs["matchcode"])
      art->(DbSetOrder(1))
      lFound := art->(DbSeek(AllTrim(hArgs["matchcode"])))   // matchcode is case-sensitive
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

   IF HHasKey(hArgs, "confirmed_only") .AND. HB_IsLogical(hArgs["confirmed_only"])
      lConfirmOnly := hArgs["confirmed_only"]
   ENDIF
   IF HHasKey(hArgs, "use_reorder_point") .AND. HB_IsLogical(hArgs["use_reorder_point"])
      lUseMelde := hArgs["use_reorder_point"]
   ENDIF
   IF HHasKey(hArgs, "tba_as_leadtime") .AND. HB_IsLogical(hArgs["tba_as_leadtime"])
      lTBAasLT := hArgs["tba_as_leadtime"]
   ENDIF
   IF HHasKey(hArgs, "blanket_use_requested_week") .AND. HB_IsLogical(hArgs["blanket_use_requested_week"])
      lBlanketReq := hArgs["blanket_use_requested_week"]
   ENDIF

   nArtnr := art->Artikelnr
   hResult["matchcode"] := HB_StrToUTF8(AllTrim(art->Matchcode))
   hResult["partno"] := nArtnr
   hResult["description"] := HB_StrToUTF8(AllTrim(art->Artikel))
   hResult["current_stock"] := art->Bestand

   // GetKwQty is the engine behind the F3 schedule. The default flags below
   // match how the F3 screen (ShowKw in artikel_browse.prg) calls it.
   BEGIN SEQUENCE
      aAvail := GetKwQty(nArtnr, lConfirmOnly, lUseMelde, lTBAasLT, lBlanketReq)
   RECOVER
      aAvail := NIL
   END SEQUENCE
   IF ! HB_IsArray(aAvail)
      DbSelectArea(nOldSelect)
      hResult["status"] := "error"
      hResult["message"] := "Schedule (GetKwQty) could not be evaluated"
      RETURN hResult
   ENDIF

   // GetKwQty row layout (model/artikel.prg): 1=week, 2=customer orders (demand),
   // 3=purchase orders (incoming), 4=production material requirement, 5=production
   // receipt, 6=available (verfuegbar), 7=uncovered production receipt,
   // 8=production start. Week 0 is the backlog (Rueckstand, overdue) and 9999 the
   // unknown/TBA bucket - the F3 screen (ShowKw) shows both.
   FOR EACH aRow IN aAvail
      IF HB_IsArray(aRow) .AND. Len(aRow) >= 6 .AND. HB_IsNumeric(aRow[1])
         hRow := {=>}
         DO CASE
         CASE aRow[1] == 0
            hRow["kind"] := "backlog"    // Rueckstand - overdue orders/receipts
         CASE aRow[1] == 9999
            hRow["kind"] := "unknown"    // unbekannt - TBA orders without a firm week
         OTHERWISE
            hRow["kind"] := "week"
            hRow["week"] := StrZero(aRow[1], 4)
            IF (dTemp := BesWeekDate(aRow[1])) != NIL
               hRow["date"] := dTemp
            ENDIF
         ENDCASE
         hRow["available"] := aRow[6]                     // running available stock (verfuegbar)
         IF aRow[2] != 0
            hRow["customer_orders"] := aRow[2]            // demand from sales orders
         ENDIF
         IF aRow[3] != 0
            hRow["purchase_orders"] := aRow[3]            // incoming from purchase orders
         ENDIF
         IF aRow[4] != 0
            hRow["production_requirement"] := aRow[4]     // component demand for production (WA Bedarf)
         ENDIF
         IF aRow[5] != 0
            hRow["production_receipt"] := aRow[5]         // incoming from production orders (WA Eingang)
         ENDIF
         IF Len(aRow) >= 8
            IF aRow[7] != 0
               hRow["uncovered_production_receipt"] := aRow[7]
            ENDIF
            IF aRow[8] != 0
               hRow["production_start"] := aRow[8]
            ENDIF
         ENDIF
         AAdd(aOut, hRow)
      ENDIF
   NEXT

   DbSelectArea(nOldSelect)

   hResult["schedule"] := aOut
   hResult["count"] := Len(aOut)
   hResult["status"] := "found"
RETURN hResult

FUNCTION MCP_Tool_Get_Production_Order(hArgs)
   LOCAL hResult := {=>}
   LOCAL nFa, hComp, dTemp
   LOCAL aComponents := {}
   LOCAL nRequired
   LOCAL nMissComp := 0, nMissQty := 0
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
                                "component), material_delivered - whether all material has been issued (for a " + ;
                                "Fremdfertigung: whether we delivered the material/Beistellung to the supplier) - " + ;
                                "and a producibility check: 'producible' (with current stock, incl. " + ;
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
         // Track outstanding material (real component lines only) for the
         // "have we issued the material" summary - for a Fremdfertigung this is
         // the Beistellung delivered to the supplier. Supply complete when
         // BookQty >= required (cf. checkstock.prg: BookQty < Qty -> not done).
         IF we->Pos > 0 .AND. nRequired > 0 .AND. we->BookQty < nRequired
            nMissComp++
            nMissQty += (nRequired - we->BookQty)
         ENDIF
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
   // Summary: has all the material been issued? For external production this
   // tells whether we have delivered the material (Beistellung) to the supplier.
   hResult["material_delivered"] := nMissComp == 0
   IF nMissComp > 0
      hResult["material_open_components"] := nMissComp
      hResult["material_open_quantity"] := nMissQty
   ENDIF
   hResult["status"] := "found"
RETURN hResult

FUNCTION MCP_Tool_List_Users(hArgs)
   LOCAL hResult := {=>}
   LOCAL aUsers := {}, hUser
   LOCAL lInactive := .F., lAbsence := .F.
   LOCAL nOne := 0
   LOCAL oUsr, dFrom, dUntil, nSubst, lAbsErr := .F.
   LOCAL nOldSelect := Select()

   // Return schema and description when called without arguments
   IF hArgs == NIL .OR. ValType(hArgs) != "H" .OR. Len(hArgs) == 0
      hResult["schema"] := {;
         "type"=>"object",;
         "properties"=>{;
            "number"=>{"type"=>"number","description"=>"Optional: return only this user (by user number)"},;
            "include_inactive"=>{"type"=>"boolean","description"=>"Also list deactivated users (default false)"},;
            "include_absence"=>{"type"=>"boolean","description"=>"Attach the away/absence status and substitute (Vertretung) from the user settings (default false)"};
         };
      }
      hResult["description"] := "List the Trader users with their number, name, initials, email and phone. With " + ;
                                "include_absence also the absence period (away_from/away_until), whether the user " + ;
                                "is currently absent, and the substitute (Vertretung) - read from the user settings " + ;
                                "(AwayFrom/AwayUntil/AwaySubst)"
      RETURN hResult
   ENDIF

   IF HHasKey(hArgs, "number") .AND. HB_IsNumeric(hArgs["number"]) .AND. hArgs["number"] > 0
      nOne := Int(hArgs["number"])
   ENDIF
   IF HHasKey(hArgs, "include_inactive") .AND. HB_IsLogical(hArgs["include_inactive"])
      lInactive := hArgs["include_inactive"]
   ENDIF
   IF HHasKey(hArgs, "include_absence") .AND. HB_IsLogical(hArgs["include_absence"])
      lAbsence := hArgs["include_absence"]
   ENDIF

   NetUse("buyer", "buy")

   // Pass 1: collect the users from the buyer file (user number = record
   // number). Pure iteration - no David calls that would move the cursor.
   IF nOne > 0
      buy->(DbGoTo(nOne))
      IF ! buy->(Eof()) .AND. ! Empty(buy->Buyer)
         AAdd(aUsers, _MCP_UserRow(nOne))
      ENDIF
   ELSE
      buy->(DbGoTop())
      DO WHILE ! buy->(Eof())
         IF ! Empty(buy->Buyer) .AND. ( lInactive .OR. buy->Aktive )
            AAdd(aUsers, _MCP_UserRow(buy->(RecNo())))
         ENDIF
         buy->(DbSkip())
      ENDDO
   ENDIF

   // Pass 2 (opt-in): away/absence status and substitute from each user's
   // settings (AwayFrom/AwayUntil/AwaySubst, as maintained by timebutler_sync).
   // Runs after pass 1 because User():Load moves the buyer cursor; guarded per
   // user so an unreadable settings record only marks that user "unavailable".
   IF lAbsence
      FOR EACH hUser IN aUsers
         BEGIN SEQUENCE
            oUsr := User():New()
            IF oUsr:Load( hUser["number"] )
               dFrom  := oUsr:oSettings:AwayFrom
               dUntil := oUsr:oSettings:AwayUntil
               nSubst := oUsr:oSettings:AwaySubst

               // Currently absent: an end date that has not passed, and either
               // no start date or a start date that has already been reached.
               hUser["absent"] := ! Empty(dUntil) .AND. dUntil >= Date() .AND. ( Empty(dFrom) .OR. dFrom <= Date() )
               IF ! Empty(dFrom)
                  hUser["away_from"] := dFrom
               ENDIF
               IF ! Empty(dUntil)
                  hUser["away_until"] := dUntil
               ENDIF
               IF HB_IsNumeric(nSubst) .AND. nSubst > 0
                  hUser["substitute_number"] := nSubst
                  buy->(DbGoTo(nSubst))   // record number - order independent
                  IF ! buy->(Eof()) .AND. ! Empty(buy->Buyer)
                     hUser["substitute_name"] := HB_StrToUTF8(AllTrim(buy->Buyer))
                  ENDIF
               ENDIF
            ELSE
               hUser["absence_status"] := "unavailable"
               lAbsErr := .T.
            ENDIF
         RECOVER
            hUser["absence_status"] := "unavailable"
            lAbsErr := .T.
         END SEQUENCE
      NEXT
      IF lAbsErr
         hResult["absence_note"] := "Absence is read from the user settings (AwayFrom/AwayUntil/AwaySubst); " + ;
                                    "'unavailable' means that user's settings could not be read"
      ENDIF
   ENDIF

   DbSelectArea(nOldSelect)

   hResult["users"] := aUsers
   hResult["count"] := Len(aUsers)
   hResult["status"] := IIF(Len(aUsers) > 0, "found", "not_found")
   IF Len(aUsers) == 0
      hResult["message"] := IIF(nOne > 0, "User " + AllTrim(Str(nOne)) + " not found", "No users found")
   ENDIF
RETURN hResult

// Build the base user row from the buyer record currently positioned at nNum.
STATIC FUNCTION _MCP_UserRow(nNum)
   LOCAL hUser := {=>}
   buy->(DbGoTo(nNum))
   hUser["number"] := nNum
   hUser["name"] := HB_StrToUTF8(AllTrim(buy->Buyer))
   IF ! Empty(buy->Initials)
      hUser["initials"] := HB_StrToUTF8(AllTrim(buy->Initials))
   ENDIF
   IF ! Empty(buy->Short)
      hUser["short"] := HB_StrToUTF8(AllTrim(buy->Short))
   ENDIF
   IF ! Empty(buy->Email)
      hUser["email"] := HB_StrToUTF8(AllTrim(buy->Email))
   ENDIF
   IF ! Empty(buy->Telefon)
      hUser["phone"] := HB_StrToUTF8(AllTrim(buy->Telefon))
   ENDIF
   hUser["active"] := buy->Aktive
RETURN hUser

FUNCTION MCP_Tool_Get_Current_User(hArgs)
   LOCAL hResult := {=>}
   LOCAL nUser
   LOCAL aRoles := {}
   LOCAL nOldSelect := Select()

   // Return schema and description when called without arguments
   IF hArgs == NIL .OR. ValType(hArgs) != "H" .OR. Len(hArgs) == 0
      hResult["schema"] := {;
         "type"=>"object",;
         "properties"=>{=>},;
         "required"=>{};
      }
      hResult["description"] := "Information about the Trader user the current request runs as: number, name, email, " + ;
                                "active flag and roles. With HTTP API-key authentication this reflects " + ;
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

   DbSelectArea(nOldSelect)
   hResult["status"] := "found"
RETURN hResult


STATIC FUNCTION _MCP_RebEventText(cType)
   LOCAL c := AllTrim(cType)
   LOCAL cText := ""
   DO CASE
   CASE c == "RECV"
      cText := "eingegangen"
   CASE c == "SCAN"
      cText := "gescant"
   CASE c == "ARCHIV"
      cText := "archiviert"
   CASE c == "APR"
      cText := "genehmigt"
   CASE c == "STORN"
      cText := "storniert"
   CASE c == "NEW"
      cText := "ersetzt"
   ENDCASE
RETURN cText

FUNCTION MCP_Tool_List_Unposted_Incoming_Invoices(hArgs)
   LOCAL hResult := {=>}
   LOCAL aInv := {}, hInv, aHist, hEv
   LOCAL nLief := 0, nLimit := 200, nCount := 0
   LOCAL lHistory := .F.
   LOCAL nTotal := 0
   LOCAL nOldSelect := Select()

   // Return schema and description when called without arguments
   IF hArgs == NIL .OR. ValType(hArgs) != "H" .OR. Len(hArgs) == 0
      hResult["schema"] := {;
         "type"=>"object",;
         "properties"=>{;
            "supplier_number"=>{"type"=>"number","description"=>"Optional: restrict to one creditor by supplier number (Liefnr)"},;
            "include_history"=>{"type"=>"boolean","description"=>"Also attach the full event log (received/scanned/approved/... with reasons) per invoice (default false)"},;
            "limit"=>{"type"=>"number","description"=>"Maximum number of invoices to return (default 200, max 2000)"};
         };
      }
      hResult["description"] := "List the not-yet-booked invoices in the incoming-invoice journal (Rechnungseingangs" + ;
                                "buch, reb where Status <> 9), each with supplier, document number, amount, received " + ;
                                "date, approval state and its free-text comment (rebnotes). Set include_history for " + ;
                                "the full event log"
      RETURN hResult
   ENDIF

   IF HHasKey(hArgs, "supplier_number") .AND. HB_IsNumeric(hArgs["supplier_number"]) .AND. hArgs["supplier_number"] > 0
      nLief := Int(hArgs["supplier_number"])
   ENDIF
   IF HHasKey(hArgs, "include_history") .AND. HB_IsLogical(hArgs["include_history"])
      lHistory := hArgs["include_history"]
   ENDIF
   IF HHasKey(hArgs, "limit") .AND. HB_IsNumeric(hArgs["limit"]) .AND. hArgs["limit"] > 0
      nLimit := Min(Int(hArgs["limit"]), 2000)
   ENDIF

   NetUse("reb", "reb")
   NetUse("rebprot", "rebp")
   NetUse("rebnotes", "rebn")

   IF nLief > 0
      reb->(DbSetOrder(6))  // Str(Liefnr,6) + Beleg
      reb->(DbSeek(Str(nLief, 6)))
   ELSE
      // Index 4 = Str(Status,1) + Str(ID,9): the unposted rows (Status 0-8)
      // sort before the booked block (Status 9), so the scan stops at the
      // first booked row instead of reading the whole journal.
      reb->(DbSetOrder(4))
      reb->(DbGoTop())
   ENDIF

   DO WHILE ! reb->(Eof()) .AND. nCount < nLimit
      IF nLief > 0
         IF reb->Liefnr != nLief
            EXIT
         ENDIF
      ELSEIF reb->Status == 9  // reached the booked block - nothing unposted beyond it
         EXIT
      ENDIF
      IF reb->Status != 9  // 9 = verbucht (booked); everything else is unposted
         hInv := {=>}
         hInv["id"] := reb->ID
         hInv["document_no"] := HB_StrToUTF8(AllTrim(reb->Beleg))
         IF HB_IsNumeric(reb->Liefnr) .AND. reb->Liefnr != 0
            hInv["supplier_number"] := reb->Liefnr
         ENDIF
         IF ! Empty(reb->Name)
            hInv["supplier_name"] := HB_StrToUTF8(AllTrim(reb->Name))
         ENDIF
         IF HB_IsNumeric(reb->Konto) .AND. reb->Konto != 0
            hInv["account"] := reb->Konto  // creditor account when booked by account, not Liefnr
         ENDIF
         IF HB_IsNumeric(reb->KS)
            IF reb->KS != 0
               hInv["cost_center"] := reb->KS
            ENDIF
         ELSEIF ValType(reb->KS) == "C" .AND. ! Empty(reb->KS)
            hInv["cost_center"] := HB_StrToUTF8(AllTrim(reb->KS))
         ENDIF
         hInv["amount"] := reb->Betrag
         hInv["revision"] := reb->Rev
         hInv["status"] := reb->Status
         hInv["status_text"] := IIF(reb->Status == 8, "approved", "open")  // 8 = genehmigt
         IF ValType(reb->Stapel) == "L"
            hInv["in_batch"] := reb->Stapel  // queued in the booking batch
         ENDIF
         IF HB_IsNumeric(reb->Person)
            IF reb->Person != 0
               hInv["person"] := reb->Person  // buyer id (-1 = automatic)
            ENDIF
         ELSEIF ValType(reb->Person) == "C" .AND. ! Empty(reb->Person)
            hInv["person"] := HB_StrToUTF8(AllTrim(reb->Person))
         ENDIF

         // Received date from the RECV protocol entry (rebp index 2 = ID+Type)
         rebp->(DbSetOrder(2))
         IF rebp->(DbSeek(Str(reb->ID, 9) + "RECV")) .AND. ! Empty(rebp->DateTime)
            hInv["received_date"] := SToD(Left(rebp->DateTime, 8))
         ENDIF

         // Free-text comment (rebnotes, keyed by ID)
         IF rebn->(DbSeek(Str(reb->ID, 9))) .AND. ! Empty(rebn->Notes)
            hInv["comment"] := HB_StrToUTF8(AllTrim(rebn->Notes))
         ENDIF

         // Optional full event log
         IF lHistory
            aHist := {}
            rebp->(DbSetOrder(1))  // by ID (chronological)
            IF rebp->(DbSeek(Str(reb->ID, 9), .T.))
               DO WHILE ! rebp->(Eof()) .AND. rebp->ID == reb->ID
                  hEv := {=>}
                  hEv["type"] := HB_StrToUTF8(AllTrim(rebp->Type))
                  hEv["event"] := HB_StrToUTF8(_MCP_RebEventText(rebp->Type))
                  IF ! Empty(rebp->DateTime)
                     hEv["date"] := SToD(Left(rebp->DateTime, 8))
                  ENDIF
                  IF HB_IsNumeric(rebp->Person)
                     IF rebp->Person != 0
                        hEv["person"] := rebp->Person  // buyer id (-1 = automatic)
                     ENDIF
                  ELSEIF ValType(rebp->Person) == "C" .AND. ! Empty(rebp->Person)
                     hEv["person"] := HB_StrToUTF8(AllTrim(rebp->Person))
                  ENDIF
                  IF ! Empty(rebp->Grund)
                     hEv["reason"] := HB_StrToUTF8(AllTrim(rebp->Grund))
                  ENDIF
                  AAdd(aHist, hEv)
                  rebp->(DbSkip())
               ENDDO
            ENDIF
            hInv["history"] := aHist
         ENDIF

         IF HB_IsNumeric(reb->Betrag)
            nTotal += reb->Betrag
         ENDIF
         AAdd(aInv, hInv)
         nCount++
      ENDIF
      reb->(DbSkip())
   ENDDO

   hResult["truncated"] := nCount >= nLimit .AND. ! reb->(Eof()) .AND. ;
      IIF(nLief > 0, reb->Liefnr == nLief, reb->Status != 9)

   DbSelectArea(nOldSelect)

   hResult["invoices"] := aInv
   hResult["count"] := Len(aInv)
   hResult["total_amount"] := Round(nTotal, 2)
   hResult["status"] := IIF(Len(aInv) > 0, "found", "not_found")
   IF Len(aInv) == 0
      hResult["message"] := "No unposted invoices in the incoming-invoice journal" + ;
         IIF(nLief > 0, " for supplier " + AllTrim(Str(nLief)), "")
   ENDIF
RETURN hResult

// Format a caught error object as "SubSystem/GenCode Description (Operation)"
// for diagnostic messages. Tolerates a non-object break value.
STATIC FUNCTION _MCP_ErrText(oErr)
   IF ! HB_IsObject(oErr)
      RETURN "unknown error"
   ENDIF
RETURN IIF(Empty(oErr:SubSystem), "?", oErr:SubSystem) + "/" + ;
       LTrim(Str(IIF(HB_IsNumeric(oErr:GenCode), oErr:GenCode, 0))) + ;
       IIF(Empty(oErr:Description), "", " " + HB_StrToUTF8(oErr:Description)) + ;
       IIF(Empty(oErr:Operation), "", " (" + HB_StrToUTF8(oErr:Operation) + ")")

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