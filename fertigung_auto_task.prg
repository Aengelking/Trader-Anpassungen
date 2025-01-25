PROC FERTIGUNG_AUTO_TASK
   LOCAL cJob,lFound
   LOCAL nJob,nRec,nNext
   LOCAL tStart,nLength

   NetUse("werkauf","wer")
   
   NetUse( "jobs",  "job" )
   NetUse("resource","res")
   NetUse("restime","rst")
   NetUse("watime","wat")

   CLS
   ? "Fertigungsauftr„ge ohne Person"

   wer->(dbSetFilter({|| Empty(wer->Liefma) .AND. Right(Str(wer->Termin,4),2) != "99" },'Empty(Liefma) .AND. Right(Str(Termin,4),2) != "99"'))
   wer->(dbSetOrder(10)) //status+startdate+aufno
   wat->(dbSetOrder(2)) //wanr+end
   IF  wer->(dbSeek( Str(3,1) ))
      DO WHILE wer->Status == 3         
         
         tStart := StoT("")
         wat->(dbSeek( Str(wer->Aufno,6) ))
         DO WHILE wat->Wanr == wer->Aufno .AND. ! wat->(EOF())            
            IF Stot(wat->End) > tStart
               tStart := Stot(wat->End)
            ENDIF
            wat->(dbSkip())   
         ENDDO

         //see if it is a task without a person, then it is time based
         rst->(dbSetOrder( 1 ))
         IF rst->(dbSeek( "WA "+Str(wer->aufno,6) ))
            
            DO WHILE rst->Complete .AND. Trim(rst->Type) == "WA" .AND. rst->No == wer->Aufno               
               rst->(dbSkip())  
            ENDDO
            IF  Trim(rst->Type) == "WA" .AND. rst->No == wer->Aufno .AND. ! rst->Complete
               job->(dbSeek( Str(rst->Job,6) ))
               cJob := Trim(job->Name)
               nJob := job->Nummer
               lFound := .F.
               nLength := 0

               DO WHILE rst->Job == nJob .AND. Trim(rst->Type) == "WA" .AND. rst->No == wer->Aufno
                  res->(dbSetOrder( 1 ))
                  res->(dbSeek( Str(rst->Resource,6)))                  
                  IF res->USer != 0
                     lFound := .T.
                  ELSE
                     nLength := Max(nLength,StoT(rst->End) - StoT(rst->Start))
                  ENDIF
                  rst->(dbSkip())
               ENDDO

               IF ! lFound
                  ? wer->Aufno,cJob,Left(TtoC(tStart),14),Left(TtoC(tStart+nLength),14)
                  IF DateTime() >= tStart+nLength
                     ?? " completed"
                     rst->(dbSeek( "WA "+Str(wer->aufno,6) ))
               
                     DO WHILE rst->Complete .AND. Trim(rst->Type) == "WA" .AND. rst->No == wer->Aufno                                    
                        rst->(dbSkip())  
                     ENDDO
                     IF  Trim(rst->Type) == "WA" .AND. rst->No == wer->Aufno .AND. ! rst->Complete
                        nJob := rst->Job
                        nRec := rst->(RecNo())
                        DO WHILE rst->Job == nJob .AND. Trim(rst->Type) == "WA" .AND. rst->No == wer->Aufno
                           res->(dbSeek( Str(rst->Resource,6)))                  
                           ? rst->Resource,res->Name
                           rst->(Rec_Lock(0))
                           rst->Complete := .T.
                           rst->(dbUnLock())
                           rst->(dbSkip())
                        ENDDO

                        //check if there are more jobs for this order
                        Select("rst")
                        SET FILTER TO ! rst->Complete
                        nNext := 0
                        IF rst->(dbSeek( "WA "+Str(wer->Aufno,6) )) //no more jobs, the order is finished
                           nNext := rst->Job
                        ENDIF
                        rst->(dbClearFilter())


                        rst->(dbGoto(nRec)) //go back to the record of the original job
                        Hook("after_fertigung_job_completed",{wer->Aufno,nJob,nNext,0})
                     ENDIF
                  ENDIF
               ENDIF
            ENDIF
         ELSE
            ? "no task found"
         ENDIF

         wer->(dbSkip())
      ENDDO

      //Sinkey(0)
   ENDIF

