#include 'hbclass.ch'

/*
   If the limit on product collection is set to high then no includes are returned, meaning there are no properties available
*/

#define SW_BASIS_FIELD "custom_trader_basis"
#define SW_CAT_TITLE_FIELD "custom_trader_category_title"
#define SW_PAGE_SIZE   50

PROC Shopware_TEST
   LOCAL oSW := ShopWareAPI():New()  //Shopware Admin REST Api   
   LOCAL cEURID,cRuleID
   LOCAL aRules,nX,nArtnr
   LOCAL aProdPrices,oArtikel
   LOCAL hProdData,aPrices
   CLS
   IF ! oSW:Auth()
      Alert("Login failed")
      RETURN
   ENDIF

   cEURID := oSW:GetCurrencyID("EUR")

   //Look for the default price rule
   aRules := oSw:Execute("rule","GET")["data"]
   FOR nX := 1 TO Len(aRules)      
      ? aRules[nX]["attributes"]["name"]
      IF aRules[nX]["attributes"]["name"] == "Always valid (Default)"
         cRuleID := aRules[nX]["id"]
         EXIT
      ENDIF
   NEXT

   IF Empty(cRuleID)
      Alert("No default rule found")
      RETURN
   ENDIF

   //? ValToPrg(aRules[nX])
   NetUse("shopware","shop")
   nArtnr := 1760
   shop->(dbSeek( Str(nArtnr,6) ))

   aProdPrices := oSw:Execute("product/"+shop->UUID+"/prices","GET")["data"]
   FOR nX := 1 TO Len(aProdPrices)      
      IF aProdPrices[nX]["attributes"]["ruleId"] != cRuleID //this is from a different price rule so we ignore it
         ? "Ignoring",aProdPrices[nX]["id"],aProdPrices[nX]["attributes"]["ruleId"]
         HB_ADel(aProdPrices,nX,.T.)
      ENDIF
   NEXT

   oArtikel := Artikel():New()
   oArtikel:Load(nArtnr)
   aPrices := oArtikel:GetSellPrices(Date())
   hProdData := {=>}
   IF Len(aPrices) > 0
      hProdData["prices"] := {}
      FOR nX := 1 TO Len(aPrices)
         Aadd(hProdData["prices"],{;            
            "quantityStart"=>Int(aPrices[nX][1]),;
            "quantityEnd"=>IF(nX<Len(aPrices),Int(aPrices[nX+1][1]-1),NIL),;
            "ruleId"=>cRuleID,;             
            "price"=>{{;               
               "currencyId"=>cEURID,;
               "net"=>aPrices[nX][2],;
               "gross"=>Round(aPrices[nX][2]*1.19,2),;
                  "linked"=>.T.;
            }};
         })
            
         IF nX<=Len(aProdPrices)
            ATail(hProdData["prices"])["price"][1]["id"] := aProdPrices[nX]["id"]
         ENDIF
      NEXT

   ENDIF
   
   //Delete any not used breaks
   FOR nX := Len(aPrices)+1 TO Len(aProdPrices)   
      //? "Deleting "+aProdPrices[nX]["id"]
      //? ValToPrg(oSW:Execute("product/"+shop->UUID+"/prices/"+aProdPrices[nX]["id"],"DELETE"))
   NEXT

   ? ValToPrg(hProdData)
   ? shop->UUID

   //Update/Save price breaks
   hData := oSw:Execute("product/"+shop->UUID,"PATCH",hProdData,.F.)
   ? ValToPrg(hData)
   Sinkey(0)
RETURN


//API for Shopware 6

CLASS ShopWareAPI FROM RestAPI
   METHOD Auth
   METHOD Execute
   METHOD New      

   METHOD GetCurrencyID

   DATA cBaseUrl //INIT "https://engelking-test.shopware.store/api/"     

   //CLASSDATA lUseBasicAuth INIT .T.

   DATA cToken
   DATA tTokenExpires INIT StoT("")
   DATA lLive INIT .T.
   
   DATA cKeyName INIT "SW_API"

   HIDDEN:
       DATA hCurrencies INIT {=>}

ENDCLASS

METHOD New(lLive) CLASS ShopWareAPI
   ::cBaseUrl := GetValue("SW_URL","https://egl.teufels-werk.de/api/","URL of the Shopware installation")
   IF ! GetConfigValue("BATCHMODE")
      IF (ValType(lLive) == "L" .AND. ! lLive) .OR. (ValType(lLive) != "L" .AND. Tr_MsgBox("Bitte w„hle die Umgebung aus, von der die Daten heruntergeladen werden sollen.",,{"Live","Staging"}) == 2)      
         ::lLive := .F.
         ::cBaseUrl := GetValue("SW_STAGING_URL","https://engelking.dev.intocommerce.de/api/","URL of the Shopware Staging Environment")
      ENDIF
   ENDIF
RETURN ::Super:New()

METHOD Auth(lRefresh) CLASS ShopWareAPI
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
      IF ! GetConfigValue("BATCHMODE")
         Alert("Fehler bei der Authentifizierung: "+hResponse["errors"][1]["title"]+" "+hResponse["errors"][1]["detail"])
         //Alert(ValToPrg(hResponse))
      ENDIF
      RETURN .F.
   ENDIF

   ::cToken := hResponse["access_token"]
   ::tTokenExpires := DateTime()+hResponse["expires_in"]/24/60/60   
   

RETURN .T.

METHOD Execute(cUrl,cMethod,hData,lJson) CLASS ShopWareAPI
   LOCAL cData,aHeaders := {'Content-Type: application/json'}

   Default(@lJson,.T.)
   
   IF ! cUrl == "oauth/token" .AND. ::tTokenExpires <= DateTime()+5/24/60/60 //add five seconds so we have enough time to execute the actual call      
      ::Auth(.T.)
   ENDIF
   IF ! Empty(::cToken)
      Aadd(aHeaders,"Authorization: Bearer "+::cToken)
   ENDIF
   cData := ::Super:Execute(cUrl,cMethod,hData,aHeaders,.T.)
   IF ! lJson
      RETURN cData
   ENDIF
RETURN HB_JsonDecode(cData)

METHOD GetCurrencyID(cISO) CLASS ShopWareAPI
   LOCAL cID := ""
   LOCAL nX
   IF Len(::hCurrencies) == 0
      ::hCurrencies := ::Execute("currency","GET")       
   ENDIF
   IF ::hCurrencies == NIL
      ::hCurrencies := {=>}      
      RETURN cID
   ENDIF
   
   // Loop through the currencies to find EUR
   FOR nX := 1 TO Len(::hCurrencies["data"])
      IF ::hCurrencies["data"][nX]["attributes"]["isoCode"] == cIso
         cID := ::hCurrencies["data"][nX]["id"]
         EXIT
      ENDIF
   NEXT

RETURN cID

