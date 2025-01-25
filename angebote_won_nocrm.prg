PROC RUN_ANGEBOTE_WON_NOCRM
   LOCAL nQty,nAb
   LOCAL oNoCrm := NoCrmApi():New()
   LOCAL oErr,nActivity
   LOCAL hQuotes := {=>}
   LOCAL hOrders := {=>}
   LOCAL nValue,hQuote,hMatchcode,aQuotes := {}
   LOCAL hLead,aClose := {},nAng,cMatchcode,cFilter
   LOCAL aPipelines,nStdPipeLine,nPipeLine,nStep
   LOCAL hQuoteOrders,cContent,hLeadData
   LOCAL aExcludeMatchcode := {"@","FREIGHT","PORTO"}
   LOCAL nFrist := 60
   LOCAL oUser
   LOCAL hLeads,aGetData,nOff,aSteps
   LOCAL aRequests,nX

   CLS
   //Check if connection is working
   IF ! oNoCRM:Connect()
      oErr := ErrorNew()
      oErr:SubSystem   := "NOCRM API"
      oErr:Description := "Connection to nocrm-io failed"
      oErr:Args        := {}
      Throw(oErr)
   ENDIF     

   //get activity Id
   nActivity := oNoCRM:GetActivityId( GetValue("NOCRM_ACTIVITY_SALE","Auftrag","Name der Aktivit„t fr Auftr„ge") )


   //get pipeline id
   nStdPipeLine := oNoCrm:GetPipeLineId( oNoCrm:GetStdPipeLineName(), @aPipelines)   

   ? "Leads werden eingelesen..."
   nRow := Row()
   nCol := Col()
   hLeads := {=>} 
   aRequests := {{"status"=>"todo,standby"},{"date_range_type"=>"update","start_date"=>Date()-365*5,"status"=>{"lost,won,cancelled"}}}
   FOR nX := 1 TO Len(aRequests)
      nOff := 0
      DO WHILE .T.
         //"status"=>"todo,standby",
         //zuerst alle die noch offen sind
            aGetData := oNoCrm:Execute("leads","GET",HMerge({"include_unassigned"=>"true","limit"=>"100","offset"=>LTrim(Str(nOff))},aRequests[nX]))
            IF ValType(aGetData) != "A"
               //Alert(Str(nX)+ValToPrg(aGetData))
            ENDIF
            AEval(aGetData,{|x| hLeads[x["id"]] := x })
            nOff := Len(hLeads)
            @ nRow,nCol+1 SAY nOff
            IF Len(aGetData) < 100
               EXIT
            ENDIF
      ENDDO
   NEXT
      ?? Len(hLeads)
   //Alert("Leads: "+Str(Len(hLeads)))
   
   NetUse("engauf","auf")
   NetUse("angebot","ang")
   NetUse("nocrm","nocrm")
   NetUse("buyer","buy")

   ang->(dbSetOrder( 4 ))
   auf->(dbSetOrder( 6 ))
   
   ang->(dbSeek( Str(1,1) ))
   
   DO WHILE ang->Bestat < 3 .AND. ! ang->(EOF())
      IF Trim(ang->Matchcode) $ aExcludeMatchcode //diese werden ignoriert
      ELSEIF nocrm->(dbSeek( Str(ang->angnr,6) )) //nur Angebote berprfen die auch in noCRM gepflegt werden
         ? ang->Angnr,ang->Itmnr,ang->Kundma,ang->Bestat,ang->Matchcode

         Select("auf")
      
         auf->(OrdScope(0,ang->Kundma+ang->Matchcode))
         auf->(OrdScope(1,ang->Kundma+ang->Matchcode))
         cFilter := "Besda >= StoD('"+DtoS(ang->Besda)+"') .AND. VkPr/Pe*(1-Rabatt/100) == "+LTrim(Str(ang->VkPr/ang->Pe*(1-ang->Rabatt/100)))+" .AND. angnr == 0"
         auf->(dbSetFilter({|| auf->(&(cFilter)) },cFilter ))
         auf->(dbGoTop()) 
         IF ! auf->(EOF())
            nQty := 0
            nAb := 0
            DO WHILE ! auf->(EOF())
               IF Tr_Getini(28) == 9 .AND. ang->Angnr == 45587;? nAb;ENDIF
               IF nAB != auf->AbNr
                  nAb := auf->Abnr
                  nQty := 0
               ENDIF
               IF ! nAB $ hOrders .OR. hOrders[nAB] == ang->Angnr
                  IF Tr_Getini(28) == 9 .AND. ang->Angnr == 45587;?? nqty;ENDIF
                  nQty += IF(auf->bestat<3 .OR. (auf->Bestat>=4 .AND. auf->Bestat<=6),auf->VkQty,auf->GelQty)
               ENDIF
               auf->(dbSkip())
            ENDDO
            IF nQty >= ang->VKQty
               auf->(dbSkip(-1))
               hOrders[nAB] := ang->Angnr
               ?? " AB", auf->Abnr,DToC( auf->Besda )
               IF ! ang->Angnr $ hQuotes
                  hQuotes[ang->Angnr] := {=>}
               ENDIF
               nValue := nQty*auf->VkPr/auf->Pe*(1-auf->Rabatt/100)               
               IF ! ang->Matchcode $ hQuotes[ang->Angnr] .OR. hQuotes[ang->Angnr][ang->Matchcode]["VALUE"] < nValue                  
                  hQuotes[ang->Angnr][ang->Matchcode] := {"AB"=>auf->Abnr,"PRICE"=>ang->VkPr/ang->Pe*(1-ang->Rabatt/100),"VALUE"=>nValue}
               ENDIF
            ENDIF
         ENDIF
         IF ! ang->Angnr $ aQuotes
            Aadd(aQuotes,ang->Angnr)
         ENDIF
         auf->(dbClearFilter())
         auf->(OrdScope(0,""))
         auf->(OrdScope(1,""))
      ELSEIF ang->Besda+nFrist <= Date() //abgelaufen
         Aadd(aClose,ang->Angnr)
      ENDIF
      IF Tr_Getini(28) == 9 .AND. ang->Angnr == 45587
         SInkey(0)
      ENDIF
         
      ang->(dbSkip())      
   ENDDO

   ang->(dbSetOrder( 1 ))

   

   //Letztendlich wurde beschlossen diese Angebote nicht zu schlieáen - siehe Fragen
   //dies verursacht auch sehr viele Abfragen an noCRM was zu einer Sperre fhrt
   FOR EACH nAng IN aQuotes  //Angebote ohne Auftrag suchen und prfen      
      IF ! nAng $ hQuotes //Es wurde kein Auftrag gefunden
         
         ang->(dbSeek( Str(nAng,6) ))
         //hLead := oNoCRM:Execute("leads/"+Ltrim(Str(nocrm->Lead)),"GET")
         //IF hLead == NIL //Lead nicht gefunden, Angebot bleibt offen bis die Frist anbgelaufen ist
         IF ! nocrm->(dbSeek( Str(nAng,6) )) .OR. ! HHasKey(hLeads,nocrm->Lead) //Lead nicht gefunden, Angebot bleibt offen bis die Frist anbgelaufen ist
            ? nAng,"Lead nicht gefunden",ang->Besda
            IF ang->Besda+nFrist <= Date() //abgelaufen
               ?? " Angebot abgelaufen"
               Aadd(aClose,nAng)
            ENDIF
         ELSE
            hLead := hLeads[nocrm->Lead]
            IF hLead["status"] == "won" //als gewonnen markiert, wir konnten aber keine Auftr„ge finden, dann kann das Angebot auch geschlossen werden
               ? nAng,nocrm->Lead,"Lead gewonnen, kein (neuen) Auftrag gefunden"
               Aadd(aClose,nAng)
            ELSEIF hLead["status"] $ {"lost","cancelled"} //ander weitig geschlossen, Angebot bleibt offen bis Frist abgelaufen 
               ? nAng,"Verloren oder Geschlossen"
               Aadd(aClose,nAng)
            ENDIF
         ENDIF
      ENDIF
   NEXT

   auf->(dbSetOrder( 15 ))
   

   FOR EACH hQuote IN hQuotes  //all quotes with orders
      nValue := 0
      nAng := hQuote:__eNumKey()
      hQuoteOrders := {=>}
      FOR EACH hMatchcode IN hQuote
         cMatchcode := hMatchcode:__eNumKey()
         nValue += hMatchcode["VALUE"]
         auf->(dbSeek( Str(hMatchcode["AB"],6)+cMatchcode ))
         IF ! hMatchcode["AB"] $ hQuoteOrders
            hQuoteOrders[hMatchcode["AB"]] := 0
         ENDIF
         hQuoteOrders[hMatchcode["AB"]] += hMatchcode["VALUE"]
         DO WHILE auf->Abnr == hMatchcode["AB"] .AND. auf->Matchcode == cMatchcode 
            IF auf->Angnr == 0 .AND. auf->VkPr/auf->Pe*(1-auf->Rabatt/100) == hMatchcode["PRICE"]
               ? auf->Abnr,auf->Itmnr,"Quote:",nAng
               auf->(Rec_Lock(0))
               auf->Angnr := nAng
               auf->(dbUnLock())
            ENDIF
            auf->(dbSkip())
         ENDDO
      NEXT
      nocrm->(dbSeek( Str(nAng,6) ))
      //hLead := oNoCRM:Execute("leads/"+Ltrim(Str(nocrm->Lead)),"GET")
      IF HHasKey(hLeads,nocrm->Lead)
         hLead := hLeads[nocrm->Lead]
      ELSE
         hLead := NIL
      ENDIF
      ? nAng,nValue,""
      IF hLead==NIL
         ?? "Lead not found "+LTrim(Str(nocrm->Lead))
      ELSE
         hLeadData := {=>}
         nPipeLine := 0
         ?? hLead["amount"],hLead["status"],hLead["pipeline"]         
         IF hLead["pipeline"] == oNoCrm:GetStdPipeLineName()  //"Angebots pipeline", Angebot wird geschlossen und lead als gewonnen markiert
            nPipeLine := nStdPipeLine       
            hLeadData["status"] := "won"
            Aadd(aClose,nAng)
         ELSEIF hLead["status"] == "won" //lead ist abgeschlossen, dann k”nne Angebote geschlossen werden, da auch ein Auftrag da ist
            //get pipeline id
            nPipeLine := oNoCrm:GetPipeLineId( hLead["pipeline"], @aPipelines)            
            Aadd(aClose,nAng)
         ENDIF

         IF nPipeLine != 0
            //now get the step id in the pipeline
            nStep := oNoCRM:GetStepId( GetValue("NOCRM_STEP_SALE","Auftrag","Phase in der Pipeline fr Auftr„ge") ,nPipeLine,@aSteps)
            IF nStep != 0 //Step was found in this pipeline
               hLeadData["step"] := nStep
            ELSE
               ? "STEP NOT FOUND"            
            ENDIF
            
            hLeadData["amount"] := nValue            

            oNoCRM:Execute("leads/"+Ltrim(Str(nocrm->Lead)),"PUT",hLeadData)
         ENDIF

         auf->(dbSetOrder( 1 ))
         
         FOR EACH nValue IN hQuoteOrders
            nAB := nValue:__eNumKey()
            //Save order as a comment on an existing lead
            cContent := 'Auftrag Nr. '+LTrim(Str(nAB))+Chr(13)+Chr(10)      
            cContent += "Wert: "+LTrim(Str(nValue,12,2))

            auf->(dbSeek( Str(nAb,6) ))
            oUser := User():New()
            oUser:Load(auf->Buyer)
   
            oNoCrm:Execute("leads/"+LTrim(Str(nocrm->Lead))+"/comments","POST",{"lead_id"=>nocrm->Lead,"content"=>cContent,"activity_id"=>nActivity,"user_id"=>oUser:Email})
         NEXT
         

      ENDIF      
   NEXT

   ang->(dbSetOrder( 1 ))
   FOR EACH nAng IN aClose
      ? "Close",nAng
      ang->(dbSeek(Str( nAng ,6)))
      DO WHILE ang->Angnr == nAng .AND. ! ang->(EOF())
         IF ang->Bestat < 3 .AND. (! ang->Angnr $ hQuotes .OR. ang->Matchcode $ hQuotes[ang->Angnr] .OR. Trim(ang->Matchcode) $ aExcludeMatchcode)         
            ang->(Rec_Lock())
            ang->Bestat := 3
            ang->(dbUnLock())            
         ENDIF
         ang->(dbSkip())
      ENDDO
   NEXT
   
RETURN 


/* FRAGEN 

- Wert ver„ndern? Ja - Nur bei "Angebotspipeline"
- Egal bei welchem Unterschied? Ja
- Oder nur ab Wert X als gewonnen markieren?
-  Nur Angebotspipeline als gewonnen
- Aber wie stellen wir dann sicher das es nicht beim n„chsten Lauf wieder aufgenommen wird?

- Angebote auf erledigt setzen? Nur gewonne Artikel, auch bei "lost" //16.12.23 ge„ndert das auch verlorene geschlossen werden
- Nicht alle Positionen bestellt - Lead gewonnen? Nur wenn alle gewonnen.

- Mehrere Angebote an einen Kunden z.b. 37087 und 37089 - Angebot beom Auftrag speichern und dann kann der Auftrag nicht nochmal gewonnen werden

**- Wenn Angebote gewandelt werden dort Lead schlieáen
*/

#include 'x:\run\nocrm.prg'
