PROC RUN_ANGEBOT_ORDER()
   LOCAL nAngnr := 0
   LOCAL getlist := {}  
   LOCAL hLead,hLeadData
   LOCAL oNoCrm := NoCrmApi():New()
   LOCAL nStep,nPipeLine,nAbnr,oErr,nActivity
   LOCAL cContent,oAuftrag,aPipelines

   Head("Angebot in Auftrag wandeln")
   NetUse("angebot","ang")
   NetUse("nocrm","nocrm")
   @ 01,00 SAY "Angebot" GET nAngnr PICTURE "999999" VALID {||
      LOCAL lRet
      ang->(dbSetOrder(1))
      ang->(dbSetFilter({|| ang->Bestat < 3 },"bestat < 3"))
      lRet := ang->(dbSeek( Str(nAngnr,6) ))            
      ang->(dbClearFilter())
      IF lRet
         @ 01,14 CLEAR
      ELSE
         @ 01,14 SAY "Nicht gefunden"
      ENDIF
      RETURN lRet
   }
   READ
   IF LastKey() != 27
      Engauft(@nAbnr,nAngnr)

      IF nAbnr != 0 .AND. nocrm->(dbSeek( Str(nAngnr,6) ))
         IF ! oNoCRM:Connect()
            oErr := ErrorNew()
            oErr:SubSystem   := "NOCRM API"
            oErr:Description := "Connection to nocrm-io failed"
            oErr:Args        := {}
            Throw(oErr)
         ENDIF     
      
         //get activity Id
         nActivity := oNoCRM:GetActivityId( GetValue("NOCRM_ACTIVITY_SALE","Auftrag","Name der Aktivit„t fr Auftr„ge") )
            
         hLead := oNoCRM:Execute("leads/"+Ltrim(Str(nocrm->Lead)),"GET")
         IF hLead != NIL
            oAuftrag := Auftrag():New()
            oAuftrag:Load(nAbnr)
            hLeadData := {=>}
            ?? hLead["amount"],hLead["status"],hLead["pipeline"]         
            IF hLead["pipeline"] == oNoCrm:GetStdPipeLineName()  //"Angebots pipeline", Angebot wird geschlossen und lead als gewonnen markiert
               hLeadData["status"] := "won"
               nPipeLine := oNoCrm:GetPipeLineId( hLead["pipeline"], @aPipelines)            
         
               //now get the step id in the pipeline
               nStep := oNoCRM:GetStepId( GetValue("NOCRM_STEP_SALE","Auftrag","Phase in der Pipeline fr Auftr„ge") ,nPipeLine)
               IF nStep != 0 //Step was found in this pipeline
                  hLeadData["step"] := nStep
               ENDIF
               //hLeadData["amount"] := nValue
               oNoCRM:Execute("leads/"+Ltrim(Str(nocrm->Lead)),"PUT",hLeadData)
            ENDIF
            //Save order as a comment on an existing lead
            cContent := 'Auftrag Nr. '+LTrim(Str(nABnr))+Chr(13)+Chr(10)      
            cContent += "Wert: "+LTrim(Str(oAuftrag:Total,12,2))
      
            oNoCrm:Execute("leads/"+LTrim(Str(nocrm->Lead))+"/comments","POST",{"lead_id"=>nocrm->Lead,"content"=>cContent,"activity_id"=>nActivity,"user_id"=>SystemUser():Email})

            oAuftrag:Positions:Each({|oPos|
               oPos:Angnr := nAngnr
               oPos:Save()
               RETURN .T.
            })
            
         ENDIF
      ENDIF


      IF Tr_MsgBox(t("Angebot schließen?"),,{"Nein","Ja"}) == 2

         ang->(dbSeek(Str(nAngnr,6)))
         DO WHILE ang->Angnr == nAngnr .AND. ! ang->(EOF())
            IF ang->Bestat < 3
               ang->(Rec_Lock())
               ang->Bestat := 3
               ang->(dbUnLock())
               ang->(dbSkip())
            ENDIF
         ENDDO
      ENDIF
   ENDIF

   #include 'x:\run\nocrm.prg'
         