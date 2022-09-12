PROC RUN_ANGEBOTE_WON_NOCRM
   LOCAL nQty,nAb
   LOCAL oNoCrm := NoCrmApi():New()
   LOCAL oErr,nActivity
   LOCAL hQuotes := {=>}
   LOCAL hOrders := {=>}
   LOCAL nValue,hQuote,hMatchcode,aQuotes := {}
   LOCAL hLead,aClose,nAng,cMatchcode,cFilter
   LOCAL aPipelines,nStdPipeLine,nPipeLine,nStep
   LOCAL hQuoteOrders,cContent,hLeadData
   LOCAL aExcludeMatchcode := {"@","FREIGHT","PORTO"}
   LOCAL oUser
   

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

   NetUse("engauf","auf")
   NetUse("angebot","ang")
   NetUse("nocrm","nocrm")
   NetUse("buyer","buy")

   ang->(dbSetOrder( 4 ))
   auf->(dbSetOrder( 6 ))
   
   ang->(dbSeek( Str(1,1) ))
   CLS
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
               IF nAB != auf->AbNr
                  nAb := auf->Abnr
                  nQty := 0
               ENDIF
               IF ! nAB $ hOrders .OR. hOrders[nAB] == ang->Angnr
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
      ENDIF
   
      ang->(dbSkip())      
   ENDDO

   ang->(dbSetOrder( 1 ))

   aClose := {}

   //Letztendlich wurde beschlossen diese Angebote nicht zu schlieáen - siehe Fragen
   /*FOR EACH nAng IN aQuotes  //Angebote ohne Auftrag suchen und prfen      
      IF ! nAng $ hQuotes //Es wurde kein Auftrag gefunden
         nocrm->(dbSeek( Str(nAng,6) ))
         ang->(dbSeek( Str(nAng,6) ))
         hLead := oNoCRM:Execute("leads/"+Ltrim(Str(nocrm->Lead)),"GET")
         IF hLead == NIL //Lead nicht gefunden, Angebot bleibt offen bis die Frist anbgelaufen ist
            ? nAng,"Lead nicht gefunden",ang->Besda
         ELSEIF hLead["status"] == "won" //als gewonnen markiert, wir konnten aber keine Auftr„ge finden, das wird als Fehler ausgegeben
            ? nAng,"Lead gewonnen, kein (neuen) Auftrag gefunden"
         ELSEIF hLead["status"] $ {"lost","cancelled"} //ander weitig geschlossen, Angebot bleibt offen bis Frist abgelaufen 
            ? nAng,"Verloren oder Geschlossen"
            //Aadd(aClose,nAng)
         ENDIF
      ENDIF
   NEXT*/

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
      hLead := oNoCRM:Execute("leads/"+Ltrim(Str(nocrm->Lead)),"GET")
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
            nStep := oNoCRM:GetStepId( GetValue("NOCRM_STEP_SALE","Auftrag","Phase in der Pipeline fr Auftr„ge") ,nPipeLine)
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

- Angebote auf erledigt setzen? Nur gewonne Artikel, auch bei "lost"
- Nicht alle Positionen bestellt - Lead gewonnen? Nur wenn alle gewonnen.

- Mehrere Angebote an einen Kunden z.b. 37087 und 37089 - Angebot beom Auftrag speichern und dann kann der Auftrag nicht nochmal gewonnen werden

**- Wenn Angebote gewandelt werden dort Lead schlieáen
*/

#include 'x:\run\nocrm.prg'
