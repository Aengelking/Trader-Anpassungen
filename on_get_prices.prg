FUNC HOOK_ON_GET_PRICES( aPriceTabs,nArtnr,nTab,dDate,cKundma )

LOCAL nRate,nMulti
LOCAL nX,nManu
LOCAL lSubDistiGBP := .F.,lPackOnly
LOCAL nVPE
LOCAL oArt,nWeight
LOCAL lFound,nPrice,nPausch,nSubArt,hPrice
LOCAL nSecs := Seconds()
/*df
   SETTINGS FOR SUB DISTIS

   Manufacuters
   1=Bulgin
   2=Edac
   3=ITW
   10=Arcolectric
*/

//which supplier to use for each manufacturer
LOCAL nSubAufschlag := 0.3
LOCAL nSubSpecial   := 0.2
LOCAL aSubSpecial := {"MONACOR"} //{"ALDERS"}
LOCAL oExtra
LOCAL cMatch
LOCAL nEx,nFixRate,aSkonto,nTable
LOCAL aAddPriceTab
LOCAL aPartPriceTabs
LOCAL nAddPrice


NetUse("engkund","ku")
IF ! Empty(cKundma)
   ku->(dbSeek( cKundma+"K" ))
   oExtra := ku->(ExtraData():New( ku->Nummer ))
ENDIF

IF AT("CMI57",art->Matchcode) == 1   
   NetUse("parts","part")
   nTable := art->Table
   art->(dbSetOrder( 1 ))
   IF art->(dbSeek( "p"+LTrim(Str(art->Artikelnr))+".SWITCH" ))      
      aPriceTabs := GetPrices(art->Artikelnr,nTable,dDate,cKundma)
      RETURN aPriceTabs
   ENDIF
ENDIF

IF art->Manufactur == 9 .AND. (AT("/PB",art->Matchcode) != 0 .OR. Left(art->Matchcode,2) == "KS") .AND. art->Gruppe == "KONK"
   NetUse("parts","part")
   art->(dbSetOrder( 2 ))

   part->(dbSeek( Str(nArtnr,6) ))
   lPackOnly := .T.
   DO WHILE part->Listart == nArtnr .AND. lPackOnly
      art->(dbSeek( Str(part->Partart,6) ))      
      IF part->Pos <= 0 .OR. At("KARTON",art->Matchcode) == 1 .OR. AT("BEUTEL",art->Matchcode) == 1 //nur Verpackung in Beutel
         //do nothing
      ELSEIF AT("NZ/",art->Matchcode) == 1
         cMatch := art->Matchcode
      ELSE
         //Alert(art->Matchcode)
         lPackOnly := .F.
      ENDIF
      part->(dbSkip())
   ENDDO
   //cMatch := StrTran(art->Matchcode,"/PB","/BU")
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
      //IF Tr_GetIni(28)==9;Alert("Waldom");ENDIF
      RETURN GetPrices(art->Artikelnr,30,dDate,cKundma)   
   ENDIF
   //IF Tr_GetIni(28)==9;Alert("NO WALDOM");ENDIF
ELSEIF nTab == 12 .OR. nTab == 29

   oArt := Artikel():New()
   oArt:Load(nArtnr)

   IF oArt:Manufactur == 9

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
         DO WHILE Len(aPriceTabs) >= 2 .AND. aPriceTabs[2,2] == aPriceTabs[1,2]
            HB_ADel(aPriceTabs,2,.T.)
         ENDDO
      ENDIF
   ENDIF
   IF nTab == 12 .AND. oExtra != NIL .AND. oExtra:IecLockDis //! Empty(cKundma) .AND. Trim(cKundMa)+"|" $ HB_AnsiToOem("PLASTRO|RGR|MÜLLERPL|FELLER|SOMMERCA|LEONI|LEONISLO|KLOTZ|") //Kunden mit Rabatt bei Scolmore
      AEval(aPriceTabs,{|aTab| aTab[2] := aTab[2]*(1-IF(aTab[1]<=500,0.15,0.10)) })
      nX := AScan(aPriceTabs,{|aTab| aTab[1] == 500 })
      IF nX > 0 .AND. nX < Len(aPriceTabs) .AND. aPriceTabs[nX,2] < aPriceTabs[nX+1,2]
         HB_ADel(aPricetabs,nX+1,.T.)
      ENDIF
   ENDIF
ELSEIF oExtra != NIL .AND. Len(oExtra:SubDisti) > 0 //HHasKey(aSubDistis,Trim(cKundma))
   oArt := Artikel():New()
   oArt:Load(nArtnr)


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
   IF art->Bezug == 5
      cLiefMa := Pad("SELF",8)
   ELSE
      cLiefma := Pad("WHTECH",8)
   ENDIF
   nPausch := 60
   NetUse( "buyprice", "bpr", .F., 0 )
   bpr->( dbSetOrder( 1 ) )   // liefma+artikelnr+qty
   IF bpr->( dbSeek( cLiefma + Str( nArtnr, 6 ) ) ) // found entry in supplier db
      DO WHILE bpr->Liefma == cLiefma .AND. bpr->Artikelnr == nArtnr
         IF ( bpr->StartDate <= Date() .AND. (bpr->Enddate >= Date() .OR. Empty( bpr->EndDate ))  )
            Aadd(aPriceTabs,{bpr->Qty,(bpr->Price / Max( bpr->Pe, 1 )+nPausch/bpr->Qty)*stpr->Proz1/100*art->VkPe})
         ENDIF
         bpr->( dbSkip() )
      ENDDO
   ENDIF
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
         IF part->Pos == 0 .OR. part->Qty+part->AddQty == 0 //header or part with no qty, ignore
         ELSEIF part->Pos == -1 //Konfektionsposition
            IF part->Qty == 1
               nSubArt := art->Artikelnr
            ELSEIF Tr_Getini(28) == 9
               Tr_MsgBox("Konfektionsposition mit mehr als einem Stck;"+art->Matchcode)
            ENDIF
         ELSEIF Trim(art->Type) == "VERP" //Left(art->Matchcode,6) == "KARTON" //nur Verpackung
            oArt := Artikel():New()
            nAddPrice += oArt:GetAvgBuyPrice()*part->Qty*part->Factor
         ELSE //IF /*! lFound .AND. manu->Principal .AND. art->Table != 15*/ //we have not found a part on the part list yet this is a part we can buy from a manufacturer and it does not have table 15 (non recursive)           
            
            aPartPriceTabs := GetPrices(art->Artikelnr,art->Table,dDate,cKundma)
            nX := 1
            DO WHILE nX <= Len(aPartPriceTabs)
               IF aPartPriceTabs[nX,2] == 0
                  HB_ADel(aPartPriceTabs,nX,.T.)
               ELSE
                  aPartPriceTabs[nX,2] /= part->Qty
                  nX++
               ENDIF               
            ENDDO
            
            lFound := .T.
            IF Len(aPartPriceTabs) == 0 .AND. ! GetConfigValue("BATCHMODE")
               aPriceTabs := {}
               lFound := .F.
               Tr_MsgBox({"Keine Preisstaffel fr "+trim(art->Matchcode)})
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
                  Tr_MsgBox({"Zu viele Artikel auf der Stckliste",art->Matchcode})
               //ELSEIF ! manu->Principal
               //   Tr_MsgBox({"Preisstaffel funktioniert nur fr Prim„rlieferanten"})
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
      
      IF lFound .AND. nSubArt != 0     //we have found a part on the part list	    
         //IF Tr_Getini(28) == 9;Tr_MsgBox({"Subartikel gefunden",Str(nSubArt),ValToPrg(aPriceTabs)});ENDIF
         bpr->( dbSetOrder( 2 ) )  
         ku->(dbsetOrder( 1 ))
         hPrice := {=>}
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
         
         nPausch := 60
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
         

      ELSE       
         //IF Tr_Getini(28) == 9;Tr_MsgBox("No part found on the part list;"+art->Matchcode);ENDIF  
         aPriceTabs := {}
      ENDIF
   ELSE
      NetUse("folgeart","fol")
      IF fol->(dbSeek(Str(art->Artikelnr,6)))         
         DO WHILE fol->Artikelnr == art->Artikelnr 
            oArt := Artikel():New() 
            oArt:Load(fol->Folgeart)
            aAddPriceTab := GetPrices(fol->Folgeart,oArt:Table,dDate,cKundma)
            IF Len(aPriceTabs) == 0
               aPriceTabs := aAddPriceTab
            ELSE
               FOR nX := 1 TO LEN(aPriceTabs)
                  nY := AScan(aAddPriceTab,{|aTab| aTab[1] <= aPriceTabs[nX,1] })
                  IF nY == 0
                     HB_ADel(aPriceTabs,nX,.T.)
                  ELSE
                     aPriceTabs[nX,2] += aAddPriceTab[nY,2]
                  ENDIF
               NEXT
            ENDIF
            //? fol->Folgeart
            fol->(dbSkip())
         ENDDO         
      ENDIF
   ENDIF
ELSEIF nTab == 75 .AND. art->Bezug == 5 //Engelking China if it is repacked
   
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
ELSEIF nTab == 26   
   NetUse("artlief","ali")
   ali->(dbSetOrder( 5 ))
   IF ali->(dbSeek( Str( nArtnr, 6)+Pad("TECHNO",8) ))
      nVPE := IF(ali->VPE==0,200,ali->VPE) //wenn keine VPE/MOQ vorhanden, dann von 200 ausgehen (wurde so von Techno best„tigt)
      FOR nX := 1 TO Len(aPriceTabs)         
         IF aPriceTabs[nX,1] < nVPE .AND. aPriceTabs[nX,2] != 0
            aPriceTabs[nX,2]  += 25/aPriceTabs[nX,1]*art->VKPE //Mindermengenzuschlag hinzurechnen
         ELSEIF ali->VPE != 0
            aPriceTabs[nX,1] := Int(aPriceTabs[nX,1]/nVPE)*nVPE //auf volle VPE „ndern
         ENDIF
      NEXT      
   ENDIF
ENDIF

//FIXED GBP RATE
//IF nTab == 29 .OR.  (nTab == 12 .AND. ! Empty(cKundma) .AND. Trim(cKundma)+"|" $ HB_AnsiToOem("DÄTWYLER|BACHMANN|")) .OR. AScan(aSubFixed,Trim(cKundma)) != 0  //fixed exchange rate

//29 = Scolmore Disti
//12 = Scolmore

IF nTab == 29 .OR. nTab == 14 .OR. ((nTab == 12 .OR. lSubDistiGBP) .AND. oExtra != NIL .AND. oExtra:FixedEx) //fixed exchange rate
   nEx := Currate("P","E")
   nFixRate := nEx
   IF Trim(cKundma) != "KASH"
      IF Date() >= StoD("20160801") .AND. nEx < 1.25
         nFixRate := 1.2 //275
         IF (AT("PA135",art->Matchcode) == 1 .AND. AT("BK4",art->Matchcode) == 0 .AND. AT("BK6",art->Matchcode) == 0) .OR. AT("PA195",art->Matchcode) == 1
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

IF ! Empty(cKundma)
   NetUse("skontoa","sk")
   IF sk->(HasSpecialPay(ku->Skonto)) 
      aSkonto := sk->(GetSkonto(ku->Skonto,dDate,dDate))
      IF Len(aSkonto) == 1 .AND. aSkonto[1,1] == 3 //wahrscheinlich ein Mitglied der GC Gruppe, z.B. EFG Bär
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
ELSE //Frachtkosten einrechnen, bei vielen gibt der Hook jedoch 0 zurck //IF art->Manufactur $ {12,16} //Elcom oder Signal, Frachtkosten einrechnen
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

#include 'x:\run\getupsimportcost.prg'