//#define DvArchivePersonalIn	101
#define DvArchiveCommon 2

//#define DvArchivePersonalTextModules	103
//#define DvItemIsLess 2
//#define DvItemIsGreater 3
#define DvItemIsEqual 0
#define DvFilterAnd 1
#define DvFilterOr 2

#define DvEMailItem 2      // MailItem Objekt
#define DvMsgSelEMail  1
#define DvRoutingEMail 2

#define DvFieldText 0

#define DvField_SRFrom HB_HexToNum("FFFFFFFF80008039")
#define DvField_To -2147450824 //HB_HexToNum("FFFFFFFFC200800B")
//#define DvField_SRTo HB_HexToNum("FFFFFFFF80008038")
#define DvField_RoutingID HB_HexToNum("FFFFFFFF8000803F")

#define DvRoutingEmail 2

#define CRLF Chr(13)+Chr(10)

#ifndef __XHARBOUR__
	#xtranslate ThreadSleep( <x> )              => hb_idleSleep( <x> / 1000 )
#endif

PROCEDURE RUN_EMAIL_ROUTING
   
   LOCAL oApp,oAccount,oCommon
   LOCAL oItem,oFilter   
   LOCAL nX   
   LOCAL cName
   LOCAL hDomains := {=>},cDomain
   LOCAL hKunden := {=>}
   LOCAL hTo := {2=>{"USER"=>58},3=>{"USER"=>54},5=>{"USER"=>69}}
   LOCAL aWebMailer := {"gmx","gmail","outlook","t-online"}   
   LOCAL cError := ""

   MEMVAR c_four_list,c_one_list

   Head("Setting up Email Routing")

   NetUse("team","team")
   NetUse("engkund","ku")
   NetUse("contacts","conts")


   //find all domains
   /*ku->(dbSetOrder(9))
   //ku->(dbSeek("K"))
   ku->(dbSeek( Str(2,2) ) )
   DO WHILE ku->Team > 0 .AND. ! ku->(EOF()) .AND. Inkey() != 27
      ? ku->Kunde

      aCustomerDomains := {}
      conts->(dbSeek( Str(ku->Nummer,6)+"0" ) )
      DO WHILE ! conts->(Eof()) .AND. conts->Active .AND. conts->Address == ku->Nummer
         IF ! Empty(conts->Email)
            cDomain := Lower(Trim(SubStr(conts->Email,AT("@",conts->Email))))
            IF AT("@",cDomain) == 0 //this is not an email address               

            ELSEIF SubStr(cDomain,2,RAT(".",cDomain)-1-1) $ aWebmailer
               
            ELSEIF ! cDomain $ aDomains
               ? "Domain: "+cDomain
               AAdd(aDomains,cDomain)
               Aadd(aCustomerDomains,cDomain)
            ELSEIF cDomain $ aDomains .AND. ! cDomain $ aCustomerDomains
               ? "NOT UNIQUE Domain: "+cDomain
               Aadd(aCustomerDomains,cDomain)
            ENDIF
         ENDIF
         conts->(dbSkip())
      ENDDO
      ku->(dbSkip())
   ENDDO     

   ? "Total: ",Len(aDomains)
   Sinkey(0)*/

   oApp := CreateObject("DVOBJAPILib.DvISEAPI")
   oAccount := oApp:Logon("", "", "", "", "", "AUTH")
      
   oCommon := oAccount:GetSpecialArchive(DvArchiveCommon)

   hEval(hTo,{|key,val|
      buy->(dbGoTo(val["USER"]))
      hTo[key]["ARCHIVE"] := oAccount:ArchiveFromID(oAccount:DavidRoot+"\Archive\User\"+Trim(buy->David_Id)+"\IN")
      RETURN NIL
   })
   //oTo := oAccount:ArchiveFromID(oAccount:DavidRoot+"\Archive\User\"+SystemUser():David_Id+"\IN")
   //Alert(oTo:DisplayName)

   nX            := 0
   ku->(dbSetOrder( 8 ))
   //find existing routing entries
   ? "Reading existing routing entries.."
   @ Row(),35+12 SAY "/"+LTrim(Str(oCommon:RoutingEntries:Count))
   Do While nX < oCommon:RoutingEntries:Count
      @ Row(),35 SAY Str(nX,12)
      oItem := oCommon:RoutingEntries:Item(nX)
      
      If AT("KUNDE:",oItem:Name) == 1 .AND. ku->(dbSeek( Str(Val(SubStr(oItem:Name,7,6)),6) ))         
         hKunden[ku->Nummer] := oItem
         oItem:Enabled := .F.
         oItem:Commit()
      Endif
      nX++
   ENDDO

   ku->(dbSetOrder(9))
   ku->(dbSeek( Str(1,2),.T. ))
   nCount := 0
   
   DO WHILE ku->Team > 0 .AND. ! ku->(EOF()) .AND. Inkey() != 27 .AND. LastKey() != 27 //.AND. nCount < 6

      ? ku->Kunde
      IF HHasKey(hTo,ku->Team)
         oTo := hTo[ku->Team]["ARCHIVE"]
      
         nCount++

         cName := "KUNDE:"+Str(ku->Nummer,6)+" "+ku->Kunde
         IF ! HHasKey(hKunden,ku->Nummer)
            oItem := oCommon:RoutingEntries:Add( cName )
            //oItem:Commit()
         ELSE
            oItem := hKunden[ku->Nummer]
            oItem:Name := cName
            oItem:Conditions:RemoveAll()
         ENDIF 
         
         oItem:RouteAsCopy := .F.
         oItem:Forward := .F.
         //oItem:ForwardAs := DvRoutingEmail
         oItem:Destinations := {oTo} 
         oItem:Commit()

         oFilter := oItem:Conditions:Add()
         oFilter:Object := DvField_RoutingID //-2147450821 //To
         oFilter:Comparision := DvItemIsEqual
         oFilter:Value := "sales@engelking.de"
         //oFilter:Operator := DvFilterAnd
            
         nFilter := 0

         conts->(dbSeek( Str(ku->Nummer,6)+"0" ) )
         DO WHILE ! conts->(Eof()) .AND. conts->Active .AND. conts->Address == ku->Nummer
            IF ! Empty(conts->Email)
               cDomain := Trim(SubStr(conts->Email,AT("@",conts->Email)))
               IF cDomain $ aWebmailer
                  IF nFilter >= 6
                     cError += "Maximale Anzahl Domains/Email-Adressen erreicht "+ku->Kunde+CRLF
                     EXIT
                  ELSE
                     nFilter++

                     oFilter := oItem:Conditions:Add()
                     oFilter:Object := DvField_SRFrom //-2147450823 //From
                     oFilter:Comparision := DvItemIsEqual
                     oFilter:Value := Trim(conts->Email)
                     IF ! lFirst
                        oFilter:Operator := DvFilterOr
                     ELSE
                        oFilter:Operator := DvFilterAnd
                     ENDIF               
                  ENDIF
                  
                  //oItem:Commit()
               ELSEIF ! cDomain $ hDomains
                  IF nFilter >= 6
                     cError += "Maximale Anzahl Domains/Email-Adressen erreicht "+ku->Kunde+CRLF
                     EXIT
                  ELSE                     
                     nFilter++

                     ? "Domain: "+cDomain               
                     ? oItem:Name               
                     oFilter := oItem:Conditions:Add()
                     oFilter:Object := DvField_SRFrom //-2147450823 //From
                     oFilter:Comparision := DvItemIsEqual
                     oFilter:Value := "*"+cDomain
                     IF nFilter > 1
                        oFilter:Operator := DvFilterOr
                     ELSE
                        oFilter:Operator := DvFilterAnd
                     ENDIF               
                     
                     hDomains[cDomain] := {"KUNDE"=>ku->Kunde,"TEAM"=>ku->Team}
                  ENDIF
               ELSEIF cDomain $ hDomains .AND. hDomains[cDomain]:Team != ku->Team
                  cError += "NOT UNIQUE Domain: "+cDomain+" "+ku->Kunde+" und "+hDomains[cDomain]:Kunde+CRLF
               ENDIF
            ENDIF
            conts->(dbSkip())
         ENDDO
         IF nFilter > 0
            oItem:Enabled := .T.
            oItem:Commit()
         ENDIF
      ENDIF

      ku->(dbSkip())
   ENDDO      

   IF ! Empty(cError)
      SendMail({{"amos.engelking@engelking.de","Amos"}},"Error in Email Routing","Error in Email Routing"+CRLF+cError)
   ENDIF

   ? "Abgeschlossen"
   Sinkey(0)

RETURN