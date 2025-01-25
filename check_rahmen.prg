PROCEDURE RUN_CHECK_RAHMEN
LOCAL aCustomers   
LOCAL hCustomer,cFremd,aABs
LOCAL cText,cSubText,lOpen
LOCAL nX,nFRQty,bPosBlock
LOCAL cMatch

/*aCustomers := {;   
   {"MATCH"=>{"BACHMANG","BACHMANR"},;
   "FREMD"=>{"BACHMANR"},;
   "BESTAND"=>.F.,;
   "EMAILS"=>{;
      {"hans-peter.hollenbach@bachmann.com","Hans-Peter Hollenbach"},;
      {"Cristina.Tutuianu@bachmann.com","Cristina Tutuianu"},;
      {"thimo.hamma@engelking.de","Thimo Hamma","CC"},;
      {"joel.engelking@engelking.de","Joel Engelking","CC"};
   },;
   "SENDER"=>"joel.engelking@engelking.de",;
   "NAME"=>"Joel Engelking",;
   "ANREDE"=>"Sehr geehrte Damen und Herren,";
   };
  }*/

   aCustomers := {{"MATCH"=>{"SEIDENAD"},;
      "FREMD"=>{"KôRBERM","F.EE","TRIPSSOL","TRIPS","KOERBERU","KOSTWEIN","BIRCHER","KOSTWEKR"},;
      "BESTAND"=>.F.,;
      "EMAILS"=>{{"amos.engelking@engelking.de","Amos"}},;
         "SENDER"=>"mara.henzler@engelking.de",;
            "NAME"=>"Mara Henzler",;
               "ANREDE"=>"Sehr geehrte Damen und Herren,";
      }};
   
   
   /*,{"MATCH"=>{"GESSMANN"},;
      "FREMD"=>{},;
      "BESTAND"=>.T.,;
      "EMAILS"=>{{"amos.engelking@engelking.de","Amos"}},;
      "SENDER"=>"sabid.pehlic@engelking.de",;
      "NAME"=>"Sabid Pehlic",;
      "ANREDE"=>"Sehr geehrter Herr BÑchtle,";
      };*/

/*IF ! GetConfigValue("BATCHMODE") .AND. Tr_MsgBox("Testmodus?",,{"Ja","Nein"}) != 2
   aCustomers[1]["EMAILS"] := {{"amos.engelking@engelking.de","Amos"}}
ENDIF*/
   


NetUse("engauf","auf")
netUse("artikel","art")
NetUse("engkund","ku")
NetUse("fremdab","frab")
NetUse("artkund","aku")

CLS

FOR EACH hCustomer IN aCustomers
   ku->(dbSetOrder( 1 ))  
   cText := hCustomer["ANREDE"]+"<br><br>nachfolgend finden Sie eine Aufstellung der aktuell noch offenen RahmenvertrÑge.<br><br>Mit freundlichen GrÅ·en<br>"+hCustomer["NAME"]
   cText += "<table>"
   cText += "<tr><td><b>AB-Nr</b></td><td><b>Pos</b></td><td><b>Auftrag</b></td><td><b>Menge</b></td><td><b>Offen</b></td><td><b>Termin</b></td><td><b>Artikel</b></td><td><b>Ihre Artikelnummer</b></td>"
   IF hCustomer["BESTAND"]
      //cText += "<td><b>Bestand</b></td>"
   ENDIF
   cText += "</tr>"
   FOR EACH cMatch IN hCustomer["MATCH"]
      aABs := {}
      IF ku->(dbSeek( Pad(cMatch,8)+"K" ))         
         auf->(dbSetOrder( 2 ))
         auf->(dbSetFilter({|| Right(Str(auf->DTerm,4),2) == "99" },'Right(Str(DTerm,4),2) == "99"'))
         auf->(dbSeek( Pad(cMatch,8) )) //+Str(0,1) ))
         ? auf->Abnr
         DO WHILE Trim(auf->Kundma) == cMatch .AND. ! auf->(EOF())
            ? auf->Abnr
            art->(dbSeek( Str(auf->Artikelnr,6) ))
            Aadd(aABs,{auf->Abnr,auf->Itmnr,Me(art->Me),art->Me})
            auf->(dbSkip())
         ENDDO
         auf->(dbClearFilter())
         IF Len(aABs) > 0
            cText += "<tr><td colspan='8'>AuftrÑge von: "+Trim(Trim(ku->Name1)+" "+ku->Name2)+"</td></tr>"
         ENDIF
         FOR nX := 1 TO Len(aABs)
            cSubText := ""
            lOpen := .F.
            auf->(dbSetOrder( 1 ))
            auf->(dbSeek( Str(aABs[nX,1],6)+Str(aABs[nX,2],3) ))
            IF frab->(dbSeek( Str(auf->AbNr,6)+Str(auf->Itmnr,3) ))
               nFrQty := frab->Qty
            ELSE
               nFRQty := 0
            ENDIF
            cSubText += "<tr><td>"+LTrim(Str(auf->Abnr))+"</td><td>"+LTrim(Str(auf->Itmnr))+"</td><td>"+Trim(auf->Aufnr)+"</td><td>"+Transform(auf->ContrQty+nFrQty,aAbs[nx,3])+"</td><td>"+Transform(IF(auf->Bestat>=3,0,auf->VkQty-auf->GelQty),aAbs[nx,3])+"</td><td></td><td>"+Trim(auf->Matchcode)+"</td><td>"
            IF aku->(dbSeek( Pad(cMatch,8)+Str(auf->Artikelnr,6) ))
               cSubText += aku->Artlief
            ENDIF
            cSubText += "</tr>"
            IF auf->Bestat < 3 .AND. auf->VkQty-auf->GelQty > 0
               lOpen := .T.
            ENDIF
            bPosBlock := {||
               IF auf->Bestat < 3 .AND. auf->VkQty-auf->GelQty > 0
                  lOpen := .T.
               ENDIF
               cSubText += "<tr><td colspan=2></td><td>"+Trim(auf->Aufnr)+"</td><td>"+Transform(IF(auf->Bestat>=3,auf->GelQty,auf->VkQty),aAbs[nx,3])+"</td><td>"+Transform(IF(auf->Bestat>=3,0,auf->VkQty-auf->GelQty),aAbs[nx,3])+"</td>"
               cSubText += "<td>"
               IF ku->JustinTime
                  cSubText += DtoC(auf->BDatum)
               ELSE
                  cSubText += NiceWeek(auf->Dterm)
               ENDIF
               cSubtext += "</td></tr>"
               RETURN NIL
            }
            auf->(dbSetFilter({|| auf->ContrPos == aABs[nX,2] .AND. (auf->Bestat < 3 .OR. auf->GelQty > 0)},"ContrPos == "+LTrim(Str(aABs[nX,2]))+" .AND. (Bestat < 3 .OR. GelQty > 0)" ))
            IF auf->(dbSeek( Str(aABs[nX,1],6) ))
               cSubText += "<tr><td colspan=2><td colspan=3>Abrufe:</td></tr>"
               DO WHILE auf->AbNr == aABs[nX,1] .AND. ! auf->(EOF())
                  Eval(bPosBlock)
                  auf->(dbSkip())
               ENDDO
            ENDIF
            auf->(dbClearFilter())

            auf->(dbSetOrder( 2 ))
            auf->(dbSetFilter({|| auf->BesRef == Str(aABs[nX,1],6)+Str(aABs[nX,2],2) },"BesRef == '"+Str(aABs[nX,1],6)+Str(aABs[nX,2],2)+"'" ))
            FOR EACH cFremd IN hCustomer["FREMD"]
               cFremd := Pad(cFremd,8)
               IF cFremd != cMatch
                  ku->(dbSeek( cFremd+"K" ))
                  IF auf->(dbSeek(cFremd))
                     cSubText += "<tr><td colspan=2></td><td colspan=3>Abgerufen durch "+Trim(Trim(ku->Name1)+" "+ku->Name2)+":</td></tr>"
                     DO WHILE auf->Kundma == cFremd .AND. ! auf->(EOF())
                        Eval(bPosBlock)
                        auf->(dbSkip())
                     ENDDO
                  ENDIF
               ENDIF
            NEXT
            auf->(dbClearFilter())
            IF lOpen
               cText += cSubText
               cText += "<tr><td colspan=5>&nbsp;</td></tr>" //add a little space between orders
            ENDIF
            
         NEXT
      ENDIF
   NEXT
   cText += "</pre>"
   
   SendMail(hCustomer["EMAILS"],HB_AnsiToOem("Aufstellung Rahmenvertr‰ge"),cText,,,,.T.,hCustomer["SENDER"])
   //SendMail({{"amos.engelking@engelking.de","Hans-Peter Hollenbach"}},HB_AnsiToOem("Aufstellung Rahmenvertr‰ge"),cText,,,,.T.,"thimo.hamma@engelking.de")
NEXT
