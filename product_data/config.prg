/**
 * Configuration settings for Product Data Export
 */

#ifndef __PRODUCT_DATA_CONFIG__
#define __PRODUCT_DATA_CONFIG__

FUNCTION GetProductDataConfig()
   LOCAL hConfig := {=>}
   
   // Stock and delivery settings
   hConfig["nQtyNoStock"]   := 1000    // Quantity for items not in stock
   hConfig["nMaxLZ"]        := 16      // Max delivery time in weeks
   hConfig["nPriceMulti"]   := 1.18    // Price multiplication factor (Conrad commission)
   hConfig["nWaldomLZ"]     := 5       // Delivery time in days for Waldom parts
   hConfig["nConradLiefnr"] := 4830    // Conrad supplier number
   
   // FTP/Upload settings
   hConfig["cFTPUrl"]       := "sftp://p543503f1:.p57#ovEslnuzr@p543503.mittwaldserver.info/"
   hConfig["cFTPHostKey"]   := "ssh-ed25519 256 pYuyCXhkKhdKuijxYZkXvyJC3TZBANdkeYrUJtzl21I="
   hConfig["cSCPDir"]       := "C:\Program Files (x86)\WinSCP\"
   
   // Company information
   hConfig["cWEEE"]         := "DE 43356265"  // WEEE number
   hConfig["cBrand"]        := "Engelking"
   hConfig["cCat"]          := "Drucktaster"
   
   // File paths
   hConfig["cDir"]          := "Y:\Dokumente und Einstellungen\Amos\Documents\ProductData\"
   hConfig["cQuoteFile"]    := Path("export\conrad\quote.csv")
   
   // Debug settings
   hConfig["lDbg"]          := .T.
   
RETURN hConfig

#endif
