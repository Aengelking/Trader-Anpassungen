PROC Shopware_Stock_Price
   /** SETTINGS ***/

   LOCAL aSuppliers := {"WALDOM"}
   LOCAL lUpdAll    := GetValue("SW_UPD_ALL",.F.,"Best„nde aller Artikel aktualisieren (1x)")
   LOCAL aErrorTo   := {{"amos.engelking@engelking.de","Amos"}}
   /** END OF SEETING ***/

   LOCAL oSW := ShopWareAPI():New()   
   LOCA cFilter := 'At("KS",matchcode) != 1 .AND. Trim(Type) == "WARE" .AND. ! Obsolete'
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
      ? aRules[nX]["attributes"]["name"]
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

   DO WHILE ! shop->(EOF())
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
         (shop->Artikelnr != 0 .AND. StoT(shop->LastUpd)+30 <= Datetime()) //if part is in trader we update the prices every 30 days
         
         hProdData := {"stock"=>nStock}
         
         IF shop->Artikelnr != 0
            IF ! oSW:lLive  //only on staging for now
               //download the current prices
               aProdPrices := oSw:Execute("product/"+shop->UUID+"/prices","GET")["data"]
               FOR nX := 1 TO Len(aProdPrices)      
                  IF aProdPrices[nX]["attributes"]["ruleId"] != cRuleID //this is from a different price rule so we ignore it                  
                     HB_ADel(aProdPrices,nX,.T.)
                  ENDIF
               NEXT

               //Add price data
               oArtikel := Artikel():New()
               oArtikel:Load(shop->Artikelnr)
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
                        
                     IF nX<=Len(aProdPrices) //if we have a price in the shopware DB we update it
                        ATail(hProdData["prices"])["price"][1]["id"] := aProdPrices[nX]["id"]
                     ENDIF
                  NEXT
                  ? ValToPrg(hProdData["prices"])
               ENDIF

               //Delete any not used breaks
               FOR nX := Len(aPrices)+1 TO Len(aProdPrices)                  
                  oSW:Execute("product/"+shop->UUID+"/prices/"+aProdPrices[nX]["id"],"DELETE")
               NEXT
            ENDIF
         ENDIF
         hData := oSw:Execute("product/"+shop->UUID,"PATCH",hProdData)
         
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
         shop->(Rec_Lock(0))
         shop->Bestand := nStock
         shop->LastUpd := TtoS(DateTime())
         shop->(dbUnlock())
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
   ? cErr
   IF ! GetConfigValue("BATCHMODE")
      Sinkey(0)
   ENDIF

   #include "x:\run\shopware.prg"