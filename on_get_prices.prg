FUNC HOOK_ON_GET_PRICES( aPriceTabs,nArtnr,nTab,dDate,cKundma )

LOCAL nRate,nMulti
LOCAL nX,nManu
LOCAL lSubDistiGBP := .F.
LOCAL nVPE
LOCAL oArt,nWeight

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
LOCAL nEx,nFixRate,aSkonto

NetUse("engkund","ku")
IF ! Empty(cKundma)
   ku->(dbSeek( cKundma+"K" ))
   oExtra := ku->(ExtraData():New( ku->Nummer ))
ENDIF

IF art->Manufactur == 9 .AND. AT("/PB",art->Matchcode) != 0
   cMatch := StrTran(art->Matchcode,"/PB","/BU")
   art->(dbSetOrder( 1 ))
   IF art->(dbSeek( cMatch ))
      aPriceTabs := GetPrices(art->Artikelnr,art->Table,dDate,cKundma)
      AEval(aPriceTabs,{|aTab| aTab[2] += 0.45 })
      RETURN aPriceTabs
   ENDIF
ENDIF


IF nTab == 1 .AND. art->Manufactur $ {1,10} //Bulgin, check if we can buy direct
   NetUSe("manufact","manu")
   manu->(dbSeek( Str(art->Manufactur,5) ))
   ku->(dbSetOrder( 8 ))
   ku->(dbSeek( Str(manu->Address,6) ))

   NetUse( "buyprice", "bpr", .F., 0 )
   bpr->( dbSetOrder( 1 ) )   // liefma+artikelnr+qty
   bpr->(dbSetFilter({|| bpr->StartDate <= Date() .AND. (bpr->Enddate >= Date() .OR. Empty( bpr->EndDate )) },"StartDate <= Date() .AND. (Enddate >= Date() .OR. Empty( EndDate ))"))
   IF ! bpr->( dbSeek( ku->Kunde + Str( art->Artikelnr, 6 ) ) ) //no prices found we hae to buy from Waldom
      RETURN GetPrices(art->Artikelnr,30,dDate,cKundma)   
   ENDIF
ELSEIF nTab == 12 .OR. nTab == 29
   oArt := Artikel():New()
   oArt:Load(nArtnr)

   IF oArt:Manufactur == 9
      NetUse("artlief","ali")
      ali->(dbSetOrder( 5 ))
      IF ali->(dbSeek( Str( nArtnr, 6)+Pad("SCOLMORE",8) ))
         IF nTab == 29 .AND. ali->VPE != 0 .AND. oArt:Mindest == 0
            DO WHILE ali->VPE >= aPriceTabs[2,1]
               HB_ADel(aPriceTabs,2,.T.)
            ENDDO
            aPriceTabs[1,1] := ali->Vpe
         ELSEIF nTab == 12 .AND. ali->VPE < aPriceTabs[3,1]
            aPriceTabs[3,1] := ali->VPE
            IF ali->VPE <= aPriceTabs[2,1]
               HB_ADel(aPriceTabs,2,.T.)
            ENDIF
         ENDIF
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
ELSEIF nTab == 26
   NetUse("artlief","ali")
   ali->(dbSetOrder( 5 ))
   IF ali->(dbSeek( Str( nArtnr, 6)+Pad("TECHNO",8) ))
      nVPE := IF(ali->VPE==0,200,ali->VPE) //wenn keine VPE/MOQ vorhanden, dann von 200 ausgehen (wurde so von Techno best„tigt)
      FOR nX := 1 TO Len(aPriceTabs)
         IF aPriceTabs[nX,1] < nVPE .AND. aPriceTabs[nX,2] != 0
            aPriceTabs[nX,2]  += 25/aPriceTabs[nX,1] //Mindermengenzuschlag hinzurechnen
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

IF nTab == 29 .OR.  ((nTab == 12 .OR. lSubDistiGBP) .AND. oExtra != NIL .AND. oExtra:FixedEx) //fixed exchange rate
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
      nWeight := art->Gewicht/1000      
      AEval(aPriceTabs,{|aTab| IF(aTab[2]!=0,aTab[2] := aTab[2]+Hook("get_supplier_ship_cost",{Pad("SIGNAL",8),nWeight/1000*aTab[1]})/aTab[1],.T.) })
   ENDIF   
ELSEIF art->Manufactur $ {12,16} //Elcom oder Signal, Frachtkosten einrechnen
   IF art->Gewicht == 0 //no weight, no prices
      aPriceTabs := {}
   ELSE
      nWeight := art->Gewicht/1000      
      AEval(aPriceTabs,{|aTab| IF(aTab[2]!=0,aTab[2] := aTab[2]+GetUpsImportCost(nWeight*aTab[1])/aTab[1],.T.) })
   ENDIF   
ENDIF

IF Tr_GetIni(28) == 9
   //Alert(cKundma)
ENDIF


RETURN aPriceTabs

#include 'x:\run\getupsimportcost.prg'