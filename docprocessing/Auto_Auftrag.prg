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

#translate  LOGRESULT <cErr> => hLog\["Ergebniss"\] += IF(!Empty(hLog\["Ergebniss"\]),Chr(10),"")+<cErr>;Error(<cErr>)
#translate   MANUELL <manuell> => hLog\["Manueller Eingriff"\] += IF(!<manuell>$hLog\["Manueller Eingriff"\],<manuell>,"")
#define DEBUG

PROC Run_Auto_Auftrag(cMsgID)
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
   LOCAL cError := "",cLog := "ID;Betreff;Kunde;Person;Lieferadresse;Rechnungsadresse;AbNr;Artikel|Menge|Preis|PE;Resultat"+CRLF
   LOCAL aLog := {},hLog
   //LOCAL cModell := "claude-3-5-sonnet-20241022"
   LOCAL cModell := "claude-3-7-sonnet-20250219"
   //LOCAL cModell := "claude-3-5-haiku-20241022"
   LOCAL nLastRequest
   LOCAL nInputTokensRateLimit := 10000
   LOCAL nInputTokensUsed := 0
   LOCAL lFound,cFileName
   LOCAL lNew,aAng
   LOCAL nEmailsProcessed := 0
   LOCAL hDocuments
   LOCAL oAIService,oDataValidator

   LOCAL cDir := "Y:\Dokumente und Einstellungen\Amos\Documents\KI\Test Dokuments\"

   LOCAL nAtt
   LOCAL cNotFileRegex := "^Angebot_.*"

   LOCAL oAccount := DV_GetMailAccount()
   LOCAL oItem,nItem

   LOCAL oArchive //:= oAccount:GetArchive("Gruppen/Sales Administration/Bestellungen")
   LOCAL cArchive
   //LOCAL oArchive := oAccount:GetArchive("Benutzer/Thomas Kînig/Eingang")
   //LOCAL oArchive := oAccount:GetArchive("Benutzer/Mara Henzler/Eingang")
   //LOCAL oArchive := oAccount:GetArchive("Benutzer/Sabid Pehlic/Eingang")
   MEMVAR c_one

   IF ! IsDir(cDir+cModell)
      MakeDir(cDir+cModell)
   ENDIF
   cDir += cModell+"\"

   cArchive := SubStr(cMsgId,1,RAT("\",cMsgId)-1)
   oArchive := oAccount:GetArchive(cArchive)
   oItem := oArchive:GetArchiveEntryById(cMsgId)      

   nItem := -1
//find the MailItem (cannot use GetArchiveEntryById because it does not return a MailItem Object)
DO WHILE (oItem := oArchive:MailItems(++nItem)) != NIL .AND. oItem:Fields:Item("FileName"):Value != cMsgID
   //? oItem:Subject,oItem:_ID
ENDDO
   //Alert(ValToPrg(oItem:Fields:Item("JobID"):Value))

   DO WHILE .T.
   nOneItem := 1
   FOR nItem  := nOneItem TO nOneItem
   //FOR nItem  := 1 TO 100
   //oItem := oArchive:MailItems(nItem-1)

   SetColor(c_one)
   CLS
   ? oItem:Subject
   cFileName := oItem:Fields:Item("FileName"):Value
   cFileName := SubStr(cFileName,RAT("\",cFileName)+1)

   cJsonFile := cDir+cFileName+".json"

   oAIService := AIService():New()
   

   IF File(cJsonFile)
      cResponse := FileStr(cJsonFile)      
      lAI := .F.
      /*IF Inkey(10) == 27
         EXIT
      ENDIF
      LOOP  //let us ignore these at the moment and only process new ones
      */
   ELSE     
      
      cResponse := oAIService:ProcessEmail(oItem,cNotFileRegex)
      IF cResponse == NIL
         LOOP
      ENDIF
       
      lAI := .T.
   ENDIF

   hDocuments := oAIService:ParseResponse(cResponse)
   IF hDocuments == NIL
      RETURN
   ENDIF

   IF lAI //first write after we checked for errors
      nH := FCreate(cJsonFile)
      FWrite(nH,cResponse)
      FClose(nH)
   ENDIF
   
   #ifdef DEBUG
      CLS
      ? "Email enthÑlt",Len(hDocuments),"Dokument(e)"        
   #endif


   nEmailsProcessed++
   FOR EACH hData IN hDocuments
   
   hLog := {=>}
   hLog["ID"] := cFileName
   hLog["Betreff"] := oItem:Subject
   hLog["Ergebniss"] := ""
   hLog["Manueller Eingriff"] := ""

   IF hData["document_type"] == "question"
      LOGRESULT "Ist eine Frage / Nachfrage => An Ansprechpartner verteilen."+CRLF
      #ifdef DEBUG
         Sinkey(0)
      #endif
   
      Aadd(aLog,hLog)
      LOOP
   ENDIF

   IF ! hData["document_type"] $ {"sales_order","sales_order_change"}            
      LOGRESULT "Dokument kann nicht verarbeitet werden, da es ein "+hData["document_type"]+" ist"+CRLF      
      #ifdef DEBUG
         Sinkey(0)
      #endif
   
      Aadd(aLog,hLog)
      LOOP
   ENDIF

   IF HHAsKey(hData,"ordered_as_quoted") .AND. hData["ordered_as_quoted"] .AND. ! Empty(hData["quote_number"]) .AND. Len(hData["items"]) == 0            
      LOGRESULT "Angebot 1:1 in Auftrag wandeln"+CRLF
      #ifdef DEBUG
         Sinkey(0)
      #endif
   
      Aadd(aLog,hLog)
      LOOP      
   ENDIF

   oDataValidator := DataValidator():New(hData)

   NetUse("engauf","auf")
   NetUse("artikel","art")
   NetUse("artkund","aku")

   IF ! oDataValidator:MatchCustomer()
      LOGRESULT "Kunde nicht gefunden: "+hData["customer"]["name"]
      LOGRESULT oDataValidator:GetErrors()

      MANUELL "Kunde"
      DO WHILE .T.
         cKunde := Space(8)
         cKunde := GetBox(cKunde,"Kunde","@!")
         IF LastKey() == 27
            EXIT
         ENDIF
         ku->(dbSetOrder( 1 ))
         IF ku->(dbSeek(cKunde+"K"))
            EXIT
         ENDIF
      ENDDO
      
      Aadd(aLog,hLog)
      #ifdef DEBUG
         Sinkey(0)
      #endif
      IF LastKey() == 27
         LOOP
      ENDIF
   ENDIF

   

   hLog["Kunde"] := ku->Kunde

   IF ! oDataValidator:ValidateCustomer()
      
      LOGRESULT "Kunde stimmt nicht Åberein"
      LOGRESULT oDataValidator:GetErrors()

      MANUELL "Kunde"
      
      Aadd(aLog,hLog)
      #ifdef DEBUG
         Sinkey(0)
      #endif
      LOOP
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
         hLog["Person"] := "NEU"
         LOGRESULT "Kontaktperson nicht gefunden und muss neu angelegt werden ("+hData["contact_person"]["firstname"]+" "+hData["contact_person"]["surname"]+" ["+hData["contact_person"]["email"]+"]"+")"         
      ELSE
         hLog["Person"] := hContactPerson["name"]
      ENDIF
   ELSE
      hLog["Person"] := "KEINE"
   ENDIF
   
   nRec := ku->(Recno())
   
   oDataValidator:MatchDeliveryAddresses()
   FOR EACH cType IN hAddsTypes
      IF oDataValidator:hAddsNum[cType:__enumKey()] == -1
         LOGRESULT cType+" nicht gefunden"  
      ENDIF
      hLog[cType] := oDataValidator:hAddsNum[cType:__enumKey()]
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
      IF ! hData["items"][nX]["is_shipping_cost"]
         IF Empty(hData["items"][nX]["our_part_number"]) .AND. ! Empty(hData["items"][nX]["customer_part_number"])
            hData["items"][nX]["our_part_number"] := hData["items"][nX]["customer_part_number"]
         ENDIF
         hData["items"][nX]["our_part_number"] := hData["items"][nX]["our_part_number"]
         IF Empty(hData["items"][nX]["our_part_number"]) 
            LOGRESULT "Keine eigene Artikelnummer gefunden"
         ELSEIF Empty(hData["items"][nX]["quantity"])
            LOGRESULT "Artikel: "+hData["items"][nX]["our_part_number"]+" hat keine Menge"
         ELSE
            ? "Artikel:",hData["items"][nX]["our_part_number"],"("+hData["items"][nX]["customer_part_number"]+")","Menge:",hData["items"][nX]["quantity"]
            IF art->(dbSeek( CorrectPartNoErrors(hData["items"][nX]["our_part_number"]) ))
               //Alert("Artikel gefunden: "+art->Matchcode)
            ELSEIF ! Empty(hData["items"][nX]["customer_part_number"]) .AND. art->(dbSeek( Pad(hData["items"][nX]["customer_part_number"],25) )) //Kundenartikelnummer suchen
            ELSEIF ! Empty(hData["items"][nX]["manufacturer_part_number"]) .AND. art->(dbSeek( Pad(hData["items"][nX]["manufacturer_part_number"],25) )) //Kundenartikelnummer suchen
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

            IF Round(hData["items"][nX]["price"]/IF(hData["items"][nX]["price_unit"]==0,1,hData["items"][nX]["price_unit"]),2) != Round(hData["items"][nX]["total_price_netto"]/hData["items"][nX]["quantity"],2)
               LOGRESULT Trim(oArtikel:Matchcode)+" Preiseinheit vermutlich falsch ausgelesen: "+LTrim(Str(hData["items"][nX]["price_unit"]))+" korrekt: "+LTrim(Str(hData["items"][nX]["price"]/(hData["items"][nX]["total_price_netto"]/hData["items"][nX]["quantity"]),12,0))
               hData["items"][nX]["price_unit"] := Round(hData["items"][nX]["price"]/(hData["items"][nX]["total_price_netto"]/hData["items"][nX]["quantity"]),0)
               ? ""
               #ifdef DEBUG
               Sinkey(0)
               #endif
            ENDIF
         ELSE         
            hData["items"][nX]["artnr"] := 0
            LOGRESULT "Artikel "+Trim(hData["items"][nX]["our_part_number"])+" nicht gefunden"
            MANUELL "Artikel"
         ENDIF
      ELSE
         hData["items"][nX]["artnr"] := 0
         LOGRESULT "Artikel "+Trim(hData["items"][nX]["our_part_number"])+" als Versandkosten erkannt"
      ENDIF
   NEXT
   
   ? "*** Auftrag ***"
   //Check if the purchase order has already been loaded
   lNew := .F.
   IF Empty(hData["purchase_order_number"])
      LOGRESULT "Keine Bestellnummer in den Daten => neuer Auftrag"
      lNew := .T.
   ELSE      
      ? "Bestellnummer:",+hData["purchase_order_number"]
      auf->(dbSetOrder( 12 ))
      
      IF auf->(dbSeek( ku->Kunde+Pad(hData["purchase_order_number"],15)))
         hLog["AB-Nr"] := LTrim(Str(auf->Abnr))
         ? "AB gefunden:",auf->AbNr
         nAbNr := auf->AbNr
         FOR EACH cType IN hAddsTypes
            IF ! oDataValidator:hHasAdd[cType:__enumKey()] .AND. auf->(FieldGet(FieldNum(hAddsFields[cType:__eNumKey()]))) != 0 
               IF auf->(FieldGet(FieldNum(hAddsFields[cType:__eNumKey()]))) != ku->(FieldGet(FieldNum(hAddsStdFields[cType:__eNumKey()])))
                  LOGRESULT "Auftrag hat eine "+cType+", diese wurde aber nicht ausgelesen"
               ENDIF
            ELSEIF oDataValidator:hHasAdd[cType:__enumKey()] .AND. auf->(FieldGet(FieldNum(hAddsFields[cType:__eNumKey()]))) == 0
               LOGRESULT "Auftrag hat keine "+cType+", diese wurde aber ausgelesen"
            ELSEIF oDataValidator:hAddsNum[cType:__enumKey()] != auf->(FieldGet(FieldNum(hAddsFields[cType:__eNumKey()])))
               LOGRESULT cType+" stimmt nicht mit Auftrag Åberein"
            ELSE
               ? cType,"=",oDataValidator:hHasAdd[cType:__enumKey()],auf->(FieldGet(FieldNum(hAddsFields[cType:__eNumKey()])))
            ENDIF
         NEXT

         IF (hContactPerson != NIL .AND. auf->Person != hContactPerson["id"]);
             .OR. hContactPerson == NIL .AND. auf->Person != 0            
            LOGRESULT "Kontaktperson weicht ab! (Auftrag:"+Trim(hContacts[auf->Person]["name"])+" ausgelesen: "+IF(hContactPerson==NIL,"keine/nicht gefunden",hContactPerson["name"])+")"
         ENDIF
      

         auf->(dbSetOrder( 15 ))
         art->(dbSetOrder( 2 ))
         
         nItemsMatch := 0
         aMatchedItems := {}
         ? "Positionen:"
         FOR nX := 1 TO Len(hData["items"])
            IF hData["items"][nX]["artnr"] != 0
               lFoundPos := .F.
               art->(dbSeek( Str(hData["items"][nX]["artnr"],6) ))

               IF auf->(dbSeek( Str(nAbnr,6)+art->Matchcode))
                  ? "Artikel:",art->Matchcode,"Menge:",Transform(hData["items"][nX]["quantity"],Me(art->Me)),auf->Aufnr
                  DO WHILE auf->abnr == nAbNr .AND. auf->Matchcode == art->Matchcode     
                     IF ! auf->Itmnr $ aMatchedItems .AND. Trim(auf->Aufnr) == hData["purchase_order_number"]                  
                        ? "Position:",auf->Itmnr                     
                        IF auf->vkqty == hData["items"][nX]["quantity"]      
                           IF auf->vkpr/auf->PE == hData["items"][nX]["price"]/IF(hData["items"][nX]["price_unit"]==0,1,hData["items"][nX]["price_unit"])
                              ?? " Preis:",LTrim(str(auf->vkpr/auf->PE,10,2)),"==",LTrim(Str(hData["items"][nX]["price"]/IF(hData["items"][nX]["price_unit"]==0,1,hData["items"][nX]["price_unit"]),10,2))
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
//                  Alert("Position nicht gefunden")
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
         LOGRESULT "Auftrag nicht gefunden: "+ku->Kunde+Pad(hData["purchase_order_number"],15)+" => neuer Auftrag"
         lNew := .T.
      ENDIF
   ENDIF

   //temporarily set all to new for test purposes
   lNew := .T.

   //*** NEUER AUFTRAG ***/
   NetUse("angebot","ang")
   IF lNew
      ? "Neuer Auftrag"

      //Check if the customer has a blanket order
      nRahmen := 0
      
      IF hData["sales_order_type"] == "calloff"  //Abrufauftrag, lass uns diesen suchen
         ? "Abruf aus:",hData["blanket_purchase_order_number"]
         auf->(dbSetOrder( 12 ))
         auf->(dbSetFilter({|| auf->Bestat < 3 .AND. Right(Str(auf->DTerm,4),2) == "99" .AND. auf->VkQty >= hData["items"][1]["quantity"] },"Bestat < 3 .AND. Right(Str(DTerm,4),2) == '99' .AND. VkQty >= "+LTrim(Str(hData["items"][1]["quantity"]))))
         IF auf->(dbSeek( ku->Kunde+Pad(hData["blanket_purchase_order_number"],15)))
            ?? " AB:",auf->Abnr
            nRahmen := auf->Abnr
            hLog["Rahmen"] := auf->Abnr
         ELSE
            LOGRESULT "Offener Rahmenauftrag nicht gefunden: "+hData["blanket_purchase_order_number"]
         ENDIF
         auf->(dbClearFilter())
      ENDIF

      ? "Positionen:"
      art->(dbSetOrder( 2 ))
      hLog["Artikel"] := ""
      FOR nX := 1 TO Len(hData["items"])
         IF hData["items"][nX]["artnr"] != 0
            oArtikel := Artikel():New(.F.)
            oArtikel:Load(hData["items"][nX]["artnr"])

            ? oArtikel:Matchcode,hData["items"][nX]["artnr"],hData["items"][nX]["quantity"],hData["items"][nX]["price"]
            hLog["Artikel"] += Trim(oArtikel:Matchcode)+"|"+LTrim(Str(hData["items"][nX]["quantity"]))+"|"

            //Rahmenvertrag suchen, falls vom Kunden nicht angegeben
            nRahmenPos := 0
            IF hData["sales_order_type"] != "calloff"
               auf->(dbSetFilter({|| auf->Bestat < 3 .AND. Right(Str(auf->DTerm,4),2) == "99" .AND. auf->VkQty >= hData["items"][1]["quantity"]},"Bestat < 3 .AND. Right(Str(DTerm,4),2) == '99' .AND. VkQty >= "+LTrim(Str(hData["items"][1]["quantity"]))))
               auf->(dbSetOrder( 6 )) //Kundma+Matchcode
               IF auf->(dbSeek( ku->Kunde+oArtikel:Matchcode ))
                  nRahmen := auf->Abnr
                  nRahmenPos := auf->Itmnr
                  LOGRESULT "Rahmenauftrag gefunden: "+LTrim(Str(auf->Abnr))+"/"+Ltrim(str(nRahmenPos))+" ("+DtoC(auf->Besda)+") (nicht angegeben)"
                  #ifdef DEBUG
                  Sinkey(0)
                  #endif
               ELSE
                  #ifdef DEBUG
                  ? "Kein Rahmevertrag gefunden"
                  #endif
               ENDIF               
               auf->(dbClearFilter())
            ELSEIF nRahmen != 0  //Rahmen wurde angegeben nur die Position suchen
               auf->(dbSetFilter({|| auf->Bestat < 3 .AND. Right(Str(auf->DTerm,4),2) == "99" .AND. auf->VkQty >= hData["items"][1]["quantity"]},"Bestat < 3 .AND. Right(Str(DTerm,4),2) == '99' .AND. VkQty >= "+LTrim(Str(hData["items"][1]["quantity"]))))
               auf->(dbSetOrder( 6 )) //Kundma+Matchcode
               IF auf->(dbSeek( Str(nRahmen,6)+art->Matchcode ))
                  nRahmenPos := auf->Itmnr
                  ? "Rahmenposition gefunden:",auf->Itmnr,"("+DtoC(auf->Besda)+")"
               ELSE                  
                  LOGRESULT "Rahmenposition nicht gefunden: "+art->Matchcode
               ENDIF
            ENDIF

            lPriceOk := .F.

            //Rahmenpreis prÅfen
            IF nRahmen != 0 .AND. nRahmenPos != 0
               auf->(dbSetOrder( 1 )) //AbNr+ItmNr
               IF auf->(dbSeek( Str(nRahmen,6)+Str(nRahmenPos,3) ))
                  ? "Rahmenpreis:",LTrim(Str(auf->VkPr/auf->Pe,10,2))
                  IF auf->VkPr/auf->Pe == hData["items"][nX]["price"]/IF(hData["items"][nX]["price_unit"]==0,1,hData["items"][nX]["price_unit"])
                     ?? " Preis akzeptiert!"
                     lPriceOk := .T.
                  ELSE
                     LOGRESULT "Preisabweichung bei Artikel "+Trim(oArtikel:Matchcode)+" mit Menge "+Transform(hData["items"][nX]["quantity"],Me(oArtikel:Me))+" (Rahmenpreis:"+LTrim(Str(auf->VkPr/auf->Pe,10,2))+" ausgelesen: "+LTrim(Str(hData["items"][nX]["price"]/IF(hData["items"][nX]["price_unit"]==0,1,hData["items"][nX]["price_unit"]),10,2))+")"
                  ENDIF
               ELSE
                  LOGRESULT "Rahmenpreis nicht gefunden: "+ku->Kunde+Pad(hData["purchase_order_number"],15)+" (Rahmenvertrag)"
               ENDIF
            ELSE
               //Angebot suchen
               aAng := {}
               aOldAng := {}
               ang->(dbSetOrder( 6 ))            
               //ang->(dbSetFilter({|| ang->Bestat > 0 .AND. ang->Bestat < 3 .AND. ang->VkQty <= hData["items"][nX]["quantity"] .AND. ang->Besda >= Date()-30},"Bestat > 0 .AND. Bestat < 3 .AND. VkQty <= "+LTrim(Str(hData["items"][nX]["quantity"]))+" .AND. Besda >= StoD("+DtoS(Date()-30)+")"))
               ang->(dbSetFilter({|| ang->Bestat <= 3 .AND. ang->VkQty <= hData["items"][nX]["quantity"] },"Bestat <= 3 .AND. VkQty <= "+LTrim(Str(hData["items"][nX]["quantity"]))))
               ang->(dbSeek( ku->Kunde+oArtikel:Matchcode ))
               DO WHILE ang->Kundma == ku->Kunde .AND. ang->Matchcode == oArtikel:Matchcode .AND. ! ang->(EOF())                          
                  IF ang->Besda >= Date()-30
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
                  IF aAng[1]["VKPR"] == hData["items"][nX]["price"]/IF(hData["items"][nX]["price_unit"]==0,1,hData["items"][nX]["price_unit"])
                     ?? " Preis akzeptiert!"
                     lPriceOk := .T.
                  ELSE
                     LOGRESULT "Preisabweichung bei Artikel "+Trim(oArtikel:Matchcode)+" mit Menge "+Transform(hData["items"][nX]["quantity"],Me(oArtikel:Me))+" (Angebotspreis:"+LTrim(Str(aAng[1]["VKPR"],10,2))+" ausgelesen: "+LTrim(Str(hData["items"][nX]["price"]/IF(hData["items"][nX]["price_unit"]==0,1,hData["items"][nX]["price_unit"]),10,2))+")"
                  ENDIF
               ENDIF

               //Staffelpreis (mit Rabatt) suchen
               IF ! lPriceOk
                  ASort(aOldAng,,,{|x,y| x:Besda > y:Besda })
                  IF Len(aOldAng) > 0
                     ? "Rabatt ("+Ltrim(Str(aOldAng[1]:AngNr))+"):",100-aOldAng[1]["PERCENT"]*100,"%"
                  ENDIF

                  //Staffelpreis suche
                  
                  aPrices := oArtikel:GetSellPrices(Date(),ku->Kunde)
                  nPrice := 0
                  FOR nP := 1 to Len(aPrices)
                     IF hData["items"][nX]["quantity"]>=aPrices[nP,1] .AND. (nP == Len(aPrices) .OR. hData["items"][nX]["quantity"] < aPrices[nP+1,1])
                        nPrice := aPrices[nP,2]
                        ? "Staffelpreis",nPrice
                        IF Len(aOldAng) > 0 .AND. aOldAng[1]["PERCENT"] > 0
                           nPrice *= aOldAng[1]["PERCENT"]
                           ?? "=",Round(nPrice,2)
                        ENDIF      
                        EXIT
                     ENDIF                
                  NEXT 
                  IF Empty(nPrice)
                     LOGRESULT "Kein passender Staffelpreis gefunden fÅr "+oArtikel:Matchcode+" mit Menge "+Transform(hData["items"][nX]["quantity"],Me(oArtikel:Me))
                  ELSEIF Round(nPrice,2) <= Round(hData["items"][nX]["price"]/IF(hData["items"][nX]["price_unit"]==0,1,hData["items"][nX]["price_unit"]),2)               
                     ?? "Preis akzeptiert!"
                     IF Round(nPrice,2) < Round(hData["items"][nX]["price"]/IF(hData["items"][nX]["price_unit"]==0,1,hData["items"][nX]["price_unit"]),2)*0.9             
                        ?? " Mehr als 10% Abweichung!"
                     ELSE
                        lPriceOk := .T.
                     ENDIF   
                  ELSE
                     LOGRESULT Trim(oArtikel:Matchcode)+" Staffelpreis hîher als Bestellung (Staffelpreis:"+LTrim(Str(nPrice,10,2))+" ausgelesen: "+LTrim(Str(hData["items"][nX]["price"]/IF(hData["items"][nX]["price_unit"]==0,1,hData["items"][nX]["price_unit"]),10,2))+")"                                 
                  ENDIF
               ENDIF
            ENDIF
            IF lPriceOk
               hLog["Artikel"] += LTrim(Str(hData["items"][nX]["price"]))+"|"
               hLog["Artikel"] += LTrim(Str(IF(hData["items"][nX]["price_unit"]==0,1,hData["items"][nX]["price_unit"])))
            ELSE
               hLog["Artikel"] += "?|?"
               MANUELL "Preis"
            ENDIF
            
         ENDIF
         IF nX != Len(hData["items"])
            hLog["Artikel"] += Chr(10)
         ENDIF
      NEXT
   ENDIF
   Aadd(aLog,hLog)
   #ifdef DEBUG
      Sinkey(0)
   #endif
   NEXT
NEXT
   IF nEmailsProcessed > 0
      ? "Verarbeitet:",nEmailsProcessed
      SaveAsCSV(cDir+"log_"+Left(TToS(DateTime()),14)+".csv",aLog)
      //MemoWrit(cDir+"\log_"+Left(TToS(DateTime()),14)+".csv",HB_OemToAnsi(cLog))   
      //cLog := ""
      //cError := ""
   ENDIF
   ? "Warten..."
   //IF LastKey() == 27 .OR. Inkey(60,128) == 27
      EXIT
   //ENDIF

   ENDDO
RETURN


#include "AIService.prg"
#include "DataValidator.prg"
#include "utils.prg"

   