/**
 * Price Calculation Module for Product Data Export
 */

#include "x:\run\product_data\config.prg"
#include "x:\run\product_data\database.prg"

FUNCTION CalculateProductPrices(oArtikel, hConfig)
   LOCAL aPrices := {}
   LOCAL nAvPreis, hConradPrices, aNewPrices, nPrice, hBuyPrice, nX
   
   // Try to get cached prices first
   IF ptc->(dbSeek(Str(oArtikel:Artikelnr,6))) .AND. ptc->LastDate >= Date()-7 .AND. ptc->Prices != "{}"
      aPrices := HB_JsonDecode(ptc->Prices)
   ELSE
      aPrices := oArtikel:GetSellPrices(Date())
   ENDIF
   
   // Remove zero quantity prices
   IF Len(aPrices) > 0
      DO WHILE aPrices[1,1] == 0
         HB_ADel(aPrices, 1, .T.)
      ENDDO
   ENDIF
   
   // Check for Conrad competitive pricing
   IF cmp2->(dbSeek(Str(oArtikel:Artikelnr,6) + Str(hConfig["nConradLiefnr"],6)))
      nAvPreis := oArtikel:GetAvgBuyPrice(Date())
      hConradPrices := HB_Deserialize(cmp2->Daten)
      aNewPrices := {}
      
      FOR nX := 1 TO Len(hConradPrices)
         hBuyPrice := GetBuyPrice(Pad("WALDOM",8), oArtikel:Artikelnr, HGetKeyAt(hConradPrices,nX))
         nPrice := HGetValueAt(hConradPrices,nX) * 0.96 / hConfig["nPriceMulti"]
         
         IF nAvPreis > 0 .AND. nPrice > nAvPreis * 1.1 .AND. nPrice >= hBuyPrice["price"] / hBuyPrice["unit"] * 1.1
            AAdd(aNewPrices, {HGetKeyAt(hConradPrices,nX), Round(nPrice * oArtikel:VkPe, 2)})
         ENDIF
      NEXT
      
      IF Len(aNewPrices) > 0 .AND. (Len(aPrices) == 0 .OR. aNewPrices[1,2] < aPrices[1,2])
         aPrices := aNewPrices
      ENDIF
   ENDIF
   
   // Apply special pricing for test products
   aPrices := ApplySpecialPricing(oArtikel, aPrices, hConfig)
   
RETURN aPrices

FUNCTION ApplySpecialPricing(oArtikel, aPrices, hConfig)
   LOCAL nX
   
   IF Trim(oArtikel:Matchcode) $ {"PX0686"}
      IF Trim(oArtikel:Matchcode) == "PX0686"
         aPrices := {{1,5.83},{10,5.75},{25,5.65},{50,5.55},{100,5.40}}
      ELSE
         aPrices := {{1,3.90},{5,3.70},{10,3.62},{25,3.55},{50,3.52},{100,3.42}}
      ENDIF
      
      FOR nX := 1 TO Len(aPrices)
         aPrices[nX,2] := aPrices[nX,2] * oArtikel:VkPe / hConfig["nPriceMulti"]
      NEXT
   ENDIF
   
RETURN aPrices

FUNCTION FormatPriceData(aPrices, oArtikel, nMwSt, hConfig)
   LOCAL hPriceData := {=>}
   LOCAL nX
   
   IF Len(aPrices) >= 1 .AND. aPrices[1,2] != 0
      hPriceData["price"] := Round(aPrices[1,2] / oArtikel:VkPe * nMwSt * hConfig["nPriceMulti"], 2)
      hPriceData["min-order-quantity"] := Max(1, aPrices[1,1])
      hPriceData["discount-ranges"] := ""
      
      FOR nX := 2 TO Len(aPrices)
         IF aPrices[nX,1] <= 100
            IF nX > 2
               IF Round(aPrices[nX,2], 2) <= Round(aPrices[nX-1,2], 2)
                  LOOP
               ENDIF
               hPriceData["discount-ranges"] += ","
            ENDIF
            hPriceData["discount-ranges"] += LTrim(Transform(aPrices[nX,1], Me(art->Me))) + "|" + ;
                                           lTrim(Str(aPrices[nX,2] / oArtikel:VkPe * nMwSt * hConfig["nPriceMulti"], 12, 2))
         ENDIF
      NEXT
   ENDIF
   
RETURN hPriceData
