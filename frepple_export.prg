#define LAG_STOCK_USABLE           2
#define LAG_STOCK_OTHER_LOCATIONS  3
#define LAG_STOCK_ADDRESS          4
#define LAG_STOCK_TEMPBLOCK        6

#define ART_NEEDS_QS art->QS .OR. AScan(aItems,{|x| x[2] == Trim(art->Matchcode)+"_UNCHECKED"}) != 0 ///*.OR. AT(".LP.BS.",art->Matchcode) != 0*/) .OR. ! Empty(art->Zeichnung)

FUNCTION RUN_FREPPLE_EXPORT()
   /* SETTINGS */
   LOCAL cPath := Path("export\frepple\")
   LOCAL nAddWeeks := 0
   LOCAL nDefaultLZ := 12
   LOCAL nDefaultQSTime := GetValue("FREPPLE_QSTIME",30,"Default time used by QS if no job (minutes)")
   LOCAL cDefaultLocation := GetValue("FREPPLE_DEFAULT-LOCATION","Engelking","Location used when not a supplier")
   LOCAL aNotSupplier := {"SELF"}
   LOCAL aOnlineSupplier := {} //"FARNELL","RS","MOUSER","DIGIKEY","ARROW","AVNET","ARROWUS","SCHUKAT","DISTRELE","TME","CONRAD","REICHELT","FUTURE","BšRKLIN","TTI","TTIUSA","SCHURICH"}
   LOCAL cUnkownSupplier := "UNKOWNSUPPLIER"
   LOCAL cOnlineSupplier := "ANYWHEREONLINE"
   LOCAL lIncludeSales := .T.
   LOCAL cOpSeparator := "|"
   /* END OF SETTINGS */
   LOCAL aRoutingItems
   LOCAL aMaterials := {},nLast
   LOCAL nI
   LOCAL lDummy
   /* LISTS */
   LOCAL aOperations := {{"Name","Item","Duration per unit","Duration","Type","Owner","Priority","Location","Size minimum","Size multiple","Size maximum","Post-Op Time"}}
   LOCAL aBom := {{"Item","Quantity","Fixed Quantity","Operation","Type"}}
   LOCAL aItemSuppliers := {{"Item-ID","Item","Supplier","Location","Lead time","Size minimum","Size multiple","Cost","Priority","Resource"}}
   LOCAL aItems := {{"Item-ID","Name","Description"}}   
   LOCAL aBuffers := {{"Item-ID","Item","Location","Onhand","Minimum","Min_Interval"}}
   LOCAL aItemDistr := {{"Item","Location","Origin","Lead Time"}}
   //LOCAL aUsedBoms   := {{"Item-ID","Item","Sales order"}}
   LOCAL aErrors := {{"Item-ID","Item","Error level","Error code","Description"}}
   LOCAL aOperationResources := {{"Operation","Resource","Quantity","Skill","Search Mode"}}
   LOCAL aPurchaseOrders := {{"Reference","Supplier","Ordering Date",/*"Item-ID",*/"Item","Quantity","Receipt Date","Status","Location"}}
   LOCAL aManuOrders := {{"Reference","Item","Quantity","Start Date","End Date","Status","Operation","Owner"}} //,"Resources"
   LOCAL aResourceDetail := {{"Resource","Reference","Quantity","Start Date","End Date","Status"}}
   LOCAL aSalesOrders := {{"Name","Customer","Item","Quantity","Minimum Shipment","Due","Priority","Location","Status"}}
   LOCAL aResource := {{"Name","Owner","Location","Type","Maximum Calendar"}}
   LOCAL aCalendars := {{"Name","Default Value"}}
   LOCAL aCalBuckets := {{"Calendar","Start Date","End Date","Value","Priority","Monday","Tuesday","Wednesday","Thursday","Friday"}} //{"Calendar","Start Date","End Date","Value","Priority","Monday","Tuesday"}}
   /* END OF LISTS */
   LOCAL lHasSupplier, lBuyOnline,oExtra,oWerExtra,aManuSubOrders
   LOCAL aThisBom
   LOCAL aSuppliers := {{"Name"}},cSup
   LOCAL aCustomers := {{"Name"}}
   LOCAL cDateFormat := Set(4,"yyyy-mm-dd")
   //LOCAL lUsedBom
   LOCAL nPrio
   LOCAL nLohnArt
   LOCAL hMinAufStock := {=>},nMinStock,nArtnr
   LOCAL dStart,dEnd
   LOCAL nMonth,nMonths
   LOCAL cMatch,cRoutingMatch
   LOCAL cJobName
   LOCAL nSelf
   LOCAL cItem,cTo,cFrom
   LOCAL nX
   LOCAL aInterParts := {}
   LOCAL lIntern,nQty,nAufQty,nStep,nFirst
   LOCAL nVPE
   LOCAL cQSJob,nQSJob := 0,nStock,cQSStart
   LOCAL cArriveTime,cArriveTime2
   LOCAL lCurrentParts
   LOCAL cErrorFile,oRec
   LOCAL aIds
   LOCAL nErrorCount
   LOCAL hFiles,aData,lCancel,cFirstOp
   LOCAL cResource,nLZ,aCalBucket
   LOCAL oErr,cStatus,lConfirmed,nDelWeek
   LOCAL tStart,tEnd,nRec,nDays,nPostOp
   LOCAL oArtExtra
   LOCAL dDate,nKW,cFilter
   LOCAL bAddPurchaseOrder,nGelQty,bAddManuOrder
   LOCAL nDWeek,nRestockWeeks,nGap,aWeeks,nTotMeld
   LOCAL lHasResource
   MEMVAR c_five

   LOCAL bAddSupplier := {|cSupplier|   
      cSup := Trim(cSupplier)
      IF ! Trim(cSup) $ aNotSupplier //these are not suppliers anymore
         IF AScan(aSuppliers,{|x| x[1] == cSup }) == 0            
            Aadd(aSuppliers,{cSup})
         ENDIF
      ENDIF
      RETURN NIL
   }

   LOCAL bAddOpResources :=  {|nJob,cMain|
      res->(dbSetOrder( 1 ))
      IF pjore->(dbSeek( Str(art->Artikelnr,6)+Str(nJob,6) ))
         DO WHILE pjore->Job == nJob .AND. pjore->Artikelnr == art->Artikelnr .AND. ! pjore->(EOF())               
            
            res->(dbSeek( Str(pjore->Resource,6) ))
            Aadd(aOperationResources,{cMain,res->Name,1,"Any","MINCOSTPENALTY"})
            
            pjore->(dbSkip())
         ENDDO
      ELSE
         jore->(dbSeek( Str(nJob,6) ))               
         DO WHILE jore->Job == nJob .AND. ! jore->(EOF())               
         
            res->(dbSeek( Str(jore->Resource,6) ))
            Aadd(aOperationResources,{cMain,res->Name,1,"Any","MINCOSTPENALTY"})
         
            jore->(dbSkip())
         ENDDO
      ENDIF
      RETURN  NIL
   }

   LOCAL bAddOps := {|nArtikelnr,cRouting,lQS,cFirstOp|
      LOCAL lFound := .F.
      pjob->(dbSeek( Str(nArtikelnr,6) )) 
      DO WHILE pjob->Artikelnr == nArtikelnr         
         job->(dbSeek( Str(pjob->Job,6) ))  
         IF (! lQS .AND. AT(cQSStart,job->Name) != 1) .OR. (lQS .AND. AT(cQSStart,job->Name) == 1)
            
            Aadd(aOperations,{Trim(art->Matchcode)+cOpSeparator+Trim(job->Name),"",pjob->Seconds,pjob->Fixed*60,IF(!Empty(pjob->Fixed),"fixed_time","time_per"),cRouting,pjob->Pos,cDefaultLocation,0,0,0,0})
            
                        
            Eval(bAddOpResources,pJob->Job,ATail(aOperations)[1])
            IF Empty(cFirstOp)
               cFirstOp := ATail(aOperations)[1]
            ENDIF
            lFound := .T.
         ENDIF

         pjob->(dbSkip())
      ENDDO
      RETURN lFound
   }

   LOCAL bAddItem := {|| 
      LOCAL hOtherStock,nOtherStock
      LOCAL cMatch
      LOCAL cQSRouting       
      IF (art->Lagerart .OR. fol->(dbSeek(Str(art->artikelnr,6)))) .AND. AScan(aItems,{|x| x[1] == art->Artikelnr },2) == 0
         Aadd(aItems,{art->Artikelnr,Trim(art->Matchcode),Trim(art->Artikel)})
         oArtExtra := art->(ExtraData():New(art->Artikelnr))
         Aadd(aBuffers,{art->Artikelnr,Trim(art->Matchcode),cDefaultLocation,LagGetStock(art->Artikelnr,LAG_STOCK_USABLE)+LagGetStock(art->Artikelnr,LAG_STOCK_ADDRESS,nSelf)+HLAGER(art->Artikelnr,Pad("090/",12)),art->Mindest,oArtExtra:MinInterval}) //LagGetStock(art->Artikelnr,LAG_STOCK_TEMPBLOCK)
         hOtherStock := LagGetStock(art->Artikelnr,LAG_STOCK_OTHER_LOCATIONS,0,.T.)
         ku->(dbSetOrder( 8))
         FOR EACH nOtherStock IN hOtherStock
            ku->(dbSeek( Str(nOtherStock:__enumKey(),6) ))
            IF Trim(ku->Kunde) != "SELF"               
               Aadd(aBuffers,{art->Artikelnr,Trim(art->Matchcode),Trim(ku->Kunde),nOtherStock,0,0})
            ENDIF
         NEXT

         nStock := LagGetStock(art->Artikelnr,LAG_STOCK_TEMPBLOCK)-HLAGER(art->Artikelnr,Pad("090/",12))
         
         IF ART_NEEDS_QS .OR. nStock > 0 //this part will need to be checked when it comes in, so we need an extra buffer for this
            Aadd(aItems,{art->Artikelnr*-1,Trim(art->Matchcode)+"_UNCHECKED","QS: "+Trim(art->Artikel)})
            Aadd(aBuffers,{art->Artikelnr*-1,Trim(art->Matchcode)+"_UNCHECKED",cDefaultLocation,nStock,0,0})

            IF nStock > 0
               //Aadd(aManuOrders,{"QS-STOCK"+LTrim(Str(art->Artikelnr)),Trim(art->Matchcode),nStock,,,"approved",Trim(art->Matchcode)+cOpSeparator+"QS:"+LTrim(Str(art->Artikelnr)),""})  //export without start and end date and let frepple plan, Frep_DtoC(Date(),"08:00")
            ENDIF

            //Add manufacturing route
            cQSRouting := Trim(art->Matchcode)+cOpSeparator+"QS:"+LTrim(Str(art->Artikelnr))
            Aadd(aOperations,{cQSRouting,Trim(art->Matchcode),0,0,"routing","",1,cDefaultLocation,0,0,0,0 })
            cFirstOp := ""
            IF ! Eval(bAddOps,art->Artikelnr,cQSRouting,.T.,@cFirstOp)
               Aadd(aOperations,{Trim(art->Matchcode)+cOpSeparator+"QS",Trim(art->Matchcode),0,nDefaultQSTime*60,"fixed_time",cQSRouting,10,cDefaultLocation,0,0,0,0 })
               cFirstOp := ATail(aOperations)[1]
               Eval(bAddOpResources,nQSJob,cFirstOp)               
            ENDIF            

            Aadd(aBom,{Trim(art->Matchcode),1,0,ATail(aOperations)[1],"end"})
            Aadd(aBom,{Trim(art->Matchcode)+"_UNCHECKED",-1,0,cFirstOp,"start"})            
         ENDIF

         //Item Supplier         
         ali->(dbSetOrder( 4 ))         
      
         lHasSupplier := .F.
         lBuyOnline := .F.
         ali->(dbSeek( Str(art->Artikelnr,6) ))         
         cMatch := Trim(art->Matchcode)
         IF ART_NEEDS_QS  //external parts are also checked when there is a drawing
            cMatch += "_UNCHECKED"
         ENDIF
      
         DO WHILE ali->Artikelnr == art->Artikelnr
            IF Trim(ali->Kunde) $ aOnlineSupplier 
               IF ! lBuyOnline               
                  Aadd(aItemSuppliers,{art->Artikelnr,cMatch,cOnlineSupplier,cDefaultLocation,(0+nAddWeeks)*7*24*60*60,0,0,0,200})         
                  Eval(bAddSupplier,cOnlineSupplier)       
               ENDIF
               lHasSupplier := .T.     
               lBuyOnline := .T.
            ELSEIF ! Trim(ali->Kunde) $ aNotSupplier
               IF Trim(ali->Kunde) == "WALDOM"  //hard coded priority for Waldom
                  nPrio := 2
               ELSEIF manu->(dbSeek( Str(art->Manufactur,5) )) .AND. manu->Address != 0 .AND. ku->(dbSeek( Str(manu->Address,6) )) .AND. ali->Kunde == ku->Kunde  //the manufacturer has a higher priority
                  nPrio := 1
               ELSE
                  nPrio := 9
               ENDIF

               //delivery time
               IF ali->LZ != 0 //if set on the item supplier
                  nLZ := ali->LZ
               ELSEIF art->LZ != 0 //if set on the item we use this instead
                  nLZ := art->LZ
               ELSE  //none found use the default
                  nLZ := nDefaultLZ
               ENDIF
               nLZ += nAddWeeks //add the extra time

               cResource := ""
               IF lsto->(dbSeek( ali->Kunde+Str(art->Artikelnr,6) )) //Stocking supplier                  
                  
                  cResource := Trim(ali->Kunde)+":"+Trim(art->Matchcode)                 

                  //add maximumm calendar, in this case the value is the stock, we give it the same name as the resource
                  //we set the degault value to a high number
                  Aadd(aCalendars,{cResource,99999})
                  //add a resource to model the stock capacity using the maximum calendar we just set up
                  Aadd(aResource,{cResource,"",cDefaultLocation,"buckets",cResource}) //Name,Owner,Location,Type,Maximum Calendar

                  aCalBucket := {cResource,Date(),,lsto->Stock,10}                  
                  IF lsto->DelQty != 0
                     aCalBucket[3] := Date()+lsto->DelTime
                  ELSE
                     aCalBucket[3] := CalWD(AddWeeks(CWeek(Date()),nLZ))
                  ENDIF

                  FOR nX := 1 TO 5
                     Aadd(aCalBucket,"True")
                  NEXT
                  Aadd(aCalBuckets,aCalBucket)

                  IF lsto->DelQty != 0
                     aCalBucket := {cResource,Date()+lsto->DelTime,CalWD(AddWeeks(CWeek(Date()),nLZ)),lsto->DelQty,20}

                     FOR nX := 1 TO 5
                        Aadd(aCalBucket,"True")
                     NEXT
                     Aadd(aCalBuckets,aCalBucket)
                  ENDIF

                  nLZ := nAddWeeks //lead time is always immediate, the rest is regulated by the calendar
               ENDIF
               
               Aadd(aItemSuppliers,{art->Artikelnr,cMatch,Trim(ali->Kunde),cDefaultLocation,nLZ*7*24*60*60,ali->VPE,IF(ali->VPE==0,10^(GetMeDecimals(art->Me)*-1),ali->VPE),0,nPrio,cResource})         
               Eval(bAddSupplier,ali->Kunde)
               lHasSupplier := .T.
            ENDIF
            ali->(dbSkip())
   
         ENDDO
         IF ! lHasSupplier .AND. ! art->Artikelnr $ aRoutingItems
            //Add an unkown supplier so it can be bought
            Aadd(aItemSuppliers,{art->Artikelnr,cMatch,cUnkownSupplier,cDefaultLocation,(nDefaultLZ+nAddWeeks)*7*24*60*60,0,0,0,100})         
            Eval(bAddSupplier,cUnkownSupplier)
            Aadd(aErrors,{art->Artikelnr,art->Matchcode,"WARNING","NOSUPPLIER","No supplier found, added dummy supplier."})
         ENDIF   
         IF ! art->Lagerart  
            //create a operation plan to take the parts apart, as this cannot be stocked
            Aadd(aOperations,{cMatch+"|DISASSEMBLE",Trim(art->Matchcode),0,0,"fixed_time","",1,cDefaultLocation,0,0,0,0 })
            //input position
            Aadd(aBom,{art->Matchcode,-1,0,ATail(aOperations)[1],"start"})
            nArtnr := art->Artikelnr
            DO WHILE fol->Artikelnr == nArtnr
               art->(dbSeek( Str(fol->Folgeart,6) ))
               Eval(bAddItem)
               Aadd(aBom,{art->Matchcode,fol->Faktor,0,ATail(aOperations)[1],"end"})
               fol->(dbSkip())
            ENDDO
            art->(dbSeek( Str(nArtnr,6) ))
         ENDIF
         

      ENDIF
      RETURN NIL
   }

   LOCAL bAddItemDistr := {|c1,c2,c3,nDays|
      cItem := Trim(c1)
      cTo := Trim(c2)
      cFrom := Trim(c3)      
      IF AScan(aItemDistr,{|x| x[1] == cItem .AND. x[2] == cTo .AND. x[3] == cFrom },2) == 0
         Aadd(aItemDistr,{cItem,cTo,cFrom,nDays*24*60*60})
      ENDIF
      RETURN NIL
   }

   SET TIME FORMAT TO "hh:mm:ss"
   

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
   NetUse("werks","we")
   NetUse("jobsres","jore")
   NetUse("partjobres","pjore")
   NetUse("resource","res")
   NetUse("bom","bom")
   NetUse("liefstock","lsto")
   NetUse("restime","rst")
   NetUse("folgeart","fol")
   NetUse("besdel","bdel")

   CLS

   job->(dbSetOrder( 2 ))
   cQSStart := Trim(GetValue("FREPPLE_QS_JOBST","QS","QS job names start with"))   
   cQSJob := Trim(GetValue("FREPPLE_QS_JOB","QS","Job name for main QS task"))
   IF AT(cQSStart,cQSJob) != 1
      oErr := ErrorNew()
      oErr:SubSystem   := "frePPLe-API"
      oErr:Description := "QS Job does not start with "+cQSStart
      oErr:Args        := {cQSJob}
      Throw(oErr) 
   ENDIF  
   IF job->(dbSeek( cQSJob ))
      nQSJob := job->Nummer
   ELSE
      Aadd(aErrors,{0,"","ERROR","NOQS","No QS job found"})
   ENDIF
   
   

   //find the SELF Adress
   ku->(dbSetOrder( 1 ))
   ku->(dbSeek( Pad("SELF",8)+"L" ))
   nSelf := ku->Nummer

   //build list of Online suppliers
   ku->(dbSetOrder( 8 ))
   aIds := GetIdsWithExtraField("KU","ONLINESUPP") //all suppliers where this field has been set
   FOR EACH nX IN aIds
      ku->(dbSeek( Str(nX,6) ))      
      oExtra := ku->(ExtraData():New(nX))
      IF ku->Group == "L"  .AND. oExtra:OnlineSupp //make sure it is a supplier and the field is set to true
         Aadd(aOnlineSupplier,Trim(ku->Kunde))
      ENDIF
   NEXT

   
   TxtBox("Routing items")

   //find all parts which are manufacturable
   Select("art")
   SET FILTER TO art->Bezug == 5 .AND. ! art->Obsolete .AND. art->Variant != "B" .AND. art->Lagerart
   art->(dbGotop())   
   aRoutingItems := {}
   DO WHILE ! art->(EOF())   
      @ MaxRow()/2+2,MaxCol()/2-4 SAY "["+Str(art->Artikelnr,6)+"]" COLOR c_five
      //IF art->Bezug == 5 .OR. part->(dbSeek( Str(art->Artikelnr,6) ))
         Aadd(aRoutingItems,art->Artikelnr)
      //ENDIF
      
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

      /*IF auf->(dbSeek( art->Matchcode )) .AND. auf->Matchcode == art->Matchcode .AND. auf->Bestat < 3 .AND. auf->VkQty-auf->GelQty > 0
         Aadd(aUsedBoms,{aRoutingItems[nI],art->Matchcode,auf->Abnr})
         lUsedBom := .T.
      ELSEIF AScan(aUsedBoms,{|x| x[1] == aRoutingItems[nI] },2) != 0
         lUsedBom := .T.
      ELSE
         lUsedBom := .F.  
      ENDIF          */
  
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
         DO WHILE pjob->Artikelnr == aRoutingItems[nI] .AND. job->(dbSeek( Str(pjob->Job,6) )) .AND. AT(cQSStart,job->Name) == 1  //skip the QS jobs
            pjob->(dbSkip())
         ENDDO
         IF pjob->Artikelnr == aRoutingItems[nI] 
            lIntern := .T.  //only if there is a job (which is not QS) we can produce internally            
         
            DO WHILE pjob->Artikelnr == aRoutingItems[nI]
               IF job->(dbSeek( Str(pjob->Job,6) )) .AND. AT(cQSStart,job->Name) != 1 //check if the job really exists and is not a QS job
                  cJobName := job->Name
               ENDIF
               pjob->(dbSkip())
            ENDDO
            IF Empty(cJobName)  //no valid job found, we will output via the DUMMY
               lDummy := .T.  //remember that we are using a DUMMY operation 
            ENDIF

            Eval(bAddItem)              

            //now we add the output position to the BOM list, we only need this if we can produce internally
            Aadd(aBom,{cMatch,1*(1-_GetScrapRate(aRoutingItems[nI])),0,Trim(art->Matchcode)+cOpSeparator+IF(!Empty(cJobName),Trim(cJobName),"DUMMY"),"end"})
         ENDIF
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
            IF art->Artikelnr == 0
               Aadd(aErrors,{part->Partart,"","FATAL","ITEMNOTFOUND","Item not found for part list "+Str(part->Listart)})                              
            ENDIF
            
            Eval(bAddItem)
            /*IF art->Bezug == 5 .AND. lUsedBom
               Aadd(aUsedBoms,{part->Partart,Trim(art->Matchcode),auf->Abnr})
            ENDIF*/
            pjob->(dbSetOrder( 1 ))
            IF ! pjob->(dbSeek( Str(aRoutingItems[nI],6)+Str(part->Job,6) )) //is this a valid job on this part list?
               lDummy := .T.
            ELSE
               job->(dbSeek( Str(part->Job,6) ))
            ENDIF            
            
            Aadd(aThisBom,{Trim(art->Matchcode),Round(part->Qty*(1+part->AddPercent/100)*IF(part->Factor==0,1,part->Factor)*-1,8),part->AddQty*IF(part->Factor==0,1,part->Factor)*-1,Trim(cRoutingMatch)+cOpSeparator+IF(pjob->(FOUND()),Trim(job->Name),"DUMMY"),IF(part->Qty<0,"end","start")})
            IF lIntern .AND. (lDummy .OR. AT(cQSStart,job->Name) != 1) //if it can be produced internally we add it directly to the BOM list, ignore QS jobs
               Aadd(aBom,ATail(aThisBom))
            ENDIF
            
         ENDIF
         part->(dbSkip())

      ENDDO

      
      art->(dbSetOrder( 2 )) 
      art->(dbSeek( Str(aRoutingItems[nI],6) ))
      pjob->(dbSetOrder( 2 ))

      IF lIntern                 

         nVPE := CeilingMe(IF(art->VPE==0,1,art->VPE)/(1-_GetScrapRate(aRoutingItems[nI])),Me(art->Me)) //we need to add the scrap to the min/mult to get the quantity without the scrap
         //nVPE := IF(art->VPE==0,1,art->VPE)/(1-_GetScrapRate(aRoutingItems[nI]))

         Aadd(aOperations,{Trim(art->Matchcode), cMatch,0,0,"routing","",20,cDefaultLocation,nVPE,nVPE,0,0 })
         
         IF lDummy  //if we need a DUMMY position (parts not assigned to a JOB), we add it here
            Aadd(aOperations,{Trim(art->Matchcode)+cOpSeparator+"DUMMY", "",0,1000,"time_per",Trim(art->Matchcode),0,cDefaultLocation,0,0,0,0 })
         ENDIF  

         Eval(bAddOps,aRoutingItems[nI],Trim(art->Matchcode),.F.,)

         nPostOp := GetValue("FREPPLE_POSTOP",7,"Post-Op time on ouput operation (days)")
         IF nPostOp != 0
            ATail(aOperations)[12] := nPostOp*24*60*60
         ENDIF
         
         Aadd(aInterParts,art->Artikelnr) //List of internally producable parts, used for the sales orders
      ENDIF
      
      IF nLohnArt != 0
         lHasSupplier := .F.
         art->(dbSeek( Str(aRoutingItems[nI],6) ))  
         

         ali->(dbSeek( Str(nLohnArt,6) ))
         DO WHILE ali->Artikelnr == nLohnArt
            IF ! Trim(ali->Kunde) $ aNotSupplier                            
               lHasSupplier := .T.
               ku->(dbSetOrder( 1 ))
               ku->(dbSeek( ali->Kunde+"L" ))
               oExtra := ku->(ExtraData():New(ku->Nummer))

               //add a operation to the operation list. For external production we only need this one. It will contain all parts
               Aadd(aOperations,{Trim(art->Matchcode)+cOpSeparator+"EXT:"+Trim(ali->Kunde), cMatch,0,(IF(ali->LZ>0,ali->LZ,IF(art->LZ==0,nDefaultLZ,art->LZ))+nAddWeeks)*7*24*60*60,"fixed_time","",10,Trim(ali->Kunde),ali->Min,ali->Vpe,0,0 })

               //add the output position for each supplier, without scrap rate as this is only used internnally
               Aadd(aBom,{cMatch,1,0,Trim(art->Matchcode)+cOpSeparator+"EXT:"+Trim(ali->Kunde),"end"})

               IF Trim(ali->Kunde) == "LACKIERZ"
                  //Alert("Resource: "+oExtra:Resource+" "+IF(! Empty(oExtra:Resource),"NOT EMPTY","EMPTY"))
               ENDIF

               //if a resource is set on this supplier we add it here
               IF ! Empty(oExtra:Resource)
                  Aadd(aOperationResources,{ATail(aOperations)[1],oExtra:Resource,1,"Any","MINCOSTPENALTY"})
               ENDIF

               //add item distribution from the supplier to us
               Eval(bAddItemDistr,cMatch,cDefaultLocation,ali->Kunde,oExtra:RecvTime)

               FOR nX := 1 TO Len(aThisBom)
                  Eval(bAddItemDistr,aThisBom[nX,1],ali->Kunde,cDefaultLocation,oExtra:ShipTime-IF(oExtra:WaDay>0,oExtra:WaDay-2,0)) //add the item distribution from us to the supplier
                  Aadd(aBom,AClone(aThisBom[nX])) //add the bom position
                  ATail(aBom)[4] := Trim(art->Matchcode)+cOpSeparator+"EXT:"+Trim(ali->Kunde)  //change the operation name to point to the external operation
               NEXT

            ENDIF
            ali->(dbSkip())     
         ENDDO
         IF lHasSupplier
            art->(dbSeek( Str(aRoutingItems[nI],6) ))  
            Eval(bAddItem)
         ELSE
            art->(dbSeek( Str(aRoutingItems[nI],6) ))
            Aadd(aErrors,{aRoutingItems[nI],art->Matchcode,"ERROR","NOSUPPLIER","No manufacturing location for external manufacturing"})               
         ENDIF
      ENDIF
   NEXT
   part->(dbClearFilter())
   art->(dbClearFilter())

   TxtClear()

   nLast := Len(aMaterials)
   ASize(aMaterials,nLast+Len(aRoutingItems))
   ACopy(aRoutingItems,aMaterials,1,,nLast+1)

   TxtBox("Sales orders")

   ku->(dbSetOrder( 1 ))
   Select("auf")
   SET FILTER TO auf->bestat < 3 .AND. auf->VkQty-auf->GelQty > 0
   auf->(dbGoTop())
   DO WHILE ! auf->(EOF())      
      @ MaxRow()/2+2,MaxCol()/2-4 SAY "["+Str(auf->Abnr,6)+"]" COLOR c_five
      IF lIncludeSales .OR. auf->Artikelnr $ aRoutingItems .OR. auf->Artikelnr $ aMaterials 
      
         art->(dbSeek( Str(auf->Artikelnr,6) )) 
         nDelWeek := AddWeeks(Cweek(Date()),IF(art->LZ==0,nDefaultLZ,art->LZ)+nAddWeeks)
         
         IF art->Lagerart            
            Eval(bAddItem)
            IF AScan(aCustomers,{|x| x[1] == Trim(auf->Kundma) }) == 0            
               Aadd(aCustomers,{Trim(auf->Kundma)})
            ENDIF   
            ku->(dbSetOrder( 1 ))
            ku->(dbSeek( auf->Kundma+"K" ))    
            IF Right(Str(auf->Dterm),2) == "99" //Rahmen, only Meldebestand
               IF ! auf->Artikelnr $ hMinAufStock 
                  hMinAufStock[auf->Artikelnr] := 0
               ENDIF

               
               IF GetValue("FREPPLE_CREATE_FORECAST",.F.,"Create a forecast for frame sales orders")                                     
                  IF auf->Artikelnr $ aInterParts .AND. auf->WTerm > Cweek(Date()) .AND. auf->MeldStock < auf->VkQty-auf->GelQty //on internal parts we spread the open qty over the rest of the time
                     dStart := Max(auf->SDatum,Date())
                     oRec := auf->(Record():New())
                     DO WHILE auf->Abnr == oRec:Abnr .AND. ! auf->(EOF())
                        IF auf->ContrPos == oRec:Itmnr
                           dStart := Max(dStart,IF(ku->JustinTime,auf->BDatum,CalWD(auf->Dterm)))
                        ENDIF
                        auf->(dbSkip())
                     ENDDO
                     oRec:GotoRec()
                     nMonths := Max(1,(CalWD(auf->Wterm)-dStart)/30)

                     art->(dbSeek( Str(auf->Artikelnr,6) ))
                     nAufQty := auf->VkQty-auf->GelQty-auf->MeldStock
                     nQty := Val(TransForm(nAufQty/nMonths,Me(art->Me)))
                     IF art->VPE != 0 .AND. Mod(nQty,art->VPE) != 0 //adjust the quantity to the min/mult
                        nQty := ( Int( nQty / art->vpe ) + 1 ) * art->vpe
                        nStep := Max(1,Int( nMonths / Int( nAufQty / nQty ) ))
                     ELSE
                        nStep := 1
                     ENDIF
                     nFirst := Max(1,(dStart-Date())/30)
                     IF auf->MeldStock > 0 //this will already re-stock
                        //nFirst := Min(nMonths, Int( auf->Meldstock / nQty * 4.3 ) )
                     ENDIF
                     FOR nMonth := nFirst TO nMonths STEP nStep                     
                        nQty := Min(nQty,nAufQty) //we might need to adjust the quantity to the remaining quantity                     
                        IF nQty > 0 //could be 0 through the above adjustment
                           Aadd(aSalesOrders,{Ltrim(Str(auf->Abnr))+"-"+StrZero(auf->Itmnr,3)+"FC"+StrZero(nMonth,2),Trim(auf->Kundma),auf->Matchcode,nQty,nQty,Frep_DtoC(AddMonth(dStart,nMonth),"10:00"),IF(ku->JustinTime,20,30),cDefaultLocation,"open"})
                        ENDIF
                        nAufQty -= nQty
                     NEXT
                  ENDIF
               ELSE
                  //Plan Minimum stock as sales order, adding to the buffer does not make it plan it correcltly.
               //dDate := auf->SDatum
                  //look for last call off
                  nKW := AddWeeks(CWeek(auf->Besda),IF(art->LZ==0,nDefaultLZ,art->LZ)+nAddWeeks)
                  nRestockWeeks := GetValue("FREPPLE_RESTOCK_WEEKS",2,"Time it takes to restock frame contracts")
                  nGap := Max(nRestockWeeks,GetValue("FREPPLE_MIN_GAP",4,"Minium gap to plan restocking"))
                  
                  oRec := auf->(Record():New()) //remember record               
                  cFilter := auf->(dbFilter()) //clear and save the filter

                  //Add up all other minium stock from other orders (LETO_SUM does not work as we need to use Min)                  
                  auf->(dbSeek(art->Matchcode+"0"))
                  nTotMeld := 0
                  DO WHILE auf->Matchcode == art->Matchcode .AND. auf->Bestat < 3
                     
                     nTotMeld += Min(auf->MeldStock,auf->VkQty)
                     
                     auf->(dbSkip())
                  ENDDO

                  IF nTotMeld+art->Mindest <= art->Bestand  //everything in stock - move at least intol today
                     nKW := CWeek(Date())
                  ENDIF

                  auf->(dbClearFilter())
                  
                  @ Row()+1,00 CLEAR
                  auf->(dbSetOrder( 1 ))
                  aWeeks := {}
                  oRec:GotoRec() //back to saved record
                  ? auf->Abnr
                  DO WHILE auf->Abnr == oRec:Abnr .AND. ! auf->(EOF()) //Abrufe are alway after the frame position, no need to search                                          
                     IF auf->ContrPos == oRec:Itmnr                        
                        nDWeek := IF(ku->JustinTime,CWeek(auf->BDatum),auf->Dterm)                        
                        IF auf->GelQty > 0  //if shipped we take this as the starting point                                                                              
                           nKW := Max(nDWeek,nKW)
                        ELSEIF auf->Bestat < 3 .AND. ! nDWeek $ aWeeks
                           Aadd(aWeeks,nDWeek)
                        ENDIF
                     ENDIF                     
                     auf->(dbSkip())
                  ENDDO                                    
                  auf->(dbSetFilter({|| &(cFilter) },cFilter))
                  auf->(dbSetOrder( 3 ))
                  oRec:GotoRec()                  
                  ASort(aWeeks)
                  FOR nX := 1 TO Len(aWeeks)
                     IF aWeeks[nX] > AddWeeks(nKW,nGap) //is this a gap, then exit and use nKW
                        EXIT
                     ENDIF
                     nKW := aWeeks[nX]
                  NEXT
                  
                  IF art->Bezug == 5
                     dDate := CalWd(AddWeeks(nKW,nRestockWeeks))+5
                  ELSE
                     dDate := CalWd(AddWeeks(nKW,IF(art->LZ==0,nDefaultLZ,art->LZ)))+5
                  ENDIF
                  IF auf->SDatum > dDate
                     dDate := auf->SDatum                  
                  ENDIF
                  dDate := Max(auf->Besda+IF(art->LZ==0,nDefaultLZ,art->LZ),dDate)                  
                  
                  Aadd(aSalesOrders,{Ltrim(Str(auf->Abnr))+"-"+StrZero(auf->Itmnr,3)+"MIN",Trim(auf->Kundma),auf->Matchcode,Min(auf->Meldstock,auf->VkQty),Min(auf->Meldstock,auf->VkQty),Frep_DtoC(IF(dDate<=Date().AND.auf->Meldstock <=art->Bestand,Date()+1,dDate),"10:00"),10,cDefaultLocation,"open"})                                 

                  IF auf->VkQty-auf->GelQty > auf->Meldstock //Add an order for the remaining quantiy at the end date of the frame contract
                     Aadd(aSalesOrders,{Ltrim(Str(auf->Abnr))+"-"+StrZero(auf->Itmnr,3)+"END",Trim(auf->Kundma),auf->Matchcode,auf->VkQty-auf->GelQty-auf->Meldstock,Min(auf->VkQty-auf->GelQty-auf->Meldstock,auf->MeldStock*2),Frep_DtoC(CalWd(Max(nDelWeek,auf->Wterm)),"10:00"),20,cDefaultLocation,"open"})
                  ENDIF
               ENDIF
            ELSE   
               nPrio := 5
               /*IF ku->JustinTime
                  nPrio := 5    
               ELSEIF auf->ContrPos != 0
                  nPrio := 7    
               ELSEIF auf->FolgeTo != 0
                  nRec := auf->(Recno())
                  auf->(dbSeek( Str(auf->Abnr,6)+Str(auf->FolgeTo,3) ))
                  IF auf->ContrPos != 0
                     nPrio := 7
                  ENDIF
                  auf->(dbGoto(nRec))
               ENDIF*/
               Aadd(aSalesOrders,{Ltrim((Str(auf->Abnr))+"-"+StrZero(auf->Itmnr,3)),Trim(auf->Kundma),auf->Matchcode,auf->VkQty-auf->GelQty,auf->VkQty-auf->GelQty,;
                                 Frep_DtoC(IF(ku->JustinTime,GetJITLiefertag(auf->BDatum,ku->JIT_LZ),CalWD(IF(Right(Str(auf->Dterm,4),2)${"97","98"},Max(nDelWeek,auf->WTerm),auf->Dterm))+4),"15:00"),;
                                 nPrio,cDefaultLocation,"open"})
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
         aBuffers[nI,5] := Max(nMinStock,aBuffers[nI,5])
      ENDIF
   NEXT
   

   TxtClear()

   TxtBox("Purchase orders")

   bAddPurchaseOrder := {|nDelivery,nQty,cArriveTime| 
      LOCAL cDelivery := ""
      IF nDelivery != 0
         cDelivery := "."+StrZero(nDelivery,3)
      ENDIF
      Aadd(aPurchaseOrders,{IF(bes->Besnr==-1,Trim(bes->Liefma)+"_WAIT",LTrim(Str(bes->Besnr)))+"-"+LTrim(Str(bes->Posnr))+cDelivery,bes->Liefma,Frep_Dtoc(IF(bes->Besnr==-1,Date(),bes->Besda),"00:00"),cMatch,nQty,cArriveTime,IF(bes->Confirmed=="Y","confirmed","approved"),cDefaultLocation})
      RETURN NIL
   }

   Select("bes")
   SET FILTER TO bes->Bestat < 3 .AND. bes->BeQty-bes->GelQty > 0 .AND. ! bes->Rahmen
   bes->(dbSeek(Str(1,6),.T.))
   DO WHILE ! bes->(EOF())
      @ MaxRow()/2+2,MaxCol()/2-4 SAY "["+Str(bes->Besnr,6)+"]" COLOR c_five
      IF lIncludeSales .OR. bes->Artikelnr $ aRoutingItems .OR. bes->Artikelnr $ aMaterials 
         art->(dbSeek( Str(bes->Artikelnr,6) ))   
         Eval(bAddItem) //artikel bereits vor der Prfung der Lagerf„hig hinzufgen, wegen Folgeartikel
         IF art->Lagerart      
            cMatch := Trim(bes->Matchcode)
            
            cArriveTime := IF(Right(Str(bes->Lterm,4),2)=="98","",Frep_DtoC( CalWD( Max( AddWeeks(CWeek(Date()),-1),bes->Lterm ) )  +4+bes->Shiptime*7,"08:00"))

            IF ART_NEEDS_QS  //external parts are also checked when there is a drawing
               cMatch += "_UNCHECKED"
               //Aadd(aManuOrders,{"QS-BES"+LTrIM(Str(bes->Besnr))+"-"+LTrim(Str(bes->Posnr)),cMatch,bes->BeQty-bes->GelQty,cArriveTime,,"approved",Trim(bes->Matchcode)+cOpSeparator+"QS:"+LTrim(Str(bes->Artikelnr)),""})
            ENDIF

            nQty := bes->beqty-bes->gelqty
            IF bdel->(dbSeek( Str(bes->Besnr,6)+Str(bes->Posnr,3) ))
               nGelQty := bes->GelQty
               nX := 0
               DO WHILE nQty > 0 .AND. bdel->Besnr == bes->Besnr .AND. bdel->Posnr == bes->Posnr .AND. ! bdel->(EOF())
                  cArriveTime2 := Frep_DtoC( CalWD( AddWeeks(Max( AddWeeks(CWeek(Date()),-1),bdel->Lterm ) ,bes->Shiptime))+4, "08:00" )
                  IF nGelQty > 0
                     IF nGelQty >= bdel->Qty //this has already been delivered
                        nGelQty -= bdel->Qty
                     ELSE                     
                        Eval(bAddPurchaseOrder,++nX,bdel->Qty-nGelQty,cArriveTime2)
                        nQty -= bdel->Qty-nGelQty
                        nGelQty := 0
                     ENDIF
                  ELSE                                 
                     Eval(bAddPurchaseOrder,++nX,Min(nQty,bdel->Qty),cArriveTime2)
                     nQty -= Min(nQty,bdel->Qty)
                  ENDIF               
                  bdel->(dbSkip())
               ENDDO
            ENDIF
            IF nQty > 0
               Eval(bAddPurchaseOrder,0,nQty,cArriveTime)            
            ENDIF
            Eval(bAddSupplier,bes->Liefma)

            //maybe we need to at this quantity back onto the stock (capacity)
            IF bes->Confirmed == "Y"
               nX := AScan(aCalBuckets,{|x| x[1] == Trim(bes->Liefma)+":"+Trim(bes->Matchcode) .AND. x[5] == 10 })  //look for stock entry
               IF nX != 0 //we found an entry
                  aCalBuckets[nX,2] := Min(aCalBuckets[nX,2],bes->Besda) //needs to start at least at the purchasing date
                  aCalBuckets[nX,4] += bes->BeQty-bes->GelQty
               ENDIF
            ENDIF
         ENDIF
      ENDIF
      bes->(dbSkip())
   ENDDO
   bes->(dbClearFilter())   

   TxtClear()

   TxtBox("Manufacturing orders")

   bAddManuOrder := {|nDelivery,nQty,tEnd2|
      LOCAL cOrder := "FA"+LTrIM(Str(wer->Aufno))
      IF nDelivery != 0
         cOrder += "."+StrZero(nDelivery,3)
      ENDIF

      Aadd(aManuOrders,{cOrder,cMatch,nQty,IF(lConfirmed,TtoC(tStart),""),IF(lConfirmed,TtoC(tEnd2),""),cStatus,Trim(wer->Matchcode)+IF(!Empty(wer->liefma),cOpSeparator+"EXT:"+Trim(wer->Liefma),"")})                           
      RETURN NIL
   }

   Select("wer")
   SET FILTER TO wer->Status < 4 .AND. wer->Qty-wer->PlanBad > 0 .AND. Right(Str(wer->TerminFrue,4),2) != "99"
   wer->(dbGotop())
   DO WHILE ! wer->(EOF())     
      oWerExtra := wer->(ExtraData():New(wer->Aufno))
      nDays := GetValue("FREPPLE_APPROVE_MO_DAYS",4,"Approve MO days ahead (0=off)")
      IF nDays > 0 .AND. wer->StartDate < Date()+nDays .AND. Trim(oWerExtra:FreppleSta) != "confirmed"         
         oWerExtra:FreppleSta := "approved"
         oWerExtra:Save()
      ENDIF

      IF GetValue("FREPPLE_EXPORT_ALL_MO",.F.,"Export all existing MOs") .OR. wer->Status >= 1 .OR.  ! Empty(wer->Liefma) .OR. ! Empty(oWerExtra:FreppleSta)  //we only add orders which are in production or also can be purchased externaly
         @ MaxRow()/2+2,MaxCol()/2-4 SAY "["+Str(wer->Aufno,6)+"]" COLOR c_five     
         IF ! Empty(wer->Liefma)
            ku->(dbSetOrder( 1 ))   
            ku->(dbSeek( wer->Liefma+"L" ))
            oExtra := ku->(ExtraData():New(ku->Nummer))
            bes->(dbSetOrder( 1 ))
            bes->(dbSeek( Str(wer->Besnr,6)+Str(IF(wer->Bespos==0,1,wer->besPos),3) )) 
            IF Val(Right(Str(wer->Termin,4),2)) >= 97
               dStart := CalWD(AddWeeks(CWeek(Date()),nDefaultLZ))
            ELSE
               dStart := AddWorkingDays(CalWD(wer->termin)+IF(oExtra:WaDay>0,oExtra:WaDay-2,4),oExtra:ShipTime)
            ENDIF
            dEnd   := CalWD(Max(CWeek(Date()),wer->End))-3 //Friday the week before, as Frepple adds RecvTime to this date through the distribution order
            IF Dow(Date()) >= 6 .AND. dEnd < Date() //on Friday, move it to the next week if necessary
               dEnd := Date()
            ENDIF                 
         ELSE
            dStart := wer->StartDate
            dEnd   := wer->EndDate
         ENDIF

         IF Empty(dEnd)
            dEnd := Date()+365  //sometime in the future
         ENDIF


         //check if there is a BOM for this supplier
         IF (! Empty(wer->Liefma) .AND. AScan(aBOM,{|x| x[4] == Trim(wer->Matchcode)+cOpSeparator+"EXT:"+Trim(wer->Liefma) }) == 0) .OR. ;
            (Empty(wer->Liefma) .AND. Ascan(aBOM,{|x| Trim(wer->Matchcode) == Trim(x[1]) .AND. ! cOpSeparator+"EXT:" $ x[4] }) == 0)
            Aadd(aErrors,{wer->Artno,wer->Matchcode,"ERROR","NOPARTLIST","No part list"+IF(!Empty(wer->Liefma)," for "+Trim(wer->Liefma),"")})               
         ELSE         
            art->(dbSeek( Str( wer->Artno,6 ) ))
            cMatch := Trim(wer->Matchcode)
            IF ART_NEEDS_QS 
               cMatch += "_UNCHECKED"
               //Aadd(aManuOrders,{"QS-FA"+LTrIM(Str(wer->Aufno)),Trim(wer->Matchcode),wer->Qty-wer->GelQty,Frep_DtoC(dEnd+1,"08:00"),,"approved",Trim(wer->Matchcode)+cOpSeparator+"QS:"+LTrim(Str(wer->Artno)),""})
            ENDIF             

            //check to make sure the order is using the current parts list
            //also add stock onto the buffers
            lCurrentParts := .T.
            //aThisBom := {}
            part->(dbSeek( Str(wer->Artno,6) ))
            we->(dbSeek( Str(wer->Aufno,6) ))
            DO WHILE part->Listart == wer->Artno .AND. we->Aufno == wer->Aufno
               IF part->Pos != 0
                  IF we->Pos != part->Pos .OR. we->Partart != part->Partart .OR. we->ListQty != part->Qty .OR. we->ListAdd != part->AddQty .OR. we->ListPerc != part->AddPercent;
                     .OR. we->Me != part->Me .OR. we->Factor != part->Factor .OR. we->Variant != part->Variant
                     lCurrentParts := .F.                  
                     //EXIT
                  ENDIF            
                  //{{"Item","Quantity","Fixed Quantity","Operation","Type"}}                                           
                  //Aadd(aThisBom,{cMatch,Round(we->Qty*(1+we->AddPercent/100)*IF(we->Factor==0,1,we->Factor)*-1,8),we->AddQty*IF(we->Factor==0,1,we->Factor)*-1,Trim(wer->Matchcode)+cOpSeparator+"FA"+LTrim(Str(wer->Aufno)),IF(we->Qty<0,"end","start")})                                           
                  IF wer->Status >= 1  .AND. we->Pos > 0 //add back to buffer if the stock has already been taken
                     //{{"Item-ID","Item","Location","Onhand","Minimum"}}

                     art->(dbSeek( Str( we->Partart,6 ) ))
                     nX := AScan(aBuffers,{|x| x[1]==we->Partart .AND. x[3] == IF(Empty(wer->Liefma),cDefaultLocation,Trim(wer->Liefma)) },2)
                     IF nX != 0                        
                        aBuffers[nX,4] += CeilingMe((we->Qty-(we->ListQty*wer->GelQty*(1+we->ListPerc/100)))*we->Factor,art->Me)
                     ELSE                        
                        oArtExtra := art->(ExtraData():New(art->Artikelnr))
                        Aadd(aBuffers,{we->Partart,Trim(art->Matchcode),IF(Empty(wer->Liefma),cDefaultLocation,Trim(wer->Liefma)),CeilingMe((we->Qty-(we->ListQty*wer->GelQty*(1+we->ListPerc/100)))*we->Factor,art->Me),0,oArtExtra:MinInterval})                        
                     ENDIF
                  ENDIF
                  we->(dbSkip())            
               ENDIF
               part->(dbSkip())
            ENDDO

            tStart := StoT(DtoS(dStart)+"080000")
            tEnd   := StoT(DtoS(dEnd)+"170000")

            IF lCurrentParts .OR. wer->status >= 1 //either the part liest ties up or goods have been supplied (then we do not need a part list in frepple)                           
               cStatus := Trim(oWerExtra:FreppleSta)
               IF wer->status>=1 .OR. (!Empty(wer->Liefma).AND.bes->Confirmed=="Y")
                  cStatus := "confirmed"
               ELSEIF Empty(cStatus) .AND. (!Empty(wer->Liefma).AND. ! bes->Printed )
                  cStatus := "proposed"
               ELSEIF Empty(cStatus)
                  cStatus := "approved"
               ENDIF
      
               lConfirmed := .T. //cStatus == "confirmed"

               rst->(dbSetOrder( 6 ))
               job->(dbSetOrder( 1 ))               
               res->(dbSetOrder( 1 ))
               aManuSubOrders := {}
               IF Empty(wer->Liefma) .AND. rst->(dbSeek( "WA "+Str(wer->Aufno,6) ))
                  tStart := StoT(DtoS(dStart)+"170000")
                  tEnd   := StoT(DtoS(dEnd)+"080000")
                  DO WHILE ! rst->(EOF()) .AND. rst->No == wer->Aufno  //look for earliest and latest date
                     tStart := Min(tStart,SToT(rst->Start))
                     tEnd   := Max(tEnd,SToT(rst->End))  
                     lHasResource := .F.                  
                     IF rst->Job != 0                        
                        job->(dbSeek( Str(rst->Job) ))                                                
                        
                        Aadd(aManuSubOrders,{;
                           "FA"+LTrIM(Str(wer->Aufno))+"-"+Trim(job->Name),;
                           cMatch,;
                           wer->Qty-wer->GelQty,;
                           IF(lConfirmed,TtoC(StoT(rst->Start)),""),;
                           IF(lConfirmed,TtoC(StoT(rst->End)),""),;
                           IF(rst->Complete,"completed",cStatus),; 
                           Trim(wer->Matchcode)+cOpSeparator+Trim(job->Name),;
                           "FA"+LTrIM(Str(wer->Aufno));
                        })

                        DO WHILE rst->Job == job->Nummer .AND. rst->No == wer->Aufno .AND. ! rst->(EOF())
                           IF rst->Resource != 0 .AND. res->(dbSeek( Str(rst->Resource,6) ))    
                              lHasResource := .T.                       
                              Aadd(aResourceDetail,{res->Name,ATail(aManuSubOrders)[1],1,TtoC(StoT(rst->Start)),TtoC(StoT(rst->End)),"confirmed"}) //alwways import as confirmed, there is no approved status
                           ENDIF
                           rst->(dbSkip())
                        ENDDO
                        rst->(dbSkip(-1))

                        IF ! lHasResource .AND. ATail(aManuSubOrders)[6] != "completed" //if there is no resource we always leave it on confirmed so it is adjusted automatically
                           ATail(aManuSubOrders)[6] := "confirmed"
                        ENDIF
                     ENDIF
                     rst->(dbSkip())
                  ENDDO
               ENDIF

               
               nQty := wer->Qty-wer->GelQty
               IF ! Empty(wer->Liefma)
                  IF bdel->(dbSeek( Str(bes->Besnr,6)+Str(bes->Posnr,3) ))
                     nGelQty := bes->GelQty
                     nX := 0
                     DO WHILE nQty > 0 .AND. bdel->Besnr == bes->Besnr .AND. bdel->Posnr == bes->Posnr .AND. ! bdel->(EOF())
                        //cArriveTime2 := Frep_DtoC( CalWD( AddWeeks(Max( AddWeeks(CWeek(Date()),-1),bdel->Lterm ) ,bes->Shiptime))+4, "08:00" )
                        dEnd   := CalWD(Max(CWeek(Date()),AddWeeks(bdel->lterm,-1)))-3 //Friday the week before, as Frepple adds RecvTime to this date through the distribution order
                        IF Dow(Date()) >= 6 .AND. dEnd < Date() //on Friday, move it to the next week if necessary
                           dEnd := Date()
                        ENDIF   
                        IF nGelQty > 0
                           IF nGelQty >= bdel->Qty //this has already been delivered
                              nGelQty -= bdel->Qty
                           ELSE                     
                              Eval(bAddManuOrder,++nX,bdel->Qty-nGelQty,StoT(DtoS(dEnd)+"080000"))
                              nQty -= bdel->Qty-nGelQty
                              nGelQty := 0
                           ENDIF
                        ELSE                                 
                           Eval(bAddManuOrder,++nX,Min(nQty,bdel->Qty),StoT(DtoS(dEnd)+"080000"))
                           nQty -= Min(nQty,bdel->Qty)
                        ENDIF               
                        bdel->(dbSkip())
                     ENDDO
                  ENDIF
               ENDIF
               IF nQty > 0
                  Eval(bAddManuOrder,0,nQty,tEnd)                      
                  //these need to be added after the routing order, otherwise Frepple cannot process it, on external orders this is always empty
                  AEval(aManuSubOrders,{|x| Aadd(aManuOrders,x)})   
               ENDIF
            ELSE
               Aadd(aErrors,{wer->Artno,wer->Matchcode,"ERROR","PARTLISTDIFFER","Part list on FA"+LTrim(Str(wer->Aufno))+" differs to the item"})               
            ENDIF
         ENDIF
      ENDIF
      wer->(dbSkip())
   ENDDO
   wer->(dbClearFilter())

   

   TxtClear()

   TxtBox("Saving files")
   hFiles := {;
      "item supplier.csv"=>aItemSuppliers,;
      "sales order.csv"=>aSalesOrders,;
      "purchase order.csv"=>aPurchaseOrders,;
      "supplier.csv"=>aSuppliers,;
      "customer.csv"=>aCustomers,;
      "item.csv"=>aItems,;
      "buffer.csv"=>aBuffers,;
      "manufacturing order.csv"=>aManuOrders,;
      "operation resource.csv"=>aOperationResources,;
      "operation material.csv"=>aBom,;
      "operation.csv"=>aOperations,;
      "item distribution.csv"=>aItemDistr,;
      "resource.csv"=>aResource,;
      "calendar.csv"=>aCalendars,;
      "calendar bucket.csv"=>aCalBuckets,;
      "resource detail.csv"=>aResourceDetail;
   }
   lCancel := .F.
   FOR EACH aData IN hFiles      
      DO WHILE ! SaveAsCSV(cPath+aData:__enumKey,aData,.T.,.T.) .AND. ! lCancel
         IF Tr_MsgBox('Datei "'+aData:__eNumKey+'" konnte nicht gespeichert werden.',,{"Wiederholen","Abbrechen"}) == 2
            lCancel := .T.
            EXIT
         ENDIF
      ENDDO
      IF lCancel
         EXIT
      ENDIF
   NEXT
   
   IF ! lCancel
      cErrorFile := cPath+"errors"+TtoS(DateTime())+".csv"
      SaveAsCSV(cErrorFile,aErrors,.T.,.T.)
   ENDIF

   TxtClear()

   Set(4,cDateFormat)
   
   IF ! lCancel
      nErrorCount := 0
      AEval(aErrors,{|x| IF(x[3] == "ERROR" .OR. x[3] == "FATAL",nErrorCount++,NIL) })
      IF nErrorCount > 0 .AND. Tr_MsgBox(LTrim(Str(nErrorCount))+" Fehler. Fehlerprotokoll ”ffnen?",,{"Ja","Nein"}) == 1
         WAPI_ShellExecute(,"open",cErrorFile)
      ENDIF
   ELSE
      Tr_MsgBox("Export abgebrochen")
   ENDIF
   

RETURN NIL


STATIC FUNCTION _GetScrapRate(nArtnr)
      IF bom->(dbSeek( Str(nArtnr,6) ))
         RETURN bom->Scrap
      ENDIF
RETURN 0      


STATIC FUNCTION Frep_DToC(dDate,cTime)
RETURN DtoC(dDate)+" "+cTime+":00"


STATIC FUNCTION ParseCSV(cFile,lWithQuotes)
   LOCAL cData := MemoRead(cFile)
   LOCAL cCol := "",cChar,lInString := .F.,nQuoteCount := 0
   LOCAL nX
   LOCAL aRow := {}
   LOCAL aData := {}

   Default(@lWithQuotes,.F.)

   FOR nX := 1 TO Len(cData)
      cChar := SubStr(cData,nX,1)      
      IF cChar == '"'            
         nQuoteCount++            
         lInString := .T.
         IF lWithQuotes
            cCol += cChar
         ENDIF
      ELSEIF cChar == "," .AND. (! lInString .OR. Mod(nQuoteCount,2)==0)            
         Aadd(aRow,cCol)
         lInString := .F.
         nQuoteCount := 0 
         cCol := ""    
      ELSEIF cChar == Chr(10) .AND. (! lInString .OR. Mod(nQuoteCount,2)==0)
         Aadd(aRow,cCol)
         Aadd(aData,aRow)
         cCol := ""
         aRow := {}
      ELSEIF cChar == Chr(13) .AND. (! lInString .OR. Mod(nQuoteCount,2)==0)  //ignore this
      ELSE
         cCol += cChar
      ENDIF
   NEXT
RETURN aData