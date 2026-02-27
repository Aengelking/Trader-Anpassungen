PROC SYNC_Supabase_Website()
   LOCAL oRest := RestApi():New()

   Head("Sync Supabase Website")

   oRest:cBaseUrl := "https://kooxwelqbqplbryoxbya.supabase.co/"
   oRest:cApiKeyName := "WEBSITE"

   //_SyncOptionsToSupabase(oRest)
   _SyncTierPricesToSupabase(oRest)

   IF ! GetConfigValue("BATCHMODE")
      ? "Sync abgeschlossen. Drcken Sie eine Taste, um fortzufahren."
      SInkey(0)
   ENDIF
RETURN

STATIC PROCEDURE _SyncOptionsToSupabase(oRest)
   LOCAL cUrl := "functions/v1/erp-options-sync"
   LOCAL cResponse
   LOCAL aHeader := {}
   LOCAL hData := _BuildOptionsJson()

   ? "Sende Options-Daten zu Supabase..."   

   AAdd(aHeader, "Authorization: Bearer $APIKEY$")   

   //gtSetClipboard(HB_JsonEncode(hData)) //debug: copy the json to clipboard

   cResponse := oRest:Execute(cUrl, "POST", hData, aHeader, .T.)

   IF ! Empty(cResponse)
      ? "OPTIONS erfolgreich synchronisiert"
      _PrintSyncResponse(cResponse)
   ELSE
      ? "Fehler: leere Antwort von Supabase"
   ENDIF

RETURN

STATIC PROCEDURE _SyncTierPricesToSupabase(oRest)
   LOCAL cUrl := "functions/v1/erp-price-sync"
   LOCAL cResponse
   LOCAL aHeader := {}
   LOCAL hData := _BuildTierPricesJson()

   ? "Sende Preisstaffeln zu Supabase..."

   AAdd(aHeader, "Authorization: Bearer $APIKEY$")

   cResponse := oRest:Execute(cUrl, "POST", hData, aHeader, .T.)

   IF ! Empty(cResponse)
      ? "PREISE erfolgreich synchronisiert"
      _PrintTierPriceSyncResponse(cResponse)
   ELSE
      ? "Fehler: leere Antwort von Supabase (Preisstaffeln)"
   ENDIF

RETURN

STATIC FUNCTION _BuildOptionsJson()
   LOCAL aEnv := SaveEnv()
   LOCAL hResult := {=>}
   LOCAL aBases := {}, aTables := {}, aKeys := {}
   LOCAL oBase
   LOCAL hBase, hTable, hKey

   @ 01,00 SAY "Lese Options-Daten aus ERP..."

   hResult["bases"]  := aBases
   hResult["tables"] := aTables
   hResult["keys"]   := aKeys

   NetUse("optbas", "opb")
   opb->(dbGoTop())

   DO WHILE ! opb->(EOF())
      IF ! Empty(Trim(opb->MODEL))
         hBase := {=>}
         hBase["model"]          := Trim(opb->MODEL)
         hBase["model_ref"]      := Trim(opb->MODEL1)
         hBase["matchcode"]      := Trim(opb->MATCHCODE)
         hBase["price_domestic"] := opb->PRICE
         hBase["price_export"]   := opb->PRICEX
         hBase["article_nr"]     := IF(opb->ARTIKELNR > 0, opb->ARTIKELNR, NIL)
         AAdd(aBases, hBase)

         oBase := OptionBase():New()
         IF oBase:Load(opb->MODEL)
            oBase:oTables:Each({|oTable|            
               IF oTable:ID != 0
                  @ 02,00 SAY "Verarbeite Tabelle: " + Trim(oTable:Funktion)
                  hTable := {=>}
                  hTable["model"]      := Trim(oTable:Model)
                  hTable["table_nr"]   := oTable:Table
                  hTable["key_length"] := oTable:Length
                  hTable["label"]      := hb_StrToUTF8(Trim(oTable:Funktion))
                  AAdd(aTables, hTable)



                  oTable:oKeys:Each({|oKey|     
                     IF oKey:ID != 0
                        hKey := {=>}
                        hKey["model"]         := Trim(oKey:oTable:Model)
                        hKey["table_nr"]      := oKey:oTable:Table
                        hKey["tab_key"]        := Trim(oKey:TabKey)
                        hKey["description"]    := hb_StrToUTF8(Trim(oKey:Descript))
                        hKey["matchcode"]      := Trim(oKey:MatchCode)
                        hKey["price_domestic"] := oKey:Price
                        hKey["price_export"]   := oKey:Pricex
                        hKey["code"]           := oKey:Code
                        hKey["article_nr"]     := IF(oKey:Artikelnr > 0, oKey:Artikelnr, NIL)
                        AAdd(aKeys, hKey)
                     ENDIF
                     RETURN NIL
                  })
               ENDIF
               RETURN NIL               
            })
         ENDIF
      ENDIF
      opb->(dbSkip())
   ENDDO

   USE
   RestEnv(aEnv)
RETURN hResult

STATIC FUNCTION _BuildTierPricesJson()
   LOCAL aEnv := SaveEnv()
   LOCAL hResult := {=>}
   LOCAL aTierPrices := {}
   LOCAL aSeenProducts := {}
   LOCAL cProductNumber
   LOCAL oArtikel
   LOCAL aPrices
   LOCAL nX
   LOCAL hTier
   LOCAL nQty
   LOCAL nPriceNet
   LOCAL aOnpowPrices


   @ 01,00 SAY "Lese Preisstaffeln aus ERP..."

   hResult["tier_prices"] := aTierPrices

   NetUse("shopware", "shop")
   NetUse("ptcache", "ptc")
   NetUse("engkund","ku")  //ONPOW_PRICING uses this
   NetUse("stafprei","stpr")

   shop->(dbGoTop())
   DO WHILE ! shop->(EOF()) //.AND. Len(aTierPrices) <  500
      IF shop->Artikelnr != 0
         cProductNumber := StrTran(Trim(shop->Matchcode), "#MT", "")
         @ 02,00 SAY cProductNumber
         IF ! Empty(cProductNumber) .AND. AScan(aSeenProducts, cProductNumber) == 0
            AAdd(aSeenProducts, cProductNumber)

            oArtikel := Artikel():New()
            oArtikel:Load(shop->Artikelnr)

            IF ptc->(dbSeek(Str(oArtikel:Artikelnr,6))) .AND. ptc->LastDate >= Date()-7 .AND. ptc->Prices != "{}"
               aPrices := HB_JsonDecode(ptc->Prices)
            ELSE
               aPrices := oArtikel:GetSellPrices(Date())
            ENDIF

            IF Len(aPrices) > 0
               DO WHILE Len(aPrices) > 0 .AND. aPrices[1,1] == 0
                  HB_ADel(aPrices, 1, .T.)
               ENDDO
            ENDIF

            FOR nX := 1 TO Len(aPrices)
               nQty := aPrices[nX,1]
               nPriceNet := Round(aPrices[nX,2] / Max(1, oArtikel:VkPe), 2)
               IF nQty > 0 .AND. nPriceNet > 0
                  hTier := {=>}
                  hTier["product_number"] := hb_StrToUTF8(cProductNumber)
                  hTier["min_quantity"] := nQty
                  hTier["price_net"] := nPriceNet
                  AAdd(aTierPrices, hTier)
               ENDIF
            NEXT
         ENDIF
      ELSEIF Left(Trim(shop->Matchcode), 2) == "CM"
         cProductNumber := Trim(shop->Matchcode)
         IF ! Empty(cProductNumber) .AND. AScan(aSeenProducts, cProductNumber) == 0
            AAdd(aSeenProducts, cProductNumber)

            aOnpowPrices := ONPOW_PRICING(Trim(shop->Matchcode))
            FOR nX := 1 TO Len(aOnpowPrices)
               nQty := aOnpowPrices[nX,1]
               nPriceNet := Round(aOnpowPrices[nX,2], 2)
               IF nQty > 0 .AND. nPriceNet > 0
                  hTier := {=>}
                  hTier["product_number"] := hb_StrToUTF8(cProductNumber)
                  hTier["min_quantity"] := nQty
                  hTier["price_net"] := nPriceNet
                  AAdd(aTierPrices, hTier)
               ENDIF
            NEXT
         ENDIF
      ENDIF
      shop->(dbSkip())      
   ENDDO

   RestEnv(aEnv)
RETURN hResult

STATIC PROCEDURE _PrintSyncResponse(cResponse)
   LOCAL hResp := NIL
   LOCAL hResults := NIL
   LOCAL nBases := 0
   LOCAL nTables := 0
   LOCAL nKeys := 0

   IF Empty(cResponse)
      RETURN
   ENDIF

   HB_JsonDecode(cResponse, @hResp)

   IF ValType(hResp) != "H"
      ? "Antwort (kein JSON): " + cResponse
      RETURN
   ENDIF

   IF HHasKey(hResp, "success") .AND. hResp["success"]
      IF HHasKey(hResp, "results") .AND. ValType(hResp["results"]) == "H"
         hResults := hResp["results"]

         IF HHasKey(hResults, "bases") .AND. ValType(hResults["bases"]) == "H" .AND. HHasKey(hResults["bases"], "upserted")
            nBases := hResults["bases"]["upserted"]
         ENDIF

         IF HHasKey(hResults, "tables") .AND. ValType(hResults["tables"]) == "H" .AND. HHasKey(hResults["tables"], "upserted")
            nTables := hResults["tables"]["upserted"]
         ENDIF

         IF HHasKey(hResults, "keys") .AND. ValType(hResults["keys"]) == "H" .AND. HHasKey(hResults["keys"], "upserted")
            nKeys := hResults["keys"]["upserted"]
         ENDIF
      ENDIF

      ? "Upserted bases : " + LTrim(Str(nBases))
      ? "Upserted tables: " + LTrim(Str(nTables))
      ? "Upserted keys  : " + LTrim(Str(nKeys))

      IF HHasKey(hResp, "synced_at")
         ? "Synced at: " + hb_ValToStr(hResp["synced_at"])
      ENDIF
   ELSE
      ? "Sync-Response meldet success = false"      
   ENDIF
RETURN

STATIC PROCEDURE _PrintTierPriceSyncResponse(cResponse)
   LOCAL hResp := NIL
   LOCAL hResults := NIL
   LOCAL nTierPrices := 0

   IF Empty(cResponse)
      RETURN
   ENDIF

   HB_JsonDecode(cResponse, @hResp)

   IF ValType(hResp) != "H"
      ? "Antwort (kein JSON): " + cResponse
      RETURN
   ENDIF

   IF HHasKey(hResp, "success") .AND. hResp["success"]
      IF HHasKey(hResp, "results") .AND. ValType(hResp["results"]) == "H"
         hResults := hResp["results"]
         IF HHasKey(hResults, "upserted")
            nTierPrices := hResults["upserted"]
         ENDIF
      ENDIF

      ? "Upserted tier_prices: " + LTrim(Str(nTierPrices))
      IF HHasKey(hResp, "synced_at")
         ? "Synced at: " + hb_ValToStr(hResp["synced_at"])
      ENDIF
   ELSE
      ? "Price-Sync meldet success = false"
      ? "Antwort: " + cResponse
   ENDIF
RETURN

FUNC ONPOW_PRICING(cMatch)   //this is only used to get prices for parts that are not in the database yet
   LOCAL cOnPow,nBuyPrice
   LOCAL nTab := 75,cSupplier := Pad("ONPOW",8)
   LOCAL aPriceTab := {},nX,nBasis,nPrice
   LOCAL cTab,cProz

   cOnpow := OnpowPartno(cMatch,IF(Left(cMatch,3)=="CMI",3,2))   //try to get the Onpow part number
   IF Empty(cOnPow)
      RETURN aPriceTab
   ENDIF
   nBasis := OnpowPrices(cOnPow)
   
   ku->(dbSetOrder( 1 ))
   ku->(dbSeek( cSupplier+"L" ))

   nBasis *= Currate(ku->Money,"E") //convert to Euro if needed
   
   IF stpr->(dbSeek( Str(nTab,2) ))
      nBasis += nBasis*stpr->BasicProz //add basic price percentage

      For nX := 1 To 10
			cTab := "TAB"+LTrim(Str(nX))
			cProz := "PROZ"+LTrim(Str(nX))
			If stpr->&cTab != 0
				nPrice := nBasis*stpr->&cProz/100

				Aadd(aPriceTab,{stpr->&cTab,nPrice})
			Endif
		Next
   ENDIF
RETURN aPriceTab


#include '..\onpow_part_no.prg'
#include '..\onpow_prices.prg'
