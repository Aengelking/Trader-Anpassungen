#include 'hbclass.ch'
//#include 'hbcompat.ch'
//ID: SWIAN2FUEFL2D01ODWHQM2W2BQ
//Key: Y1ZpSlRrbXVvTGc1MVpSNHhqclRjVFlpaWVLVEJocGQ2QW9JSmM

/*
   If the limit on product collection is set to high then no includes are returned, meaning there are no properties available
*/

#define SW_BASIS_FIELD "custom_trader_basis"
#define SW_CAT_TITLE_FIELD "custom_trader_category_title"
#define SW_PAGE_SIZE   50

PROC ShopWare_Update_Partno
   LOCAL oSW := ShopWareAPI():New()
   LOCAL hProdData,hParentData,aIncluded := {}
   LOCAL hParents := {=>}
   LOCAL hParent
   LOCAL nX
   LOCAL oBase,nFirsttab,cPN,oKey
   LOCAL hPropGroups := {=>},hData
   LOCAL hPropGroupNames := {=>}
   LOCAL hPropOptions := {=>}
   LOCAL hSendData
   LOCAL hProductOptions,nY,cID
   LOCAL cFunktion,aFunktion,nLength,lFound,cOptType,cDescription
   LOCAL getlist := {},nLimit := 100
   LOCAL cPNContains := Pad("CMI15",30),lError
   LOCAL nPage,nDone,nUpdated := 0,cTitle,cCatTitle,hProductOptionsNames,nSt,nEnd
   LOCAL aOptions,cTemp
   LOCAL hResponse
   LOCAL cErrorLog := ""
   LOCAL cSep

   MEMVAR c_five
   
   //oSW:cBaseUrl := "https://egl.teufels-werk.de/api/" // "https://engelkingtest.shopware.store/api/"

   IF ! oSW:Auth()
      Alert("Login failed")
      RETURN
   ENDIF

   NetUse("artikel","art")

   Head("Matchcodes fr Shopware generieren")
   @ 01,00 SAY "Anzahl Produkte      " GET nLimit PICTURE "99999" VALID nLimit >= 0 
   @ 02,00 SAY "Produktnummer enth„lt" GET cPNContains 
   READ

   IF LastKey() == 27
      RETURN
   ENDIF

   nPage := 1
   nDone := 0
   DO WHILE nDone < nLimit
      ? "Downloading product list... "
      hSendData := {;
         "filter"=>{;
            {;		   
               "type"=>"multi",;
               "operator"=>"and",;
               "queries"=>{;
                  {;
                     "type"=>"not",;
                     "operator"=>"or",;
                     "queries"=>{;
                        {;
                           "type"=>"equals",;
                           "field"=>"parentId",;
                           "value"=>NIL; //all parts which have a parent ID
                        };
                     };
                  },;
                  /*{;
                     "type"=>"contains",;
                     "field"=>"productNumber",;
                     "value"=>"."; //only part numbers containing a dot, as we do not have any with a dot and shopware always adds a dot and a number when generating the parts
                  },*/;
                  {;
                     "type"=>"contains",;
                     "field"=>"productNumber",;
                     "value"=>Trim(cPNContains); 
                  };
               };    
            };     
         },;
         "associations"=>{; 
            "properties"=>{},; //get all used properties			   		   
            "options"=>{}; //get all options, these are the ones set by the variantions
         },;	
         "includes"=>{;
            "product"=>{; //only the fields we really need
               "id",;
               "name",;		
               "parentId",;
               "productNumber",;
               "properties",;
               "options",;
               "customFields";
            },;
            "property_group_option"=>{;
               "name","id","groupId","group";
            };
         },;
         "limit"=>Min(nLimit-nDone,SW_PAGE_SIZE),;
         "page"=>nPage; 
      }      

      hProdData := oSw:Execute("search/product","POST",hSendData)
      IF ! HHasKey(hProdData,"data")
         ?? "Fehler beim Herunterladen der Daten."
         ? ValToPrg(hProdData)
         EXIT
      ENDIF
      nDone += Len(hProdData["data"])
      ?? " done. ("+LTrim(Str(Len(hProdData["data"])))+";"+LTrim(Str(nDone))+")"

      
      IF Len(hProdData["data"]) == 0 //no more products found
         EXIT
      ENDIF
      nPage++

      //download property groups and save the names
      ? "Downloading property group names..."
      hData := oSw:Execute("property-group","GET")
      FOR nX := 1 TO Len(hData["data"])
         hPropGroups[hData["data"][nX]["id"]] := _DeUpper(Trim(hData["data"][nX]["attributes"]["name"]))
         hPropGroupNames[_DeUpper(Trim(hData["data"][nX]["attributes"]["name"]))] := hData["data"][nX]["id"]      
      NEXT
      ?? " done."
      

      //get the parent nodes, also using the search interface to reduce the amount of data transmitted
      ? "Downloading parents... "
      FOR nX := 1 TO Len(hProdData["data"])    
         IF ! hProdData["data"][nX]["attributes"]["parentId"] $ hParents //if this parent has not been setup yet        
            hSendData := {;
               "filter"=>{;
                  {;
                     "type"=>"equals",;
                     "field"=>"id",;
                     "value"=>hProdData["data"][nX]["attributes"]["parentId"];
                  };
               },;            
               "associations"=>{; 
                  "properties"=>{},; //get all used properties			   		   
                  "options"=>{}; //get all options, these are the ones set by the variantions
               },;
               "includes"=>{;
                  "product"=>{;
                     "id","name","productNumber","customFields","properties","options";
                  },;
                  "property_group_option"=>{;
                     "name","id","groupId","group";
                  };
               };
            }
            hParentData := oSw:Execute("search/product","POST",hSendData)

            oBase := OptionBase():New()         
            cPN := Trim(hParentData["data"][1]["attributes"]["productNumber"])

            lError := .F.

            IF ! HHAsKey(hParentData["data"][1]["attributes"]["customFields"],SW_BASIS_FIELD) .OR. Empty(hParentData["data"][1]["attributes"]["customFields"][SW_BASIS_FIELD])
               ? 'Fehler: Kein Feld "'+SW_BASIS_FIELD+'"; Artikelnummer: '+cPN
            ELSEIF ! HHAsKey(hParentData["data"][1]["attributes"]["customFields"],SW_CAT_TITLE_FIELD) .OR. Empty(hParentData["data"][1]["attributes"]["customFields"][SW_CAT_TITLE_FIELD])
               ? 'Fehler: Kein Feld "'+SW_CAT_TITLE_FIELD+'"; Artikelnummer: '+cPN
            ELSEIF ! art->(dbSeek( Pad(hParentData["data"][1]["attributes"]["customFields"][SW_BASIS_FIELD],25) )) .OR. ! oBase:Load(Pad(hParentData["data"][1]["attributes"]["customFields"][SW_BASIS_FIELD],25))
               ? "Fehler: Keine Variantenbasis ("+hParentData["data"][1]["attributes"]["customFields"][SW_BASIS_FIELD]+") gefunden fr "+cPN
            ELSE
               nFirstTab := 1            
               IF cPN != Trim(oBase:Model) //the base part is a variant itself               
                  cPN := SubStr(cPN, Len(Trim(oBase:Model))+1 )               
                  oBase:oTables:Each({|oTable|
                     LOCAL lRet := .T.
                     IF ! Empty(cPN)  //this table is still part of the part no                                       
                        oKey := oTable:oKeys:GetRecord( SubStr( cPN,1,oTable:Length ))                         
                        IF oKey == NIL                        
                           oKey := oTable:oKeys:GetRecord( Space( oTable:Length ))  //look if there is a blank one
                           IF oKey == NIL //no blank one either
                              ? "Fehler: Schlssel '"+SubStr( cPN,1,oTable:Length )+"' nicht in der Tabelle '"+Trim(oTable:Funktion)+"'"
                              lRet := .F. //cancel loop
                           ENDIF
                        ELSE
                           cPN := SubStr( cPN,oTable:Length+1 ) 
                           IF ! Empty(oKey:Descript)
                              //? Trim(Pad(oTable:funktion("DE")+":",27)+oKey:descript("DE"))                  
                           ENDIF      
                        ENDIF
                        nFirsttab++
                     ELSE
                        aFunktion := Shopware_Group_Map(Trim(oTable:Funktion),Trim(oBase:Model))
                        FOR EACH cFunktion IN aFunktion
                           IF ! _DeUpper(cFunktion) $ hPropGroupNames //Check to see if we can find a property group with this name, property groups are unique
                              ? "Fehler: Keine Eigenschaftengruppe fr Tabelle '"+Trim(oTable:Funktion)+"' gefunden"                           
                           ENDIF
                        NEXT
                     ENDIF   
                     RETURN lRet
                  })
                  IF ! Empty(cPN) //we still have something left
                     ? "Fehler: Matchcode '"+Trim(hParentData["data"][1]["attributes"]["productNumber"])+"' des Hauptartikels konnte nicht entschlsselt werden"                  
                     lError := .T.
                  ENDIF
               ENDIF
               IF ! lError
                  //hParents[ hProdData["data"][nX]["id"] ] :=  {"data"=>hProdData["data"][nX],"base"=>oBase,"firsttab"=>nFirsttab}
                  hParents[ hProdData["data"][nX]["attributes"]["parentId"] ] :=  {"data"=>HB_HClone(hParentData["data"][1]),"base"=>oBase,"firsttab"=>nFirsttab}
                  Aadd(aIncluded,hParentData["included"])
               ENDIF
            ENDIF         
         ENDIF
      NEXT
      ?? " done ("+LTrim(Str(Len(hParents)))+")."   

      //process the property group options
      Aadd(aIncluded,hProdData["included"])
      FOR EACH hData IN aIncluded //{hProdData["included"],hParentData["included"]}
         FOR nX := 1 TO Len(hData)      
            IF hData[nX]["type"] == "property_group_option"                                  
               hPropOptions[hData[nX]["id"]] := {"name"=>Trim(hData[nX]["attributes"]["name"]),"group"=>hData[nX]["attributes"]["groupId"]}
            ENDIF
         NEXT
      NEXT



      //now work through all parts without a correct part no
      ? "Updating part numbers"
      FOR nX := 1 TO Len(hProdData["data"])
         IF HHasKey(hParents,hProdData["data"][nX]["attributes"]["parentId"])                       //and we have a base class
            ? hProdData["data"][nX]["attributes"]["productNumber"]
            hParent := hParents[hProdData["data"][nX]["attributes"]["parentId"]]
            //attempting to build part no
            cPN := Trim(hParent["data"]["attributes"]["productNumber"])

            hProductOptions := {=>}            
            hProductOptionsNames := {=>}

            //collect all product options from the parent and the product
            FOR EACH hData IN {hParent["data"],hProdData["data"][nX]}            
               FOR EACH cOptType IN {"options","properties"}               
                  FOR nY := 1 TO Len( hData["relationships"][cOptType]["data"] )                   
                     cID := hData["relationships"][cOptType]["data"][nY]["id"]                   
                     IF cID == NIL                        
                     ELSEIF cID $ hPropOptions               
                        IF ! hPropOptions[cID]["group"] $ hProductOptions
                           hProductOptions[ hPropOptions[cID]["group"] ] := {}
                           hProductOptionsNames[ hPropOptions[cID]["group"] ] := ""                           
                        ELSE                           
                           hProductOptionsNames[ hPropOptions[cID]["group"] ] += "|"
                        ENDIF
                        Aadd(hProductOptions[ hPropOptions[cID]["group"] ],_DeUpper(hPropOptions[cID]["name"]))
                        hProductOptionsNames[ hPropOptions[cID]["group"] ] += hPropOptions[cID]["name"]                        
                     ELSE
                        ? "Fehler: Eigenschaft '"+cID+"' nicht gefunden"
                     ENDIF
                  NEXT
               NEXT
            NEXT

            
            FOR EACH aOptions IN hProductOptions               
               ASort(aOptions)       
               cTemp  := ""        
               AEval(aOptions,{|cValue,nX| cTemp += IF(nX>1,"|","")+cValue })               
               hProductOptions[aOptions:__eNumKey()] := cTemp
            NEXT

            lError := .F.
            cTitle := hParent["data"]["attributes"]["name"]
            cCatTitle := hParent["data"]["attributes"]["customFields"][SW_CAT_TITLE_FIELD]

            hParent["base"]:oTables:Each({|oTable|                    
               IF oTable:Table >= hParent["firsttab"]
                  IF ! Empty(oTable:funktion)                    
                     aFunktion := Shopware_Group_Map(Trim(oTable:funktion))
                     cDescription := ""
                     nLength := oTable:Length
                     lFound := .F.
                     cSep := " "
                     FOR EACH cFunktion IN aFunktion
                        //? cFunktion
                        cFunktion := _DeUpper(cFunktion)
                        IF AT("$",cFunktion) == 1
                           cSep := SubStr(cFunktion,2)
                        ELSE
                           IF cFunktion $ hPropGroupNames
                              IF hPropGroupNames[cFunktion] $ hProductOptions
                                 IF ! Empty(cDescription)
                                    cDescription += cSep
                                 ENDIF
                                 cDescription += hProductOptions[hPropGroupNames[cFunktion]]
                                 //?? " :",cDescription
                              ELSE
                                 //?? ValToPrg(hProdData["data"][nX]["attributes"])
                                 //? "Fehler: Keine Eigenschaft '"+Trim(oTable:Funktion)+"' auf Artikel '"+Trim(hProdData["data"][nX]["attributes"]["productNumber"])+"' gefunden"
                                 //lError := .T.
                              ENDIF                     
                           ENDIF
                        ENDIF
                     NEXT
                     //?? cDescription
                     //IF ! Empty(cDescription)
                        oTable:oKeys:Each({|oKey|                         
                           IF (Empty(cDescription) .AND. Empty(oKey:Descript)) .OR.;
                              (! Empty(cDescription) .AND. _DeUpper(Trim(oKey:Descript)) $ {cDescription,hProductOptions[hPropGroupNames[aFunktion[1]]]}) //also match against the unkombined description of the first one
                              cPN += Pad(oKey:TabKey,nLength)                           
                              FOR EACH cFunktion IN aFunktion
                                 nSt := AT("%"+cFunktion+"%",_DeUpper(cTitle))
                                 IF nSt > 0
                                    nEnd := AT("%",SubStr(cTitle,nSt+1))                              
                                    cTitle := Substr(cTitle,1,nSt-1)+hProductOptionsNames[hPropGroupNames[_DeUpper(cFunktion)]]+SubStr(cTitle,nSt+nEnd+1)
                                 ENDIF

                                 nSt := AT("%"+cFunktion+"%",_DeUpper(cCatTitle))
                                 IF nSt > 0
                                    nEnd := AT("%",SubStr(cCatTitle,nSt+1))                              
                                    cCatTitle := Substr(cCatTitle,1,nSt-1)+hProductOptionsNames[hPropGroupNames[_DeUpper(cFunktion)]]+SubStr(cCatTitle,nSt+nEnd+1)
                                 ENDIF
                              NEXT
                              lFound := .T.
                              RETURN .F.
                           ENDIF
                           RETURN .T.
                        })
                        IF ! lFound
                           ? "Fehler: Schlssel '"+cDescription+"' nicht in der Tabelle '"+Trim(oTable:funktion)+"'"
                        ENDIF
                     /*ELSE
                        ? "Keine Eigenschaft fr Tabelle "+aFunktion[1]
                        FOR nT := 2 TO Len(aFunktion)
                           ? " oder "+aFunktion[nT]
                        NEXT
                     ENDIF*/
                     IF ! lFound
                        cPN += Replicate("?",nLength)
                        lError := .T.
                     ENDIF
                     //? cPN
                  ENDIF
               ENDIF
               RETURN .T.
            })
            ?? " ->"
            IF ! lError 
               hData := {=>}
               IF Trim(hProdData["data"][nX]["attributes"]["productNumber"]) != Trim(cPN)
                  hData["productNumber"] := cPN
                  ?? "",cPN
               ENDIF
               IF hProdData["data"][nX]["attributes"]["name"] == NIL .OR. Trim(cTitle) != Trim(hProdData["data"][nX]["attributes"]["name"])
                  hData["name"] := HB_StrToUtf8(cTitle)
                  ?? " Name:",cTitle                  
               ENDIF               
               IF hProdData["data"][nX]["attributes"]["customFields"] == NIL .OR. hProdData["data"][nX]["attributes"]["customFields"][SW_CAT_TITLE_FIELD] == NIL .OR. Trim(cCatTitle) != Trim(hProdData["data"][nX]["attributes"]["customFields"][SW_CAT_TITLE_FIELD])
                  hData["customFields"] := {=>}
                  hData["customFields"][SW_CAT_TITLE_FIELD] := HB_StrToUtf8(cCatTitle)
                  ?? " Cat-Title:",cCatTitle                  
               ENDIF
               IF Len(hData) > 0
                  nUpdated++
                  hResponse := oSw:Execute("product/"+hProdData["data"][nX]["id"],"PATCH",hData)
                  IF HB_IsHash(hResponse) .AND. "errors" $ hResponse
                     ? "FEHLER"
                     cErrorLog += "Error updating "+hProdData["data"][nX]["attributes"]["productNumber"]+": "
                     cErrorLog += hResponse["errors"][1]["title"]+" "+hResponse["errors"][1]["detail"]+Chr(10)+Chr(13)
                  ENDIF
               ELSE
                  ?? "up to date"
               ENDIF
            ELSE
               ?? "",cPN," nicht vollst„ndig"
            ENDIF
            
            
         ENDIF
         IF Inkey() == 27
            RETURN
         ENDIF
      NEXT
   ENDDO
   ? nDone," Datens„tze geprft"
   ? nUpdated," Datens„tze aktualisiert"
   ? "Beliebige Taste drcken..."
   Sinkey(0)
   IF ! Empty(cErrorLog)
      SetColor(c_five)
      MemoEdit(cErrorLog)
   ENDIF

FUNCTION Shopware_Group_Map(cName)
   LOCAL hMap := {;
      "Material"=>{"Geh„usematerial","Geh„usefarbe"},;
      "Kabeldurchmesser [mm]"=>{"Kabeldurchmesser [mm] min.","$-","Kabeldurchmesser [mm] max."};
   }
   
   IF cName $ hMap
      RETURN hMap[cName]
   ENDIF
RETURN {cName}


//API for Shopware 6

CLASS ShopWareAPI FROM RestAPI
   METHOD Auth
   METHOD Execute
   METHOD New

   DATA cBaseUrl //INIT "https://engelking-test.shopware.store/api/"     

   //CLASSDATA lUseBasicAuth INIT .T.

   DATA cToken
   DATA tTokenExpires INIT StoT("")
   
   DATA cKeyName INIT "SW_API"

ENDCLASS

METHOD New()
   ::cBaseUrl := GetValue("SW_URL","https://egl.teufels-werk.de/api/","URL of the Shopware installation")
RETURN ::Super:New()

METHOD Auth(lRefresh)
   LOCAL hProdData
   LOCAL hResponse

   Default(@lRefresh,.F.)

   hProdData := {=>}
   hProdData["client_id"] := "$USERNAME$"
   /*IF lRefresh
      hProdData["grant_type"] := "refresh_token"
      hProdData["refresh_token"] := ::cToken
   ELSE*/
      hProdData["grant_type"] := "client_credentials"      
      hProdData["client_secret"] := "$PASSWORD$"
   //ENDIF

   hResponse := ::Execute("oauth/token","POST",hProdData) 
   IF "errors" $ hResponse
      Alert(ValToPrg(hResponse))
      RETURN .F.
   ENDIF

   ::cToken := hResponse["access_token"]
   ::tTokenExpires := DateTime()+hResponse["expires_in"]/24/60/60   
   

RETURN .T.

METHOD Execute(cUrl,cMethod,hProdData,lJson)
   LOCAL cData,aHeaders := {'Content-Type: application/json'}

   Default(@lJson,.T.)
   
   IF ! cUrl == "oauth/token" .AND. ::tTokenExpires <= DateTime()+5/24/60/60 //add five seconds so we have enough time to execute the actual call      
      ::Auth(.T.)
   ENDIF
   IF ! Empty(::cToken)
      Aadd(aHeaders,"Authorization: Bearer "+::cToken)
   ENDIF
   cData := ::Super:Execute(cUrl,cMethod,hProdData,aHeaders,.T.)
   IF ! lJson
      RETURN cData
   ENDIF
RETURN HB_JsonDecode(cData)

STATIC FUNCTION _DeUpper(cText)
   LOCAL hRepl := {"„"=>"Ž","”"=>"™",""=>"š"}
   LOCAL cRepl
   cText := Upper(cText)
   FOR EACH cRepl IN hRepl
      cText := StrTran(cText,cRepl:__eNumKey(),cRepl)
   NEXT
RETURN cText
