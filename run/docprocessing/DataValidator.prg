/**
 * DataValidator.prg - Data Validation Class for Auto_Auftrag
 *
 * This class handles validation of extracted order data against the database.
 * It validates customer information, addresses, contact persons, and order items.
 */

#include "hbclass.ch"
#define CRLF CHR(13)+CHR(10)

CLASS DataValidator
      METHOD New(hData)
      METHOD MatchCustomer()
      METHOD ValidateCustomer()

      METHOD MatchDeliveryAddresses()
         

      METHOD GetErrors()
      METHOD AddError(cErr)
      METHOD ClearErrors()

      METHOD CompareValue
      METHOD StandardiseValue(cVal, cType)

         VAR oCustomer      // Customer object
         VAR hHasAdd INIT {=>}
         VAR hAddsNum INIT {=>}

      PROTECTED:
         VAR cError       // Error messages
         VAR hContacts    // Contact persons cache
         VAR hAddsTypes   // Address types mapping
         VAR hAddsFields  // Address fields mapping
         VAR hAddsStdFields // Standard address fields mapping
         VAR hData         //Data to validate
         
         
      HIDDEN:
         METHOD FindLieferAdresse(cKunde,hData)
   
ENDCLASS

METHOD New(hData) CLASS DataValidator
   ::cError := ""
   ::hContacts := NIL
   ::hAddsTypes := {"delivery_to"=>"Lieferadresse","invoice_to"=>"Rechnungsadresse"}
   ::hAddsFields := {"delivery_to"=>"delad","invoice_to"=>"reliefadr"}
   ::hAddsStdFields := {"delivery_to"=>"StdLiefAdr","invoice_to"=>"ReLiefAdr"}
   ::hData := hData

   NetUse("engkund","ku")
   NetUse("gerichte","ger")

   RETURN Self

METHOD AddError(cErr) CLASS DataValidator
   ::cError += IF(!Empty(::cError),Chr(10),"")+cErr
   RETURN Self

METHOD ClearErrors() CLASS DataValidator
   ::cError := ""
   RETURN Self

METHOD GetErrors() CLASS DataValidator
   RETURN ::cError

METHOD MatchCustomer() CLASS DataValidator
   //Look for the company using the registration number and court if available
   LOCAL lFound := .F.
   LOCAL cGericht,aMatch
   
   IF ! HHasKey(::hData,"customer")
      RETURN ::AddError("Kein Kunde in den Daten vorhanden")
   ENDIF

   IF ::hData["customer"]["country_iso"] == "DE";
      .AND. HHasKey(::hData["customer"],"company_registration_no") .AND. ! Empty(::hData["customer"]["company_registration_no"])  ;
      .AND. HHasKey(::hData["customer"],"company_registration_court") .AND. ! Empty(::hData["customer"]["company_registration_court"])

      #ifdef DEBUG
      ? "** Gericht **"      
      ? ::hData["customer"]["company_registration_court"]
      #endif

      cGericht := AllTrim(StrTran(StrTran(Upper(::hData["customer"]["company_registration_court"]),"AMTSGERICHT",""),"AG ",""))
      
      // Try to find the court in the database
      Select("ger")
      IF ! ger->(dbSeek(::hData["customer"]["country_iso"]+cGericht))
         ger->(dbGoTop())
         LOCATE FOR AllTrim(DEUpper(cGericht)) == AllTrim(DEUpper(ger->SimpleName))
      ENDIF

      // If the court was found, look for the company using the registration number
      IF ger->(Found())
         #ifdef DEBUG
         ?? " =",ger->Name
         #endif

         // Look for a company using the company registration number
         Select("ku")
         ku->(dbSetOrder( 2 ))
         ku->(dbSeek( "K" ,.T.))

         aMatch := HB_Regex("HR[A,B]\s*[0-9]{4,}",::hData["customer"]["company_registration_no"])         
         IF Len(aMatch) != 0         
            LOCATE FOR HB_RegexMatch(StrTran(aMatch[1]," ","\s*")+"[^0-9]*",ku->Compno) WHILE ku->Group == "K"
         ENDIF
         
         IF Len(aMatch) == 0 .OR. ! ku->(Found())
            #ifdef DEBUG
            ? "Kunde mit Registernummer nicht gefunden"            
            #endif
         ELSEIF ger->No == ku->Gericht // Compare the court, if we found one before
            #ifdef DEBUG
            ? "Kunde mit Registernummer gefunden",ku->CompNo
            #endif
            lFound := .T.            
         ELSE
            #ifdef DEBUG
            ? "Gericht weicht bei "+ku->Kunde+" ab"
            #endif
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
      #ifdef DEBUG
      ? "Suche:",::hData["customer"]["name"]
      #endif
      LOCATE FOR ::StandardiseValue(DEUpper(ku->Name1+ku->Name2),"name") == ::StandardiseValue(DEUpper(::hData["customer"]["name"]),"name") .AND. Trim(::hData["customer"]["zip"]) == Trim(ku->PLZ) WHILE ku->Group == "K"
      IF ku->(Found())                  
         lFound := .T.         
      ENDIF
   ENDIF
   IF lFound
      ::oCustomer := Adresse():New()
      ::oCustomer:Load(ku->Nummer)
   ENDIF
   
   RETURN lFound

METHOD ValidateCustomer() CLASS DataValidator
   LOCAL cFieldMap := {;
      "name" => Trim(ku->Name1)+" "+ku->Name2,;
      "address" =>ku->Street ,;
      "zip" => ku->PLZ,;
      "city" => ku->Town,;
      "country_iso" => ku->countryiso;
   }
   LOCAL lValid := .T.
   LOCAL cKey
   
   IF ! HHasKey(::hData,"customer")
      RETURN ::AddError("Kein Kunde in den Daten vorhanden")
   ENDIF

   IF ! HHasKey(::hData["customer"],"country_iso")
      RETURN ::AddError("Land nicht gefunden")
   ENDIF
   
   IF At("Engelking Elektronik GmbH",::hData["supplier"]["name"]) == 0
      RETURN ::AddError("Lieferant nicht Engelking Elektronik GmbH")
   ENDIF

   #ifdef DEBUG
   ? "** Kunde **"
   #endif
  
  
   // Validate customer data
   FOR EACH cKey IN {"country_iso","name","address","zip","city"}
      IF ! HHasKey(::hData["customer"],cKey)
         ::AddError("Fehlendes Feld: "+cKey)
         RETURN .F.
      ENDIF
      IF ! ::CompareValue(::hData["customer"][cKey],cFieldMap[cKey],cKey,ku->countryiso)
         ::AddError("Abweichendes Feld: "+cKey+" (Daten:"+::hData["customer"][cKey]+" Kundenstamm:"+cFieldMap[cKey]+")")
         lValid := .F.
      ELSE
         #ifdef DEBUG
         ? cKey,::hData["customer"][cKey],"=",cFieldMap[cKey]
         #endif
      ENDIF
   NEXT
   
RETURN lValid


METHOD MatchDeliveryAddresses()
   LOCAL cKunde := ku->Kunde
   LOCAL cType,cVal

   FOR EACH cType IN {"delivery_to"=>"Lieferadresse","invoice_to"=>"Rechnungsadresse"}
      ? "** "+cType+" **"
      ::hHasAdd[cType:__eNumKey()] := .F.
      FOR EACH cVal IN ::hData[cType:__eNumKey()]
         ? cVal:__eNumKey(),cVal
         IF cVal:__eNumKey() != "description"
            IF CompareValue(cVal,::hData["customer"][cVal:__eNumKey()],cVal:__enumKey())
               ?? " = "
            ELSE
               ?? " != "
               ::hHasAdd[cType:__eNumKey()] := .T.         
            ENDIF
            ?? ::hData["customer"][cVal:__eNumKey()]
         ENDIF
      NEXT   
      ::hAddsNum[cType:__eNumKey()] := 0
      IF ! ::hHasAdd[cType:__eNumKey()]
         ? "=>  "+cType+" ist gleich Kundenadresse"         
      ELSE
         
         ? "=> "+cType+" weicht von Kundenadresse ab"
         #ifdef DEBUG
         Sinkey(0)
         #endif
         IF (::hAddsNum[cType:__eNumKey()] := ::FindLieferAdresse(cKunde,::hData[cType:__eNumKey()])) == 0            
            ::hAddsNum[cType:__eNumKey()] := -1          
         ELSE
            //hLog["Lieferadresse"] := LTrim(Str(::hAddsNum[cType:__eNumKey()]))
         ENDIF
      ENDIF
      
   NEXT
RETURN .T.

METHOD FindLieferAdresse(cKunde,hData) CLASS DataValidator
   LOCAL nFound := 0,nLief,cAddressVal,cVal
   LOCAL aMatches
   LOCAL hKuFields := {"address"=>"street","city"=>"Town","zip"=>"PLZ","country_iso"=>"countryiso"}
   LOCAL nNameOnly := 0
   
   ku->(dbSetOrder( 1 )) //Kunden+Gruppe
   
   FOR nLief := 1 TO 99  //Max. 99 Adressen
      IF ! ku->(dbSeek( cKunde+GetLieferAddrGroup(nLief) ))
         EXIT
      ELSE
         nFound := nLief
         ? "Adresse:",Ltrim(Str(nLief))
         FOR EACH cVal IN hData
            IF cVal:__eNumKey() != "description"
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
               IF ::CompareValue(cVal,cAddressVal,cVal:__eNumKey())
                  ?? " = "
               ELSE
                  ?? " != "
                  IF nNameOnly == 0 .AND. cVal:__eNumKey() == "name"
                     nNameOnly := nLief
                  ELSEIF nNameOnly == nLief                  
                     nNameOnly := 0
                  ENDIF
                  nFound := 0
               ENDIF
               ?? cAddressVal
            ENDIF
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

METHOD ValidateContactPerson(hData) CLASS DataValidator
   LOCAL hContactPerson := NIL
   LOCAL hContact, nX
   
   IF ! HHasKey(hData,"contact_person")
      RETURN Self
   ENDIF
   
   ::hContacts := ::GetAddressContacts(.F.,.T.)
   
   // Try to find contact person using different matching strategies
   FOR nX := 1 TO 3  // First check surname+email, then surname+salutation and first name+email last
      FOR EACH hContact IN ::hContacts
         IF (AT(hData["contact_person"]["surname"],hContact["name"]) > 0 .OR. (nX == 3 .AND. AT(hData["contact_person"]["firstname"],hContact["name"]) > 0)) .AND.;
            ((nX $ {1,3} .AND. Trim(Lower(hData["contact_person"]["email"])) == Trim(Lower(hContact["email"]))) .OR. ;
            (nX == 2 .AND. AT(hData["contact_person"]["salutation"],hContact["name"]) > 0))
            
            hContactPerson := hContact
            IF nX == 2
               ::AddError("Abweichende Email (Daten:"+hData["contact_person"]["email"]+" Kontaktperson:"+Trim(hContact["email"])+")")
            ENDIF
            EXIT
         ENDIF
      NEXT
      IF hContactPerson != NIL
         EXIT
      ENDIF
   NEXT
   
   IF hContactPerson == NIL
      ::AddError("Kontaktperson nicht gefunden und muss neu angelegt werden ("+hData["contact_person"]["firstname"]+" "+hData["contact_person"]["surname"]+" ["+hData["contact_person"]["email"]+"]"+")")
   ENDIF
   
   RETURN Self

METHOD CompareValue(cVal, cVal2, cType,cCountryIso) CLASS DataValidator  
      LOCAL aTokens,aTokens2
      LOCAL aMatches

      cVal := DeUpper(cVal)
      cVal2 := DeUpper(cVal2)
      Default(@cType,"")
      IF cType == "city" //Special treatment of City names, only the first token is compared
         aTokens := HB_ATokens(cVal," ")
         aTokens2 := HB_ATokens(cVal2," ")
         RETURN aTokens[1] $ cVal2 .OR. aTokens2[1] $ cVal
      ELSEIF cType == "zip" .AND. cCountryIso == "DE"
         aMatches := HB_Regex("([0-9]{5})",cVal)
         IF Len(aMatches) != 0
            cVal := aMatches[1]            
         ENDIF      
         cVal2 := Trim(cVal2)
      ELSE
         cVal := ::StandardiseValue(cVal,cType)
         cVal2 := ::StandardiseValue(cVal2,cType)
      ENDIF
      ? cVal,cVal2
RETURN cVal == cVal2


METHOD StandardiseValue(cVal, cType) CLASS DataValidator
   LOCAL cRepl,hReplace := {" UND "=>"&"," AND "=>"&","+"=>"&","."=>"","/"=>"","-"=>"",":"=>"",","=>"",";"=>""}
   Default(@cType,"")
   IF cType == "name"
      hReplace := HB_HCopy({;
         "AKTIENGESELLSCHAFT"=>"AG",;
         "GESELLSCHAFT MIT BESCHRŽNKTER HAFTUNG"=>"GMBH",;
         "OFFENE HANDELSGESELLSCHAFT"=>"OHG",;
         "LIMITED"=>"LTD";
      },hReplace)
   ELSEIF cType == "address"
      hReplace := HB_HCopy({;
         "STRASSE"=>"STR",;
         "STREET"=>"ST",;
         "STRADA"=>"STR",;
         "PLACE"=>"PL",;
         "PLATZ"=>"PL",;
         " NR "=>"";
         },hReplace)
   ENDIF
   FOR EACH cRepl IN hReplace
      cVal := StrTran(cVal,cRepl:__eNumKey(),cRepl)
   NEXT
   cVal := StrTran(cVal," ","")
RETURN cVal
