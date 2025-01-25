PROC RUN_SHOPWARE_PRODUCTS  //donwload product ID's from website (this will run at night)
   LOCAL hSendData
   LOCAL nLimit := 5000
   LOCAL nDown  := 0
   LOCAL nFound := 0   
   LOCAL nWald  := 0
   LOCAL nPage  := 1
   LOCAL hProdData   
   LOCAL lSave

   LOCAL oSW := ShopWareAPI():New() 

   NetUse("shopware","shop")
   NetUse("artikel","art")
   NetUse("waldom","wald")
   
   //"filter"=>{{"type"=>"not","queries"=>{{"type"=>"equals","field"=>"parentId","value"=>NIL}}}},;
   //this filter was going to exlude all parents ofvariant products, but also exludes all single products too

   hSendData := {;       
      "includes"=>{;
         "product"=>{; //only the fields we really need
            "id",;
            "productNumber";
         };
      },;
      "limit"=>nLimit,;
      "page"=>1; 
   }
   
   Head("Downloading product ID's from Shopware")

   

   @ 01,00 SAY "Downloaded:"
   @ 02,00 SAY "Found:"
   @ 03,00 SAY "Waldom:"

   shop->(dbSetOrder( 2 ))  //UUID

   DO WHILE .T.    

      hSendData["page"] := nPage

      hProdData := oSw:Execute("search/product","POST",hSendData)      
      IF ! HHasKey(hProdData,"data")
         ?? "Fehler beim Herunterladen der Daten."
         IF HHasKey(hProdData,"errors")
            ? hProdData["errors"][1]["detail"]
         ELSE
            ? ValToPrg(hProdData)
         ENDIF
         EXIT
      ENDIF      
      nDown += Len(hProdData["data"])
      
      @ 01,13 SAY Str(nDown,10)

      AEval(hProdData["data"],{|aData| 
         LOCAL nArtnr := 0
         LOCAL lFound,nRec
         
         IF art->(dbSeek( aData["attributes"]["productNumber"] ))            
            nArtnr := art->Artikelnr
            nFound++
         ENDIF         

         //save in DB, if no part is found then for future use, e.g. when the product is created
         //lSave := .F.
         IF nArtnr != 0
            shop->(dbSetOrder( 1 ))
            lFound := shop->(dbSeek( Str(nArtnr,6) ))
            IF lFound
               nRec := shop->(Recno())

               //check for duplicates and delete them
               shop->(dbSkip(1))
               DO WHILE ! shop->(Eof()) .AND. shop->Artikelnr == nArtnr
                  shop->(Rec_Lock(0))
                  shop->(dbDelete())
                  shop->(dbDelete())
                  shop->(dbSkip(1))
               ENDDO
               shop->(dbGoto(nRec))
            ENDIF
         ELSE
            shop->(dbSetOrder( 2 ))
            lFound := shop->(dbSeek( aData["id"] ))
         ENDIF

         IF lFound
            shop->(Rec_Lock(0))
            //lSave := .T.            
         ELSE
            shop->(Add_Rec(0))
             
            //lSave := .T.
         ENDIF
         //IF lSave    
         shop->UUID := aData["id"]         
            IF nArtnr != shop->Artikelnr
               shop->Bestand   := 0
            ENDIF
            shop->Artikelnr := nArtnr
            shop->Matchcode := aData["attributes"]["productNumber"]
            IF nArtnr == 0 .AND. wald->(dbSeek(aData["attributes"]["productNumber"]))
               shop->Waldom := .T.
               nWald++
            ELSE
               shop->Waldom := .F.
            ENDIF
            shop->(dbUnLock())
         //ENDIF

         @ 02,13 SAY Str(nFound,10)
         @ 03,13 SAY Str(nWald,10)

         RETURN .T.
      })
      //@ 01,13 SAY Str(nDown,10)
      @ 02,13 SAY Str(nFound,10)
      @ 03,13 SAY Str(nWald,10)
      IF Len(hProdData["data"]) < nLimit //we received less than one page, all data has been downloaded         
         EXIT
      ENDIF   
      nPage++   
   ENDDO
   //? "completed"
   IF ! GetConfigValue("BATCHMODE")
      ? "completed"
      SInkey(0)
   ENDIF

   #include 'x:\run\shopware.prg'