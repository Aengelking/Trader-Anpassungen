PROC Shopware_Stock_Price
   /** SETTINGS ***/

   LOCAL aSuppliers := {"WALDOM"}
   LOCAL lUpdAll    := GetValue("SW_UPD_ALL",.F.,"Best„nde aller Artikel aktualisiern (1x)")
   LOCAL aErrorTo   := {{"amos.engelking@engelking.de","Amos"}}
   /** END OF SEETING ***/

   LOCAL oSW := ShopWareAPI():New()   
   LOCA cFilter := 'At("KS",matchcode) != 1 .AND. Trim(Type) == "WARE" .AND. ! Obsolete'
   LOCAL hSendData,hProdData,oExtra
   LOCAL hData,oErr,aAvail,nStock,nX,cSupplier
   
   LOCAL nCurWeek := CWeek(Date())
   LOCAL nStart := Seconds()
   LOCAL bGetStock
   LOCAL nCount := 0
   LOCAL nUpdate := 0

   NetUse("artikel","art")
   NetUSe("liefstock","lsto")
   NetUse("waldom","wald")
   NetUse("shopware","shop")

   IF lUpdAll
      SetValue("SW_UPD_ALL",.F.)
   ENDIF

   /*art->(dbSetFilter({|| art->(&(cFilter))},cFilter))
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
   }*/

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
   }

   CLS
   cFilter := "artikelnr != 0 .OR. waldom"
   shop->(dbSetFilter( {|| shop->(&(cFilter))},cFilter))
   shop->(dbGoTop())


   DO WHILE ! shop->(EOF())
      nStock := 0
      IF shop->Artikelnr == 0 //part not in trader, we only use Waldom stock
         IF wald->(dbSeek( shop->Matchcode ))
            nStock := Round(wald->Stock,0)
         ENDIF
      ELSE
         art->(dbSetOrder( 2 ))
         art->(dbSeek( Str(shop->Artikelnr,6) ))
         Eval(bGetStock)
      ENDIF
      IF lUpdAll .OR. nStock != shop->Bestand //if the stock differs we upload it
         hData := oSw:Execute("product/"+shop->UUID,"PATCH",{;
                  "stock"=>nStock;                  
         })
         
         IF hData != NIL .AND. HHasKey(hData,"errors")
            oErr := ErrorNew()
            oErr:SubSystem   := "SHOPWARE-UPDATE"
            oErr:Description := hData["errors"][1]["detail"]+" ("+shop->Matchcode+";"+LTrim(Str(nStock))+") "
            Throw(oErr) 
         ENDIF
         nUpdate++
      ENDIF
      @ 01,00 SAY shop->UUID+shop->Matchcode+Str(nStock)
      shop->(Rec_Lock(0))
      shop->Bestand := nStock
      shop->(dbUnlock())
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


   #include "x:\run\shopware.prg"