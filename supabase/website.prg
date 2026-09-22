PROC SYNC_Supabase_Website()
   LOCAL oRest := RestApi():New()
   LOCAL lOptions := GetConfigValue("BATCHMODE")
   LOCAL lProducts := GetConfigValue("BATCHMODE")

   Head("Sync Supabase Website")

   IF ! GetConfigValue("BATCHMODE")
      lOptions := Tr_msgbox("Sync Options zu Supabase?",, {"Ja", "Nein"}) != 2
      lProducts := Tr_msgbox("Sync Products zu Supabase?",, {"Ja", "Nein"}) != 2
   ENDIF

   oRest:cBaseUrl := "https://kooxwelqbqplbryoxbya.supabase.co/"
   oRest:cApiKeyName := "WEBSITE"

   IF lOptions
      _SyncOptionsToSupabase(oRest)
   ENDIF
   IF lProducts
      _SyncProductsToSupabase(oRest)
   ENDIF

   IF ! GetConfigValue("BATCHMODE")
      ? "Sync abgeschlossen. DrÅcken Sie eine Taste, um fortzufahren."
      SInkey(0)
   ENDIF
RETURN

*  ---------------------------------------------------------------------------
*  Testlauf: schickt die ersten <nArticles> Artikel (Default 20) MIT Preisen an
*  die CMS-Function - ohne die 7-Tage-Drossel, ohne LastPrUpd zu schreiben und
*  mit is_last_batch = .F. (loest KEINEN Channel-Export aus). Danach in Supabase
*  product_tier_prices gegen die ERP-Werte pruefen, bevor der Volllauf startet.
*  ---------------------------------------------------------------------------
PROC SYNC_Supabase_Website_Test(nArticles)
   LOCAL oRest := RestApi():New()
   LOCAL cUrl := "functions/v1/erp-product-sync"
   LOCAL aHeader := {}
   LOCAL hData
   LOCAL aProducts
   LOCAL hBatch
   LOCAL cResponse

   IF nArticles == NIL
      nArticles := 20
   ENDIF

   Head("TEST Sync Supabase Website (" + LTrim(Str(nArticles)) + " Artikel)")

   oRest:cBaseUrl := "https://kooxwelqbqplbryoxbya.supabase.co/"
   oRest:cApiKeyName := "WEBSITE"
   AAdd(aHeader, "Authorization: Bearer $APIKEY$")

   // nLimit=nArticles, lForcePrices=.T., lNoStamp=.T. -> nicht-destruktiver Test
   hData := _BuildProductsJson(nArticles, .T., .T.)
   aProducts := IF(HHasKey(hData, "products"), hData["products"], {})

   ? "Gebaute Produkte: " + LTrim(Str(Len(aProducts)))
   IF Empty(aProducts)
      ? "Keine Produkte gebaut - Test abgebrochen."
      IF ! GetConfigValue("BATCHMODE")
         SInkey(0)
      ENDIF
      RETURN
   ENDIF

   hBatch := {=>}
   hBatch["products"]      := aProducts
   hBatch["batch_id"]      := "test"
   hBatch["is_last_batch"] := .F.     // wichtig: keinen Channel-Export ausloesen

   //gtSetClipboard(HB_JsonEncode(hBatch))  // optional: JSON in die Zwischenablage

   cResponse := oRest:Execute(cUrl, "POST", hBatch, aHeader, .T.)

   ? "Antwort: " + cResponse
   _PrintProductSyncResponse(cResponse)

   IF ! GetConfigValue("BATCHMODE")
      ? "Test abgeschlossen. Taste druecken..."
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

STATIC PROCEDURE _SyncProductsToSupabase(oRest)
   LOCAL cUrl := "functions/v1/erp-product-sync"
   LOCAL cResponse
   LOCAL aHeader := {}
   LOCAL hData := _BuildProductsJson()
   LOCAL aProducts := {}
   LOCAL aBatch
   LOCAL hBatchData
   LOCAL nTotalProducts
   LOCAL nBatchSize := 200   
   LOCAL nStart
   LOCAL nEnd
   LOCAL nX
   LOCAL nBatchNo := 0
   LOCAL nBatchCount
   LOCAL lBatchSuccess
   LOCAL nFailedBatches := 0
   LOCAL nProductsUpdated := 0
   LOCAL nProductsSkipped := 0
   LOCAL nTierPricesUpserted := 0

   ? "Sende Produktdaten zu Supabase..."

   AAdd(aHeader, "Authorization: Bearer $APIKEY$")

   IF HHasKey(hData, "products") .AND. ValType(hData["products"]) == "A"
      aProducts := hData["products"]
   ENDIF

   nTotalProducts := Len(aProducts)
   IF nTotalProducts == 0
      ? "Keine Produkte zum Synchronisieren gefunden"
      RETURN
   ENDIF

   nBatchCount := Int((nTotalProducts + nBatchSize - 1) / nBatchSize)

   FOR nStart := 1 TO nTotalProducts STEP nBatchSize
      nEnd := Min(nStart + nBatchSize - 1, nTotalProducts)
      nBatchNo++

      aBatch := {}
      FOR nX := nStart TO nEnd
         AAdd(aBatch, aProducts[nX])
      NEXT

      hBatchData := {=>}
      hBatchData["products"] := aBatch
      hBatchData["batch_id"] := nBatchNo
      hBatchData["is_last_batch"] := (nBatchNo == nBatchCount)

      ? "Batch " + LTrim(Str(nBatchNo)) + "/" + LTrim(Str(nBatchCount)) + " (" + LTrim(Str(Len(aBatch))) + " Produkte)"

      cResponse := oRest:Execute(cUrl, "POST", hBatchData, aHeader, .T.)
      IF Empty(cResponse)
         nFailedBatches++
         ? "Fehler: leere Antwort von Supabase (Batch " + LTrim(Str(nBatchNo)) + ")"
      ELSE
         lBatchSuccess := .F.
         _AccumulateProductSyncResponse(cResponse, @nProductsUpdated, @nProductsSkipped, @nTierPricesUpserted, @lBatchSuccess)
         IF ! lBatchSuccess
            nFailedBatches++
            ? "Fehlerhafte Antwort in Batch " + LTrim(Str(nBatchNo))
            ? "Antwort: " + cResponse
         ENDIF
      ENDIF
   NEXT

   IF nFailedBatches == 0
      ? "PRODUKTE erfolgreich in Batches synchronisiert"
   ELSE
      ? "Synchronisierung mit Fehlern abgeschlossen"
      ? "Fehlgeschlagene Batches: " + LTrim(Str(nFailedBatches))
   ENDIF

   ? "Upserted products: " + LTrim(Str(nProductsUpdated))
   ? "Skipped products (no changes): " + LTrim(Str(nProductsSkipped))
   ? "Upserted tier prices: " + LTrim(Str(nTierPricesUpserted))

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
   //RestEnv(aEnv,.F.)
RETURN hResult

STATIC FUNCTION _BuildProductsJson(nLimit, lForcePrices, lNoStamp)
   LOCAL aEnv := SaveEnv()
   LOCAL hResult := {=>}
   LOCAL aProducts := {}
   LOCAL hProducts := {=>}
   LOCAL cProductNumber
   LOCAL oArtikel
   LOCAL aPrices
   LOCAL nX
   LOCAL hTier
   LOCAL hProduct
   LOCAL aTierPrices
   LOCAL nQty
   LOCAL nPriceNet
   LOCAL aOnpowPrices
   LOCAL nCurWeek := CWeek(Date())
   LOCAL cWaldom := Pad("WALDOM",8)
   LOCAL nTotal,nCount := 0
   LOCAL nLimitPrices := 100
   LOCAL nPrices := 0

   IF nLimit == NIL          // 0 = alle Produkte (Produktion)
      nLimit := 0
   ENDIF
   IF lForcePrices == NIL    // .T. = 7-Tage-Drossel umgehen (Test)
      lForcePrices := .F.
   ENDIF
   IF lNoStamp == NIL        // .T. = LastPrUpd nicht schreiben (Test, nicht-destruktiv)
      lNoStamp := .F.
   ENDIF

   @ 01,00 SAY "Lese Produktdaten aus ERP..."

   hResult["products"] := aProducts

   NetUse("shopware", "shop")
   NetUse("ptcache", "ptc")
   NetUse("liefstock", "lsto")
   NetUse("waldom","wald")
   NetUse("buyprice", "bpr")
   NetUse("engkund","ku")  //ONPOW_PRICING uses this
   NetUse("stafprei","stpr")
   NetUse("artikel","art")  //Zolltarifnummer/Ursprungsland aus dem Artikelstamm
   bpr->(dbSetOrder(2))
   
   shop->(dbSetOrder(0))
   nTotal := shop->(LastRec())
   
   shop->(dbSetOrder(3))   
   shop->(dbGoTop())
   
   IF shop->(EOF())
      ? "Keine Produkte in der Datenbank gefunden."
      ? nTotal," datensÑtze insgesamt."
      Sinkey(0)
      RETURN hResult
   ENDIF

   IF Tr_Getini(28) == 9 .AND. ! GetConfigValue("BATCHMODE")
      //shop->(dbSeek("THB.381.A2A")); nLimit := 1
   ENDIF
   DO WHILE ! shop->(EOF()) .AND. (nLimit == 0 .OR. Len(aProducts) < nLimit)
      nCount++
      @ 03,00 SAY Str(nCount)+"/"+LTrim(Str(nTotal))
      IF shop->Artikelnr != 0
         cProductNumber := StrTran(Trim(shop->Matchcode), "#MT", "")
         @ 02,00 SAY Pad(cProductNumber,25)         
         IF ! Empty(cProductNumber)
            IF ! HHasKey(hProducts, cProductNumber)
               hProduct := {=>}
               aTierPrices := {}
               hProduct["product_number"] := hb_StrToUTF8(cProductNumber)
               hProduct["erp_article_nr"] := shop->Artikelnr
               hProduct["stock"] := 0
               hProduct["manufacturer_stock"] := 0
               hProduct["delivery_time"] := 0               
               hProducts[cProductNumber] := hProduct
               AAdd(aProducts, hProduct)
            ELSE
               hProduct := hProducts[cProductNumber]
               aTierPrices := IF(HHasKey(hProduct, "tier_prices"), hProduct["tier_prices"], {})
            ENDIF

            oArtikel := Artikel():New()
            oArtikel:Load(shop->Artikelnr)

            _ApplyProductStockData(hProduct, oArtikel, nCurWeek, cWaldom)
            
            IF lForcePrices .OR. StoT(shop->LastPrUpd) < DateTime()-7 //*24*3600 //only update every 7 days
               aPrices := oArtikel:GetSellPrices(Date())
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
                     hTier["min_quantity"] := nQty
                     hTier["price_net"] := nPriceNet
                     AAdd(aTierPrices, hTier)
                  ENDIF
               NEXT

               // Only include tier_prices when we have a complete staffel list.
               // The CMS treats a present tier_prices array as delete-and-replace,
               // so an empty array would wipe the article's prices; omitting the
               // field leaves the existing CMS prices untouched.
               IF Len(aTierPrices) > 0
                  hProduct["tier_prices"] := aTierPrices
               ENDIF

               // Advance the throttle stamp whenever prices were recomputed,
               // even if none were found, so the 7-day cadence holds for
               // price-less articles too. Skipped in test mode (lNoStamp).
               IF ! lNoStamp
                  shop->(Rec_Lock())
                  shop->LastPrUpd := TtoS(DateTime())
                  shop->(dbUnLock())
               ENDIF
            ENDIF

            _ApplyProductCustomsData(hProduct, shop->Artikelnr)
         ENDIF
      ELSEIF Left(Trim(shop->Matchcode), 2) == "CM"
         cProductNumber := Trim(shop->Matchcode)
         @ 02,00 SAY Pad(cProductNumber,25)         
         IF ! Empty(cProductNumber)
            IF ! HHasKey(hProducts, cProductNumber)
               hProduct := {=>}
               aTierPrices := {}
               hProduct["product_number"] := hb_StrToUTF8(cProductNumber)
               hProduct["stock"] := 0
               hProduct["manufacturer_stock"] := 0
               hProduct["delivery_time"] := 4               
               hProducts[cProductNumber] := hProduct
               AAdd(aProducts, hProduct)
            ELSE
               hProduct := hProducts[cProductNumber]
               aTierPrices := IF(HHasKey(hProduct, "tier_prices"), hProduct["tier_prices"], {})
            ENDIF

            IF lForcePrices .OR. StoT(shop->LastPrUpd) < DateTime()-7*24*3600 //only update every 7 days
               aOnpowPrices := ONPOW_PRICING(Trim(shop->Matchcode))
               FOR nX := 1 TO Len(aOnpowPrices)
                  nQty := aOnpowPrices[nX,1]
                  nPriceNet := Round(aOnpowPrices[nX,2], 2)
                  IF nQty > 0 .AND. nPriceNet > 0
                     hTier := {=>}
                     hTier["min_quantity"] := nQty
                     hTier["price_net"] := nPriceNet
                     AAdd(aTierPrices, hTier)
                  ENDIF
               NEXT

               // See the Artikelnr branch: never send an empty array (it deletes
               // the article's prices), and always advance the throttle stamp.
               IF Len(aTierPrices) > 0
                  hProduct["tier_prices"] := aTierPrices
               ENDIF

               IF ! lNoStamp
                  shop->(Rec_Lock())
                  shop->LastPrUpd := Ttos(DateTime())
                  shop->(dbUnLock())
               ENDIF
            ENDIF
         ENDIF
      ENDIF
      shop->(dbSkip())      
   ENDDO
   IF Tr_Getini(28) == 9 .AND. ! GetConfigValue("BATCHMODE")
      //? ValToPrg(hProducts)
   ENDIF


   RestEnv(aEnv,.F.)
RETURN hResult

STATIC PROCEDURE _AccumulateProductSyncResponse(cResponse, nProductsUpdated, nProductsSkipped, nTierPricesUpserted, lBatchSuccess)
   LOCAL hResp := NIL
   LOCAL hResults := NIL

   lBatchSuccess := .F.

   IF Empty(cResponse)
      RETURN
   ENDIF

   HB_JsonDecode(cResponse, @hResp)

   IF ValType(hResp) != "H"
      RETURN
   ENDIF

   IF ! (HHasKey(hResp, "success") .AND. hResp["success"])
      RETURN
   ENDIF

   IF HHasKey(hResp, "results") .AND. ValType(hResp["results"]) == "H"
      hResults := hResp["results"]

      IF HHasKey(hResults, "products_updated") .AND. ValType(hResults["products_updated"]) == "N"
         nProductsUpdated += hResults["products_updated"]
      ENDIF

      IF HHasKey(hResults, "products_skipped") .AND. ValType(hResults["products_skipped"]) == "N"
         nProductsSkipped += hResults["products_skipped"]
      ENDIF

      IF HHasKey(hResults, "tier_prices_upserted") .AND. ValType(hResults["tier_prices_upserted"]) == "N"
         nTierPricesUpserted += hResults["tier_prices_upserted"]
      ENDIF
   ENDIF

   lBatchSuccess := .T.
RETURN

STATIC PROCEDURE _ApplyProductStockData(hProduct, oArtikel, nCurWeek, cWaldom)
   LOCAL nArtLZ
   LOCAL aAvail
   LOCAL nStock
   LOCAL nX
   LOCAL nOwnStock
   LOCAL nManufacturerStock := 0
   LOCAL nManufacturerMOQ := 1
   LOCAL nDeliveryTime

   nArtLZ := IF(oArtikel:LZ == 0, 12, oArtikel:LZ)
   aAvail := GetKwQty(oArtikel:Artikelnr)

   nStock := oArtikel:Bestand
   FOR nX := 1 TO Len(aAvail)
      IF aAvail[nX,1] <= AddWeeks(nCurWeek, nArtLZ + 1)
         nStock := Min(nStock, aAvail[nX,6])
      ENDIF
   NEXT

   IF oArtikel:Bestand > 0 .AND. nStock > 0
      nOwnStock := Max(0, Min(nStock, oArtikel:Bestand))      
   ELSE
      nOwnStock := 0
   ENDIF
   nDeliveryTime := (nArtLZ + 1)
   

   IF lsto->(dbSeek(cWaldom + Str(oArtikel:Artikelnr,6))) .AND. lsto->Stock > 0 ;
      .AND. bpr->(dbSeek(Str(oArtikel:Artikelnr,6) + cWaldom))      
      nManufacturerStock := lsto->Stock
      IF wald->(dbSeek(Pad(oArtikel:Matchcode,35)))
         nManufacturerMOQ := wald->MOQ
      ENDIF
   ENDIF

   hProduct["stock"] := nOwnStock
   hProduct["manufacturer_stock"] := nManufacturerStock
   hProduct["manufacturer_moq"] := nManufacturerMOQ
   hProduct["delivery_time"] := nDeliveryTime
RETURN

*  ---------------------------------------------------------------------------
*  Zolltarifnummer (art->KnCode) und Ursprungsland (art->Ursprung, ISO-2) aus
*  dem Artikelstamm nachziehen. Wie bei tier_prices wird der Schluessel nur
*  gesetzt, wenn ein Wert vorhanden ist - ein fehlender Schluessel laesst den
*  bestehenden CMS-Wert unangetastet, statt ihn zu leeren.
*  ---------------------------------------------------------------------------
STATIC PROCEDURE _ApplyProductCustomsData(hProduct, nArtikelnr)
   art->(dbSetOrder(2))   // 2 = Artikelnr
   IF art->(dbSeek(Str(nArtikelnr, 6)))
      IF ! Empty(art->KnCode)
         hProduct["customs_tariff_number"] := hb_StrToUTF8(StrTran(AllTrim(art->KnCode), " ", ""))
      ENDIF
      IF ! Empty(art->Ursprung)
         hProduct["country_of_origin"] := hb_StrToUTF8(Upper(AllTrim(art->Ursprung)))
      ENDIF
   ENDIF
RETURN

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

STATIC PROCEDURE _PrintProductSyncResponse(cResponse)
   LOCAL hResp := NIL
   LOCAL hResults := NIL

   IF Empty(cResponse)
      RETURN
   ENDIF

   HB_JsonDecode(cResponse, @hResp)

   IF ValType(hResp) != "H"
      ? "Antwort (kein JSON): " + cResponse
      RETURN
   ELSE
    //  ? "Antwort: " + cResponse
   ENDIF

   IF HHasKey(hResp, "success") .AND. hResp["success"]
      IF HHasKey(hResp, "results") .AND. ValType(hResp["results"]) == "H"
         hResults := hResp["results"]
         IF HHasKey(hResults, "products_updated")
            ? "Upserted products: " + LTrim(Str(hResults["products_updated"]))
         ELSE
            ? "No products updated"
         ENDIF
         IF HHasKey(hResults, "products_skipped")
            ? "Skipped products (no changes): " + LTrim(Str(hResults["products_skipped"]))
         ENDIF
         IF HHasKey(hResults, "tier_prices_upserted")
            ? "Upserted tier prices: " + LTrim(Str(hResults["tier_prices_upserted"]))
         ENDIF
            
      ENDIF

      
      IF HHasKey(hResp, "synced_at")
         ? "Synced at: " + hb_ValToStr(hResp["synced_at"])
      ENDIF
   ELSE
      ? "Product-Sync meldet success = false"
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
