PROC Shopware_Stock_Price
   /** SETTINGS ***/
   LOCAL nUpdateEvery := GetValue("SW_UPDEVERY",1/24,"Update IDs every x days") //Time in fractions of a day
   LOCAL aSuppliers := {"WALDOM"}
   LOCAL lOnlyNoId  := GetValue("SW_UPDNOIDONLY",.T.,"Only update ID of parts with no ID")
   LOCAL lOnlyStock := GetValue("SW_UPDSTOCKONLY",.T.,"Only update ID of parts with stock")
   /** END OF SEETING ***/

   LOCAL oSW := ShopWareAPI():New()   
   LOCA cFilter := 'At("KS",matchcode) != 1 .AND. Trim(Type) == "WARE" .AND. ! Obsolete'
   LOCAL hSendData,hProdData,oExtra
   LOCAL hData,oErr,aAvail,nStock,nX,cSupplier
   
   LOCAL nCurWeek := CWeek(Date())
   LOCAL nStart := Seconds()
   LOCAL bGetStock

   NetUse("artikel","art")
   NetUSe("liefstock","lsto")

   art->(dbSetFilter({|| art->(&(cFilter))},cFilter))
   art->(dbGoTop())

   hSendData := {;
      "filter"=>{;
         {;		   
            "type"=>"multi",;
            "operator"=>"and",;
            "queries"=>{;                  
               {;
                  "type"=>"equals",;
                  "field"=>"productNumber",;
                  "value"=>""; 
               };
            };    
         };     
      },;
      "associations"=>{; 
         "properties"=>{},; //get all used properties			   		   
         "options"=>{}; //get all options, these are the ones set by the variantions
      },;	
      "includes"=>{;
         "product"=>{; //only the fields we really need
            "id";
         };
      },;
      "limit"=>1;
   }

   bGetStock := {||
      aAvail := GetKwQty(art->Artikelnr)
            
      nStock := art->Bestand //GetKwStock(art->Artikelnr,AddWeeks(nCurWeek,nArtLZ+1),aAvail) //VerfÅgbarer Lagerbestand. Wir verwenden die Menge die nach der LZ noch verfÅgbar wÑre
      FOR nX := 1 TO Len(aAvail)
         IF aAvail[nX,1] <= AddWeeks(nCurWeek,IF(art->LZ==0,12,art->LZ)+1)
            nStock := Min(nStock,aAvail[nX,6])
         ENDIF
      NEXT  

      FOR EACH cSupplier IN aSuppliers
         IF lsto->(dbSeek(Pad(cSupplier,8)+Str(art->Artikelnr,6))) .AND. lsto->Stock > 0
            nStock += lsto->Stock
         ENDIF
      NEXT
      nStock := Round(nStock,GetMeDecimals( art->Me ))
   }

   CLS

   DO WHILE ! art->(EOF())
      ? art->Artikelnr
      
      IF lOnlyStock
         Eval(bGetStock)
      ENDIF

      oExtra := art->(ExtraData():New(art->Artikelnr))
      IF (! lOnlyStock .OR. nStock > 0) .AND. (! lOnlyNoId .OR. Empty(oExtra:SW_ID)) .AND. StoT(oExtra:SW_Last)+nUpdateEvery <= DateTime() //Update the ID every nUpdateEvery
         ? art->Matchcode,oExtra:SW_ID,TtoC(StoT(oExtra:SW_Last))
         hSendData["filter"][1]["queries"][1]["value"] := hb_StrToUtf8(art->Matchcode)
         hProdData := oSw:Execute("search/product","POST",hSendData)
         IF hProdData == NIL
            oErr := ErrorNew()
            oErr:SubSystem   := "SHOPWARE-UPDATE"
            oErr:Description := "NO DATA RECEIVED"
            Throw(oErr) 
         ELSEIF HHasKey(hProdData,"errors")
            oErr := ErrorNew()
            oErr:SubSystem   := "SHOPWARE-UPDATE"
            oErr:Description := hProdData["errors"][1]["detail"]
            Throw(oErr) 
         ENDIF
         IF Len(hProdData["data"]) > 0 //product found online                  
            ?? "",hProdData["data"][1]["id"]
            oExtra:SW_ID := hProdData["data"][1]["id"]         
         ENDIF
         oExtra:SW_Last := TtoS(DateTime())
         oExtra:Save()
      ENDIF

      IF ! Empty(oExtra:SW_ID)
         IF ! lOnlyStock //we did not get the stock before
            Eval(bGetStock)
         ENDIF   

         IF oExtra:SW_STOCK != nStock //Stock has changed

            ? art->Matchcode,oExtra:SW_ID,nStock

            hData := oSw:Execute("product/"+oExtra:SW_ID,"PATCH",{;
                     "stock"=>nStock;                  
            })
            
            IF hData != NIL .AND. HHasKey(hData,"errors")
               oErr := ErrorNew()
               oErr:SubSystem   := "SHOPWARE-UPDATE"
               oErr:Description := hData["errors"][1]["detail"]
               Throw(oErr) 
            ENDIF
            
            oExtra:SW_STOCK := nStock
            oExtra:Save()
         ENDIF
      ENDIF

      art->(dbSkip())
      IF Inkey() == 27
         EXIT
      ENDIF
   ENDDO

   art->(dbCloseArea())
   lsto->(dbCloseArea())

   //Alert("It took: "+Str(Seconds()-nStart))

   #include "x:\run\shopware.prg"