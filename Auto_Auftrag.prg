/**
 * Auto_Auftrag.prg - Automated Sales Order Processing System
 *
 * This program processes incoming sales orders from email attachments using AI.
 * It extracts order information from emails and PDF attachments, validates it against
 * the customer database, and either identifies matching existing orders or flags
 * new orders for creation.
 *
 * Key features:
 * - Extracts order data from emails and PDF attachments using Claude AI models
 * - Validates customer information against the database
 * - Matches delivery and invoice addresses
 * - Verifies contact persons
 * - Validates order line items (quantity, price, article numbers)
 * - Logs discrepancies between extracted data and existing orders
 * - Caches AI responses as JSON for future reference
 *
 * The program handles rate limiting for the AI API and provides detailed
 * logging of the processing results.
 */

#define CRLF CHR(13)+CHR(10)
#include 'hbcompat.ch'
#translate  LOGRESULT <cErr> => cError += IF(!Empty(cError),Chr(10),"")+<cErr>;Error(<cErr>)
#define debug

PROC Run_Auto_Auftrag
   LOCAL oRest := RestApi():New()
   LOCAL aHeader := {}  
   LOCAL cFile,cData,cPrompt,hData,cText
   LOCAL cResponse,hResponse,cGericht
   LOCAL nAbNr,nItemsMatch,nX
   LOCAL hContact,hContacts
   LOCAL cJsonFile,cVal,nH
   LOCAL aMatchedItems
   LOCAL cType,hAdds
   LOCAL cCompVal,cAddressVal
   LOCAL hAddsTypes := {"delivery_to"=>"Lieferadresse","invoice_to"=>"Rechnungsadresse"}
   LOCAL hAddsFields := {"delivery_to"=>"delad","invoice_to"=>"reliefadr"}
   LOCAL hAddsStdFields := {"delivery_to"=>"StdLiefAdr","invoice_to"=>"ReLiefAdr"}
   LOCAL hAddsNum := {=>}
   LOCAL hContactPerson,lFoundPos
   LOCAL cError,cLog := "ID;Betreff;Kunde;AbNr;Resultat"+CRLF
   //LOCAL cModell := "claude-3-5-sonnet-20241022"
   LOCAL cModell := "claude-3-7-sonnet-20250219"
   //LOCAL cModell := "claude-3-5-haiku-20241022"
   LOCAL nLastRequest
   LOCAL nInputTokensRateLimit := 10000
   LOCAL nInputTokensUsed := 0
   LOCAL lFound,cFileName
   LOCAL lNew,aAng

   LOCAL cDir := "Y:\Dokumente und Einstellungen\Amos\Documents\KI\Test Dokuments\"

   LOCAL nAtt
   LOCAL cNotFileRegex := "^Angebot_.*"

   LOCAL oAccount := DV_GetMailAccount()
   LOCAL oItem,nItem

   //LOCAL oArchive := oAccount:GetArchive("Gruppen/Sales Administration/Bestellungen")
   //LOCAL oArchive := oAccount:GetArchive("Benutzer/Thomas Kînig/Eingang")
   LOCAL oArchive := oAccount:GetArchive("Benutzer/Mara Henzler/Eingang")
   MEMVAR c_one

   IF ! IsDir(cDir+cModell)
      MakeDir(cDir+cModell)
   ENDIF
   cDir += cModell+"\"

   nOneItem := 14
   FOR nItem  := nOneItem TO nOneItem
   //FOR nItem  := 1 TO 50
   oItem := oArchive:MailItems(nItem-1)
   
   CLS
   ? oItem:Subject
   cFileName := oItem:Fields:Item("FileName"):Value
   cFileName := SubStr(cFileName,RAT("\",cFileName)+1)
   //Alert(cFileName)

   cJsonFile := cDir+cFileName+".json"

   IF File(cJsonFile)
      cResponse := FileStr(cJsonFile)      
      lAI := .F.
      //LOOP  //let us ignore these at the moment and only process new ones
   ELSE      
      cText := oItem:BodyText:PlainText
      IF Empty(cText)
         cText := oItem:BodyText:HTMLText
      ENDIF

      oRest:cBaseUrl := "https://api.anthropic.com/v1/"
      Aadd(aHeader,"content-type: application/json")
      Aadd(aHeader,"x-api-key: SCHLUESSEL_ENTFERNT")
      Aadd(aHeader,"anthropic-version: 2023-06-01")

      
      TEXT INTO cPrompt
      You are an AI assistant specialized in extracting and structuring sales order information from emails and attachments.
      Your task is to analyze the following email content and attached sales order, then extract the relevant information into a 
      strictly formatted JSON structure.

      Here is the email content:
      <email_from>
      {{EMAILFROM}}
      </email_from>
      <email_receipt_time>
      {{EMAILTIME}}
      </email_receipt_time>
      <email_subject>
      {{EMAILSUBJECT}}
      </email_subject>
      <email_content>
      {{EMAILCONTENT}}
      </email_content>  
      
      Your goal is to extract all relevant order information and format it according to the specified JSON structure. Please follow
      these instructions carefully:
      
      1. Read and analyze the entire email content and attached sales order information.
      
      2. Extract all relevant order details, including but not limited to:
         - Document type (sales order, sales order change, sales order cancellation, other, question)
         - Sales order type (standard, calloff, or blanket)
         - (Purchase) order number (if there is no attachment return "Email" plus the date in the format DD.MM.YY)
         - Customer ID
         - Order date
         - Blanket order details (if applicable)
         - Currency
         - Additional requirements
         - Contact person details (not Joel Engelking or Mara Henzler, always return an email address ans salutation too)
         - Supplier information (which is always Engelking Elektronik GmbH)
         - Customer information
         - Delivery information
         - Invoice information
         - Item details
      
      3. Pay special attention to the following:
         - Engelking Elektronik GmbH is the seller, not the customer.
         - "Ihre" refers to the seller Engelking Elektronik GmbH.
         - Use the seller's part number (Engelking Elektronik), typically found in the item description. 
         - The customer's internal part number should go into the "customer_part_number" field.
         - The customer number appearing outside the description/table is the number assigned by the customer - use this as "customer_part_number".
         - If invoice address is not given, use the customers address values instead.
         - The company registration number often starts with HRB or HRA. Output the company registration in the format HRB123456.
         - Only return an invoice to email address if it is explicitly given.
      
      4. Format the extracted information into the specified JSON structure.
      
      5. Ensure that all fields are included in the output, even if they are empty (use empty strings or arrays for missing values).
      
      6. Preserve and properly encode German letters (Ñ, î, Å, ·) in the output.
      
      7. Do not add any explanation, notes, or markdown. Return only valid JSON. 
         
      Before providing the final JSON output, wrap your extraction process inside <extraction_process> tags. In this section:
      - List out key information found in the email and sales order.
      - Identify the sales order type and justify your choice.
      - Explicitly note any missing information.
      - Show how you're interpreting the information.
      This will help ensure a thorough and accurate extraction of the data.
     
      
      Here's an example of the required JSON structure:
      
      {
         "document_type": "sales_order|sales_order_change|sales_order_cancellation|other|question",
         "sales_order_type": "standard|calloff|blanket",
         "purchase_order_number": "",
         "customer_id": "",
         "order_date": "",
         "blanket_start_date": "",
         "blanket_end_date": "",
         "blanket_purchase_order_number": "",
         "currency": "",
         "additional_requirements": "",
         "quote_number": "",
         "ordered_as_quoted": false,
         "contact_person": { 
            "salutation": "",
            "firstname": "", 
            "surname": "", 
            "email": "", 
            "phone": "" 
         },
         "invoice_to_email":"",
         "order_confirmation_to_email":"",
         "supplier":{ 
            "name": "Engelking Elektronik GmbH"
         },
         "customer":{ 
            "name": "",
            "address": "",
            "city": "",
            "zip": "",
            "country_iso": "DE",
            "company_registration_no":"",
            "company_registration_court":"",
            "VAT-ID":""
         },
         "delivery_to": {
            "name": "",
            "address": "",
            "city": "",
            "zip": "",
            "country_iso": "DE" 
         },
         "invoice_to": { 
            "name": "",
            "address": "",
            "city": "",
            "zip": "",
            "country_iso": "DE",            
         },
         "items": [
            {
               "item_number": 1,
               "customer_part_number": "",
               "our_part_number": "",
               "manufacturer_part_number": "",
               "our_material_number": "",
               "quantity": 0,
               "call_off_quantity":0,
               "price": 0.0,
               "price_unit": 0,
               "UOM":"",
               "delivery_date": "",
               "blanket_purchase_order_item_number": 0,
               "additional_requirements": "",
               "description": "",
               "total_price_netto": 0.00,
               "total_price_brutto": 0.00
            }
         ]
      }
      
      Please proceed with your extraction process and JSON output based on the provided email content and sales order information.   
      ENDTEXT

      /*
      Before providing the final JSON output, wrap your extraction process inside <extraction_process> tags. In this section:
      - List out key information found in the email and sales order.
      - Identify the sales order type and justify your choice.
      - Explicitly note any missing information.
      - Show how you're interpreting the information.
      This will help ensure a thorough and accurate extraction of the data.
   */

   /*
   <known_part_number_regex>
      CM(?:I)[0-9]{2}\/.{2}\/.{1}\/.{1}\/.{2}\/[0-9]{2}\/[L,M]\/[S,D]\/.{2}
      </known_part_number_regex>

               - Use the known part number regex to identify our part number inside the description field.
   */

      cPrompt := StrTran(cPrompt,"{{EMAILCONTENT}}",cText)
      cPrompt := StrTran(cPrompt,"{{EMAILSUBJECT}}",oItem:Subject)
      cPrompt := StrTran(cPrompt,"{{EMAILTIME}}",TtoS(oItem:StatusTime))
      cPrompt := StrTran(cPrompt,"{{EMAILFROM}}",oItem:From)

      //"model"=>"claude-3-7-sonnet-latest",;
      //"model"=>"claude-3-5-haiku-latest",;
      hData := {;      
         "model"=>cModell,;
         "max_tokens"=>8192,;
         "temperature"=>0.2,;      
         "messages"=>{{;
         "role"=>"user",;
         "content"=>{{;
               "type"=>"text",;
               "text"=>hb_strtoutf8(cPrompt);
         }}};
      }}

      
      FOR nAtt := 0 TO oItem:Attachments:Count-1         
         IF ! HB_RegexMatch(cNotFileRegex,oItem:Attachments:Item(nAtt):FileName,.F.) .AND. HB_RegexMatch(".*\.pdf",oItem:Attachments:Item(nAtt):FileName,.F.)
            
            cFile := CopyAttToTemp(oItem:Attachments:Item(nAtt))
            cData := FileStr(cFile)         
            FErase(cFile)

            AAdd(hData["messages"][1]["content"],;
               {"type"=>"document",;
               "source"=>{;
                     "type"=>"base64",;
                     "media_type"=>"application/pdf",;
                     "data"=>hb_base64encode(cData);
               };
            })      
            
         ENDIF
      NEXT
   
      IF !Empty(nLastRequest) .AND. nLastRequest+60 > Seconds() .AND. nInputTokensUsed+4000 > nInputTokensRateLimit
         ? "Input tokens used: "+LTrim(Str(nInputTokensUsed))
         IF ValType(hResponse) == "H"
            ? "Last Request:",hResponse["usage"]["input_tokens"]            
         ENDIF
         ? "Waiting for tokens to be available"
         nPos := Col()
         DO WHILE nLastRequest+60 > Seconds()
            @ Row(),nPos SAY Pad(Replicate(".",nLastRequest+60-Seconds()),60) 
            Inkey(1,128)
         ENDDO
         nInputTokensUsed := 0
      ELSE
         
      ENDIF

      TxtBox("Processing with AI, please wait...")
      cResponse := oRest:Execute("messages", "POST",hData,aHeader,.T.)
      TxtClear()

      nLastRequest := Seconds()

      IF AT("Bad Gateway",cResponse) != 0
         Alert("Random 502 Error")
         RETURN      
      ENDIF
 
      lAI := .T.
   ENDIF

   
   hResponse := HB_JsonDecode(hb_utf8tostr(cResponse))

   IF hResponse["type"] == "error"
      //Alert(hResponse["message"])
      Alert( "ERROR;"+ValToPrg(hResponse) )
      LOOP
   ENDIF

   IF lAI //first write after we checked for errors
      nH := FCreate(cJsonFile)
      FWrite(nH,cResponse)
      FClose(nH)

      nInputTokensUsed := hResponse["usage"]["input_tokens"]
   ENDIF
   
   IF ! HHasKey(hResponse,"content")
      Alert("No content found in response:"+ValToPRg(hResponse))
      LOOP
   ENDIF

   IF hResponse["stop_reason"] != "end_turn"
      Alert("Response not complete")
      LOOP
   ENDIF


   //? ValToPrg(hResponse)
   cData := hResponse["content"][1]["text"]
   IF (nPos := AT("<extraction_process>",cData)) != 0
      #ifdef debug
         MemoEdit(StrTran(SubStr(cData,nPos+Len("<extraction_process>"),;
            AT("</extraction_process>",cData)-nPos-Len("<extraction_process>")),"\n",CRLF),,,,.F.)
      #endif
      cData := SubStr(cData,AT("</extraction_process>",cData)+Len("</extraction_process>"))
   ENDIF
   hData := HB_JsonDecode(StrTran(StrTran(StrTran(cData,"\n",""),"```json",""),"```",""))
   
   #ifdef debug
      //Alert(cData)
      CLS
      ? ValToPrg(hData)
      Sinkey(0)
   #endif

   cLog += cFileName+";"+oItem:Subject+";"

   IF hData["document_type"] == "question"
      cLog += ";;" //Kein Kunde oder AB
      cLog += "Ist eine Frage / Nachfrage. Diese wird ignoriert kînnte aber auch verteilt werden."+CRLF
      LOOP
   ENDIF

   IF ! hData["document_type"] $ {"sales_order","sales_order_change"}            
      cLog += ";;" //Kein Kunde oder AB
      cLog += "Dokument kann nicht verarbeitet werden, da es ein "+hData["document_type"]+" ist"+CRLF
      LOOP
   ENDIF

   IF HHAsKey(hData,"ordered_as_quoted") .AND. hData["ordered_as_quoted"] .AND. ! Empty(hData["quote_number"]) .AND. Len(hData["items"]) == 0      
      cLog += ";;" //Kein Kunde oder AB
      cLog += "Angebot 1:1 in Auftrag wandeln"+CRLF
      LOOP      
   ENDIF

   NetUse("engkund","ku")
   NetUse("gerichte","ger")
   NetUse("engauf","auf")
   NetUse("artikel","art")
   NetUse("artkund","aku")

   IF ! HHasKey(hData,"customer")
      Alert("No customer found in response")
      RETURN
   ENDIF

   IF ! HHasKey(hData["customer"],"country_iso")      
      cLog += ";;" //Kein Kunde oder AB
      cLog += "Land nicht gefunden"+CRLF
      LOOP      
   /*ELSEIF  hData["customer"]["country_iso"] != "DE"
      cLog += ";;" //Kein Kunde oder AB
      cLog += "Land nicht Deutschland"+CRLF
      LOOP*/
   ENDIF

   cError := ""

   IF At("Engelking Elektronik GmbH",hData["supplier"]["name"]) == 0
      cLog += ";;" //Kein Kunde oder AB
      cLog += "Lieferant nicht Engelking Elektronik GmbH"+CRLF
      #ifdef debug
         Sinkey(0)
      #endif
      LOOP
   ENDIF

   //Look for the company using the registration number and court if available
   lFound := .F.
   IF hData["customer"]["country_iso"] == "DE" .AND. HHasKey(hData["customer"],"company_registration_no") .AND. ! Empty(hData["customer"]["company_registration_no"])  ;
      .AND. HHasKey(hData["customer"],"company_registration_court") .AND. ! Empty(hData["customer"]["company_registration_court"])

      ? "** Gericht **"      
      ? hData["customer"]["company_registration_court"]
      cGericht := AllTrim(StrTran(StrTran(Upper(hData["customer"]["company_registration_court"]),"AMTSGERICHT",""),"AG ",""))
      IF ! ger->(dbSeek( hData["customer"]["country_iso"]+cGericht))
         Select("ger")
         ger->(dbGoTop())
         LOCATE FOR AllTrim(DEUpper(cGericht)) == AllTrim(DEUpper(ger->SimpleName))
      ENDIF

      //if the court was not found, look for the company using the registration number
      IF ger->(Found()) //ger->(dbSeek( hData["customer"]["countryiso"]+Soundex(cGericht)))
         ?? " =",ger->Name

         //Look for a company using the company registration number
         Select("ku")
         ku->(dbGoTop())
         LOCATE FOR Trim(StrTran(ku->compno," ","")) == Trim(StrTran(hData["customer"]["company_registration_no"]," ",""))
         
         IF ! ku->(Found()) //record not found
            ? "Kunde mit Registernummer nicht gefunden"            
         ELSEIF ger->(Found()) .AND. ger->No == ku->Gericht //compare the court, if we found one before
            ? "Kunde mit Registernummer gefunden",ku->CompNo
            lFound := .T.
         ELSE
            ? "Gericht weicht bei "+ku->Kunde+" ab"
         ENDIF
      ENDIF
   ENDIF

   //If the company was not found using the registration number, look for it using the name
   IF ! lFound
      Select("ku")
      ku->(dbSetOrder( 2 ))
      ku->(dbSeek( "K" ))
      //Soundex does not work well, e.g. EMC == Engelking Elektronik GmbH
      //LOCATE FOR Soundex(ku->Name1+ku->Name2) == Soundex(hData["customer"]["name"]) WHILE ku->Group == "K"
      
      LOCATE FOR StandardiseValue(DEUpper(ku->Name1+ku->Name2),"name") == StandardiseValue(DEUpper(hData["customer"]["name"]),"name") .AND. Trim(hData["customer"]["zip"]) == Trim(ku->PLZ) WHILE ku->Group == "K"
      IF ku->(Found())         
         //Alert("Most likely found company: "+ku->Kunde+";"+ValToPrg(ku->Gericht))
      ELSE
         //Alert("Company not found")
         cLog += ";;" //Kein Kunde oder AB
         cLog += "Kunde nicht gefunden: "+hData["customer"]["name"]+CRLF
         ? "Kunde nicht gefunden: "+DEUpper(StrTran(hData["customer"]["name"]," ",""))
         LOOP
      ENDIF
   ENDIF


   ? "** Kunde **"
   cLog += ku->Kunde+";"   
   IF ! CompareValue(hData["customer"]["name"],ku->Name1+ku->Name2,"name")
      LOGRESULT "Kundenname weicht ab (Daten:"+Trim(hData["customer"]["name"])+" Kundenstamm:"+Trim(Trim(ku->Name1)+ku->Name2)+")"
   ELSE
      ? hData["customer"]["name"],"=",ku->Name1+ku->Name2
   ENDIF   
   IF ! CompareValue(hData["customer"]["address"],ku->Street,"address")
      LOGRESULT "Abweichende Stra·e (Daten:"+hData["customer"]["address"]+" Kundenstamm:"+Trim(ku->Street)+")"
   ELSE
      ? hData["customer"]["address"],"=",ku->Street
   ENDIF   
   IF Trim(hData["customer"]["zip"]) != Trim(ku->PLZ)      
      SetColor("R+/W*")
      ?? "*** Zip mismatch ***"
      SetColor(c_one)
      LOGRESULT "Abweichende PLZ (Daten:"+hData["customer"]["zip"]+" Kundenstamm:"+Trim(ku->PLZ)+")"
   ELSE
      ? hData["customer"]["zip"],"=",ku->PLZ
   ENDIF
   IF ! CompareValue(hData["customer"]["city"],ku->TOWN,"city")
      LOGRESULT "Abweichende Stadt (Daten:"+hData["customer"]["city"]+" Kundenstamm:"+Trim(ku->Town)+")"
   ELSE
      ? hData["customer"]["city"],"=",ku->Town
   ENDIF   
   IF ! CompareValue(hData["customer"]["country_iso"],ku->CountryIso,"country_iso")      
      LOGRESULT "Abweichendes Land (Daten:"+hData["customer"]["country_iso"]+" Kundenstamm:"+Trim(ku->CountryIso)+")"
   ELSE
      ? hData["customer"]["country_iso"],"=",ku->CountryIso
   ENDIF

   ? "** Kontaktperson **"
   //Find the contact person if it was set
   hContactPerson := NIL
   IF HHasKey(hData,"contact_person")
      hContacts := GetAddressContacts(.F.,.T.)
      ? "Kontakt Person:",hData["contact_person"]["salutation"],hData["contact_person"]["firstname"],hData["contact_person"]["surname"],"("+hData["contact_person"]["email"]+")"
      FOR nX := 1 TO 3  //first check surname+email, then surname+salutation and first name+email last
         FOR EACH hContact IN hContacts
            IF (AT(hData["contact_person"]["surname"],hContact["name"]) > 0 .OR. (nX == 3 .AND. AT(hData["contact_person"]["firstname"],hContact["name"]) > 0)) .AND.;
               ((nX $ {1,3} .AND. Trim(Lower(hData["contact_person"]["email"])) == Trim(Lower(hContact["email"]))) .OR. ;
               (nX == 2 .AND. AT(hData["contact_person"]["salutation"],hContact["name"]) > 0))
               ?? " =",hContact["name"],"("+hContact["email"]+")"
               hContactPerson := hContact
               IF nX == 2
                  LOGRESULT "Abweichende Email (Daten:"+hData["contact_person"]["email"]+" Kontaktperson:"+Trim(hContact["email"])+")"
               ENDIF
               EXIT
            ELSEif AT(hData["contact_person"]["surname"],hContact["name"]) > 0
               IF nX == 1
                  ? Trim(Lower(hData["contact_person"]["email"])),"!=",Trim(Lower(hContact["email"]))
               ELSE
                  ? "kein",hData["contact_person"]["salutation"]
               ENDIF
            ENDIF
         NEXT
         IF hContactPerson != NIL
            EXIT
         ENDIF
      NEXT
      IF hContactPerson == NIL         
         LOGRESULT "Kontaktperson nicht gefunden und muss neu angelegt werden ("+hData["contact_person"]["firstname"]+" "+hData["contact_person"]["surname"]+" ["+hData["contact_person"]["email"]+"]"+")"         
      ENDIF
   ENDIF

   
   //Find delivery address
   hAdds := {=>}
   nRec := ku->(Recno())
   cKunde := ku->Kunde
   FOR EACH cType IN hAddsTypes
      ? "** "+cType+" **"
      hAdds[cType:__eNumKey()] := .F.
      FOR EACH cVal IN hData[cType:__eNumKey()]
         ? cVal:__eNumKey(),cVal
         IF CompareValue(cVal,hData["customer"][cVal:__eNumKey()],cVal:__enumKey())
            ?? " = "
         ELSE
            ?? " != "
            hAdds[cType:__eNumKey()] := .T.         
         ENDIF
         ?? hData["customer"][cVal:__eNumKey()]
      NEXT   
      hAddsNum[cType:__eNumKey()] := 0
      IF ! hAdds[cType:__eNumKey()]
         ? "=>  "+cType+" ist gleich Kundenadresse"
      ELSE
         
         ? "=> "+cType+" weicht von Kundenadresse ab"
         #ifdef debug
         Sinkey(0)
         #endif
         IF (hAddsNum[cType:__eNumKey()] := FindLieferAdresse(cKunde,hData[cType:__eNumKey()])) == 0
            LOGRESULT cType+" nicht gefunden"
         ENDIF
      
           
      ENDIF
   NEXT
   ku->(dbGoTo(nRec))

   
   IF HHAsKey(hData,"invoice_to_email") .AND. ! Empty(hData["invoice_to_email"])
      ? "** RechnungsempfÑnger **"
      hContact := GetInvoiceContact()
      IF hContact == NIL
         ? "Neuer RechnungsempfÑnger:",hData["invoice_to_email"]
      ELSEIF Lower(hContact["email"]) != Lower(hData["invoice_to_email"])
         LOGRESULT "Abweichender RechnungsempfÑnger: bisher:"+hContact["email"]+" neu:"+hData["invoice_to_email"]         
      ELSE
         ? "öbereinstimmender RechnungsempfÑnger"
      ENDIF
   ENDIF

   ? "*** Artikel ***"
   IF Len(hData["items"]) == 0
      LOGRESULT "Keine Positionen gefunden"
   ENDIF
   /** Artikel suchen ***/
   FOR nX := 1 TO Len(hData["items"])
      IF Empty(hData["items"][nX]["our_part_number"]) .AND. ! Empty(hData["items"][nX]["customer_part_number"])
         hData["items"][nX]["our_part_number"] := hData["items"][nX]["customer_part_number"]
      ENDIF
      hData["items"][nX]["our_part_number"] := hData["items"][nX]["our_part_number"]
      IF Empty(hData["items"][nX]["our_part_number"]) 
         LOGRESULT "Keine eigene Artikelnummer gefunden"
      ELSEIF Empty(hData["items"][nX]["quantity"])
         LOGRESULT "Artikel: "+hData["items"][nX]["our_part_number"]+" hat keine Menge"
      ELSE
         ? "Artikel:",hData["items"][nX]["our_part_number"],"Menge:",hData["items"][nX]["quantity"]
         IF art->(dbSeek( CorrectPartNoErrors(hData["items"][nX]["our_part_number"]) ))
            //Alert("Artikel gefunden: "+art->Matchcode)
         ELSEIF aku->(dbSeek( ku->Kunde+Pad(hData["items"][nX]["customer_part_number"],35) )) //Kundenartikelnummer suchen
            art->(dbSeek( aku->Matchcode ))
         ELSEIF aku->(dbSeek( ku->Kunde , .T. ))
            Select("aku")
            LOCATE FOR aku->Artlief == Pad(hData["items"][nX]["our_part_number"],35) //Kundenartikelnummer suchen
            IF ! aku->(Found()) .AND. ! Empty(hData["items"][nX]["customer_part_number"])
               LOCATE FOR aku->Artlief == Pad(hData["items"][nX]["customer_part_number"],35) //Kundenartikelnummer suchen
            ENDIF
            IF aku->(Found())                     
               art->(dbSeek( aku->Matchcode ))
            ENDIF
         ENDIF
         IF ! art->(Found())
            IF  ! Empty(hData["items"][nX]["customer_part_number"]) .AND. art->(dbSeek( CorrectPartNoErrors(hData["items"][nX]["customer_part_number"]) ))
               //Artikel gefunden
            ELSEIF ! Empty(hData["items"][nX]["our_material_number"]) .AND. art->(dbSeek( CorrectPartNoErrors(hData["items"][nX]["our_material_number"]) ))
               //Artikel gefunden
            ENDIF
         ENDIF
      ENDIF
      IF art->(Found())
         ?? " (Artikelnr.: "+LTrim(Str(art->Artikelnr))+")"
         hData["items"][nX]["artnr"] := art->Artikelnr
      ELSE         
         hData["items"][nX]["artnr"] := 0
         LOGRESULT "Artikel "+Trim(hData["items"][nX]["our_part_number"])+" nicht gefunden"
      ENDIF
   NEXT
   
   ? "*** Auftrag ***"
   //Check if the purchase order has already been loaded
   lNew := .F.
   IF Empty(hData["purchase_order_number"])      
      cLog += ";" //Keine AB
      LOGRESULT "Keine Bestellnummer in den Daten => neuer Auftrag"
      lNew := .T.
   ELSE      
      ? "Bestellnummer:",+hData["purchase_order_number"]
      auf->(dbSetOrder( 12 ))
      
      IF auf->(dbSeek( ku->Kunde+Pad(hData["purchase_order_number"],15)))
         cLog += LTrim(Str(auf->Abnr))+";"
         ? "AB gefunden:",auf->AbNr
         nAbNr := auf->AbNr
         FOR EACH cType IN hAddsTypes
            IF ! hAdds[cType:__enumKey()] .AND. auf->(FieldGet(FieldNum(hAddsFields[cType:__eNumKey()]))) != 0 
               IF auf->(FieldGet(FieldNum(hAddsFields[cType:__eNumKey()]))) != ku->(FieldGet(FieldNum(hAddsStdFields[cType:__eNumKey()])))
                  LOGRESULT "Auftrag hat eine "+cType+", diese wurde aber nicht ausgelesen"
               ENDIF
            ELSEIF hAdds[cType:__enumKey()] .AND. auf->(FieldGet(FieldNum(hAddsFields[cType:__eNumKey()]))) == 0
               LOGRESULT "Auftrag hat keine "+cType+", diese wurde aber ausgelesen"
            ELSEIF hAddsNum[cType:__enumKey()] != auf->(FieldGet(FieldNum(hAddsFields[cType:__eNumKey()])))
               LOGRESULT cType+" stimmt nicht mit Auftrag Åberein"
            ELSE
               ? cType,"=",hAdds[cType:__enumKey()],auf->(FieldGet(FieldNum(hAddsFields[cType:__eNumKey()])))
            ENDIF
         NEXT

         IF (hContactPerson != NIL .AND. auf->Person != hContactPerson["id"]);
             .OR. hContactPerson == NIL .AND. auf->Person != 0            
            LOGRESULT "Kontaktperson weicht ab! (Auftrag:"+Trim(hContacts[auf->Person]["name"])+" ausgelesen: "+IF(hContactPerson==NIL,"keine/nicht gefunden",hContactPerson["name"])+")"
         ENDIF
      

         auf->(dbSetOrder( 15 ))
         
         nItemsMatch := 0
         aMatchedItems := {}
         ? "Positionen:"
         FOR nX := 1 TO Len(hData["items"])
            IF hData["items"][nX]["artnr"] != 0
               lFoundPos := .F.
               IF auf->(dbSeek( Str(nAbnr,6)+art->Matchcode))
                  DO WHILE auf->abnr == nAbNr .AND. auf->Matchcode == art->Matchcode     
                     IF ! auf->Itmnr $ aMatchedItems .AND. Trim(auf->Aufnr) == hData["purchase_order_number"]                  
                        ? "Position:",auf->Itmnr                     
                        IF auf->vkqty == hData["items"][nX]["quantity"]                                    
                           IF auf->vkpr/auf->PE == hData["items"][nX]["price"]/IF(hData["items"][nX]["price_unit"]==0,1,hData["items"][nX]["price_unit"])
                              ?? " Preis:",LTrim(str(auf->vkpr/auf->PE,10,2)),"==",LTrim(Str(hData["items"][nX]["price"],10,2))
                              nItemsMatch++
                           ELSE                                 
                              LOGRESULT "Preisabweichung bei Artikel "+Trim(art->Matchcode)+" mit Menge "+LTrim(Transform(auf->VkQty,Me(art->Me)))+" (Auftrag:"+LTrim(Str(auf->vkpr/auf->PE,10,2))+" ausgelesen: "+LTrim(Str(hData["items"][nX]["price"]/IF(hData["items"][nX]["price_unit"]==0,1,hData["items"][nX]["price_unit"]),10,2))+")"
                           ENDIF
                           
                           AAdd(aMatchedItems,auf->Itmnr)
                           lFoundPos := .T.
                           EXIT
                        ELSE
                           ? " Menge:",Transform(auf->vkqty,Me(art->Me)),"!=",Transform(hData["items"][nX]["quantity"],Me(art->Me))                              
                        ENDIF
                     ENDIF
                     auf->(dbSkip())
                  ENDDO
               ENDIF
               IF ! lFoundPos
                  //Alert("Position nicht gefunden")
                  LOGRESULT "Position mit Artikel  "+Trim(art->Matchcode)+" und Menge "+Transform(hData["items"][nX]["quantity"],Me(art->Me))+" nicht gefunden"
               ENDIF            
            ENDIF            
         NEXT
         IF Len(hData["items"]) == nItemsMatch
            auf->(dbSeek( Str(nAbnr,6) ))
            DO WHILE auf->abnr == nAbNr
               IF ! auf->Itmnr $ aMatchedItems .AND. Trim(auf->Aufnr) == hData["purchase_order_number"]
                  LOGRESULT "Position Nr. "+LTrim(Str(auf->Itmnr))+" Auftrag wurde nicht verarbeitet."
               ENDIF
               auf->(dbSkip())               
            ENDDO
            IF Empty(cError)               
               LOGRESULT "Auftrag bereits vollstÑndig erfasst."
            ENDIF
         ELSE
            //Alert("Not all items match")
         ENDIF
         
      ELSE         
         cLog += ";" //Keine AB
         LOGRESULT "Auftrag nicht gefunden: "+ku->Kunde+Pad(hData["purchase_order_number"],15)+" => neuer Auftrag"
         lNew := .T.
      ENDIF
   ENDIF

   //*** NEUER AUFTRAG ***/
   NetUse("angebot","ang")
   IF lNew
      ? "Neuer Auftrag"
      IF hData["sales_order_type"] == "calloff"  //Abrufauftrag, lass uns diesen suchen
         ? "Abruf aus:",hData["blanket_purchase_order_number"]
         auf->(dbSetOrder( 12 ))
         IF auf->(dbSeek( ku->Kunde+Pad(hData["blanket_purchase_order_number"],15)))
            ?? " AB:",auf->Abnr
         ELSE
            LOGRESULT "Rahmenauftrag nicht gefunden: "+hData["blanket_purchase_order_number"]
         ENDIF
      ENDIF
      ? "Positionen:"
      art->(dbSetOrder( 2 ))
      FOR nX := 1 TO Len(hData["items"])
         IF hData["items"][nX]["artnr"] != 0
            oArtikel := Artikel():New(.F.)
            oArtikel:Load(hData["items"][nX]["artnr"])

            ? oArtikel:Matchcode,hData["items"][nX]["artnr"],hData["items"][nX]["quantity"],hData["items"][nX]["price"]

            //Angebot suchen
            aAng := {}
            aOldAng := {}
            ang->(dbSetOrder( 6 ))            
            //ang->(dbSetFilter({|| ang->Bestat > 0 .AND. ang->Bestat < 3 .AND. ang->VkQty <= hData["items"][nX]["quantity"] .AND. ang->Besda >= Date()-30},"Bestat > 0 .AND. Bestat < 3 .AND. VkQty <= "+LTrim(Str(hData["items"][nX]["quantity"]))+" .AND. Besda >= StoD("+DtoS(Date()-30)+")"))
            ang->(dbSetFilter({|| ang->Bestat > 0 .AND. ang->VkQty <= hData["items"][nX]["quantity"] },"Bestat > 0 .AND. VkQty <= "+LTrim(Str(hData["items"][nX]["quantity"]))))
            ang->(dbSeek( ku->Kunde+oArtikel:Matchcode ))
            DO WHILE ang->Kundma == ku->Kunde .AND. ang->Matchcode == oArtikel:Matchcode .AND. ! ang->(EOF())                              
               IF ang->Bestat < 3 .AND. ang->Besda >= Date()-30
                  Aadd(aAng,{"ANGNR"=>ang->Angnr,"BESDA"=>ang->Besda,"VKPR"=>ang->VkPr/ang->Pe,"STAFFEL"=>ang->Staffel})               
               ELSEIF ang->Staffel != 0 //.AND. ang->Besda >= Date()-365*3
                  Aadd(aOldAng,{"ANGNR"=>ang->Angnr,"BESDA"=>ang->Besda,"PERCENT"=>(ang->VkPr/ang->Pe)/ang->Staffel})
               ENDIF
               ang->(dbSkip())
            ENDDO
            ang->(dbClearFilter())

            ASort(aAng,,,{|x,y| x:Besda <= y:Besda })
            IF Len(aAng) > 0
               ? "Angebotspreis ("+Ltrim(Str(aAng[1]:Angnr))+" "+DtoC(aAng[1]:Besda)+"):",aAng[1]["VKPR"]    
               IF aAng[1]["STAFFEL"] != 0
                  ?? " (Rabatt:",100-aAng[1]:VkPr/aAng[1]:Staffel*100,"%)"
               ENDIF
            ENDIF

            ASort(aOldAng,,,{|x,y| x:Besda <= y:Besda })
            IF Len(aOldAng) > 0
               ? "Rabatt:",100-aOldAng[1]["PERCENT"]*100
            ENDIF

            //Staffelpreis suche
            
            aPrices := oArtikel:GetSellPrices(Date(),ku->Kunde)

            FOR nP := 1 to Len(aPrices)
                IF hData["items"][nX]["quantity"]>=aPrices[nP,1] .AND. (nP == Len(aPrices) .OR. hData["items"][nX]["quantity"] < aPrices[nP+1,1])
                   nPrice := aPrices[nP,2]
                   ? "Staffelpreis",nPrice
                   EXIT
                ENDIF                
             NEXT            
         ENDIF
      NEXT
   ENDIF

   cLog += '"'+cError+'"'+CRLF
   #ifdef debug
      Sinkey(0)
   #endif
   NEXT
   MemoWrit(cDir+"\log_"+Left(TToS(DateTime()),14)+".csv",HB_OemToAnsi(cLog))   
RETURN

STATIC FUNCTION CopyAttToTemp(oAtt)
   LOCAL cTempPath := GetEnv("temp")

   oAtt:CopyOut(cTempPath,oAtt:FileName)

RETURN cTempPath+"\"+oAtt:FileName


STATIC FUNCTION StandardiseValue(cVal,cType)
   LOCAL cRepl,hReplace := {" UND "=>"&"," AND "=>"&","+"=>"&","."=>"","/"=>"","-"=>""}
   Default(@cType,"")
   IF cType == "name"
      hReplace := HB_HCopy({"AKTIENGESELLSCHAFT"=>"AG","LIMITED"=>"LTD"},hReplace)
   ELSEIF cType == "address"
      hReplace := HB_HCopy({"STRASSE"=>"STR","STREET"=>"ST","STRADA"=>"STR"," NR "=>""},hReplace)
   ENDIF
   FOR EACH cRepl IN hReplace
      cVal := StrTran(cVal,cRepl:__eNumKey(),cRepl)
   NEXT
   cVal := StrTran(cVal," ","")
   IF cType == "address"
   ? cVal
   ENDIF
RETURN cVal

STATIC FUNCTION CompareValue(cVal,cVal2,cType)
   LOCAL aTokens,aTokens2
   cVal := DeUpper(cVal)
   cVal2 := DeUpper(cVal2)
   Default(@cType,"")
   IF cType == "city"
      aTokens := HB_ATokens(cVal," ")
      aTokens2 := HB_ATokens(cVal2," ")
      RETURN aTokens[1] $ cVal2 .OR. aTokens2[1] $ cVal
   ELSE
      cVal := StandardiseValue(cVal,cType)
      cVal2 := StandardiseValue(cVal2,cType)
   ENDIF
RETURN cVal == cVal2

STATIC FUNCTION Error(cError)
   MEMVAR c_one
   SetColor("R+/W*")
   ? cError
   SetColor(c_one)
RETURN NIL

STATIC FUNCTION FindLieferAdresse(cKunde,hData)
   LOCAL nFound := 0,nLief,cAddressVal,cVal
   LOCAL aMatches
   LOCAL hKuFields := {"address"=>"street","city"=>"Town","zip"=>"PLZ","country_iso"=>"countryiso"}
   LOCAL nNameOnly := 0
   
   FOR nLief := 1 TO 99  //Max. 99 Adressen
      IF ! ku->(dbSeek( cKunde+GetLieferAddrGroup(nLief) ))
         EXIT
      ELSE
         nFound := nLief
         ? "Adresse:",Ltrim(Str(nLief))
         FOR EACH cVal IN hData
            IF cVal:__eNumKey() == "name"
               cAddressVal := Trim(ku->Name1)+" "+ku->Name2
            ELSE
               cAddressVal := ku->(FieldGet(FieldNum(hKuFields[cVal:__eNumKey()])))   
               IF cVal:__eNumKey() == "zip" .AND. hData["country_iso"] == "DE"
                  aMatches := HB_Regex("([0-9]{5})",cAddressVal)
                  IF Len(aMatches) != 0
                     cVal := aMatches[1]
                  ENDIF
               ENDIF
            ENDIF
            ? cVal:__eNumKey(),cVal
            IF CompareValue(cVal,cAddressVal,cVal:__eNumKey())
               ?? " = "
            ELSE
               ?? " != "
               IF cVal:__eNumKey() == "name"
                  nNameOnly := nLief
               ELSEIF nNameOnly == nLief
                  nNameOnly := 0
               ENDIF
               nFound := 0
            ENDIF
            ?? cAddressVal
         NEXT
         IF nFound != 0
            EXIT
         ENDIF
      ENDIF
   NEXT 
   IF nFound == 0 .AND. nNameOnly != 0
      nFound := nNameOnly
   ENDIF
   
RETURN nFound

STATIC FUNCTION CorrectPartNoErrors(cVal)
   LOCAL hSearchReplace := {"CM1([0-9]{2})/(.*)"=>"CMI$1/$2","C1([0-9]{2})/(.*)"=>"CI$1/$2"}
   LOCAL cRepl,cRegex
   LOCAL nStart,nLen,nMatch,aMatches
   //Remove any blank characters
   cVal := StrTran(cVal," ","")
   //Errors often come from OCR
   FOR EACH cRepl IN hSearchReplace
      cRegex := cRepl:__eNumKey()
      aMatches := HB_Regex(cRegex,cVal,@nStart,@nLen)
      IF Len(aMatches) != 0
         cVal := cRepl
         FOR nMatch := 1 TO Len(aMatches)
            cVal :=  StrTran(cVal,"$"+LTrim(Str(nMatch-1)),aMatches[nMatch])
         NEXT
      ENDIF
   NEXT
   //Pad to 25 characters
   cVal := Pad(cVal,25)
RETURN cVal


/*TEXT INTO cPrompt
   Below is the content of an Email and attached is a sales order.
   Extract the order information in **strict JSON format**. Return all fields even if empty.
   Do not add any explanation, notes, or markdown, return only valid JSON.
   The structure must match the example exactly, with field names and types unchanged.
   Leave missing values as empty strings or arrays. German letters (Ñ, î, Å, ·) must be preserved and encoded properly.
   Engelking Elektronik GmbH is the seller and ***not the customer***.
   Important: - Use the part number of the seller (Engelking Elektronik), which is typically found in the item **description** ? NOT the customer?s internal part number. - If multiple numbers appear in the description or in the table: - The seller's part number is usually the **technical or structured one**, like `NZ/GBS/KLG/140/200/SW/BU` or 'KS12345/10' or 'PX0587'. - The **shorter or simpler number** (e.g. `210137`) is typically the customer's internal part number ? this should go into `customer_part_number`. If multiple values appear in the same column (e.g., Art.-Nr.) but on separate lines, treat them as one combined value. For example, combine CMI35ASFRG and N24LS28 into CMI35ASFRGN24LS28 for the customer_part_number field. - The customer number appearing **outside the description/table** is the number assigned **by** the customer ? use this as `customer_id`. - Ignore customer item numbers. - If invoice address is not given, use the **delivery address** values instead.
   The company registration number ofen starts with HRB or HRA.
   ------- JSON structure --------
   {
      "document_type": "sales_order",
      "sales_order_type": "standard|calloff|blanket",
      "purchase_order_number": "12345",
      "customer_id": "67890",
      "order_date": "2023-10-01",
      "blanket_start_date": "2023-10-01",
      "blanket_end_date": "2024-10-01",
      "blanket_purchase_order_number": "12345",
      "currency": "EUR",
      "additional_requirements": "Please deliver before 10:00 AM",
      "contact_person": { 
         "firstname": "John", 
         "surname": "Doe", 
         "email": "john.doe@example.com", 
         "phone": "1234567890" 
      },
      "customer":{ 
         "name": "ACME Inc.",
         "address": "123 Main St.",
         "city": "Anytown",
         "zip": "12345",
         "country_iso": "US" ,
         "company_registration_no":"HRB1234",
         "company_registration_court":"Frankfurt"
      },
      "delivery_to": {
         "name": "John Doe Production Site",
         "address": "456 Elm St.",
         "city": "Anytown",
         "zip": "12345",
         "country_iso": "US" 
      },
      "invoice_to": { 
         "name": "John Doe Billing Address",
         "address": "789 Oak St.",
         "city": "Anytown",
         "zip": "12345",
         "country_iso": "US"
      },
      "items": [
         {
            "item_number": 1,
            "part_number": "12345",
            "customer_part_number": "",
            "quantity": 10,
            "price": 10.0,
            "price_unit": 100,
            "UOM":"PCS",
            "delivery_date": "2023-10-01",
            "blanket_purchase_order_item_number": 1,
            "additional_requirements": "",
            "description": "Steel flange ù20, galvanized",
            "total_price_netto": 100.00,
            "total_price_brutto": 119.00
         }
      ]
   }
   ----- EMAIL CONTENT --------
   This is the content of the email. It may contain additional information or context related to the sales order.
   -----------------------------
      ENDTEXT*/

   