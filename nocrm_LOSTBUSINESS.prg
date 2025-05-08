#define CRLF Chr(13)+Chr(10)

PROC RUN_LOSTBUSINESS
   LOCAL nMonths := 18
   LOCAL nLastInvoice := 6

   LOCAL dStart //:= BoM(AddMonth(Date(),nMonths*-1))
	LOCAL dEnd
   LOCAL dLastInvoice := BoM(AddMonth(Date(),-nLastInvoice))
   LOCAL hABs := {=>},cCustomer
   LOCAL hLost := {=>}
   LOCAL oArt,hTurnover
   LOCAL nM,nY
   LOCAL cText,dLast
   LOCAL oNoCrm := NoCrmApi():New()
   LOCAL aPipelines,nPipeLine,nStep,hLeadData
   LOCAL cUsrEmail,hLead
   LOCAL nAngnr

   CLS

   noCRM_Setup()

   NetUse("engauf","auf")
   NetUse("rechnung","reh")
   NetUse("buyer","buy")
   NetUse("group","grup")
   NetUse("engkund","ku")
   NetUSe("angebot","ang")
   NetUse("contacts","conts")
   NetUse("notes","nts")
   NetUSe("artikel","art")
   NetUse("kuinfo","kuinfo")

   //get pipeline id   
   nPipeLine := oNoCrm:GetPipeLineId( GetValue("NOCRM_PIPELINE_LOST"), @aPipelines) //,"Lost Business","Name der Pipeline fr Lost Business Leads")
   
   //now get the step id in the pipeline   
   nStep := oNoCRM:GetStepId( GetValue("NOCRM_STEP_LOST") ,nPipeLine) //,"Erfasst","Phase in der Lost Business Pipeline")

   hLeadData := {=>}
   hLeadData["remind_date"] := noCRM_DateConv(Date()+1)
   hLeadData["status"] := "standby"         
   hLeadData["step"] := nStep 

	
   FOR nM := 1 TO 1
      dStart := BoM(AddMonth(Date(),nMonths*-1-nM))
      dEnd := EoM(dStart)
   
      auf->(dbSetOrder(4))
      ? "Prfe",dStart,dEnd

      //Suche alle Kunden im Prfmonat
      auf->(dbSeek( DtoS(dStart) ,.T. ))  
      DO WHILE !auf->(Eof()) .AND. auf->Besda >= dStart .AND. auf->Besda <= dEnd
         IF ! auf->Kundma $ hABs
            hABs[auf->Kundma] := auf->Abnr
         ENDIF
         auf->(dbSkip())
      ENDDO

      //Prfe ob diese Kunden noch einen Auftrag platziert haben
      auf->(dbSetOrder( 9 ))
      reh->(dbSetOrder( 2 ))
      reh->(dbSetFilter( {|| reh->Rechdat >= dLastInvoice }, "Rechdat >= StoD('"+DtoS(dLastInvoice)+"')" ))
      ang->(dbSetOrder( 7 ))
      conts->(dbSetOrder( 2 ))
      
      FOR EACH cCustomer IN HGetKeys(hABs)
         auf->(dbSeek( cCustomer+DtoS(dEnd+1), .T. ))
         IF auf->Besda >= dEnd+1 .AND. cCustomer == auf->Kundma
            //? cCustomer,auf->Besda
            //Kunde hat noch einen Auftrag platziert
         ELSE 
            auf->(dbSetOrder( 2 ))
            IF auf->(dbSeek( cCustomer )) .AND. (auf->Bestat < 3 .OR. (auf->Bestat >= 4 .AND. auf->Bestat < 6))
               //? cCustomer,auf->Besda,"offener Auftrag"
               //kunde hat noch  einen aktiven Auftrag
            ELSEIF reh->(dbSeek( cCustomer ))
               //Kunde hatte eine Rechnungen in den letzten X Monaten
               //? cCustomer,auf->Besda,"Letzte Rechnung:",reh->Rechnr,reh->Rechdat
            ELSE
               auf->(dbSetOrder( 1 ))
               auf->(dbSeek( Str(hABs[cCustomer],6) ))
               hTurnover := GetCustomerTurnover(cCustomer)
               IF hTurnover["total"] >= 500
                  buy->(dbGoTo( auf->Buyer ))
                  ku->(dbSeek( cCustomer+"K" ))
                  ? cCustomer
                  cText := "Kunde (Matchcode): "+hb_strtoutf8(ku->Kunde)+CRLF
                  cText += "<p><b>Letzter Auftrag:</b><br>"
                  //cText += '<a href="
                  //cText += '"trader: Engauft('+LTrim(Str(hABs[cCustomer]))+')"'
                  cText += LTrim(Str(hABs[cCustomer]))+" vom "+DToC(auf->Besda)+"<br>"
                  IF auf->Person != 0
                     conts->(dbSeek( Str(ku->Nummer,6)+Str(auf->Person,4) ))
                     cText += "Ansprechpartner: "+Trim(conts->Name)+"<br>"
                  ENDIF
                  cText += "Mitarbeiter: "+Trim(buy->Buyer)
                  cText += "</p>"

                  ang->(dbSetFilter( {|| ang->Besda > auf->Besda }, "Besda > StoD('"+DtoS(auf->Besda)+"')" ))
                  cText += "<b>Angebote seit letztem Auftrag:</b><br>"
                  cText += "<table border=1 cellpadding=5><tr><td>Angebot</td><td>Datum</td><td>Positionen</td><td>Notizen</td></tr>"
                  ang->(dbSeek( cCustomer ))               
                  DO WHILE ang->Kundma == cCustomer .AND. ! ang->(EOF())                  
                     cText += "<tr><td>"+LTrim(Str(ang->Angnr))+"</td><td>"+DToC(ang->Besda)+"</td><td><table border=1>"
                     cText += "<tr><td>#</td><td>Artikel</td><td>Menge</td><td>Preis</td></tr>"
                     nAngnr := ang->Angnr
                     DO WHILE ang->Angnr == nAngnr
                        cText += "<tr><td>"+LTrim(Str(ang->Itmnr))+"</td><td>"+ang->Matchcode+"</td><td>"+Transform(ang->VkQty,Me(art->Me))+"</td><td>"+Str(ang->VkPr,12,2)+"</td></tr>"
                        ang->(dbSkip())
                     ENDDO     
                     cText += "</table></td><td>"
                     cText += "<table border='1'><tr><td>Datum</td><td>Art</td><td>Inhalt</td></tr>"

                     nts->(dbSetOrder( 3 ))
                     nts->(dbSeek("ANG"+Str(nAngnr,6),.T.))
                     DO WHILE nts->Betreff == "ANG" .AND. nts->Nummer == nAngnr
                        cText += "<tr><td>"+DToC(nts->Date)+"</td><td>"
                        cText += NoteType(nts->Type)
                        If nts->Buyer != 0
                           cText += "<br>"+Trim("von: "+Buy(nts->Buyer,.T.))
                        Endif
                        If nts->Person != 0
                           cText += "<br>"+Trim(If(nts->Type=="VISIT","bei","mit")+": "+PERSAY(nts->Person,.T.))
                        Endif
                        cText += "</td><td>"+StrTran(nts->Note,Chr(13),"<br>")+"</td></tr>"                       

                        nts->(dbSkip())
                     ENDDO
                     cText += "</table></td></tr>"
                  ENDDO
                  cText += "</table><br>"

                  cText += "<b>Gekaufte Artikel</b><br>"
                  cText += "<table border=1 cellpadding=5><tr><td>Artikel</td><td>Gruppe</td><td>Letzter Kauf</td></tr>"
                  auf->(dbSetOrder( 6 ))
                  auf->(dbSeek( cCustomer))               
                  DO WHILE auf->Kundma == cCustomer .AND. ! auf->(EOF())
                     IF Left(art->Matchcode,1) != "@" .AND. Left(art->Matchcode,4) != "TEXT"
                        oArt := Artikel():New()
                        oArt:Load(auf->Artikelnr)
                        dLast := auf->Besda
                        //cText += auf->matchcode+" "+oArt:Gruppe
                        cText += "<tr><td>"+Trim(auf->Matchcode)+"</td><td>"
                        IF grup->(dbSeek(oArt:Gruppe))
                           cText += Trim(grup->Name)
                        ELSE
                           cText += oArt:Gruppe
                        ENDIF
                        cText += "</td>"
                        DO WHILE auf->Kundma == cCustomer .AND. auf->Matchcode == oArt:Matchcode .AND. ! auf->(EOF())
                           dLast := Max(dLast,auf->Besda)
                           auf->(dbSkip())
                        ENDDO
                        cText += "<td>"+DToC(dLast)+"</td></tr>"
                     ENDIF
                  ENDDO
                  cText += "</table><br>"
                  


                  cText += CRLF
                  cText += "<b>Bisherigen Jahresums„tze:</b><br>"
                  cText += "<table border=1 cellpadding=5><tr><td>Jahr</td><td>Umsatz</td></tr>"
                  FOR EACH nY IN HGetKeys(hTurnover["years"])
                     //cText += Str(nY)+": "+Str(hTurnover["years"][nY],12,2)+CRLF
                     cText += "<tr><td>"+Str(nY)+"</td><td>"+Str(hTurnover["years"][nY],12,2)+"</td></tr>"
                     hLeadData["amount"] := hTurnover["years"][nY]
                  NEXT
                  cText += "</table>"+CRLF  
                  
                  IF ! kuinfo->(dbSeek( Str(ku->Nummer,6) )) .OR. Empty(kuinfo->Info)
                     UpdateBrancheWithAI()
                  ENDIF

                  cText += CRLF
                  cText += "<b>Kurzinformationen:</b><br>"
                  cText += kuinfo->Info


                  cUsrEmail := GetValue("NOCRM_USER_LOST","nora.zimmermann@engelking.de") //"amos.engelking@engelking.de"
                  hLead := oNoCRM:Execute("leads","POST",{"title"=>HB_StrToUtf8(Trim(Trim(ku->Name1)+" "+ku->Name2)),"description"=>HB_StrToUtf8(cText),"user_id"=>cUsrEmail})  
                  IF HHasKey(hLead,"errors")
                     //Alert("Error creating lead; "+hLead["errors"][1])
                  ELSE                  
                     oNoCRM:Execute("leads/"+Ltrim(Str(hLead["id"])),"PUT",hLeadData)
                  ENDIF

                  hLost[cCustomer] := hABs[cCustomer]           
               ENDIF    
            ENDIF
            auf->(dbSetOrder( 9 ))
         ENDIF      
      NEXT
   NEXT

   reh->(dbClearFilter())

   //Alert("Anzahl verlorene Kunden: "+Str(Len(hLost)))

   //Sinkey(0)

#include 'nocrm.prg'
#include 'update_branch_ai.prg'