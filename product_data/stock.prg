/**
 * Stock Management Module for Product Data Export
 */

#include "x:\run\product_data\config.prg"
#include "x:\run\product_data\database.prg"

FUNCTION CreateStockEntry(cSKU, nQuantity, nLeadTime, cUpdateDelete)
   LOCAL hStockData := {=>}
   
   hStockData["sku"] := cSKU
   hStockData["quantity"] := nQuantity
   hStockData["leadtime-to-ship"] := nLeadTime
   
   IF ! Empty(cUpdateDelete)
      hStockData["update-delete"] := cUpdateDelete
   ENDIF
   
RETURN hStockData

FUNCTION ProcessStockLevels(oArtikel, hPriceData, nCurWeek, nArtLZ, hConfig, aHolidayData)
   LOCAL aAvail, nStock, nX, nLZ
   LOCAL aPriceData := {}
   LOCAL hManuHoliday := aHolidayData[1]
   LOCAL aWaldHoliday := aHolidayData[2]
   LOCAL hStockData
   
   aAvail := GetKwQty(art->Artikelnr)
   nStock := art->Bestand
   
   // Calculate available stock considering lead time
   For nX := 1 To Len(aAvail)
      If aAvail[nX,1] <= AddWeeks(nCurWeek, nArtLZ + 1)
         nStock := Min(nStock, aAvail[nX,6])
      Endif
   Next
   
   // Stock entry (S = Stock)
   hStockData := HB_HClone(hPriceData)
   hStockData["sku"] := LTrim(Str(art->Artikelnr,6)) + "S"
   
   IF art->Bestand > 0 .AND. nStock > 0
      hStockData["quantity"] := Val(Transform(Min(nStock, art->Bestand), Me(art->Me)))
      IF hStockData["min-order-quantity"] > hStockData["quantity"]
         hStockData["min-order-quantity"] := Max(1, hStockData["quantity"])
      ENDIF
      hStockData["leadtime-to-ship"] := 1
      AAdd(aPriceData, hStockData)
   ELSE
      hStockData["quantity"] := 0
      hStockData["leadtime-to-ship"] := 0
      hStockData["update-delete"] := "delete"
   ENDIF
   
   // Waldom stock entry (W = Waldom)
   hStockData := HB_HClone(hPriceData)
   hStockData["sku"] := LTrim(Str(art->Artikelnr,6)) + "W"
   
   bpr->(dbSetOrder(2))
   IF lsto->(dbSeek(Pad("WALDOM",8) + Str(art->Artikelnr,6))) .AND. lsto->Stock > 0 .AND. ;
      bpr->(dbSeek(Str(art->Artikelnr,6) + Pad("WALDOM",8)))
      
      hStockData["update-delete"] := ""
      hStockData["quantity"] := lsto->Stock
      hStockData["leadtime-to-ship"] := _AddHoliday(hConfig["nWaldomLZ"], aWaldHoliday)
      AAdd(aPriceData, hStockData)
   ELSE
      hStockData["quantity"] := 0
      hStockData["leadtime-to-ship"] := 0
      hStockData["update-delete"] := "delete"
   ENDIF
   
   // Incoming stock entry (I = Incoming)
   hStockData := HB_HClone(hPriceData)
   hStockData["sku"] := LTrim(Str(art->Artikelnr,6)) + "I"
   
   IF nStock > art->bestand
      hStockData["update-delete"] := ""
      hStockData["quantity"] := nStock - art->Bestand
      nLZ := WeeksBetween(nCurWeek, GetAvailKw(art->Artikelnr, nStock, aAvail))
      
      IF nLz <= hConfig["nMaxLZ"] .AND. nLZ < nArtLZ
         hStockData["leadtime-to-ship"] := Max(1, nLZ * 5)
         AAdd(aPriceData, hStockData)
      ENDIF
   ELSE
      hStockData["quantity"] := 0
      hStockData["leadtime-to-ship"] := 0
      hStockData["update-delete"] := "delete"
   ENDIF
   
   // Production stock entry (P = Production)
   IF nArtLZ + 1 <= hConfig["nMaxLZ"]
      hStockData := HB_HClone(hPriceData)
      hStockData["sku"] := LTrim(Str(art->Artikelnr,6)) + "P"
      hStockData["update-delete"] := ""
      hStockData["quantity"] := hConfig["nQtyNoStock"]
      
      IF HHasKey(hManuHoliday, art->Manufactur)
         hStockData["leadtime-to-ship"] := _AddHoliday((nArtLZ + 1) * 5, hManuHoliday[art->Manufactur])
      ELSE
         hStockData["leadtime-to-ship"] := (nArtLZ + 1) * 5
      ENDIF
      
      AAdd(aPriceData, hStockData)
   ENDIF
   
RETURN aPriceData

STATIC FUNCTION _AddHoliday(nLZ, aHoliday)
   IF Date() <= aHoliday[2] .AND. Date() + nLZ - aHoliday[3] >= aHoliday[1]
      nLZ := aHoliday[2] - Date() + 1 + nLZ
   ENDIF
RETURN nLZ
