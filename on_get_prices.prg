FUNC HOOK_ON_GET_PRICES( aPriceTabs,nArtnr,nTab,dDate,cKundma )

LOCAL nRate,nMulti, nX, nManu, lSubDistiGBP := .F., lPackOnly, nVPE, oArt, nWeight, lFound, nPrice, nPausch, nSubArt, nInternalCost, nHourlyRate
LOCAL hPrice, nSecs := Seconds(), nTabSecs, nY, hCostOO, nQ, nC, nP
LOCAL nSubAufschlag := 0.3, nSubSpecial := 0.2, aSubSpecial := {"MONACOR"}
LOCAL oExtra, cMatch, nEx, nFixRate, aSkonto, nTable, aAddPriceTab, aPartPriceTabs, nAddPrice, cLiefma
LOCAL oArtExtra,nVPEPack
LOCAL nVK,nQty
LOCAL aData, cInfoData, cDebugInfo
LOCAL aSubDistis := {=>}
LOCAL cSupplier,aAvail,nAvailableStock,nEk
LOCAL aQty,oFolArt

NetUse("ptcache","ptc")
//use cache if it is not older than a week (or a month for tab 60=Engelking)
//we cannot do this here as this function might be called several times per part e.g. gepr�fter preis
/*IF ptc->(dbSeek( Str(nArtnr,6) )) .AND. ptc->LastDate >= Date()-IF(nTab==60,30,7) .AND. ptc->Prices != "{}" .AND. Empty(cKundMa) .AND. dDate <= Date()
   RETURN HB_JsonDecode(ptc->Prices)
ENDIF*/

NetUse("engkund","ku")
IF ! Empty(cKundma)
   ku->(dbSeek( cKundma+"K" ))
   oExtra := ku->(ExtraData():New( ku->Nummer ))
ENDIF

oArtExtra := art->(ExtraData():New( nArtnr ))


oArt := Artikel():New()
oArt:Load(nArtnr)

//?? "_ ("+Trim(art->Matchcode)+" "+Ltrim(Str(nTab,2))+") "

//Adjust to VPE and VPEPACK
IF oArtExtra:VPE != 0
   nVPE := oArtExtra:VPE
ELSEIF ! Empty(art->VPE)
   nVPE := art->VPE
ELSE
   nVPE := 50
ENDIF
IF oArtExtra:VPEPack != 0
   nVPEPack := oArtExtra:VPEPack
ELSE
   nVPEPack := 20*nVPE
ENDIF
AEval(aPriceTabs,{|aTab| 
   IF aTab[1] < 0
      aTab[1] := ABS(aTab[1])*nVPE
      IF aTab[1] > nVPEPack
         aTab[1] := CeilingMe(aTab[1]/nVPEPack,Me(art->Me))*nVPEPack
      ENDIF
   ENDIF
})


IF AT("CMI57",art->Matchcode) == 1   
   NetUse("parts","part")
   nTable := art->Table
   art->(dbSetOrder( 1 ))
   IF art->(dbSeek( "p"+LTrim(Str(art->Artikelnr))+".SWITCH" ))      
      aPriceTabs := GetPrices(art->Artikelnr,nTable,dDate,cKundma)
      RETURN aPriceTabs
   ENDIF
ENDIF

IF art->Manufactur == 9 .AND. (AT("/PB",art->Matchcode) != 0 .OR. Left(art->Matchcode,2) == "KS") //.AND. art->Gruppe == "KANK"
   NetUse("parts","part")
   art->(dbSetOrder( 2 ))
      

   part->(dbSeek( Str(nArtnr,6) ))
   lPackOnly := .T.
   DO WHILE part->Listart == nArtnr .AND. lPackOnly
      art->(dbSeek( Str(part->Partart,6) ))      
      IF part->Pos <= 0 .OR. At("KARTON",art->Matchcode) == 1 .OR. AT("BEUTEL",art->Matchcode) == 1 //nur Verpackung in Beutel
         //do nothing
      ELSEIF AT("NZ/",art->Matchcode) == 1 .OR. AT("PA",art->Matchcode) == 1
         cMatch := art->Matchcode
      ELSE
         //Alert(art->Matchcode)
         lPackOnly := .F.
      ENDIF
      part->(dbSkip())
   ENDDO
   
   IF lPackOnly .AND. ! Empty(cMatch)
      art->(dbSetOrder( 1 ))
      IF art->(dbSeek( cMatch ))
         aPriceTabs := GetPrices(art->Artikelnr,art->Table,dDate,cKundma)
         AEval(aPriceTabs,{|aTab| aTab[2] += 0.45 })
         RETURN aPriceTabs
      ENDIF
   ENDIF
ENDIF

IF nTab == 1 .AND. art->Manufactur $ {1,10} //Bulgin, check if we can buy direct
   NetUSe("manufact","manu")
   manu->(dbSeek( Str(art->Manufactur,5) ))
   ku->(dbSetOrder( 8 ))
   ku->(dbSeek( Str(manu->Address,6) ))

   NetUse( "buyprice", "bpr", .F., 0 )
   //IF Tr_GetIni(28)==9;Alert("Starting search");ENDIF
   bpr->( dbSetOrder( 1 ) )   // liefma+artikelnr+qty
   bpr->(dbSetFilter({|| bpr->StartDate <= Date() .AND. (bpr->Enddate >= Date() .OR. Empty( bpr->EndDate )) },"StartDate <= Date() .AND. (Enddate >= Date() .OR. Empty( EndDate ))"))
   IF ! bpr->( dbSeek( ku->Kunde + Str( art->Artikelnr, 6 ) ) ) //no prices found we have to buy from Waldom      
      RETURN GetPrices(art->Artikelnr,30,dDate,cKundma)   
   ENDIF
   //IF Tr_GetIni(28)==9;Alert("NO WALDOM");ENDIF
ELSEIF nTab == 12 .OR. nTab == 29

   oArt := Artikel():New()
   oArt:Load(nArtnr)

   IF oArt:Manufactur == 9 //Scolmore
      NetUse("artlief","ali")
      ali->(dbSetOrder( 5 ))        
      IF ali->(dbSeek( Str( nArtnr, 6)+Pad("SCOLMORE",8) ))                  
         IF nTab == 29 .AND. ali->MIN != 0 .AND. oArt:Mindest == 0                                    
            DO WHILE ali->MIN >= aPriceTabs[2,1]               
               HB_ADel(aPriceTabs,2,.T.)
            ENDDO
            aPriceTabs[1,1] := ali->MIN         
         ELSEIF nTab == 12 .AND. ali->MIN != 0 .AND. ali->MIN < aPriceTabs[3,1]
            aPriceTabs[3,1] := ali->MIN
            IF ali->MIN <= aPriceTabs[2,1]
               HB_ADel(aPriceTabs,2,.T.)
            ENDIF
         ENDIF
         //remove duplicate price tiers
         FOR nX := 2 TO Len(aPriceTabs)
            DO WHILE Len(aPriceTabs) >= 2 .AND. nX <= Len(aPriceTabs) .AND. Round(aPriceTabs[nX,2],2) == Round(aPriceTabs[nX-1,2],2)
               HB_ADel(aPriceTabs,nX,.T.)
            ENDDO
         NEXT
      ENDIF
   ENDIF
   IF nTab == 12 .AND. oExtra != NIL .AND. oExtra:IecLockDis //! Empty(cKundma) .AND. Trim(cKundMa)+"|" $ HB_AnsiToOem("PLASTRO|RGR|M�LLERPL|FELLER|SOMMERCA|LEONI|LEONISLO|KLOTZ|") //Kunden mit Rabatt bei Scolmore
      AEval(aPriceTabs,{|aTab| aTab[2] := aTab[2]*(1-IF(aTab[1]<=500,0.15,0.10)) })
      nX := AScan(aPriceTabs,{|aTab| aTab[1] == 500 })
      IF nX > 0 .AND. nX < Len(aPriceTabs) .AND. aPriceTabs[nX,2] < aPriceTabs[nX+1,2]
         HB_ADel(aPricetabs,nX+1,.T.)
      ENDIF
   ENDIF
ELSEIF oExtra != NIL .AND. Len(oExtra:SubDisti) > 0 .AND. (nManu := AScan(oExtra:SubDisti,oArt:Manufactur)) != 0
   //HHasKey(aSubDistis,Trim(cKundma))

   IF Trim(cKundma) $ aSubSpecial
      nMulti := 1+nSubSpecial
   ELSE
      nMulti := 1+nSubAufschlag
   ENDIF


//   IF (nManu := AScan(aSubDistis[Trim(cKundma)],oArt:Manufactur)) != 0
   IF (nManu := AScan(oExtra:SubDisti,oArt:Manufactur)) != 0
      NetUSe("manufact","manu")
      manu->(dbSeek( Str(oArt:Manufactur,5) ))

      ku->(dbSetOrder( 8 ))
      IF ku->(dbSeek( Str(manu->Address,6) ))

         lSubDistiGBP := ku->Money=="P"
         nRate := Currate(ku->Money,"E") //,StoD("20140708"))
         aPriceTabs := {}

         NetUse( "buyprice", "bpr", .F., 0 )
         bpr->( dbSetOrder( 1 ) )   // liefma+artikelnr+qty
         bpr->(dbSetFilter({|| bpr->StartDate <= dDate .AND. (bpr->Enddate >= dDate .OR. Empty( bpr->EndDate )) },"StartDate <= StoD('"+DtoS(dDate)+"') .AND. (Enddate >= StoD('"+DtoS(dDate)+"') .OR. Empty( EndDate ))"))
         IF bpr->( dbSeek( ku->Kunde + Str( oArt:Artikelnr, 6 ) ) ) // found entry in supplier db
            
            DO WHILE bpr->Liefma == ku->Kunde .AND. bpr->Artikelnr == oArt:Artikelnr               
               Aadd(aPriceTabs,{bpr->qty, bpr->Price*Max( bpr->Pe, 1 )*nRate*nMulti*oArt:VKPe})
               
               bpr->(dbSkip())
            ENDDO

         ENDIF
         bpr->(dbClearFilter())
      ENDIF
   ENDIF
ELSEIF nTab == 44   

   aPriceTabs := MBaseRun(Trim(Tr_Getini(1))+"\run\prices\pricetabs",{nArtnr,dDate})   
   nTabSecs := Seconds()-nSecs
ELSEIF nTab == 13 //Kabelkonfektion   
   NetUse("artlief","ali") 
   IF art->Bezug == 5
      //cLiefMa := Pad("SELF",8)
      NetUse("parts","part")
      part->(dbSetOrder( 1 ))      
      IF part->(dbSeek( Str(nArtnr,6)+Str(-1,4) )) //Lohnartikel gefunden         
         nArtnr := part->Partart                  
      ENDIF      
   ENDIF 

   NetUse("artlief","ali")
   ali->(dbSetOrder( 6 ))
   IF ali->(dbSeek( Str( nArtnr, 6)+Str(1,1) )) .AND. Trim(ali->Kunde) $ {"SELT","WHTECH"} //Prio 1
      cLiefma := ali->Kunde
   ELSE
      cLiefma := Pad("WHTECH",8)
   ENDIF

   nPausch := 60
   NetUse( "buyprice", "bpr", .F., 0 )
   bpr->( dbSetOrder( 1 ) )   // liefma+artikelnr+qty
   IF bpr->( dbSeek( cLiefma + Str( nArtnr, 6 ) ) ) // found entry in supplier db
      DO WHILE bpr->Liefma == cLiefma .AND. bpr->Artikelnr == nArtnr
         
         IF ( bpr->StartDate <= Date() .AND. (bpr->Enddate >= Date() .OR. Empty( bpr->EndDate ))  )
            IF art->Bezug == 5
               nPrice := StCalc(art->Artikelnr,8,99,.T.,,,bpr->Qty)
               
               IF nPrice > 0
                  
                  Aadd(aPriceTabs,{bpr->Qty,(nPrice+nPausch/bpr->Qty)*stpr->Proz1/100*art->VkPe})
               ELSE
                  //Tr_MsgBox("St�ckliste konnte f�r "+LTrim(Transform(bpr->Qty,Me(art->Me)))+" "+art->Me+" nicht bewertet werden")
               ENDIF
            ELSE
               Aadd(aPriceTabs,{bpr->Qty,(bpr->Price / Max( bpr->Pe, 1 )+nPausch/bpr->Qty)*stpr->Proz1/100*art->VkPe})
            ENDIF
         ENDIF
         bpr->( dbSkip() )
      ENDDO
   ENDIF
   aPriceTabs := ASort(aPriceTabs,,,{|a,b| a[1] < b[1] })
   
   IF Len(aPriceTabs) == 0
      aPriceTabs := {{1,9999.99}}
   ENDIF
   
ELSEIF nTab == 14 //Gessmann
   NetUSe("manufact","manu")
   NetUse( "buyprice", "bpr", .F., 0 )

   manu->(dbSeek( Str(art->Manufactur,5) ))
   ku->(dbSetOrder( 8 ))
   ku->(dbSeek( Str(manu->Address,6) ))

   nEx := Currate(ku->Money,"E")

   bpr->( dbSetOrder( 1 ) )   // liefma+artikelnr+qty

   IF bpr->( dbSeek( ku->Kunde + Str( nArtnr, 6 ) ) ) // found entry in supplier db
      DO WHILE bpr->Liefma == ku->Kunde .AND. bpr->Artikelnr == nArtnr
         IF ( bpr->StartDate <= Date() .AND. (bpr->Enddate >= Date() .OR. Empty( bpr->EndDate )) .AND. bpr->Type == "LIST" )
            Aadd(aPriceTabs,{bpr->Qty,bpr->Price / Max( bpr->Pe, 1 )*nEx*1.5*art->VkPe})
         ENDIF
         bpr->( dbSkip() )
      ENDDO
   ENDIF

ELSEIF nTab == 15 //Value-Add
   IF art->Bezug == 5
      

      NetUse("parts","part")
      NetUSe("manufact","manu")
      NetUse( "buyprice", "bpr" )
      NetUse( "engkund", "ku" )
      art->(dbSetOrder( 2 ))

      IF ! part->(dbSeek( Str(nArtnr,6) ))      
         Alert("No partlist")
      ENDIF
      nSubArt := 0
      nAddPrice := 0
      lFound := .F.
      DO WHILE part->Listart == nArtnr .AND. ! part->(EOF())
         art->(dbSetORder(2))
         art->(dbSeek( Str(part->Partart,6) ))    
         manu->(dbSeek( Str(art->Manufactur,5) ))
         IF part->Pos == 0 .OR. part->Qty+part->AddQty <= 0 //header or part with no qty, ignore
            IF part->Pos == -1 .AND. ! GetConfigValue("BATCHMODE")               
               Tr_MsgBox("Lohnposition ohne Menge")
            ENDIF         
         ELSEIF part->Pos == -1 //Lohnposition
            IF part->Qty == 1
               nSubArt := art->Artikelnr
            ELSEIF Tr_Getini(28) == 9
               Tr_MsgBox("Lohnposition mit mehr als einem St�ck;"+art->Matchcode)
            ENDIF
         ELSEIF Trim(art->Type) == "VERP" //Left(art->Matchcode,6) == "KARTON" //nur Verpackung
            oArt := Artikel():New()
            nAddPrice += oArt:GetAvgBuyPrice()*part->Qty*part->Factor
         ELSE //IF /*! lFound .AND. manu->Principal .AND. art->Table != 15*/ //we have not found a part on the part list yet this is a part we can buy from a manufacturer and it does not have table 15 (non recursive)           
            lFound := .T.

            aPartPriceTabs := GetPrices(art->Artikelnr,art->Table,dDate,cKundma)
            nX := 1
            DO WHILE nX <= Len(aPartPriceTabs)
               IF aPartPriceTabs[nX,2] == 0
                  HB_ADel(aPartPriceTabs,nX,.T.)
               ELSE
                  //? aPartPriceTabs[nX,1],aPartPriceTabs[nX,2]/art->vkpe
                  aPartPriceTabs[nX,2] /= art->vkPe*part->Qty*part->Factor
                  nX++
               ENDIF               
            ENDDO            
            
            IF Len(aPartPriceTabs) == 0 .AND. ! GetConfigValue("BATCHMODE")
               aPriceTabs := {}
               lFound := .F.
               IF ! GetConfigValue("BATCHMODE")
                  Tr_MsgBox({"Keine Preisstaffel f�r "+trim(art->Matchcode)})
               ENDIF
               EXIT
            ELSEIF Len(aPriceTabs) == 0
               aPriceTabs := aPartPriceTabs
            ELSE
               nX := 1
               DO WHILE nX <= Len(aPriceTabs)
                  nY := AScan(aPartPriceTabs,{|aTab| aTab[1] <= aPriceTabs[nX,1] })
                  IF nY == 0
                    HB_ADel(aPriceTabs,nX,.T.)
                  ELSE
                     aPriceTabs[nX,2] += aPartPriceTabs[nY,2]
                     HB_ADel(aPartPriceTabs,nY,.T.)
                     nX++
                  ENDIF
               ENDDO
            ENDIF
         
         /*ELSE //we have more than one part on the part list
            IF ! GetConfigValue("BATCHMODE")
               IF lFound
                  Tr_MsgBox({"Zu viele Artikel auf der St�ckliste",art->Matchcode})
               //ELSEIF ! manu->Principal
               //   Tr_MsgBox({"Preisstaffel funktioniert nur f�r Prim�rlieferanten"})
               //ELSEIF art->Table != 15                             
               //   Tr_MsgBox({Trim(art->Matchcode)+" hat die falsche Preisstaffel"})
               ELSE
                  IF Tr_Getini(28) == 9;Tr_MsgBox({"Too many parts on the part list",art->Matchcode,art->Type,Str(part->Pos)});ENDIF
               ENDIF
            ENDIF

            aPriceTabs := {}
            EXIT */           
         ENDIF
         part->(dbSkip())
      ENDDO      
      
      IF lFound 
         hPrice := {=>}
         IF nSubart == 0 //keine Lohnposition, pr�fen ob T�tigkeiten hinterlegt sind.
            NetUse("partjobs","pjob")
            NetUse("jobs","job")
            NetUse("resource","res")

            nPausch := 60
            
            pjob->(dbSetOrder(2)) // Artikelnr
            IF pjob->(dbSeek(Str(nArtnr,6)))
               nInternalCost := 0
               DO WHILE pjob->Artikelnr == nArtnr .AND. ! pjob->(EOF())
                  job->(dbSeek(Str(pjob->Job,6)))
                  IF job->(Found()) .AND. pjob->Seconds > 0
                     // Use a default hourly rate for internal production (60 EUR/hour)
                     nHourlyRate := GetValue("FA_HOURLYRATE",25)
                     nInternalCost += (pjob->Seconds/3600) * nHourlyRate // Convert seconds to hours and multiply by rate
                  ENDIF
                  pjob->(dbSkip())
               ENDDO
               
               // Add^set internal production cost as the buy price
               hPrice[1] := nInternalCost
               hPrice[100] := nInternalCost
            ENDIF
         ELSE
            bpr->( dbSetOrder( 2 ) )  
            ku->(dbsetOrder( 1 ))

            nPausch := 60
            
            IF bpr->( dbSeek( Str( nSubArt, 6 ) ) ) // found entry in supplier db            
               DO WHILE bpr->Artikelnr == nSubArt
                  IF bpr->StartDate <= dDate .AND. (bpr->Enddate >= dDate .OR. Empty( bpr->EndDate ))
                     ku->(dbSeek( bpr->Liefma+"L" ))                  
                     nPrice := (bpr->Price / Max( bpr->Pe, 1 ))*Currate( ku->Money, "E" )                  
                     IF ! HHasKey(hPrice,bpr->Qty) .OR. hPrice[bpr->Qty] > nPrice
                        hPrice[bpr->Qty] := nPrice
                     ENDIF
                     //cSupplier := bpr->Liefma               
                  ENDIF
                  bpr->( dbSkip() )
               ENDDO
            ENDIF
         ENDIF
      ENDIF

      IF lFound .AND. Len(hPrice) > 0     //we have found a part on the part list and we have a cost for manufacturing
         IF ! GetConfigValue("BATCHMODE") 
            //Alert(ValToPrg(aPriceTabs))
         ENDIF
         DO WHILE  Len(aPriceTabs) >= 1 .AND. Len(hPrice) >= 1 .AND. HGetKeyAt(hPrice,1) > aPriceTabs[1,1] //remove all pricetabs which are too small
            IF Len(aPriceTabs) >= 2 .AND. HGetKeyAt(hPrice,1) < aPriceTabs[2,1] //the next one is big enough, then we change the quantity on this one
               aPriceTabs[1,1] := HGetKeyAt(hPrice,1)
               nX := 2
               DO WHILE nX <= Len(hPrice) .AND. HGetKeyAt(hPrice,nX) <= aPriceTabs[nX,1] 
                  HB_AIns(aPriceTabs,nX,{HGetKeyAt(hPrice,nX),aPriceTabs[1,2]},.T.) 
                  nX++
               ENDDO    
            ELSE
               HB_ADel(aPriceTabs,1,.T.)
            ENDIF
         ENDDO
         ASort(aPriceTabs,,,{|a,b| a[1] < b[1] })
         HB_HSort(hPrice,,,{|a,b| a < b })

         FOR nX := 1 TO Len(aPriceTabs)            
            nY := 1
            nPrice := 0
            DO WHILE nY <= Len(hPrice) .AND. HGetKeyAt(hPrice,nY) <= aPriceTabs[nX,1]         
               nPrice := HGetValueAt(hPrice,nY)
               nY++
            ENDDO
            IF nPrice != 0 .AND. aPriceTabs[nX,2] != 0
               aPriceTabs[nX,2] += (nPrice+nAddPrice)*stpr->Proz1/100+nPausch/aPriceTabs[nX,1]
            ELSE
               aPriceTabs[nX,2] := 9999.99
            ENDIF
         NEXT
         
         ASort(aPriceTabs,,,{|a,b| a[1] < b[1] })

      ELSE       
         IF ! GetConfigValue("BATCHMODE") 
            IF ! lFound
               Tr_MsgBox("Kein Artikel auf der St�ckliste gefunden")
            ELSEIF nSubArt == 0
               Tr_MsgBox("Kein Konfektionsartikel auf der St�ckliste gefunden")
            ENDIF
         ENDIF
             
         aPriceTabs := {}
      ENDIF
   ELSE
      NetUse("folgeart","fol")
      IF fol->(dbSeek(Str(art->Artikelnr,6)))         
         DO WHILE fol->Artikelnr == art->Artikelnr 
            oArt := Artikel():New() 
            oArt:Load(fol->Folgeart)
            IF Tr_Getini(28) == 9
            ? oArt:Matchcode
            ENDIF
            aAddPriceTab := GetPrices(fol->Folgeart,oArt:Table,dDate,cKundma)
            IF Tr_Getini(28) == 9
               ? ValToPrg(aAddPriceTab)
            ENDIF
            IF Len(aPriceTabs) == 0
               aPriceTabs := aAddPriceTab
            ELSE
               FOR nX := 1 TO LEN(aPriceTabs)
                  nY := AScan(aAddPriceTab,{|aTab| aTab[1] <= aPriceTabs[nX,1] })
                  IF nY == 0
                     IF Tr_Getini(28) == 9
                        ? "Deleting",aPriceTabs[nX,1]
                     ENDIF
                     HB_ADel(aPriceTabs,nX,.T.)
                  ELSE
                     aPriceTabs[nX,2] += aAddPriceTab[nY,2]
                  ENDIF
               NEXT
            ENDIF
            //? fol->Folgeart
            fol->(dbSkip())
         ENDDO     
         IF Tr_Getini(28) == 9
            Sinkey(0)
         ENDIF    
      ENDIF
   ENDIF
ELSEIF nTab == 75 .OR. nTab == 10
   IF dDate >= StoD("20260401")
      AEval(aPriceTabs,{|aTab| 
         aTab[2] *= 1.05 //general price increase of 5% from April 1st, 2026 due to increased costs for raw materials and logistics         
      }) 
   ENDIF
   //Alert(ali->Kunde+Str(ali->Min))
   IF art->Bezug == 5 //Engelking China if it is repacked
   
      NetUse("parts","part")
      NetUSe("manufact","manu")
      NetUse( "buyprice", "bpr" )
      NetUse( "engkund", "ku" )
      art->(dbSetOrder( 2 ))

      IF ! part->(dbSeek( Str(nArtnr,6) ))      
         Alert("No partlist")
      ENDIF
      nSubArt := 0
      lFound := .F.
      DO WHILE part->Listart == nArtnr .AND. ! part->(EOF())
         art->(dbSeek( Str(part->Partart,6) ))    
         manu->(dbSeek( Str(art->Manufactur,5) ))
         IF part->Pos == 0 //header, ignore
//         ELSEIF part->Pos == -1 //Konfektionsposition
//            nSubArt := art->Artikelnr
         ELSEIF Left(art->Matchcode,6) == "KARTON"

         ELSEIF ! lFound  //we have not found a part on the part list yet this is a part we can buy from a manufacturer and it does not have table 15 (non recursive)           
            
            aPriceTabs := GetPrices(art->Artikelnr,75,dDate,cKundma)
            lFound := .T.
         
         ELSE //we have more than one part on the part list
            IF Tr_Getini(28) == 9;Tr_MsgBox("Too many parts on the part list;"+art->Matchcode);ENDIF
            aPriceTabs := {}
            EXIT            
         ENDIF
         part->(dbSkip())
      ENDDO
   ENDIF
   IF ! ali->(EOF()) .AND. ali->Min != 0  //if the supplier has a minimum order quantity, we have to adjust the price tiers accordingly
      //delete all price tiers which are below the minimum order quantity, but keep the last one which is below the minimum order quantity, as this is the price for the minimum order quantity
      nX := 1
      DO WHILE nX <= Len(aPriceTabs)
         IF aPriceTabs[nX,1] < ali->Min
            IF nX < Len(aPriceTabs) .AND. aPriceTabs[nX+1,1] > ali->Min
               aPriceTabs[nX,1] := ali->Min
               nX++
            ELSE
               HB_ADel(aPriceTabs,nX,.T.)
            ENDIF
         ELSE
            nX++
         ENDIF
      ENDDO
   ENDIF
ELSEIF nTab == 26   
   NetUse("artlief","ali")
   ali->(dbSetOrder( 5 ))
   IF ali->(dbSeek( Str( nArtnr, 6)+Pad("TECHNO",8) ))
      nVPE := IF(ali->VPE==0,200,ali->VPE) //wenn keine VPE/MOQ vorhanden, dann von 200 ausgehen (wurde so von Techno best�tigt)
      FOR nX := 1 TO Len(aPriceTabs)         
         IF aPriceTabs[nX,1] < nVPE .AND. aPriceTabs[nX,2] != 0
            aPriceTabs[nX,2]  += 25/aPriceTabs[nX,1]*art->VKPE //Mindermengenzuschlag hinzurechnen
         ELSEIF ali->VPE != 0
            aPriceTabs[nX,1] := Int(aPriceTabs[nX,1]/nVPE)*nVPE //auf volle VPE �ndern
         ENDIF
      NEXT      
   ENDIF
ELSEIF nTab == 60  //Engelking
   TxtBox({"Preis wird berechnet",""})
   aPriceTabs := {}  
   oExtra := art->(ExtraData():New(art->Artikelnr))
   oArt := Artikel():New()
   oArt:Load(nArtnr)
   aQty := Hook("GET_CALC_QUANTITIES",{oArt},{})
   lDebug := IF(SystemUser():Id${9,37}.AND.Tr_MsgBox("Show debug info for price calculation?",,{"No","Yes"}) == 2,.T.,.F.)
 
   IF oExtra:CalcMargin > 0
      nMulti := 1/(1-oExtra:CalcMargin/100)
   ELSE
      nMulti := 2.5 //default: 60% margin
   ENDIF

   //Preis kalkulieren, wenn es sich um einen Fertigungsartikel handelt ODER wenn Folgeartikel hinterlegt sind
   NetUse("folgeart","fol")
   IF oArt:Bezug == 5 .OR. fol->(dbSeek(Str(art->Artikelnr,6)))
      cDebugInfo := ""
      FOR EACH nQ IN aQty
         @ MaxRow()/2+1,(MaxCol()-Len(LTrim(Str(Atail(aQty)))))/2 SAY Ltrim(Transform(nQ,oArt:cPicture)) //Replicate(".",nQ:__enumIndex())
         cInfoData := ""
         IF oArt:Bezug == 5
            //first we try to calculate the price using the parts list, price base 9 = stock based + supplier price for purchasing
            nP := StCalc(nArtnr,9,,.T.,Date(),,nQ,.T.,@cInfoData)
            IF lDebug
               cDebugInfo += "Price for "+Trim(oArt:Matchcode)+" "+LTrim(Str(nQ,10))+" pieces "+Chr(13)+cInfoData+CHR(13)
            ENDIF
         ELSEIF ! oArt:Lagerart
            //nicht lagerf�higer Artikel (reiner Folgeartikel-Tr�ger): kein eigener Basis-EK, nur die Folgeartikel-Kosten z�hlen
            nP := 0
            IF lDebug
               cDebugInfo += "No base EK (article not stockable) for "+Trim(oArt:Matchcode)+" "+LTrim(Str(nQ,10))+" pieces"+CHR(13)
            ENDIF
         ELSE
            //kein Fertigungsartikel, aber lagerf�hig: eigener EK als Grundpreis (gleiche Logik wie bei den Folgeartikeln)
            cSupplier := ""
            IF oArt:Mindest == 0
               aAvail := GetKwQty(oArt:Artikelnr)
               nAvailableStock := ATail(aAvail)[6] //we have stock left at the end
            ENDIF
            IF oArt:Mindest > 0 .OR. nAvailableStock >= nQ
               // Sufficient stock available - use D/S price
               nEk := oArt:GetAvgBuyPrice()*CURRATE(oArt:money,"E")*oArt:pe
               IF nEk == 0
                  nEk := oArt:GetAvgBuyPrice(dDate)*oArt:Pe
               ENDIF
            ELSE
               // Insufficient stock - use supplier price
               nEk := GetLowestBuyPrice(oArt:Artikelnr,nQ,dDate,@cSupplier)*oArt:Pe
               IF nEk == 0
                  nEk := -1 // No supplier price available
               ENDIF
            ENDIF
            IF nEk > 0
               nP := nEk/oArt:PE
            ELSE
               nP := -1
            ENDIF
            IF lDebug
               cDebugInfo += "Base EK for "+Trim(oArt:Matchcode)+" "+LTrim(Str(nQ,10))+" pieces: "+LTrim(Str(nP))+CHR(13)
            ENDIF
         ENDIF

         IF nP >= 0

            //add the cost of all folgeartikel
            NetUse("folgeart","fol")
            IF fol->(dbSeek(Str(art->Artikelnr,6)))

               DO WHILE fol->Artikelnr == art->Artikelnr
                  oFolArt := Artikel():New()
                  oFolArt:Load(fol->Folgeart)
                  cSupplier := ""

                  IF oFolArt:Bezug == 5
                     // Folgeartikel ist selbst ein Fertigungsartikel -> Preis �ber St�ckliste (price base 9)
                     cInfoData := ""
                     nEk := StCalc(oFolArt:Artikelnr,9,,.T.,Date(),,nQ*fol->Faktor,.T.,@cInfoData)
                     IF lDebug
                        cDebugInfo += "Price for "+Trim(oFolArt:Matchcode)+" "+LTrim(Str(nQ*fol->Faktor,10))+" pieces "+Chr(13)+cInfoData+CHR(13)
                     ENDIF
                     IF nEk >= 0
                        nP += nEk*fol->Faktor
                     ELSE
                        cDebugInfo += "No price for "+Trim(oFolArt:Matchcode)+" "+LTrim(Str(nQ,10))+" pieces "+Chr(13)+cInfoData+CHR(13)
                        nP := -1
                        EXIT
                     ENDIF
                  ELSE
                     IF oFolArt:Mindest == 0
                        aAvail := GetKwQty(oFolArt:Artikelnr)
                        nAvailableStock := ATail(aAvail)[6] //we have stock left at the end
                     ENDIF

                     IF oFolArt:Mindest > 0 .OR. nAvailableStock >= nQ*fol->Faktor
                        // Sufficient stock available - use D/S price
                        nEk := oFolArt:GetAvgBuyPrice()*CURRATE(oFolArt:money,"E")*oFolArt:pe
                        IF nEk == 0
                           nEk := oFolArt:GetAvgBuyPrice(dDate)*oFolArt:Pe
                        ENDIF
                     ELSE
                        // Insufficient stock - use supplier price
                        nEk := GetLowestBuyPrice(oFolArt:Artikelnr,nQ*fol->Faktor,dDate,@cSupplier)*oFolArt:Pe
                        IF nEk == 0
                           nEk := -1 // No supplier price available
                        ENDIF
                     ENDIF
                     IF nEk > 0
                        nP += nEk*fol->Faktor/oFolArt:PE
                        IF lDebug
                           cDebugInfo += "Base EK for "+Trim(oFolArt:Matchcode)+" "+LTrim(Str(nQ*fol->Faktor,10))+" pieces: "+LTrim(Str(nEk/oFolArt:PE))+CHR(13)
                        ENDIF
                     ELSE
                        cDebugInfo += "No price for "+Trim(oFolArt:Matchcode)+" "+LTrim(Str(nQ,10))+" pieces "+Chr(13)+cInfoData+CHR(13)
                        nP := -1
                        EXIT
                     ENDIF
                  ENDIF

                  fol->(dbSkip())
               ENDDO
            ENDIF
            /*IF Tr_Getini(28) == 9
               ? nP
               Sinkey(0)
            ENDIF*/

         ENDIF

         IF lDebug
            cDebugInfo += "Total price for "+LTrim(Str(nQ,10))+" pieces: "+LTrim(Str(nP))+CHR(13)
         ENDIF

         //add margin
         nP *= nMulti
         IF nP > 0
            Aadd(aPriceTabs,{nQ,nP})
         ELSE
            cDebugInfo += "No price for "+LTrim(Str(nQ,10))+" pieces "+Chr(13)+cInfoData+CHR(13)
         ENDIF
      NEXT
   ELSE
      cDebugInfo := "Kein Fertigungsartikel und keine Folgeartikel"+Chr(10)+Chr(13)
   ENDIF

   IF ! Empty(cDebugInfo) .AND. Tr_Getini(28) $ {9,37} .AND. Tr_MsgBox("Debug pricetab calculation?",,{"No","Yes"}) == 2
      MemoEdit(cDebugInfo)
   ENDIF

   
   
   nQty := GetKwStock(nArtnr,9999)  //�briger Lagerbestand
   IF nQty > 0
      oArt := Artikel():New()
      oArt:Load(nArtnr)
      nVK := oArt:GetAvgBuyPrice()*3.33 //70% margin
      IF nVK > 0 .AND. (Len(aPriceTabs) == 0 .OR. nQty < aPriceTabs[1,1])
         HB_AInS(aPriceTabs,1,{nQty, nVK},.T.)
      
      ENDIF
      //Alert(ValToPRg(hCostOO))
      
   ENDIF

   TxtClear()

ENDIF

//FIXED GBP RATE
//IF nTab == 29 .OR.  (nTab == 12 .AND. ! Empty(cKundma) .AND. Trim(cKundma)+"|" $ HB_AnsiToOem("D�TWYLER|BACHMANN|")) .OR. AScan(aSubFixed,Trim(cKundma)) != 0  //fixed exchange rate

//29 = Scolmore Disti
//12 = Scolmore

IF nTab == 29 .OR. nTab == 14 .OR. ((nTab == 12 .OR. lSubDistiGBP) .AND. oExtra != NIL .AND. oExtra:FixedEx) //fixed exchange rate
   nEx := Currate("P","E")
   nFixRate := nEx
   IF Trim(cKundma) != "KASH"
      IF Date() >= StoD("20160801") .AND. nEx < 1.22
         nFixRate := 1.2 //275
         IF (AT("PA135",art->Matchcode) == 1 .AND. AT("BK4",art->Matchcode) == 0 .AND. AT("BK6",art->Matchcode) == 0);
             .OR. AT("PA195",art->Matchcode) == 1
            nFixRate *= 1.05  //5% extra on these products
         ENDIF
      ENDIF
   ELSE //Kash
      IF Date() >= StoD("20170201")
         nFixRate := 1.275*1.1 //extra 10% as fixed for one year
         IF Trim(art->Matchcode) == "PA130100BK"
            nFixRate := 1.275*1.085  //only 8.5% to make it tie up with the priceklist
         ENDIF

      ELSE
         nFixRate := 1.35
      ENDIF
   ENDIF
   IF nFixRate != nEx
      AEval(aPriceTabs,{|aTab| aTab[2] := aTab[2]/nEx*nFixRate })
   ENDIF
ENDIF

//FIXED USD RATE
IF nTab == 9999
   nEx := Currate("U","E")
   nFixRate := 0.92
   IF nEx > nFixRate+0.02
      nFixRate := 0.92
   ENDIF
   IF nFixRate != nEx
      AEval(aPriceTabs,{|aTab| aTab[2] := aTab[2]/nEx*nFixRate })
   ENDIF
ENDIF

IF ! Empty(cKundma)
   NetUse("skontoa","sk")
   IF sk->(HasSpecialPay(ku->Skonto)) 
      aSkonto := sk->(GetSkonto(ku->Skonto,dDate,dDate))
      IF Len(aSkonto) == 1 .AND. aSkonto[1,1] == 3 //wahrscheinlich ein Mitglied der GC Gruppe, z.B. EFG B�r
         AEval(aPriceTabs,{|aTab| aTab[2] := aTab[2]*1.03 })
      ENDIF
   ENDIF
ENDIF

IF art->Manufactur $ {12} //Elcom Mindermengenzuschlag, EK bis 400$, 60$ Zuschlag. Gehen hier von einem Faktor von 2,2 aus  und einem Wechselkurs von 0,9. Daher Rechnen wir das 1000? ein und dann 60?
   AEval(aPriceTabs,{|aTab| IF(aTab[2]!=0 .AND. aTab[1]*aTab[2]/2.2<1000,aTab[2] := aTab[2]+60/aTab[1],.T.) })
ENDIF

IF nTab == 11
   IF art->Gewicht == 0 //no weight, no prices
      aPriceTabs := {}
   ELSE
      nWeight := art->Gewicht      
      AEval(aPriceTabs,{|aTab| IF(aTab[2]!=0,aTab[2] := aTab[2]+Hook("get_supplier_ship_cost",{Pad("SIGNAL",8),nWeight*aTab[1]})/aTab[1],.T.) }) 
   ENDIF   
ELSE //Frachtkosten einrechnen, bei vielen gibt der Hook jedoch 0 zur�ck //IF art->Manufactur $ {12,16} //Elcom oder Signal, Frachtkosten einrechnen
   IF art->Gewicht == 0 
      IF art->Manufactur $ {12,16} //no weight, no prices only for these manufacturers
         aPriceTabs := {}
      ENDIF
   ELSE
      nWeight := art->Gewicht      
      AEval(aPriceTabs,{|aTab| IF(aTab[2]!=0,aTab[2] := aTab[2]+GetUpsImportCost(nWeight*aTab[1])/aTab[1],.T.) })  //this also uses get_supplier_ship_cost just looks for the manufacturer first
   ENDIF   
ENDIF

IF Tr_GetIni(28) == 9 //.AND. nTab == 44
   //Alert("Table "+LTrim(Str(nTab))+" finished in "+LTrim(Str(Seconds()-nSecs))+" seconds") //; Pricetabs took "+Ltrim(Str(nTabSecs))+" seconds")
   //Alert(cKundma)
ENDIF


RETURN aPriceTabs

#include '..\run\getupsimportcost.prg'
#include '..\run\OO_costing.prg'