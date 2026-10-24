/**
 * AIService Class
 * Handles interactions with the Claude AI API
 */

//#include 'hbcompat.ch'
#includ 'hbclass.ch'
//#include 'auto_auftrag.ch'

CLASS AIService

   METHOD New()
   METHOD ProcessEmail(oItem, cNotFileRegex)
   METHOD ParseResponse(cResponse)

   VAR cPromptFile INIT "sales_order_prompt.txt"
   VAR cModell INIT "claude-3-7-sonnet-20250219"

   PROTECTED:
      VAR oRest
      VAR aHeader
      
      VAR nLastRequest
      VAR nInputTokensRateLimit
      VAR nInputTokensUsed
      
   PROTECTED:
      METHOD GeneratePrompt(oItem)
      METHOD HandleRateLimiting(hResponse)
      METHOD ExtractAttachments(oItem, cNotFileRegex, hData)
ENDCLASS

METHOD New() CLASS AIService
   ::oRest := RestApi():New()
   ::aHeader := {}
   
   ::nInputTokensRateLimit := 10000
   ::nInputTokensUsed := 0
   
   // Initialize API headers
   Aadd(::aHeader, "content-type: application/json")
   Aadd(::aHeader, "x-api-key: $APIKEY$")
   Aadd(::aHeader, "anthropic-version: 2023-06-01")
   
   ::oRest:cBaseUrl := "https://api.anthropic.com/v1/"
   ::oRest:cApiKeyName := "ANTHROPIC"
   
RETURN Self

METHOD ProcessEmail(oItem, cNotFileRegex) CLASS AIService
   LOCAL cPrompt, hData, cResponse

   cPrompt := ::GeneratePrompt(oItem)
   IF cPrompt == NIL
      RETURN NIL
   ENDIF
   
   // Prepare request data
   hData := {;      
      "model"=>::cModell,;
      "max_tokens"=>8192,;
      "temperature"=>0.2,;      
      "messages"=>{{;
         "role"=>"user",;
         "content"=>{{;
            "type"=>"text",;
            "text"=>hb_strtoutf8(cPrompt);
         }}};
      }}
   
   // Add attachments
   ::ExtractAttachments(oItem, cNotFileRegex, @hData)
   
   // Handle rate limiting
   ::HandleRateLimiting()
   
   // Execute API call
   TxtBox("Processing with AI, please wait...")
   cResponse := ::oRest:Execute("messages", "POST", hData, ::aHeader, .T.)
   TxtClear()
   
   ::nLastRequest := Seconds()
   
   // Check for errors
   IF AT("Bad Gateway", cResponse) != 0
      Alert("Random 502 Error")
      RETURN NIL
   ENDIF
   
RETURN cResponse

METHOD ParseResponse(cResponse) CLASS AIService
   LOCAL hResponse, cData, aData, nPos
   
   hResponse := HB_JsonDecode(hb_utf8tostr(cResponse))
   
   IF hResponse["type"] == "error"
      Alert("ERROR;" + ValToPrg(hResponse))
      RETURN NIL
   ENDIF
   
   IF !HHasKey(hResponse, "content")
      Alert("No content found in response:" + ValToPRg(hResponse))
      RETURN NIL
   ENDIF
   
   IF hResponse["stop_reason"] != "end_turn"
      Alert("Response not complete")
      RETURN NIL
   ENDIF
   
   // Update token usage for rate limiting
   IF HHasKey(hResponse, "usage") .AND. HHasKey(hResponse["usage"], "input_tokens")
      ::nInputTokensUsed := hResponse["usage"]["input_tokens"]
   ENDIF
   
   // Extract JSON data
   cData := hResponse["content"][1]["text"]
   IF (nPos := AT("<extraction_process>", cData)) != 0
      #ifdef DEBUG
         MemoEdit(StrTran(SubStr(cData, nPos+Len("<extraction_process>"), ;
            AT("</extraction_process>", cData)-nPos-Len("<extraction_process>")), "\n", CRLF), , , , .F.)
      #endif
      cData := SubStr(cData, AT("</extraction_process>", cData)+Len("</extraction_process>"))
   ENDIF
   
   // Parse JSON
   aData := HB_JsonDecode(StrTran(StrTran(StrTran(cData, "\n", ""), "```json", ""), "```", ""))

   IF ValType(aData) != "A"
      aData := {aData}
   ENDIF
   
   #ifdef DEBUG
      MemoEdit(JsonEncodeFormatted(aData),,,,.F.)
      //CLS
      //? ValToPrg(hData)
      //Sinkey(0)
   #endif
   
RETURN aData

METHOD GeneratePrompt(oItem) CLASS AIService
   LOCAL cPrompt,cText

   // Get email text
   cText := oItem:BodyText:PlainText
   IF Empty(cText)
      cText := oItem:BodyText:HTMLText
   ENDIF
   
   // Generate prompt
   cPrompt := FileStr(Path("run\docprocessing\"+::cPromptFile))
   IF Empty(cPrompt)
      Alert("Prompt file not found: "+::cPromptFile)
      RETURN NIL
   ENDIF
   cPrompt := StrTran(cPrompt, "{{EMAILCONTENT}}", cText)
   cPrompt := StrTran(cPrompt, "{{EMAILSUBJECT}}", oItem:Subject)
   cPrompt := StrTran(cPrompt, "{{EMAILTIME}}", TtoS(oItem:StatusTime))
   cPrompt := StrTran(cPrompt, "{{EMAILFROM}}", oItem:From)
   
RETURN cPrompt

METHOD ExtractAttachments(oItem, cNotFileRegex, hData) CLASS AIService
   LOCAL nAtt, cFile, cData
   
   FOR nAtt := 0 TO oItem:Attachments:Count-1
      IF ! HB_RegexMatch(cNotFileRegex, oItem:Attachments:Item(nAtt):FileName, .F.) .AND. ;
         HB_RegexMatch(".*\.pdf", oItem:Attachments:Item(nAtt):FileName, .F.)
         
         cFile := CopyAttToTemp(oItem:Attachments:Item(nAtt))
         cData := FileStr(cFile)
         FErase(cFile)

         AAdd(hData["messages"][1]["content"], ;
            {"type"=>"document", ;
            "source"=> {;
                  "type"=>"base64", ;
                  "media_type"=>"application/pdf", ;
                  "data"=>hb_base64encode(cData);
            };
         })
      ENDIF
   NEXT
RETURN NIL

METHOD HandleRateLimiting(hResponse) CLASS AIService
   // Check if we need to wait for rate limiting
   IF !Empty(::nLastRequest) .AND. ::nLastRequest+60 > Seconds() .AND. ::nInputTokensUsed+4000 > ::nInputTokensRateLimit
      ? "Input tokens used: " + LTrim(Str(::nInputTokensUsed))
      
      IF ValType(hResponse) == "H"
         ? "Last Request:", hResponse["usage"]["input_tokens"]
      ENDIF
      
      ? "Waiting for tokens to be available"
      nPos := Col()
      
      DO WHILE ::nLastRequest+60 > Seconds()
         @ Row(), nPos SAY Pad(Replicate(".", ::nLastRequest+60-Seconds()), 60) 
         Inkey(1, 128)
      ENDDO
      
      ::nInputTokensUsed := 0
   ENDIF
RETURN NIL