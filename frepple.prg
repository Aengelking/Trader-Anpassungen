#define LAG_STOCK_USABLE           2
#define LAG_STOCK_OTHER_LOCATIONS  3
#define LAG_STOCK_ADDRESS          4
#define LAG_STOCK_TEMPBLOCK        6

#define ART_NEEDS_QS .F. //(! Empty(art->Zeichnung) .OR. art->QS .OR. AT(".LP.BS.",art->Matchcode) != 0)

FUNCTION RUN_FREPPLE
   LOCAL cPath := Path("export\frepple\")
   LOCAL nAddWeeks := 1
   LOCAL cDefaultLocation := "Engelking"
   LOCAL aNotSupplier := {"ITW","ETH","SELF","CONNECTS","HOPA"}
   
   LOCAL aRoutingItems
   LOCAL aMaterials := {},nLast
   LOCAL nI
   LOCAL lDummy
   /* LISTS */
   LOCAL aOperations := {{"Name","Item","Duration per unit","Duration","Type","Owner","Priority","Location","Size minimum","Size multiple","Size maximum"}}
   LOCAL aBom := {{"Item","Quantity","Fixed Quantity","Operation","Type"}}
   LOCAL aItemSuppliers
   LOCAL aItems := {{"Item-ID","Name","Description"}}   
   LOCAL aBuffers := {{"Item-ID","Item","Location","Onhand","Minimum"}}
   LOCAL aItemDistr := {{"Item","Location","Origin","Lead Time"}}
   LOCAL aUsedBoms   := {{"Item-ID","Item","Sales order"}}
   LOCAL aNoSupplierParts := {{"Item-ID"}}
   LOCAL aOperationResources := {{"Operation","Resource","Quantity","Skill","Search Mode"}}
   /* END OF LISTS */
   LOCAL lHasSupplier
   LOCAL aThisBom, aResources
   LOCAL aSalesOrders,aPurchaseOrders
   LOCAL aSuppliers := {{"Name"}},cSup
   LOCAL aCustomers := {{"Name"}}
   LOCAL aManuOrders
   LOCAL cDateFormat := Set(4,"yyyy-mm-dd")
   LOCAL lUsedBom
   LOCAL nPrio
   LOCAL nLohnArt
   LOCAL hMinAufStock := {=>},nMinStock,nArtnr
   LOCAL dStart,dEnd
   LOCAL nMonth,nMonths
   LOCAL cMatch,cRoutingMatch
   LOCAL cJobName
   LOCAL nSelf
   LOCAL cItem,cTo,cFrom
   LOCAL nX,oExtra
   LOCAL aInterParts := {}
   LOCAL lIntern,lFixed,nQty
   
   LOCAL bAddSupplier := {|cSupplier|   
      cSup := Trim(cSupplier)
      IF ! Trim(cSup) $ aNotSupplier //these are not suppliers anymore
         IF AScan(aSuppliers,{|x| x[1] == cSup }) == 0            
            Aadd(aSuppliers,{cSup})
         ENDIF
      ENDIF
      RETURN NIL
   }

   LOCAL bAddItem := {|| 
      LOCAL hOtherStock,nOtherStock
      IF art->Lagerart .AND. AScan(aItems,{|x| x[1] == art->Artikelnr },2) == 0
         Aadd(aItems,{art->Artikelnr,Trim(art->Matchcode),Trim(art->Artikel)})
         Aadd(aBuffers,{art->Artikelnr,Trim(art->Matchcode),cDefaultLocation,LagGetStock(art->Artikelnr,LAG_STOCK_USABLE)+LagGetStock(art->Artikelnr,LAG_STOCK_ADDRESS,nSelf)+LagGetStock(art->Artikelnr,LAG_STOCK_TEMPBLOCK),0})
         hOtherStock := LagGetStock(art->Artikelnr,LAG_STOCK_OTHER_LOCATIONS,0,.T.)
         ku->(dbSetOrder( 8))
         FOR EACH nOtherStock IN hOtherStock
            ku->(dbSeek( Str(nOtherStock:__enumKey(),6) ))
            IF Trim(ku->Kunde) != "SELF"               
               Aadd(aBuffers,{art->Artikelnr,Trim(art->Matchcode),Trim(ku->Kunde),nOtherStock,0})
            ENDIF
         NEXT
         /*IF ART_NEEDS_QS .OR. LagGetStock(art->Artikelnr,LAG_STOCK_TEMPBLOCK) != 0 //this part will need to be checked when it comes in, so we need an extra buffer for this
            Aadd(aItems,{art->Artikelnr*-1,Trim(art->Matchcode)+"_UNCHECKED","QS: "+Trim(art->Artikel)})
            Aadd(aBuffers,{art->Artikelnr*-1,Trim(art->Matchcode)+"_UNCHECKED",cDefaultLocation,LagGetStock(art->Artikelnr,LAG_STOCK_TEMPBLOCK),0})

            //Add manufacturing route
            Aadd(aOperations,{Trim(art->Matchcode)+"_QS", Trim(art->Matchcode),0,2*60*60,"fixed_time","",0,"Engelking" })
            Aadd(aOperationResources,{ATail(aOperations)[1],"Heike",1,,"MINCOSTPENALTY"})
            Aadd(aBom,{Trim(art->Matchcode),1,0,ATail(aOperations)[1],"end"})
            Aadd(aBom,{Trim(art->Matchcode)+"_UNCHECKED",-1,0,ATail(aOperations)[1],"start"})            
         ENDIF*/
      ENDIF
      RETURN NIL
   }

   LOCAL bAddItemDistr := {|c1,c2,c3,nDays|
      cItem := Trim(c1)
      cTo := Trim(c2)
      cFrom := Trim(c3)      
      IF AScan(aItemDistr,{|x| x[1] == cItem .AND. x[2] == cTo .AND. x[3] == cFrom },2) == 0
         Aadd(aItemDistr,{cItem,cTo,cFrom,nDays*24*60})
      ENDIF
      RETURN NIL
   }

   MEMVAR c_five

   NetUSe("artikel","art")
   NetUse("parts","part")
   NetUSe("werkauf","wer")
   NetUse("watime","wat")
   NetUse("jobs","job")
   NetUse("buyprice","bpr")
   NetUse("artlief","ali")
   NetUse("engkund","ku")
   NetUse("engauf","auf")
   NetUse("engbes","bes")
   NetUse("manufact","manu")
   NetUSe("partjobs","pjob")

   CLS

   ku->(dbSetOrder( 1 ))
   ku->(dbSeek( Pad("SELF",8)+"L" ))
   nSelf := ku->Nummer
   
   TxtBox("Routing items")

   //find all parts which are manufacturable
   Select("art")
   SET FILTER TO art->Bezug == 5 .AND. ! art->Obsolete .AND. art->Variant != "B"
   art->(dbGotop())   
   aRoutingItems := {}
   DO WHILE ! art->(EOF())   
      @ MaxRow()/2+2,MaxCol()/2-4 SAY "["+Str(art->Artikelnr,6)+"]" COLOR c_five
      IF art->Lagerart
         Aadd(aRoutingItems,art->Artikelnr)
      ENDIF
      art->(dbSkip())
   ENDDO
   art->(dbClearFilter())
   //aRoutingItems := {16830,16829}
   TxtClear()

   TxtBox("Bill of materials / operations")

   part->(dbSetOrder( 1 ))
   art->(dbSetOrder( 2 ))
   auf->(dbSetOrder( 3 ))
   ali->(dbSetOrder( 4 ))
   Select("part")

      
   FOR nI := 1 TO Len(aRoutingItems)
      @ MaxRow()/2+2,MaxCol()/2-4 SAY "["+Str(aRoutingItems[nI],6)+"]" COLOR c_five

      art->(dbSetOrder( 2 ))
      art->(dbSeek( Str(aRoutingItems[nI],6) ))
      cMatch := cRoutingMatch := Trim(art->Matchcode)
      IF ART_NEEDS_QS
         cMatch += "_UNCHECKED"
      ENDIF

      IF auf->(dbSeek( art->Matchcode )) .AND. auf->Matchcode == art->Matchcode .AND. auf->Bestat < 3 .AND. auf->VkQty-auf->GelQty > 0
         Aadd(aUsedBoms,{aRoutingItems[nI],art->Matchcode,auf->Abnr})
         lUsedBom := .T.
      ELSEIF AScan(aUsedBoms,{|x| x[1] == aRoutingItems[nI] },2) != 0
         lUsedBom := .T.
      ELSE
         lUsedBom := .F.  
      ENDIF     
      
      IF art->Artikelnr == 0; Frep_ERROR("Artikel nicht gefunden"+Str(aRoutingItems[nI])); ENDIF
      Eval(bAddItem)      
   
      IF ! part->(dbSeek( Str(aRoutingItems[nI],6) ))  //no bom found, then this cannot be produced
         LOOP
      ENDIF

      lDummy := .F.  
      lIntern := .F.    

      //find the last job, this is the one that outputs the part
      cJobName   := ""
      job->(dbSetOrder( 1 ))
      pjob->(dbSetOrder( 2 ))
      IF pjob->(dbSeek( Str(aRoutingItems[nI],6) ))
         lIntern := .T.  //only if there is a job we can produce internally           
      
         DO WHILE pjob->Artikelnr == aRoutingItems[nI]
            IF job->(dbSeek( Str(pjob->Job,6) ))  //check if the job really exists
               cJobName := job->Name
            ENDIF
            pjob->(dbSkip())
         ENDDO
         IF Empty(cJobName)  //no valid job found, we will output via the DUMMY
            lDummy := .T.  //remember that we are using a DUMMY operation 
         ENDIF

         //now we add the output position to the BOM list, of course only if we can produce internally
         Aadd(aBom,{cMatch,1*(1-_GetScrapRate(aRoutingItems[nI])),0,Trim(art->Matchcode)+"_"+IF(!Empty(cJobName),Trim(cJobName),"DUMMY"),"end"})
      ENDIF

      nLohnArt := 0
      aThisBom := {}
      
      DO WHILE part->Listart == aRoutingItems[nI]
         IF part->Pos == -1 .AND. (part->Qty != 0 .OR. part->AddQty != 0)
            nLohnArt := part->Partart
         ELSEIF part->Pos > 0 .AND. (part->Qty != 0 .OR. part->AddQty != 0)
            IF ! part->Partart $ aMaterials .AND. ! part->Partart $ aRoutingItems
               Aadd(aMaterials,part->Partart)
            ENDIF         
            art->(dbSeek( Str(part->Partart,6) ))
            IF art->Artikelnr == 0; Frep_ERROR("Artikel nicht gefunden fr Stli "+Str(part->Listart)+" Artikel:"+Str(part->Partart)); ENDIF           
            
            Eval(bAddItem)
            IF art->Bezug == 5 .AND. lUsedBom
               Aadd(aUsedBoms,{part->Partart,Trim(art->Matchcode),auf->Abnr})
            ENDIF
            pjob->(dbSetOrder( 1 ))
            IF ! pjob->(dbSeek( Str(aRoutingItems[nI],6)+Str(part->Job,6) )) //is this a valid job on this part list?
               lDummy := .T.
            ELSE
               job->(dbSeek( Str(part->Job,6) ))
            ENDIF            

            Aadd(aThisBom,{Trim(art->Matchcode),Round(part->Qty*(1+part->AddPercent/100)*IF(part->Factor==0,1,part->Factor)*-1,8),part->AddQty*IF(part->Factor==0,1,part->Factor)*-1,Trim(cRoutingMatch)+"_"+IF(pjob->(FOUND()),Trim(job->Name),"DUMMY"),IF(part->Qty<0,"end","start")})
            IF lIntern //if it can be produced internally we add it directly to the BOM list
               Aadd(aBom,ATail(aThisBom))
            ENDIF
         ENDIF
         part->(dbSkip())

      ENDDO

      
      art->(dbSetOrder( 2 )) 
      art->(dbSeek( Str(aRoutingItems[nI],6) ))
      pjob->(dbSetOrder( 2 ))

      IF lIntern
         pjob->(dbSeek( Str(aRoutingItems[nI],6) )) 
         Aadd(aOperations,{Trim(art->Matchcode), cMatch,0,0,"routing","","","Engelking",IF(art->VPE==0,1,art->VPE),IF(art->VPE==0,1,art->VPE) })

         IF lDummy  //if we need a DUMMY position (parts not assigned to a JOB), we add it here
            Aadd(aOperations,{Trim(art->Matchcode)+"_DUMMY", "",0,0,"time_per",Trim(art->Matchcode),0,"Engelking" })
         ENDIF  
         
         DO WHILE pjob->Artikelnr == aRoutingItems[nI]
            job->(dbSeek( Str(pjob->Job,6) ))
            lFixed := AT("TROCKNEN",Upper(Trim(job->Name)) ) == 1
            Aadd(aOperations,{Trim(art->Matchcode)+"_"+Trim(job->Name),"",IF(lFixed,0,pjob->Seconds),IF(lFixed,pjob->Seconds,0),IF(lFixed,"fixed_time","time_per"),Trim(art->Matchcode),pjob->Pos,"Engelking" })
            
            SWITCH Lower(Trim(job->Name))
               CASE "verpacken"
               CASE "programmieren"
                  aResources := {"Produktion"}
                  EXIT
               CASE "montage"
               CASE "kabel anl”ten"               
               CASE "bestcken"
                  aResources := {"Montage"}
                  EXIT
               CASE "prfen"
               CASE "prfen und verpacken"
                  aResources := {"Andrea"}
                  EXIT
               CASE "vergieáen"
                  aResources := {"Montage","Vergussmaschine"}
                  EXIT
               CASE "lackieren"
                  aResources := {"HP"}
                  EXIT
               OTHERWISE
                  aResources := {}
            END

            FOR nX := 1 TO Len(aResources)
               Aadd(aOperationResources,{ATail(aOperations)[1],aResources[nX],1,,"MINCOSTPENALTY"})
            NEXT
            pjob->(dbSkip())
         ENDDO
         Aadd(aInterParts,art->Artikelnr) //List of internally producable parts, used for the sales orders
      ENDIF
      
      IF nLohnArt != 0
         ali->(dbSeek( Str(nLohnArt,6) ))
         DO WHILE ali->Artikelnr == nLohnArt
            IF ! Trim(ali->Kunde) $ aNotSupplier
               art->(dbSeek( Str(aRoutingItems[nI],6) ))  
               
               //add a operation to the operation list. For external production we only need this one. It will contain all parts
               Aadd(aOperations,{Trim(art->Matchcode)+"_"+Trim(ali->Kunde), cMatch,0,(IF(ali->LZ>0,ali->LZ,IF(art->LZ==0,12,art->LZ))+nAddWeeks)*7*24*60*60,"fixed_time","","",Trim(ali->Kunde) })

               //add the output position for each supplier, without scrap rate as this is only used internnally
               Aadd(aBom,{cMatch,1,0,Trim(art->Matchcode)+"_"+Trim(ali->Kunde),"end"})

               ku->(dbSeek( ali->Kunde+"L" ))
               oExtra := ku->(ExtraData():New(ku->Nummer))
               Eval(bAddItemDistr,art->Matchcode,cDefaultLocation,ali->Kunde,oExtra:RecvTime)
               FOR nX := 1 TO Len(aThisBom)
                  Eval(bAddItemDistr,aThisBom[nX,1],ali->Kunde,cDefaultLocation,oExtra:ShipTime) //add the item distribution from us to the supplier
                  Aadd(aBom,AClone(aThisBom[nX])) //add the bom position
                  ATail(aBom)[4] := Trim(art->Matchcode)+"_"+Trim(ali->Kunde)  //change the operation name to point to the external operation
               NEXT

            ENDIF
            ali->(dbSkip())     
         ENDDO
      ENDIF
   NEXT
   part->(dbClearFilter())
   art->(dbClearFilter())

   TxtClear()

   nLast := Len(aMaterials)
   ASize(aMaterials,nLast+Len(aRoutingItems))
   ACopy(aRoutingItems,aMaterials,1,,nLast+1)

   TxtBox("Item suppliers")

   aItemSuppliers := {{"Item-ID","Item","Supplier","Location","Lead time","Size minimum","Size multiple","Cost","Priority"}}
   
   bpr->(dbSetOrder( 2 ))
   ali->(dbSetOrder( 4 ))
   Select("bpr")
   SET FILTER TO bpr->StartDate <= Date() .AND. (Empty(bpr->Enddate) .OR. bpr->EndDate >= Date())

   FOR nI := 1 TO Len(aMaterials)
      @ MaxRow()/2+2,MaxCol()/2-4 SAY "["+Str(aMaterials[nI],6)+"]" COLOR c_five
      lHasSupplier := .F.
      ali->(dbSeek( Str(aMaterials[nI],6) ))
      
      DO WHILE ali->Artikelnr == aMaterials[nI]
         IF ! Trim(ali->Kunde) $ aNotSupplier
            art->(dbSeek( Str(aMaterials[nI],6) ))  
            IF Trim(ali->Kunde) == "WALDOM"  //hard coded priority for Waldom
               nPrio := 20
            ELSEIF manu->(dbSeek( Str(art->Manufactur,5) )) .AND. manu->Address != 0 .AND. ku->(dbSeek( Str(manu->Address,6) )) .AND. ali->Kunde == ku->Kunde  //the manufacturer has a higher priority
               nPrio := 10
            ELSE
               nPrio := 100
            ENDIF
               
            Aadd(aItemSuppliers,{aMaterials[nI],Trim(art->Matchcode),Trim(ali->Kunde),cDefaultLocation,(IF(ali->LZ>0,ali->LZ,IF(art->LZ==0,12,art->LZ))+nAddWeeks)*7*24*60*60,ali->VPE,ali->VPE,0,nPrio})         
            Eval(bAddSupplier,ali->Kunde)
            lHasSupplier := .T.
         ENDIF
         ali->(dbSkip())

      ENDDO
      IF ! lHasSupplier .AND. ! aMaterials[nI] $ aRoutingItems
         Aadd(aNoSupplierParts,{aMaterials[nI]})
      ENDIF
   NEXT
   bpr->(dbClearFilter())

   //save the file
   
   
   TxtClear()

   TxtBox("Sales orders")

   aSalesOrders := {{"Name","Customer",/*"Item-ID",*/"Item","Quantity","Minimum Shipment","Due","Priority","Location","Status"}}
   ku->(dbSetOrder( 1 ))
   Select("auf")
   SET FILTER TO auf->bestat < 3 .AND. auf->VkQty-auf->GelQty > 0
   auf->(dbGoTop())
   DO WHILE ! auf->(EOF())      
      @ MaxRow()/2+2,MaxCol()/2-4 SAY "["+Str(auf->Abnr,6)+"]" COLOR c_five
      IF auf->Artikelnr $ aRoutingItems .OR. auf->Artikelnr $ aMaterials 
      
         art->(dbSeek( Str(auf->Artikelnr,6) ))    
         IF art->Lagerart     
            Eval(bAddItem)

            IF AScan(aCustomers,{|x| x[1] == Trim(auf->Kundma) }) == 0            
               Aadd(aCustomers,{Trim(auf->Kundma)})
            ENDIF   
            ku->(dbSeek( auf->Kundma+"K" ))    
            IF Right(Str(auf->Dterm),2) == "99" //Rahmen, only Meldebestand
               IF ! auf->Artikelnr $ hMinAufStock 
                  hMinAufStock[auf->Artikelnr] := 0
               ENDIF
               hMinAufStock[auf->Artikelnr] += Min(auf->MeldStock,auf->VkQty)
               IF auf->Artikelnr $ aInterParts .AND. auf->WTerm > Cweek(Date())  .AND. auf->MeldStock < auf->VkQty //on internal parts we spread the open qty over the rest of the time
                  nMonths :=  WeeksBetween(auf->Wterm,Cweek(Date()))/4.3
                  art->(dbSeek( Str(auf->Artikelnr,6) ))
                  nQty := Val(TransForm((auf->VkQty-auf->GelQty-auf->MeldStock)/nMonths,Me(art->Me)))
                  FOR nMonth := 1 TO nMonths      
                     Aadd(aSalesOrders,{Ltrim(Str(auf->Abnr))+"-FC-"+StrZero(nMonth,2),Trim(auf->Kundma),auf->Matchcode,nQty,nQty,Frep_DtoC(AddMonth(Date(),nMonth),"10:00"),IF(ku->JustinTime,20,30),cDefaultLocation,"open"})
                  NEXT
               ENDIF
            ELSE            
               Aadd(aSalesOrders,{Ltrim((Str(auf->Abnr))+"-"+StrZero(auf->Itmnr,3)),Trim(auf->Kundma),/*auf->Artikelnr,*/auf->Matchcode,auf->VkQty-auf->GelQty,auf->VkQty-auf->GelQty,Frep_DtoC(IF(ku->JustinTime,GetJITLiefertag(auf->BDatum,ku->JIT_LZ),CalWD(auf->Dterm)+4),"10:00"),IF(ku->JustinTime,5,10),cDefaultLocation,"open"})
            ENDIF
         ENDIF
      ENDIF
      auf->(dbSkip())
   ENDDO
   auf->(dbClearFilter())

   FOR EACH nMinStock IN hMinAufStock
      nArtnr := nMinStock:__eNumKey()
      nI := AScan(aBuffers,{|x| x[1] == nArtnr .AND. x[3] == cDefaultLocation },2)    
      IF nI == 0
         Tr_MsgBox("Buffer missing for "+LTrim(str(nMinStock:__eNumKey())))                    
      ELSE
         ///aBuffers[nI,5] := Max(nMinStock:__eNumKey(),aBuffers[nI,5])
      ENDIF
   NEXT
   

   TxtClear()

   TxtBox("Purchase orders")

   aPurchaseOrders := {{"Reference","Supplier",/*"Item-ID",*/"Item","Quantity","Receipt Date","Status","Location"}}
   Select("bes")
   SET FILTER TO bes->Bestat < 3 .AND. bes->BeQty-bes->GelQty > 0 .AND. ! bes->Rahmen
   bes->(dbSeek(Str(1,6),.T.))
   DO WHILE ! bes->(EOF())
      @ MaxRow()/2+2,MaxCol()/2-4 SAY "["+Str(bes->Besnr,6)+"]" COLOR c_five
      IF bes->Artikelnr $ aRoutingItems .OR. bes->Artikelnr $ aMaterials 
         art->(dbSeek( Str(bes->Artikelnr,6) ))   
         IF art->Lagerart      
            Eval(bAddItem)
            Aadd(aPurchaseOrders,{IF(bes->Besnr==-1,Trim(bes->Liefma)+"_WAIT",LTrim(Str(bes->Besnr)))+"-"+LTrim(Str(bes->Posnr)),bes->Liefma,/*bes->Artikelnr,*/bes->Matchcode,bes->BeQty-bes->GelQty,Frep_DtoC(CalWD(bes->Lterm)+4+nAddWeeks*7,"08:00"),IF(bes->Confirmed=="Y","confirmed","approved"),cDefaultLocation})
            Eval(bAddSupplier,bes->Liefma)
         ENDIF
      ENDIF
      bes->(dbSkip())
   ENDDO
   bes->(dbClearFilter())   

   TxtClear()

   TxtBox("Manufacturing orders")

   aManuOrders := {{"Reference","Item","Quantity","Start Date","End Date","Status","Operation"}}
   Select("wer")
   SET FILTER TO wer->Status < 4 /*.AND. Empty(wer->Liefma)*/ .AND. wer->Qty-wer->PlanBad > 0 .AND. Right(Str(wer->TerminFrue,4),2) != "99"
   wer->(dbGotop())
   DO WHILE ! wer->(EOF())
      IF wer->Status >= 1 .OR.  ! Empty(wer->Liefma) //AScan(aItemSuppliers,{|x| x[1] == wer->Artno },2) != 0 //we only add orders which are in production or also can be purchased externaly
         @ MaxRow()/2+2,MaxCol()/2-4 SAY "["+Str(wer->Aufno,6)+"]" COLOR c_five     
         IF ! Empty(wer->Liefma)
            bes->(dbSetOrder( 1 ))
            bes->(dbSeek( Str(wer->Besnr,6) )) 
            dStart := CalWD(wer->termin)+4
            dEnd   := CalWD(wer->End)+4
         ELSE
            dStart := wer->StartDate
            dEnd   := wer->EndDate
         ENDIF
         //IF Empty(wer->Liefma) //.OR. bes->Confirmed == "Y"
            Aadd(aManuOrders,{"FA"+LTrIM(Str(wer->Aufno)),Trim(wer->Matchcode),wer->Qty-wer->PlanBad-wer->GelQty,Frep_DtoC(dStart,"08:00"),Frep_DtoC(dEnd,"16:30"),IF(wer->status>=1,"confirmed","approved"),Trim(wer->Matchcode)+IF(!Empty(wer->liefma),"_"+Trim(wer->Liefma),"")})
         //ENDIF
         //IF(wat->(dbSeek( Str(wer->Aufno,6) )),"confirmed","approved")
      ENDIF
      wer->(dbSkip())
   ENDDO
   wer->(dbClearFilter())

   

   TxtClear()

   TxtBox("Saving files")

   SaveAsCSV(cPath+"item supplier.csv",aItemSuppliers,.T.,.T.)
   SaveAsCSV(cPath+"sales order.csv",aSalesOrders,.T.,.T.)
   SaveASCSV(cPath+"purchase order.csv",aPurchaseOrders,.T.,.T.)
   SaveASCSV(cPath+"supplier.csv",aSuppliers,.T.,.T.)
   SaveASCSV(cPath+"customer.csv",aCustomers,.T.,.T.)
   SaveASCSV(cPath+"item.csv",aItems,.T.,.T.)
   SaveASCSV(cPath+"buffer.csv",aBuffers,.T.,.T.)
   SaveASCSV(cPath+"manufacturing order.csv",aManuOrders,.T.,.T.)
   SaveAsCSV(cPath+"operation resource.csv",aOperationResources,.T.,.T.)
   SaveAsCSV(cPath+"operation material.csv",aBom,.T.,.T.)
   SaveAsCSV(cPath+"operation.csv",aOperations,.T.,.T.)
   SaveASCSV(cPath+"item distribution.csv",aItemDistr,.T.,.T.)

   //non frePPLe files
   SaveASCSV(cPath+"used_boms.csv",aUsedBoms,.T.,.T.)
   SaveAsCSV(cPath+"parts with no supplier.csv",aNoSupplierParts,.T.,.T.)

   TxtClear()

   Set(4,cDateFormat)

RETURN NIL


STATIC FUNCTION _GetScrapRate(nArtnr)
      LOCAL nTotQty  := 0      
      LOCAL nTotBad  := 0

      wer->(dbSetOrder( 2 )) // Str(artno)
      
      Select("wer")    
      SET FILTER TO wer->Status >= 4 .AND. wer->Qty > 0 .AND. wer->Date >= StoD("20150601")
      wer->(dbSeek( Str(nArtnr,6) ))
      DO WHILE wer->Artno == nArtnr .AND. ! wer->(EOF())
         nTotQty += wer->Qty
         nTotBad += wer->BadQty //+(wer->Qty-wer->GelQty)           
         wer->(dbSkip())
      ENDDO
      wer->(dbClearFilter())
      IF nTotQty <= 0
         RETURN 0
      ENDIF
      
RETURN nTotBad/nTotQty


STATIC FUNCTION Frep_DToC(dDate,cTime)
RETURN DtoC(dDate)+" "+cTime+":00"

STATIC FUNCTION Frep_ERROR(cText)
   Alert(cText)
RETURN NIL


#include 'x:\run\savetooo.prg'