/**
 * Utility Functions for Product Data Export
 */

FUNCTION AddHash(aData, hData)
   LOCAL cValue, cKey, nKey
   
   Aadd(aData, Array(Len(aData[1])))
   FOR EACH cValue IN hData
      cKey := cValue:__eNumKey()
      nKey := AScan(aData[1], cKey)
      IF nKey == 0
         Aadd(aData[1], cKey)
         Aadd(Atail(aData), NIL)
         nKey := Len(aData[1])
      ENDIF
      Atail(aData)[nKey] := cValue
   NEXT
RETURN NIL

FUNCTION CreateBaseProductData(cSku, cProdIdType, nArtLZ, hConfig)
   LOCAL hPriceData := {=>}
   
   hPriceData["product-id"] := cSku
   hPriceData["producer-id[DE-WEEE]"] := hConfig["cWEEE"]
   hPriceData["product-id-type"] := cProdIdType
   hPriceData["leadtime-to-ship"] := (nArtLZ + 1) * 5
   hPriceData["state"] := 11  // "Neu"
   hPriceData["reversecharge"] := "false"
   hPriceData["warehouse"] := 1
   
RETURN hPriceData

FUNCTION ProcessSpecialProducts(aSKU, shop, hConfig, nMwSt)
   LOCAL hPriceData, aPrices, cSKU, nX
   LOCAL aPriceData := {}
   
   IF Left(shop->Matchcode, 2) == "CM"  // Add all CM/CMI parts even without artikel database
      cSKU := StrTran(Trim(shop->Matchcode), "/", "-")
      IF ! cSKU $ aSKU
         hPriceData := CreateBaseProductData(Trim(shop->Matchcode), "SHOP_SKU", 3, hConfig)
         
         aPrices := ONPOW_PRICING(shop->Matchcode)
         IF Len(aPrices) >= 1 .AND. aPrices[1,2] != 0
            FOR nX := 1 TO Len(aPrices)
               aPrices[nX,2] := aPrices[nX,2] * oArtikel:VkPe / hConfig["nPriceMulti"]
            NEXT
            
            hPriceData["price"] := aPrices[1,2] / oArtikel:VkPe * nMwSt * hConfig["nPriceMulti"]
            hPriceData["min-order-quantity"] := Max(1, aPrices[1,1])
            hPriceData["discount-ranges"] := ""
            
            FOR nX := 2 TO Len(aPrices)
               IF aPrices[nX,1] <= 100
                  IF nX > 2
                     hPriceData["discount-ranges"] += ","
                  ENDIF
                  hPriceData["discount-ranges"] += LTrim(Str(aPrices[nX,1], 12, 0)) + "|" + ;
                                                  lTrim(Str(aPrices[nX,2] / oArtikel:VkPe * nMwSt * hConfig["nPriceMulti"]))
               ENDIF
            NEXT
            
            hPriceData["sku"] := cSKU
            hPriceData["update-delete"] := ""
            hPriceData["quantity"] := hConfig["nQtyNoStock"]
            
            AAdd(aPriceData, hPriceData)
            Aadd(aSKU, cSKU)
         ENDIF
      ENDIF
   ENDIF
   
RETURN aPriceData
