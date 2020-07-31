#define LAG_STOCK_USABLE           2
#define LAG_STOCK_OTHER_LOCATIONS  3

FUNCTION RUN_UPD_PARTJOBS
   
   LOCAL aRoutingItems
   LOCAL hJobs,hTotJobs
   LOCAL nI,nTotGel,nTime,nT,nJob,nX
   LOCAL aJob,nLastPos
  
   MEMVAR c_five

   NetUSe("artikel","art")
   NetUSe("werkauf","wer")

   NetUse("parts","part")
   NetUse("watime","wat")
   NetUse("jobs","job")
   NetUse("partjobs","pjob")

   CLS
   
   TxtBox("Routing items")

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

   TxtClear()
   
   //aRoutingItems := {16830}

   TxtBox("Bill of materials / operations")

   part->(dbSetOrder( 1 ))
   art->(dbSetOrder( 2 ))
   Select("part")
   //SET FILTER TO part->Pos > 0
   FOR nI := 1 TO Len(aRoutingItems)
      @ MaxRow()/2+2,MaxCol()/2-4 SAY "["+Str(aRoutingItems[nI],6)+"]" COLOR c_five

      art->(dbSetOrder( 2 ))
      art->(dbSeek( Str(aRoutingItems[nI],6) ))

     
      hTotJobs := {=>}     
      nTotGel := 0 

      wer->(dbSetOrder( 2 )) // Str(artno)
      wer->(dbSeek( Str(aRoutingItems[nI],6) )) 

      art->(dbSetOrder( 2 )) 
      art->(dbSeek( Str(aRoutingItems[nI],6) ))         

      Select("wer")    
      SET FILTER TO wer->Status >= 4 .AND. wer->Qty > 0 .AND. wer->Date >= StoD("20150601")
      DO WHILE wer->Artno == aRoutingItems[nI] .AND. ! wer->(EOF())
         wat->(dbSeek( Str(wer->Aufno,6) ))
         nTime := 0
         hJobs := {=>}
         DO WHILE wat->Wanr == wer->Aufno .AND. ! wat->(EOF())
            nT := (StoT(wat->End)-StoT(wat->Start))*24*60
            nTime += nT
            IF ! HHasKey(hJobs,wat->Job)
               hJobs[wat->Job] := 0
            ENDIF
            hJobs[wat->Job] += nT
            wat->(dbSkip())
         ENDDO
         IF nTime > 0            
            nTotGel  += wer->GelQty
            FOR EACH nT IN hJobs
               nJob := nT:__eNumKey()
               IF ! HHasKey(hTotJobs,nJob)
                  hTotJobs[nJob] := {0,0}
               ENDIF
               hTotJobs[nJob][1] += nT
               hTotJobs[nJob][2] += wer->Qty
            NEXT
         ENDIF
         wer->(dbSkip())
      ENDDO
      wer->(dbClearFilter())

      nLastPos := 0
      pjob->(dbSetOrder(2))
      pjob->(dbSeek( Str(aRoutingItems[nI],6) ))
      DO WHILE pjob->Artikelnr == aRoutingItems[nI] .AND. ! pjob->(EOF())
         nLastPos := pjob->Pos
         pjob->(dbSkip())
      ENDDO
      pjob->(dbSetOrder(1))
      
      FOR nX := 1 TO Len(hTotJobs)
         aJob := HGetValueAt(hTotJobs,nX)
         nJob := HGetKeyAt(hTotJobs,nX)
         //job->(dbSeek( Str(nJob,6) ))
         
         IF aJob[2] > 0 .AND. nJob != 0
            ? aRoutingItems[nI],nJob, (aJob[1]/aJob[2])*60
            IF pjob->(dbSeek(Str(aRoutingItems[nI],6)+Str(nJob,3)))
               pjob->(Rec_Lock())
            ELSE
               nLastPos++
               pjob->(Add_Rec())
               pjob->Artikelnr := aRoutingItems[nI]
               pjob->Pos := nLastPos
               pjob->Job := nJob
            ENDIF
            pjob->Seconds := (aJob[1]/aJob[2])*60
            pjob->(dbUnlock())
         ENDIF
         
      NEXT      

   NEXT
   part->(dbClearFilter())
   


RETURN NIL