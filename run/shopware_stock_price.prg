
/*
 * Shopware Stock and Price Update Procedure
 * 
 * This procedure synchronizes stock levels and pricing information between
 * the internal trading system and Shopware e-commerce platform. Additionally,
 * it creates a CSV and uploads this via FTP to our server for further processing via a Multi-Channel-System.
 *
 * Main Functions:
 * - Updates stock quantities for all products in Shopware
 * - Synchronizes pricing information including quantity breaks
 * - Handles supplier stock from WALDOM and other sources
 * - Processes both standard warehouse items and follow-up articles
 * - Manages currency conversion (EUR) and price rules
 *
 * Data Sources:
 * - artikel: Main product database
 * - liefstock: Supplier stock information
 * - waldom: WALDOM supplier specific data
 * - shopware: Shopware product mappings
 *
 */

//#define SHOPWARE_UPLOAD

PROC Shopware_Stock_Price
   /** SETTINGS ***/

   LOCAL aSuppliers := {"WALDOM"}
   LOCAL aErrorTo   := {{"amos.engelking@engelking.de","Amos"}}
   LOCAL cFTPUrl     := "sftp://24982-conrad:H7f2e6ardK(z@ftp.engelking-elektronik.de/"
   LOCAL cFTPHostKey := "ssh-rsa 4096 d8UwfuV9Sp9JIOjQwek7pTcF8kZhPI4yapqOSZvFWcI="
   LOCAL cSCPDir     := "C:\Program Files (x86)\WinSCP\"

   /** END OF SEETING ***/

   LOCAL oSW := ShopWareAPI():New()   
   LOCAL lUpdAll    :=  ! oSW:lLive .OR. GetValue("SW_UPD_ALL",.F.,"Best„nde aller Artikel aktualisieren (1x)")
   LOCAL cFilter := 'At("KS",matchcode) != 1 .AND. Trim(Type) == "WARE" .AND. ! Obsolete'
   LOCAL hSendData,hProdData,oExtra
   LOCAL hData,oErr,aAvail,nStock,nX,cSupplier
   LOCAL cErr := ""
   
   LOCAL nCurWeek := CWeek(Date())
   LOCAL nStart := Seconds()
   LOCAL bGetStock
   LOCAL nCount := 0
   LOCAL nUpdate := 0

   LOCAL aPrices,oArtikel
   LOCAL cEURID,cRuleID
   LOCAL aRules,aProdPrices
   LOCAL aCSV := {},hCSVData

   LOCAL cFile,cCmd,cParam,cData,cLine
   LOCAL nStdOut,nProc,nBytes

   NetUse("artikel","art")
   NetUSe("liefstock","lsto")
   NetUse("waldom","wald")
   NetUse("shopware","shop")

   IF lUpdAll
      SetValue("SW_UPD_ALL",.F.)
   ENDIF

   
   bGetStock := {|lWaldom|
      LOCAL nSaveStock,nRec
      Default(@lWaldom,.T.)

      aAvail := GetKwQty(art->Artikelnr)
            
      nStock := IF(! art->Lagerart,999999,art->Bestand)
      FOR nX := 1 TO Len(aAvail)         
         IF aAvail[nX,1] <= AddWeeks(nCurWeek,IF(art->LZ==0,GetConfigValue("DEFAULTS_SUPPLIER_DELTIME"),art->LZ)+1)
            nStock := Min(nStock,aAvail[nX,6])
            
         ENDIF
      NEXT  

      IF lWaldom
         FOR EACH cSupplier IN aSuppliers
            IF lsto->(dbSeek(Pad(cSupplier,8)+Str(art->Artikelnr,6))) .AND. lsto->Stock > 0
               nStock += lsto->Stock
            ENDIF
         NEXT
      ENDIF
      nStock := Round(nStock,GetMeDecimals( art->Me ))

      IF ! art->Lagerart //wenn nicht Lagerf„hig ist (FolgeArtikel) schauen wir ob wir den gleichen Artikel montiert da haben
         nRec := art->(Recno())
         nSaveStock := nStock
         IF art->(dbSeek( SubStr(art->Matchcode,22)+"#MT" ))
            Eval(bGetStock,.F.) //without Waldom to avoid doubles
            nStock += nSaveStock
         ENDIF
         art->(dbGoto(nRec))
      ENDIF
      IF nStock < 0
         nStock := 0
      ENDIF
      RETURN NIL
   }

   CLS
   cFilter := "artikelnr != 0 .OR. waldom"
   shop->(dbSetFilter( {|| shop->(&(cFilter))},cFilter))
   shop->(dbGoTop())

   //Look for currency ID
   cEURID := oSW:GetCurrencyID("EUR")

   //Look for the default price rule
   aRules := oSw:Execute("rule","GET")["data"]
   FOR nX := 1 TO Len(aRules)            
      IF aRules[nX]["attributes"]["name"] == "Always valid (Default)"
         cRuleID := aRules[nX]["id"]
         EXIT
      ENDIF
   NEXT

   IF Empty(cRuleID)
      oErr := ErrorNew()
      oErr:SubSystem   := "SHOPWARE-UPDATE"
      oErr:Description := "No default price rule found"   
      Throw(oErr) 
   ENDIF

   DO WHILE ! shop->(EOF()) .AND. Inkey(,128) != 27
      nStock := 0
      IF shop->Artikelnr == 0 //part not in trader, we only use Waldom stock
         IF wald->(dbSeek( shop->Matchcode ))
            nStock := Round(wald->Stock,0)
         ENDIF
         aPrices := {}
      ELSE
         art->(dbSetOrder( 2 ))
         art->(dbSeek( Str(shop->Artikelnr,6) ))
         Eval(bGetStock)
      ENDIF            
      IF lUpdAll .OR. nStock != shop->Bestand .OR.; //if the stock differs we upload it
         (shop->Artikelnr != 0 .AND. StoT(shop->LastUpd)+HB_RandomInt(20,40) <= Datetime()) //if part is in trader we update the prices every 20-40 days, we use random to try and spread over 20 days
         
         hProdData := {"stock"=>nStock}
         
         IF shop->Artikelnr != 0
            hCSVData  := {"Stock"=>nStock,"Matchcode"=>Trim(shop->Matchcode),"Shopware_uuid"=>shop->UUID,"Partno"=>shop->Artikelnr}         

            IF ! oSW:lLive  //only on staging for now
               //download the current prices
               #ifdef SHOPWARE_UPLOAD
               aProdPrices := oSw:Execute("product/"+shop->UUID+"/prices","GET")["data"]
               FOR nX := 1 TO Len(aProdPrices)      
                  IF aProdPrices[nX]["attributes"]["ruleId"] != cRuleID //this is from a different price rule so we ignore it                  
                     HB_ADel(aProdPrices,nX,.T.)
                  ENDIF
               NEXT
               #endif

               //Add price data
               oArtikel := Artikel():New()
               oArtikel:Load(shop->Artikelnr)
               aPrices := oArtikel:GetSellPrices(Date())               
               IF Len(aPrices) > 0
                  hProdData["prices"] := {}
                  FOR nX := 1 TO Len(aPrices)
                     hCSVData["Quantity "+LTrim(Str(nX))] := Val(Transform(aPrices[nX][1],oArtikel:cPicture))
                     hCSVData["Price "+LTrim(Str(nX))] := aPrices[nX][2]
                     //hCSVData[Int(aPrices[nX][1])] := aPrices[nX][2]
                     #ifdef SHOPWARE_UPLOAD
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
                        
                     IF nX<=Len(aProdPrices) //if we have a price in the shopware DB we update it
                        ATail(hProdData["prices"])["price"][1]["id"] := aProdPrices[nX]["id"]
                     ENDIF
                     #endif
                  NEXT      
               ELSE   
                  hCSVData["Quantity 1"] := 0
                  hCSVData["Price 1"] := 0         
               ENDIF

               //Delete any not used breaks
               #ifdef SHOPWARE_UPLOAD
               FOR nX := Len(aPrices)+1 TO Len(aProdPrices)                                    
                  oSW:Execute("product/"+shop->UUID+"/prices/"+aProdPrices[nX]["id"],"DELETE")                  
               NEXT
               #endif
            ENDIF
            Aadd(aCSV,hCSVData)            
         ENDIF
         #ifdef SHOPWARE_UPLOAD
         hData := oSw:Execute("product/"+shop->UUID,"PATCH",hProdData)
         #endif
         
         
         IF hData != NIL .AND. HHasKey(hData,"errors")
            IF hData["errors"][1]["code"] == "FRAMEWORK__WRITE_TYPE_INTEND_ERROR"
               IF ! Empty(cErr)
                  cErr += Chr(13)+Chr(10)
               ENDIF
               cErr += "Artikel "+shop->Matchcode+" nicht gefunden. Wurde dieses umbenannt?"
            ELSE
               oErr := ErrorNew()
               oErr:SubSystem   := "SHOPWARE-UPDATE"
               oErr:Description := hData["errors"][1]["detail"]+" ("+shop->Matchcode+";"+LTrim(Str(nStock))+") "
               Throw(oErr) 
            ENDIF
         ENDIF
         nUpdate++
      ENDIF
      @ 01,00 SAY shop->UUID+shop->Matchcode+Str(nStock)
      IF oSW:lLive //update record in trader if we are Live
         #ifdef SHOPWARE_UPLOAD
         shop->(Rec_Lock(0))
         shop->Bestand := nStock
         shop->LastUpd := TtoS(DateTime())
         shop->(dbUnlock())
         #endif
      ENDIF
      shop->(dbSkip())
      nCount++
   ENDDO


   art->(dbCloseArea())
   lsto->(dbCloseArea())
   wald->(dbCloseArea())
   shop->(dbCloseArea())

   

   ? "completed. "+LTrim(Str(nCount))
   ? "Updated: "+LTrim(Str(nUpdate))
   ? "It took: "+Str(Seconds()-nStart)   
   
   ? "Length of CSV data:",Len(aCSV)
   
   IF Len(aCSV) != 0
      cFile := GetEnv("temp")+"\stock_prices_"+TtoS(DateTime())+".csv"
      SaveAsCSV(cFile,aCSV)

      /*cCmd := '"'+cScpDir+'\WinScp.com"'
      cParam := '/command "open '+cFTPUrl+' -hostkey=""'+cFTPHostKey+'""" '+;
         '"put '+cFile+'" "stock_price.csv" "exit"'
   
      nStdOUT := 0   
      nProc := HB_OpenProcess(cCmd+" "+cParam,,@nStdOut,,.T.)
      cData := ""
      DO WHILE HB_ProcessValue(nProc,.F.) == -1
         cLine := Space( 1000 )
         nBytes := Fread( nStdOUT, @cLine, Len(cLine) )         
         cData += SubStr(cLine,1,nBytes)       
      ENDDO            
      IF AT("100%",cData) == 0
         SendMail({{"amos.engelking@engelking.de","Amos"}},"Stock and price data upload error",cData)
      ENDIF*/
   ENDIF

   IF ! GetConfigValue("BATCHMODE")
      Sinkey(0)
   ENDIF

   #include "x:\run\shopware.prg"