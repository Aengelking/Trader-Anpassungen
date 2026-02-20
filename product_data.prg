#include 'y:\hb32\include\hbmxml.ch'
#include 'x:\run\product_data\channel_config.ch'


PROCEDURE ProductDataXML(lPrices,lUploadOnly,cChannel)

// Local variables
LOCAL cWEEE, nQtyNoStock, nMaxLZ, nPriceMulti, nWaldomLZ, nConradLiefnr, lDbg
LOCAL cQuoteFile, cFTPUrl, cFTPHostKey, cSCPDir
LOCAL aPriceData := {{}},hPriceData
LOCAL cMatch
LOCAL oArtikel,aPrices,nX
LOCAL nCurWeek := CWeek(Date())
LOCAL aAvail,nStock
LOCAL nArtLZ,nLZ,aMatches,bAddQuote
LOCAL aArtikel := {},aSKU := {},cSKU
LOCAL hManuHoliday := {=>},aWaldHoliday := {Date()+1,Date()-1,0}
LOCAL nAvPreis,hConradPrices,aNewPrices,nPrice,hBuyPrice
LOCAL nH2
LOCAL nMwSt,oErr
LOCAL nRow,nCol
LOCAL nStdOUT,nProc,cData,cCmd,cLine,nBytes,nSecond,hData,lSuccess
LOCAL aRecipients,cSubject
LOCAL oExtra

Default(@cChannel,"conrad")

// Set current channel and load all configurations
IF ! SetCurrentChannel(cChannel)
   RETURN
ENDIF

/******** CHANNEL SETTINGS FROM JSON ********/
cWEEE := GetChannelSetting("company_settings.weee_number")
IF cWEEE == NIL
   cWEEE := "DE 43356265"
ENDIF

nQtyNoStock := GetChannelSetting("inventory_settings.qty_no_stock")
IF nQtyNoStock == NIL
   nQtyNoStock := 1000
ENDIF

nMaxLZ := GetChannelSetting("inventory_settings.max_delivery_weeks")
IF nMaxLZ == NIL
   nMaxLZ := 16
ENDIF

nPriceMulti := GetChannelSetting("pricing_settings.price_multiplier")
IF nPriceMulti == NIL
   nPriceMulti := 1.18
ENDIF

nWaldomLZ := GetGeneralSetting("suppliers.waldom.default_delivery_days")
IF nWaldomLZ == NIL
   nWaldomLZ := 5
ENDIF

nConradLiefnr := GetChannelSetting("inventory_settings.supplier_number")
IF nConradLiefnr == NIL
   nConradLiefnr := 4830
ENDIF

lDbg := GetGeneralSetting("system.debug_default")
IF lDbg == NIL
   lDbg := .T.
ENDIF

// Use standardized export directory and filename convention
cQuoteFile := Path("export\product_data\" + GetCurrentChannel() + ".csv")

cFTPUrl := GetChannelSetting("upload_settings.ftp_fallback.url")
cFTPHostKey := GetChannelSetting("upload_settings.ftp_fallback.host_key")
cSCPDir := GetChannelSetting("upload_settings.ftp_fallback.scp_directory")

/*************************/

Default(@lPrices,.T.)
Default(@lUploadOnly,.F.)

Taxit(1,@nMwSt,Date())
nMwSt := 1+nMwSt/100

NetUse("artikel","art")
NetUse("artlief","ali")
NetUse("liefstock","lsto")
NetUse("buyprice","bpr")
NetUse("waldom","wald")
NetUse("manufact","manu")
NetUse("engkund","ku")
NetUse("shopware","shop")
NetUse("ptcache","ptc")
NetUse("stafprei","stpr")
NetUse("comprice2","cmp2")
IF Select("bte") != 0
   bte->(dbCloseArea())
ENDIF

IF ! lUploadOnly

   DO WHILE (nH2 := IF(File(cQuoteFile),FOpen(cQuoteFile,1),FCreate(cQuoteFile,0))) == -1  //if it exists only open the file (does not delete)
      IF GetConfigValue("BATCHMODE")
         oErr := ErrorNew()
         oErr:SubSystem   := "PRODUCT-DATA-UPLOAD"
         oErr:Description := "File creation error ("+cQuoteFile+" Error: "+LTrim(Str(FError()))+")"
         Throw(oErr)
      ELSEIF Tr_MsgBox("Datei konnte nicht erstellt werden (ERROR: "+LTrim(Str(FError()))+")",,{"erneut versuchen","abbrechen"}) == 2
         RETURN
      ENDIF
   ENDDO

   //Collect Holiday
   ku->(dbSeek( Pad("WALDOM",8)+"L" ))
   oExtra := ku->(ExtraData():New(ku->Nummer))
   IF ku->En_Holiday >= Date()
      aWaldHoliday[1] := ku->St_Holiday
      aWaldHoliday[2] := ku->En_Holiday
      aWaldHoliday[3] := oExtra:RecvTime
   ENDIF
   manu->(dbGoTop())
   ku->(dbSetOrder( 8 ))
   DO WHILE ! manu->(EOF())
      IF manu->Principal
         ku->(dbSeek( Str(manu->Address,6) ))
         oExtra := ku->(ExtraData():New(ku->Nummer))
         IF ku->En_Holiday >= Date()
            hManuHoliday[manu->ID] := {ku->St_Holiday,ku->En_Holiday,oExtra:RecvTime}
         ENDIF
      ENDIF
      manu->(dbSkip())
   ENDDO


   bAddQuote := {|cSku,lArtFound,cProdIdType|
      LOCAL nKey

      IF art->obsolete //.AND. art->Bestand == 0
         IF lDbg
            ?? " obsolete"
         ENDIF
         RETURN .T.
      ENDIF

      IF art->Artikelnr $ aArtikel .AND. cProdIdType == "SHOP_SKU"
         IF lDbg
            ?? " already processed"
         ENDIF
      
         RETURN .T. //Artikel wurde bereits verarbeitet
      ENDIF

      Aadd(aArtikel,art->Artikelnr)

      nArtLZ := IF(art->LZ==0,12,art->LZ)
      hPriceData := {=>}
      hPriceData["product-id"] := cSku
      hPriceData["producer-id[DE-WEEE]"] := cWEEE
      hPriceData["product-id-type"] := cProdIdType
      hPriceData["leadtime-to-ship"] := (nArtLZ+1) * GetGeneralSettingWithDefault("product_defaults.lead_time_multiplier", 5)
      hPriceData["state"] := GetGeneralSettingWithDefault("product_defaults.state", 11)
      hPriceData["reversecharge"] := IF(GetGeneralSettingWithDefault("product_defaults.reversecharge", .F.), "true", "false")
      hPriceData["warehouse"] := GetGeneralSettingWithDefault("product_defaults.warehouse", 1)

      
      oArtikel := Artikel():New()
      oArtikel:Load(art->Artikelnr)
      
      IF lDbg
         ?? " prices"
      ENDIF
      nRow := Row()
      nCol := Col()

      //Get the prices   
      IF ptc->(dbSeek( Str(oArtikel:Artikelnr,6) )) .AND. ptc->LastDate >= Date()-7 .AND. ptc->Prices != "{}" //use cache if it is not older than a week, do it here to speed things up a bit
         aPrices := HB_JsonDecode(ptc->Prices)
      ELSE
         aPrices := oArtikel:GetSellPrices(Date())
      ENDIF

      IF Len(aPrices) > 0
         DO WHILE Len(aPrices) > 0 .AND. aPrices[1,1] == 0
            HB_ADel(aPrices,1,.T.)  //delete all prices with 0 qty
         ENDDO
      ENDIF

      //do we have conrad pricing, then we reduce prices if required
      IF cmp2->(dbSeek( Str(oArtikel:Artikelnr,6)+Str(nConradLiefnr,6) ))  
         nAvPreis := oArtikel:GetAvgBuyPrice(Date())
         
         hConradPrices := HB_Deserialize(cmp2->Daten)
         aNewPrices := {}
         FOR nX := 1 TO Len(hConradPrices)               
            hBuyPrice := GetBuyPrice( Pad("WALDOM",8), oArtikel:Artikelnr, HGetKeyAt(hConradPrices,nX)) 
            nPrice := HGetValueAt(hConradPrices,nX)*0.96/nPriceMulti //4% billiger, PriceMulit gets added again afterwards
            IF nAvPreis > 0 .AND. nPrice > nAvPreis*1.1 .AND. nPrice >= hBuyPrice["price"]/hBuyPrice["unit"]*1.1 //at least 10% above avg buy price
               AAdd(aNewPrices,{HGetKeyAt(hConradPrices,nX),Round(nPrice*oArtikel:VkPe,2)})
            ENDIF
         NEXT
         IF Len(aNewPrices) > 0 .AND. (Len(aPrices) == 0 .OR. aNewPrices[1,2] < aPrices[1,2])
            aPrices := aNewPrices
         ENDIF      
      ENDIF

      SetPos(nRow,nCol)   
      IF lDbg
         ?? " ok"
      ENDIF
      
      IF Len(aPrices) >= 1 .AND. aPrices[1,2] != 0  //nur Artikel mit Preisen werden hinzugefÅgt
         IF Trim(oArtikel:Matchcode) $ {"PX0686"} //testing to see what happens with competitive pricing
               //discount prices
               IF Trim(oArtikel:Matchcode) == "PX0686" //calculated with a avg. buy price of 2.50? or Waldom 2.99
                  aPrices := {{1,5.83},{10,5.75},{25,5.65},{50,5.55},{100,5.40}}
               ELSE //calculated with a avg. buy price of 1.76? or Waldom 2.19
                  aPrices := {{1,3.90},{5,3.70},{10,3.62},{25,3.55},{50,3.52},{100,3.42}}       
               ENDIF
               FOR nX := 1 TO Len(aPrices)
                  aPrices[nX,2] := aPrices[nX,2]*oArtikel:VkPe/nPriceMulti  //this gets multiplied again later
               NEXT
            //ENDIF
         ENDIF
         
         hPriceData["price"] :=  Round(aPrices[1,2]/oArtikel:VkPe*nMwSt*nPriceMulti,2) //Preis fÅr ein StÅck      

         hPriceData["min-order-quantity"] := Max(1,aPrices[1,1]) //Mindestbestellmenge auf die erste Staffel setzten

         hPriceData["discount-ranges"] := ""
         FOR nX := 2 TO Len(aPrices)
            IF aPrices[nX,1] <= 100 //we do not display prices for qty's greater than 100pcs
               IF nX > 2
                  IF Round(aPrices[nX,2],2) <= Round(aPrices[nX-1,2],2) //due to the rounding it can happen that prices are the same, we need to skip these
                     LOOP
                  ENDIF
                  hPriceData["discount-ranges"] += ","
               ENDIF   
               hPriceData["discount-ranges"] += LTrim(Transform(aPrices[nX,1],Me(art->Me)))+"|"+lTrim(Str(aPrices[nX,2]/oArtikel:VkPe*nMwSt*nPriceMulti,12,2))
            ENDIF
         NEXT
      
         IF lArtFound   
            
            aAvail := GetKwQty(art->Artikelnr)
            
            
            nStock := art->Bestand //GetKwStock(art->Artikelnr,AddWeeks(nCurWeek,nArtLZ+1),aAvail) //VerfÅgbarer Lagerbestand. Wir verwenden die Menge die nach der LZ noch verfÅgbar wÑre
            For nX := 1 To Len(aAvail)
               If aAvail[nX,1] <= AddWeeks(nCurWeek,nArtLZ+1)
                  nStock := Min(nStock,aAvail[nX,6])
               Endif
            Next      

            hPriceData["sku"] := LTrim(Str(art->Artikelnr,6))+"S"
            IF art->Bestand > 0 .AND. nStock > 0 //Lagerbestand                                                      
               hPriceData["quantity"] := Val(Transform(Min(nStock,art->Bestand),Me(art->Me)))
               IF hPriceData["min-order-quantity"] > hPriceData["quantity"]
                  hPriceData["min-order-quantity"] := Max(1,hPriceData["quantity"])               
               ENDIF
               hPriceData["leadtime-to-ship"] := 1
               AddHash(aPriceData,hPriceData)
            ELSE
               hPriceData["quantity"] := 0
               hPriceData["leadtime-to-ship"] := 0
               hPriceData["update-delete"] := "delete"
               //AddHash(aPriceData,hPriceData) //upload this, to make sure that the stock will be reset if there was any
               //we use the upload type replace instead so this does not need to be uploaded
            ENDIF

            bpr->(dbSetOrder( 2 ))

            hPriceData["sku"] := LTrim(Str(art->Artikelnr,6))+"W"
            IF lsto->(dbSeek(Pad("WALDOM",8)+Str(art->Artikelnr,6))) .AND. lsto->Stock > 0 .AND. bpr->(dbSeek(Str(art->Artikelnr,6)+Pad("WALDOM",8))) //Waldom hat Bestand  
               hPriceData["update-delete"] := ""                            
               hPriceData["quantity"] := lsto->Stock
               
               hPriceData["leadtime-to-ship"] := _AddHoliday(nWaldomLZ,aWaldHoliday) //LZ in Tagen, mindestens 1
               AddHash(aPriceData,hPriceData) 

               //set min order quantity to the qty we get from waldom, do this in the cloned hash
               nKey := AScan(aPriceData[1],"min-order-quantity") //search in header for column
               //Atail(aPriceData)[nKey] := bpr->Qty //set to Waldom MOQ
               //Atail(aPriceData)[nKey] := 1

               IF Trim(art->Matchcode) == "FX0385"  //change warehouse for drop shipping items
                  //nKey := AScan(aPriceData[1],"warehouse") //search in header for column
                  //Atail(aPriceData)[nKey] := 2 //drop shipping form Waldom
               ENDIF
            ELSE
               hPriceData["quantity"] := 0
               hPriceData["leadtime-to-ship"] := 0
               hPriceData["update-delete"] := "delete"
               //AddHash(aPriceData,hPriceData) //upload this, to make sure that the stock will be reset if there was any   
            ENDIF         
            

            hPriceData["sku"] := LTrim(Str(art->Artikelnr,6))+"I"
            IF nStock > art->bestand //Wir haben auch noch welche im Zulauf  
               hPriceData["update-delete"] := ""                            
               hPriceData["quantity"] := nStock-art->Bestand
               nLZ := WeeksBetween(nCurWeek,GetAvailKw( art->Artikelnr, nStock, aAvail )) //Lieferzeit in Wochen                           
               IF nLz <= nMaxLZ .AND. nLZ < nArtLZ //nur hinzufÅgen wenn innerhalb der max. erlaubten Lieferzeit und kleiner als die Standardlieferzeit               
                  hPriceData["leadtime-to-ship"] := Max(1, nLZ * GetGeneralSettingWithDefault("product_defaults.lead_time_multiplier", 5))
                  AddHash(aPriceData,hPriceData)
               ENDIF
            ELSE
               hPriceData["quantity"] := 0
               hPriceData["leadtime-to-ship"] := 0
               hPriceData["update-delete"] := "delete"
               //AddHash(aPriceData,hPriceData) //upload this, to make sure that the stock will be reset if there was any
            ENDIF
         ENDIF

         IF nArtLZ+1 <= nMaxLZ //die Standardlieferzeit auf diesem Artikel ist geringer als die Maximal erlaubte                            
            hPriceData["sku"] := LTrim(Str(art->Artikelnr,6))+"P"
            IF ! lArtFound
               aMatches := HB_Regex("\/(06|24)\/",cMatch)
               hPriceData["sku"] += "-"+aMatches[2]
            ENDIF  
            hPriceData["update-delete"] := ""                                                     
            hPriceData["quantity"] := nQtyNoStock
            IF HHasKey(hManuHoliday,art->Manufactur)
               hPriceData["leadtime-to-ship"] := _AddHoliday( (nArtLZ+1)*5, hManuHoliday[art->Manufactur] )
            ELSE
               hPriceData["leadtime-to-ship"] := (nArtLZ+1)*5                           
            ENDIF
            AddHash(aPriceData,hPriceData)
         ENDIF          
      ENDIF
      IF ! lDbg
         @ 01,00 SAY Str(Len(aPriceData)) 
      ENDIF
      RETURN .T.
   }

   CLS

   //all parts we know are listed on Conrad anyway
   IF cChannel == "conrad" .AND. (GetConfigValue("BATCHMODE") .OR. Tr_MsgBox("Artikel mit Conrad-Artikelnr",,{"Ja","Nein"}) == 1)

      Select("art")
      SET FILTER TO art->Manufactur == 1  
      art->(dbGoTop())
      ali->(dbSeek(Pad("CONRAD",8)))
      DO WHILE ! ali->(EOF()) .AND. Trim(ali->Kunde) == "CONRAD"
         IF lDbg
            ? ali->artlief
         ENDIF
         art->(dbSetOrder( 2 )) //order by Artikelnr
         IF ! Empty(ali->Artlief) .AND. art->(dbSeek(Str(ali->Artikelnr,6))) 
            //@ 00,00 SAY art->Matchcode
            IF lDbg
               ?? art->Matchcode
            ENDIF
            Eval(bAddQuote,Trim(ali->Artlief),.T.,"SKU")
         ENDIF
         
         ali->(dbSkip())
      ENDDO
      /*DO WHILE ! art->(EOF())
         IF ali->(dbSeek(Pad("CONRAD",8)+Str(art->Artikelnr,6))) .AND. ! Empty(ali->Artlief) .AND. ! Val(ali->Artlief) $ hExclude
            @ 00,00 SAY art->Matchcode
            hPriceData := {=>} 
            Eval(bAddQuote,Trim(ali->Artlief),.T.,"SKU")
         ENDIF
         art->(dbSkip())
      ENDDO*/

      art->(dbClearFilter())
   ENDIF

   //all parts we have online
   art->(dbSetOrder( 2 )) //order by Artikelnr
   //shop->(dbSetFilter({|| shop->HasImage },"HasImage")) //only products with image
   shop->(dbGoTop())
   DO WHILE ! shop->(EOF()) .AND. Inkey(,128) != 27 //ESC   
      IF shop->Artikelnr != 0 //we currently cannot calculate prices for parts without a part
         IF lDbg
            ? shop->Matchcode   
            ?? shop->Artikelnr
         ENDIF
         art->(dbSetOrder( 2 )) //order by Artikelnr
         art->(dbSeek(Str(shop->Artikelnr,6)))
         
         Eval(bAddQuote,StrTran(Trim(shop->Matchcode),"#MT",""),shop->Artikelnr != 0,"SHOP_SKU")
      ELSEIF Left(shop->Matchcode,2) == "CM"  //add all CM/CMI parts even if they are not in our artikel database
         IF lDbg
            ? shop->Matchcode   
         ENDIF
         cSKU := StrTran(Trim(shop->Matchcode),"/","-")
         IF ! cSKU $ aSKU
            hPriceData := {=>}
            hPriceData["product-id"] := Trim(shop->Matchcode)
            hPriceData["producer-id[DE-WEEE]"] := cWEEE
            hPriceData["product-id-type"] := "SHOP_SKU"
            hPriceData["leadtime-to-ship"] := (3+1) * GetGeneralSettingWithDefault("product_defaults.lead_time_multiplier", 5)
            hPriceData["state"] := GetGeneralSettingWithDefault("product_defaults.state", 11)
            hPriceData["reversecharge"] := IF(GetGeneralSettingWithDefault("product_defaults.reversecharge", .F.), "true", "false")
            hPriceData["warehouse"] := GetGeneralSettingWithDefault("product_defaults.warehouse", 1)
            
            aPrices := ONPOW_PRICING(shop->Matchcode)
            IF Len(aPrices) >= 1 .AND. aPrices[1,2] != 0  //nur Artikel mit Preisen werden hinzugefÅgt
               ?? " prices generated without part"
               FOR nX := 1 TO Len(aPrices)
                  //aPrices[nX,2] := aPrices[nX,2]*oArtikel:VkPe/nPriceMulti  //this gets multiplied again later
                  aPrices[nX,2] := aPrices[nX,2]/nPriceMulti  //this gets multiplied again later
               NEXT
            

               //hPriceData["price"] :=  aPrices[1,2]/oArtikel:VkPe*nMwSt*nPriceMulti //Preis fÅr ein StÅck
               hPriceData["price"] :=  aPrices[1,2]*nMwSt*nPriceMulti //Preis fÅr ein StÅck
               hPriceData["min-order-quantity"] := Max(1,aPrices[1,1]) //Mindestbestellmenge auf die erste Staffel setzten

               hPriceData["discount-ranges"] := ""
               FOR nX := 2 TO Len(aPrices)
                  IF aPrices[nX,1] <= 100 //we do not display prices for qty's greater than 100pcs
                     IF nX > 2
                        hPriceData["discount-ranges"] += ","
                     ENDIF   
                     //hPriceData["discount-ranges"] += LTrim(Str(aPrices[nX,1],12,0))+"|"+lTrim(Str(aPrices[nX,2]/oArtikel:VkPe*nMwSt*nPriceMulti))
                     hPriceData["discount-ranges"] += LTrim(Str(aPrices[nX,1],12,0))+"|"+lTrim(Str(aPrices[nX,2]*nMwSt*nPriceMulti))
                  ENDIF
               NEXT
         
               hPriceData["sku"] := cSKU
               hPriceData["update-delete"] := ""                                                     
               hPriceData["quantity"] := nQtyNoStock                             
               
               AddHash(aPriceData,hPriceData)

               Aadd(aSKU,cSKU)
            ENDIF
         ENDIF     
      ENDIF
      shop->(dbSkip())
   ENDDO
   shop->(dbClearFilter())

   CLS
   //? "Anzahl:",Len(aData)-1
   ? "Anzahl Preise:",Len(aPriceData)-1
   IF ! GetConfigValue("BATCHMODE")
      Sinkey(0)
   ENDIF

   //FClosE(nH)
   FClose(nH2)

   //SaveAsCSV(cPDFile,aData,.T.)
   IF GetChannelSettingWithDefault("upload_settings.method", "API") == "DIGIKEY_API"
      MemoWrit(cQuoteFile,HB_JsonEncode(aPriceData))
   ELSE
      SaveAsCSV(cQuoteFile,aPriceData,.T.)
   ENDIF 
ELSE
   //Alert("Upload only mode, skipping data preparation")
   IF GetChannelSettingWithDefault("upload_settings.method", "API") == "DIGIKEY_API"
      aPriceData := HB_JsonDecode(MemoRead(cQuoteFile))
   ENDIF
ENDIF



IF GetConfigValue("BATCHMODE") .OR. Tr_MsgBox("Run upload script?",,{"Yes","No"}) == 1
   // Get upload method from configuration
   IF GetChannelSettingWithDefault("upload_settings.method", "API") == "DIGIKEY_API"
      lSuccess := DigiKey_UploadOffersV2(aPriceData, cChannel)
      cData := IF(lSuccess, "OK", "DigiKey upload failed")
   ELSEIF GetChannelSettingWithDefault("upload_settings.method", "API") == "API"
      // Build API upload command from configuration
      cCmd := GetChannelSettingWithDefault("upload_settings.api.curl_path", "c:\curl\bin\curl")
      cCmd += " -s -X POST " + GetChannelSetting("upload_settings.api.url")
      cCmd += ' -H "Authorization: ' + GetChannelSetting("upload_settings.api.authorization") + '" '
      cCmd += ' -H "Content-Type: ' + GetChannelSettingWithDefault("upload_settings.api.content_type", "multipart/form-data") + '" '
      cCmd += ' -F "file=@'+cQuoteFile+'" '
      cCmd += ' -F "import_mode=' + GetChannelSettingWithDefault("upload_settings.api.import_mode", "REPLACE") + '"'
      cCmd += ' -F "operator_format=' + IF(GetChannelSettingWithDefault("upload_settings.api.operator_format", .T.), "true", "false") + '"'
      cCmd += ' -F "with_products=' + IF(GetChannelSettingWithDefault("upload_settings.api.with_products", .F.), "true", "false") + '"'
   ELSE
      // Build FTP upload command from configuration
      cCmd := '"'+cScpDir+'\WinScp.com" '
      cCmd += '/command "open '+cFTPUrl+' -hostkey=""'+cFTPHostKey+'""" '+;
         '"put '+cQuoteFile+'" "exit"'
   ENDIF
   /*gtSetClipboard(cCmd+" "+cParam)
   WAPI_ShellExecute(,"open",cCmd,cParam)*/    //-hostkey="ssh-rsa 2048 '+cFTPHostKey+'"'+;
   
   IF GetChannelSettingWithDefault("upload_settings.method", "API") != "DIGIKEY_API"
      nStdOUT := 0   
      nProc := HB_OpenProcess(cCmd,,@nStdOut,,.T.)
      cData := ""

      nSecond := Seconds()
      DO WHILE HB_ProcessValue(nProc,.F.) == -1
         cLine := Space( 1000 )
         nBytes := Fread( nStdOUT, @cLine, Len(cLine) )         
         cData += SubStr(cLine,1,nBytes)       
         IF Seconds() - nSecond > GetChannelSettingWithDefault("upload_settings.api.timeout_seconds", 30)
            ? "timeout"
            EXIT
         ENDIF
      ENDDO            
      
      // Check success based on upload method
      IF GetChannelSettingWithDefault("upload_settings.method", "API") == "API"
         hData := HB_JsonDecode(cData)
         lSuccess := ValType(hData) == "H" .AND. HHasKey(hData,"import_id")
      ELSE //FTP
         lSuccess := AT("100%",cData) != 0
      ENDIF
   ENDIF
   
   IF ! lSuccess
      // Get error notification settings from configuration
      /*aRecipients := GetChannelSetting("notification_settings.error_email.recipients")
      IF aRecipients == NIL
         aRecipients := {}
      ENDIF
      cSubject := GetChannelSettingWithDefault("notification_settings.error_email.subject", "Upload Error")*/
      SendMessage("Produktmanagement | Angebotsupload fehlgeschlagen", "Upload fehlgeschlagen: "+cChannel, "Response:<br>"+cData)
   ELSEIF ! GetConfigValue("BATCHMODE")
      Alert("Uploaded successfully")
   ENDIF

ENDIF


RETURN

STATIC FUNCTION AddHash(aData,hData)
   LOCAL cValue,cKey,nKey   
   Aadd(aData,Array(Len(aData[1])))
   FOR EACH cValue IN hData
      cKey := cValue:__eNumKey()
      nKey := AScan(aData[1],cKey)
      IF nKey == 0
         Aadd(aData[1],cKey)
         Aadd(Atail(aData),NIL)
         nKey := Len(aData[1])
      ENDIF
      Atail(aData)[nKey] := cValue
   NEXT
RETURN NIL

STATIC FUNCTION _AddHoliday(nLZ,aHoliday)
   IF Date() <= aHoliday[2]; //we are before the End of the the holiday
      .AND. Date()+nLZ-aHoliday[3] >= aHoliday[1] //and it will not be shipped before their holiday 
      
      nLZ := aHoliday[2]-Date()+1+nLZ //nLZ from the day after the holiday

   ENDIF
RETURN nLZ

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

#include 'onpow_part_no.prg'
#include 'onpow_prices.prg'
#include 'x:\run\product_data\channel_config.prg'
#include 'x:\run\product_data\digikey_api.prg'