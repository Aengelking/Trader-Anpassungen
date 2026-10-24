/**
  Aufbau:
  Sprache,Ansprechpartner, Anrede, Firma, Straﬂe, PLZ, Stadt, Land, Email, CS-No, Techn.‰nd., CM-No
**/


#command @ <top>,<left>,<bottom>,<right> GET <var> LISTBOX <hash> ASSOCIATIVE ;
	[VALID <valid>];
	[WHEN <when>];
	[COLOR <color>];
;
=> GET_AssociativeListBox(getlist,<top>,<left>,<bottom>,<right>,{|v| If(v==NIL,<var>,<var>:=v)},<hash>,<{valid}>, <{when}>,<color>)

#include 'inkey.ch'

STATIC s_hBlackEmail
STATIC s_hBlackDomain

PROCEDURE RUN_Email_Mailing
   LOCAL hSettings := {;
      "NTYPE" => 1,;
      "CBEGIN" => Space(255),;
      "LMUSTER" => .T.,;
      "LANGEBOT" => .T.,;
      "LAUFTRAG" => .T.,;
      "LALLCONTACTS" => .F.,;
      "LNOGENERAL" => .F.,;
      "NMANU" => 1,;
      "CGROUP" => Space(4),;         
      "CLANG" => "D",;
      "HPARAMS"=>{=>};
   }
   
   LOCAL getlist := {}
   
   LOCAL aTypes := {"Matchcode (Regex)","Hersteller","Produktgruppe"}
   LOCAL hManu := GetManufacturerHash()


   LOCAL hPos,cWeek,nX,cKunde,nP
   LOCAL nA   
   LOCAL aPeople

   LOCAL nCount   
   LOCAL oBrevo := Brevo():New()
   LOCAL hResponse,hTemplate,cParam
   LOCAL hTemplates
   LOCAL nTemplate := 1
   LOCAL aParams   
   LOCAL aTokens
   LOCAL hParamData
   LOCAL hParamBasic
   LOCAL nRow
   LOCAL bShowGets
   LOCAL dFrom := BoM(Date()-365)
   LOCAL oGetBegin,oGetManu,oGetGroup
   LOCAL oBrowse,nY,cKey,aPerson
   LOCAL nChoice,aVersions,xData   
   LOCAL hCustomer,hData
   LOCAL cFile,lNew := .T.
   LOCAL cEmail
   LOCAL nLimit,nMax

   NetUse("engauf","auf",.F.,0)
   NetUse("lagerne","lne",.F.,0)
   NetUse("artkund","aku")
   NetUse("engkund","ku",.F.,0)
   NetUse("artikel","art")
   NetUse("angebot","ang")
   NetUse("contacts","conts")
   NetUse("anrede","an") 
   NetUse("parts","part")    
   NetUse("buyer","buy") 

   Head("Produktmailing")

   IF Tr_MsgBox("Bestendes Mailing laden?",,{"neu","laden"}) == 2
      cFile := Wvt_GetOpenFileName( 0,"" , "Mailing Einstellungen îffnen", { {"Filter Einstellungen (*.json)","*.json"},{"Alle Dateien (*.*)","*.*"} }, ,"" )
      IF Empty(cFile)
         RETURN
      ENDIF
      hSettings := HB_JsonDecode(MemoRead(cFile))         
      lNew := .F.
   ELSEIF LastKey() == 27
      RETURN               
   ENDIF

   //Head("Ansprechpartner mit Email Adressen exportieren")
   DO WHILE .T.

      @ 01,00 CLEAR
            
      hResponse := oBrevo:Execute("smtp/templates","GET")

      IF ValType(hResponse) != "H"
         Tr_MsgBox("Fehler beim Abruf der Vorlagen")
         RETURN 
      ENDIF
      IF ! HHasKey(hResponse,"templates")
         Tr_MsgBox("Keine Vorlagen gefunden")
         IF HHasKey(hResponse,"message")
            Tr_MsgBox(hResponse["message"])
         ENDIF
         RETURN
      ENDIF
      hTemplates := {=>}
      FOR nX := 1 TO Len(hResponse["templates"])
         hTemplate := hResponse["templates"][nX]
         IF AT("{{product.",hTemplate["htmlContent"]) > 0          
            hTemplates[nX] := hb_utf8tostr(hTemplate["name"])
         ENDIF
      NEXT
      IF Len(hTemplates) == 0
         Tr_MsgBox("Fehler","Keine Vorlagen fÅr Produktmailings gefunden")
         RETURN
      ENDIF
      @ 01,00 SAY "Vorlage"
      @ 01,24,20,77 GET nTemplate LISTBOX hTemplates ASSOCIATIVE WHEN lNew
      READ
      IF LastKey() == K_ESC .OR. nTemplate == 0
         RETURN
      ENDIF
      @ 02,00 SAY Replicate(Chr(196),05)+" FELDER "+Replicate(Chr(196),61)
      nRow := 03
 
      aParams := {}   
      aTokens := HB_ATokens(hResponse["templates"][nTemplate]["htmlContent"],"{{")
      FOR EACH cParam IN aTokens
         cParam := SubStr(cParam,1,AT("}}",cParam)-1)
         IF Left(cParam,7) == "params." .AND. ! cParam $ aParams .AND. ! Substr(cParam,8,AT(".",Substr(cParam,8))-1) $ {"customer","person","products"}       
            Aadd(aParams,cParam)
            IF cParam == "params.manufacturer"
               IF ! HHasKey(hSettings:hParams,cParam)
                  hSettings:hParams[cParam] := 1
               ENDIF               
               @ nRow,00 SAY "Hersteller"
               @ nRow,24,nRow+12,49 GET hSettings:hParams["params.manufacturer"] LISTBOX hManu ASSOCIATIVE WHEN lNew
            ELSEIF cParam == "params.increase"            
               IF ! HHasKey(hSettings:hParams,cParam)                 
                  hSettings:hParams[cParam] := 0
               ENDIF
               @ nRow,00 SAY "Preiserhîhung"
               @ nRow,24 GET hSettings:hPArams["params.increase"] PICTURE "99.99" WHEN lNew
               @ nRow,30 SAY "%"
            ELSE 
               IF ! HHasKey(hSettings:hParams,cParam)
                  hSettings:hParams[cParam] := Space(255)
               ELSE
                  hSettings:hParams[cParam] := Pad(hSettings:hParams[cParam],255)
               ENDIF
               @ nRow,00 SAY Substr(cParam,8)
               @ nRow,24 GET hSettings:hParams[cParam] PICTURE "@S25" WHEN lNew
            ENDIF
            nRow++
         ENDIF
      NEXT
      FOR EACH cParam IN HGetKeys(hSettings:hParams)
         IF ! cParam $ aParams //if we are using saved settings make sure there are only ones in the template
            HB_HDel(hSettings:hParams,cParam,.T.)
         ELSEIF ValType(hSettings:hParams[cParam]) == "C" //trim all character values
            hSettings:hParams[cParam] := Trim(hSettings:hParams[cParam])
         ENDIF
      NEXT
      @ nRow,00 SAY Replicate(Chr(196),05)+" PRODUKT/KUNDEN AUSWAHL "+Replicate(Chr(196),45)
      nRow++

      bShowGets := {|| 
         LOCAL nG := MaxRow()+1
         getlist[1]:Control:close()

         @ nRow-1,00 CLEAR TO nRow-1,MaxCol()   
         IF hSettings:nType == 1
            @ nRow-1,00 SAY "Regex"      
         ELSEIF hSettings:nType == 2
            @ nRow-1,00 SAY "Hersteller"
         ELSE
            @ nRow-1,00 SAY "Produktgruppe"      
         ENDIF
            
         oGetBegin:row := IF(hSettings:nType==1,nRow-1,nG)         
         oGetManu:row := IF(hSettings:nType==2,nRow-1,nG)
         oGetManu:Control:top := IF(hSettings:nType==2,nRow-1,nG)   
         oGetGroup:row := IF(hSettings:nType==3,nRow-1,nG)

         oGetBegin:Display()
         oGetManu:control:Display()
         oGetGroup:Display()
         
         RETURN .T.
      }

      @ nRow,00 SAY "Sprache"
      @ nRow,24,nRow+10,50 GET hSettings:cLang LISTBOX {"D"=>"Deutsch","E"=>"Englisch"} ASSOCIATIVE WHEN lNew
      nRow++
      @ nRow,00 SAY "Auswahlart"
      @ nRow,24,nRow+10,50 GET hSettings:nType LISTBOX aTypes DROPDOWN VALID Eval(bShowGets) WHEN lNew
      nRow++
      hSettings:cBegin := Pad(hSettings:cBegin,255)
      @ nRow,24 GET hSettings:cBegin PICTURE "@S50" WHEN hSettings:nType == 1 .AND. lNew VALID ! Empty(hSettings:cBegin) 
      oGetBegin := Atail(getlist)
      @ MaxRow()+1,24,24,40 GET hSettings:nManu LISTBOX hManu ASSOCIATIVE WHEN hSettings:nType == 2 .AND. lNew
      oGetManu := Atail(getlist)
      @ MaxRow()+1,24 GET hSettings:cGroup PICTURE "@!" WHEN hSettings:nType == 3 .AND. lNew
      oGetGroup := Atail(getlist)
      @ ++nRow,00 SAY "Ab Datum"
      @ nRow,24 GET dFrom WHEN lNEw

      Eval(bShowGets)

      @ nRow+1,00 SAY "Muster"
      @ nRow+1,24 GET hSettings:lMuster CHECKBOX WHEN lNew
      @ nRow+2,00 SAY "Angebote"
      @ nRow+2,24 GET hSettings:lAngebot CHECKBOX WHEN lNew
      @ nRow+3,00 SAY t("Auftr‰ge")
      @ nRow+3,24 GET hSettings:lAuftrag CHECKBOX WHEN lNew
      @ nRow+4,00 SAY "Alle Kontakte"
      @ nRow+4,24 GET hSettings:lAllContacts CHECKBOX WHEN lNew
      @ nRow+5,00 SAY "Allgemeine ausschlie·en"
      @ nRow+5,24 GET hSettings:lNoGeneral CHECKBOX WHEN lNew

      //@ nRow+6,00 SAY Replicate(Chr(196),05)+" INFO "+Replicate(Chr(196),61)
      //@ nRow+7,00 SAY "Emails werden an alle Kontakte gesendet die mit den Produkten in Verbindung stehen"
      READ


      IF LastKey() == 27
         RETURN
      ENDIF

      IF ! lNew
         hPos := hSettings["data"]         
      ELSE
         hSettings:cBegin := Trim(hSettings:cBegin)
         
         hPos := {=>}

         auf->(dbSetOrder( 10 ))
         ku->(dbSetOrder( 1 ))
         art->(dbSetOrder( 2 ))
   
         cWeek := CalWeek(dFrom)

         SET CURSOR OFF

         nCount := 0
         IF hSettings:lAuftrag
            auf->(dbSetFilter({|| auf->VkPr != 0 },"VkPr != 0"))
            auf->(dbSeek( cWeek , .T. ))
            @ 23,00 SAY "Auftrag"
            Do While ! auf->(EOF()) .AND. auf->DTERM >= Val(cWeek) .AND. Left(Str(auf->Dterm,4),2) < "50"
               IF hSettings:nType >= 2
                  art->(dbSeek( Str(auf->Artikelnr,6) ))
               ENDIF      
               
               nCount += __AddEntry(hPos,auf->Kundma,auf->Matchcode,auf->person,hSettings)
               @ 23,14 SAY Str(auf->Abnr,6)+" ("+LTrim(Str(nCount))+")"

               auf->(dbSkip())
            Enddo
            auf->(dbClearFilter())
         ENDIF


         IF hSettings:lMuster
            nCount := 0
            @ 24,00 SAY "Musterauftrag"
            lne->(dbSetFilter({|| lne->Versand .AND. lne->Datum >= dFrom .AND. lne->Gruppe == "K"},"Versand .AND. Datum >= StoD('"+DtoS(dFrom)+"') .AND. Gruppe == 'K'"))
            lne->(dbGoTop())
            Do While ! lne->(Eof())
               IF hSettings:nType >= 2
                  art->(dbSeek( Str(lne->Artikelnr,6) ))
               ENDIF             
               nCount += __AddEntry(hPos,lne->Kunde,lne->Matchcode,lne->Person,hSettings)
               @ 24,14 SAY Str(lne->Nummer,6)+" ("+LTrim(Str(nCount))+")"         
               
               lne->(dbSkip())
            Enddo
            lne->(dbClearFilter())
         ENDIF

         IF hSettings:lAngebot
            nCount := 0
            @ 25,00 SAY "Angebote"
            ang->(dbSetFilter({|| ang->Datum >= dFrom },"Datum >= StoD('"+DtoS(dFrom)+"')"))
            ang->(dbGoTop())
            Do While ! ang->(Eof())
               IF hSettings:nType >= 2
                  art->(dbSeek( Str(ang->Artikelnr,6) ))
               ENDIF         
               nCount += __AddEntry(hPos,ang->Kundma,ang->Matchcode,ang->Person,hSettings)
               @ 25,14 SAY Str(ang->Angnr,6)+" ("+LTrim(Str(nCount))+")"         
               
               ang->(dbSkip())
            Enddo
            ang->(dbClearFilter())
         ENDIF
      ENDIF

      
   
      oBrowse := TABrowse():New(01,75,MaxRow(),MaxCol())
      oBrowse:aData := {} //HGetValues(hPos)    
      FOR nX := 1 TO Len(hPos)
         hCustomer := HGetValueAt(hPos,nX)
         IF Len(hCustomer["people"]) == 0
            HB_HDel(hPos,hCustomer["kunde"],.T.)
            nX--      
         ELSE
            FOR nY := 1 TO Len(hCustomer["people"])
               /*hPerson := HGetValueAt(hCustomer["people"],nY)
               IF hHasKey(hPerson,"messageid") .AND. ! HHasKey(hPerson,"status") .AND. nY == 1
                  hResult := oBrevo:Execute("smtp/statistics/events","GET",{"messageId"=>hPerson["messageid"],"limit"=>1})
                  Alert(hPerson["messageid"]+";"+ValToPrg(hResult))
                  //hPerson["status"] := hResult["events"][1]["event"]
               ENDIF*/
               Aadd(oBrowse:aData, {hCustomer["kunde"],HGetKeyAt(hCustomer["people"],nY)})
            NEXT
         ENDIF 
      NEXT

      IF Len(oBrowse:aData) == 0
         Tr_MsgBox("Keine Kunden gefunden")
         LOOP
      ENDIF
      
      oBrowse:NewColumn("  "+Pad("Kunde",8)+" "+Pad("Anrede",29)+" "+Pad("Person",30)+" "+"Email",{|| 
         LOCAL hPers
         LOCAL hData := hPos[oBrowse:CurrentDataRow()[1]]      
         LOCAl cStatus

         hPers := hData["people"][oBrowse:CurrentDataRow()[2]]
         
         ku->(dbSeek( hData["kunde"]+"K" ))
         conts->(dbSetOrder(2))      
         
         // Add validation indicator
         IF ! IsValidEmail(hPers["email"])
            cStatus := Chr(15) // Warning symbol for invalid email
         ELSEIF HHasKey(hPers,"messageid")
            cStatus := Chr(251) // Checkmark for sent
         ELSE
            cStatus := " "
         ENDIF
         
         RETURN cStatus+" "+hData["kunde"]+" "+Pad(hPers["anrede"],29)+" "+Pad(hPers["email"],35)+IF(HHasKey(hPers,"status"),Pad(hPers["status"],10),Space(10))  
      })   
      
      oBrowse:AddKey(K_ESC,{|| .F. })
      oBrowse:AddKey(K_ENTER,{||
         LOCAL hData := hPos[oBrowse:CurrentDataRow()[1]]
         LOCAL hPers := hData["people"][oBrowse:CurrentDataRow()[2]]
         LOCAL cNewEmail, cOldEmail,aMsgs
         
         IF HHasKey(hPers,"messageid")
            Tr_MsgBox("Email bereits versendet - kann nicht geÑndert werden")
         ELSE
            cOldEmail := hPers["email"]
            cNewEmail := GetBox(Pad(cOldEmail,50), "Email-Adresse bearbeiten fÅr " + hPers["name"], "@S50")
            IF LastKey() != K_ESC .AND. ! Empty(cNewEmail)
               cNewEmail := Trim(cNewEmail)
               IF IsValidEmail(cNewEmail)
                  aMsgs := {"Email-Adresse erfolgreich geÑndert: "+cNewEmail}
                  IF ! HHasKey(hPers,"nummer")
                     Aadd(aMsgs,"Kundenstamm wurde nicht aktualisiert (alte JSON-Datei)")
                  ELSE
                     ku->(dbSeek( hData["kunde"]+"K" ))
                     conts->(dbSetOrder(2))      
                     IF conts->(dbSeek( Str(ku->Nummer,6)+Str(hPers["nummer"],4) ))
                        conts->(Rec_Lock())
                        conts->Email := cNewEmail
                        conts->(dbUnlock())
                     ENDIF                                       
                  ENDIF
                  hPers["email"] := cNewEmail                  
                  Tr_MsgBox(aMsgs)
               ELSE
                  Tr_MsgBox("UngÅltige Email-Adresse - énderung nicht gespeichert")
               ENDIF
            ENDIF
         ENDIF
         RETURN .T.
      })
      oBrowse:AddKey(K_DEL,{||      
         LOCAL hData := hPos[oBrowse:CurrentDataRow()[1]]
         LOCAL hPers := hData["people"][oBrowse:CurrentDataRow()[2]]
         hPers := hData["people"][oBrowse:CurrentDataRow()[2]]
         IF HHasKey(hPers,"messageid")
            Tr_MsgBox("Email bereits versendet - EmpfÑnger kann nicht gelîscht werden")
         ELSE
            IF Tr_MsgBox(hPers["name"]+" aus Mailing entfernen?",,{"Nein","Ja"}) == 2
               HB_HDel(hData["people"],oBrowse:CurrentDataRow()[2],.T.)
               IF Len(hData["people"]) == 0
                  HB_HDel(hPos,oBrowse:CurrentDataRow()[1],.T.)
               ENDIF         
               HB_ADel(oBrowse:aData,oBrowse:CurrentRow(),.T.)
               IF Len(hPos) == 0
                  RETURN .F.
               ENDIF
            ENDIF
         ENDIF
         RETURN .T.
      })


      oBrowse:AddKey(Asc("B"),{|| BlacklistFromBrowse(oBrowse,hPos) })
      oBrowse:AddKey(Asc("b"),{|| BlacklistFromBrowse(oBrowse,hPos) })

      oBrowse:bAnyFun := {||
         LOCAL nX
         LOCAL hData := hPos[oBrowse:CurrentDataRow()[1]]
         @ 28,49 CLEAR TO MaxRow()-1,73
         FOR nX := 1 TO Min(Len(hData["artikel"]),MaxRow()-27)
            @ 27+nX,49 SAY hData["artikel"][nX]
         NEXT
         RETURN .T.
      }
      @ 27,48 TO MaxRow(),74 DOUBLE
      @ 27,49 SAY "[ Artikel ]"
      @ MaxRow(),00 SAY "ENTER=Email bearb.  DEL=entfernen  B=Blacklist  ESC=Weiter"
      oBrowse:EventLoop()
      @ 27,48 CLEAR TO MaxRow(),74

      nMax := 0
      FOR nX := 1 TO Len(hPos)
         hCustomer := HGetValueAt(hPos,nX)
         aPeople := hCustomer["people"] 
         FOR nP := 1 TO Len(aPeople)
            hPerson := HGetValueAt(aPeople,nP)     
            IF ! HHasKey(hPerson,"messageid")
               nMax++
            ENDIF
         NEXT
      NEXT
      IF nMax == 0
         //Tr_MsgBox("Keine Emails zum Versenden")
         //RETURN
      ENDIF

      //Alert(ValToPrg(HGetValueAt(hPos,1)["people"]))
      nChoice := AMenu({IF(lNew,"Speichern & ","")+"Versenden","Einstellungen anpassen","Abbrechen"},{nMax>0,!HHasKey(HgetValueAt(HGetValueAt(hPos,1)["people"],1),"messageid"),.T.})
      IF nChoice == 1
         IF lNew
            hSettings["data"] := hPos            
            //Save         
            cFile := Wvt_GetSaveFileName( 0,"" , "Mailing Einstellungen speichern", { {"Filter Einstellungen (*.json)","*.json"} }, ,"" )      
            IF Lower(Right(cFile,5)) != ".json"
               cFile := cFile+".json"
            ENDIF
            MemoWrit(cFile,HB_JsonEncode(hSettings))
         ENDIF
         EXIT
      ELSEIF nChoice == 2
         IF Tr_MsgBox("Aktuelle Auswahl geht verloren",,{"fortsetzen","abbrechen"}) == 1
            lNew := .T.
         ENDIF
         LOOP
         
      ELSEIF nChoice == 3
         RETURN
      ENDIF
   ENDDO   

   nCount := 0
   DO WHILE .T.
      
      nChoice := Tr_MsgBox("Emails versenden?",,{"Testlauf (kein Versand)","Testlauf (intern 2x)","Nein","Versenden"}) 
   
      IF ! nChoice $ {1,2,4}
         RETURN
      ENDIF

      IF nChoice == 2
         cEmail := Trim(GetBox(Pad(SystemUser():Email,50),"Email Adresse eingeben"))
         nLimit := 2
         IF LastKey() == 27
            LOOP
         ENDIF
      ELSEIF nChoice == 1
         cEmail := "amos.engelking@engelking.de"
      ENDIF
      IF nChoice != 2
         
         nLimit := GetBox(Min(nMax,1000),"Anzahl Emails (max. "+LTrim(Str(Min(nMax,1000)))+")","9999",,,,{|x| x <= nMax })
      ENDIF

      @ 26,00 SAY "Versende Emails..."
      @ 26,26 SAY "/"+LTrim(Str(nLimit))

      aku->(dbSetOrder( 3 ))

      aVersions := {}
      hParamBasic := {=>}

      FOR EACH xData IN hSettings:hParams
         cKey := xData:__eNUmKey()
         IF AT("params.",cKey) == 1
            IF cKey == "params.manufacturer"
               hParamBasic["manufacturer"] := Trim(hManu[xData])
            ELSE
               hParamBasic[SubStr(cKey,8)] := IF(ValType(xData)=="C",Trim(xData),xData)
            ENDIF
         ENDIF
      NEXT
         

      FOR nX := 1 TO Len(hPos)
         
         hCustomer := HGetValueAt(hPos,nX)
         cKunde := hCustomer["kunde"]
         ku->(dbSeek( cKunde+"K" ))

         hParamData := HB_HClone(hParamBasic)
         hParamData["customer"] := {;
            "matchcode"=>hb_strToUtf8(Trim(ku->Kunde)),;
            "number"=>ku->Nummer,;
            "name"=>hb_strToUtf8(Trim(Trim(ku->Name1)+" "+ku->Name2)),;
            "street"=>hb_strToUtf8(Trim(ku->Street)),;
            "postcode"=>Trim(ku->Plz),;
            "town"=>hb_strToUtf8(Trim(ku->Town)),;
            "country"=>hb_strToUtf8(Trim(GetCountryname(ku->CountryIso)));
         }

         hParamData["products"] := {}

         ASort(hCustomer["artikel"])
         FOR nA := 1 TO Len(hCustomer["artikel"])
            Aadd(hParamData["products"],{;
               "partno"=>hb_strToUtf8(Trim(hCustomer["artikel"][nA])),;
               "custpartno"=>IF(aku->(dbSeek( cKunde+hCustomer["artikel"][nA] )),hb_strToUtf8(Trim(aku->Artlief)),"");
            })
         NEXT

         //aMsg := {"Testlauf wird versendet an:"}
         
         /*
         API reference: https://developers.brevo.com/reference/
         */
         aPeople := hCustomer["people"]
         
         FOR nP := 1 TO Len(aPeople)
            IF ! HHasKey(HGetValueAt(aPeople,nP),"messageid")
               aPerson := HGetValueAt(aPeople,nP)
               
               // Validate email before adding to send list
               IF ! IsValidEmail(aPerson["email"])
                  @ 26,40 SAY "Invalid email: " + Left(aPerson["email"],20)
                  LOOP // Skip this recipient
               ENDIF

               // Skip blacklisted recipients (also catches loaded mailings)
               IF IsBlacklisted(aPerson["email"],"B")
                  @ 26,40 SAY "Blacklisted:   " + Left(Trim(aPerson["email"]),20)
                  LOOP // Skip this recipient
               ENDIF
               
               nCount++
               @ 26,16 SAY Str(nCount,10)
               //Aadd(aTo,{"name"=>aPeople[nP]["name"],"email"=>aPeople[nP]["email"]})         
               IF nChoice == 4
                  cEmail := aPerson["email"]
               ENDIF
               Aadd(aVersions,{;
                  "to"=>{{"name"=>IF(Empty(aPerson["name"]),hb_strToUtf8(hParamData["customer"]["name"]),hb_strToUtf8(aPerson["name"])),"email"=>cEmail}},;  //{"name"=>aPeople[nP]["name"],"email"=>aPeople[nP]["email"]}
                  "params"=>HB_HCopy(hParamData,{"person"=>{"salutation"=>hb_strToUtf8(aPerson["anrede"]),"name"=>hb_strToUtf8(aPerson["name"])}});
               })
               IF nCount >= nLimit
                  EXIT
               ENDIF
            ENDIF
         NEXT
         IF nCount >= nLimit
            EXIT
         ENDIF
      NEXT

      //Send Emails
      hData := {=>}
      hData["templateId"] := hResponse["templates"][nTemplate]["id"]
      hData["messageVersions"] := aVersions   
      IF nChoice == 1
         hData["headers"] := {"X-Sib-Sandbox"=>"drop"}
      ENDIF

      //gtSetClipboard(HB_JsonEncode(hData))

      hResult := oBrevo:Execute("smtp/email","POST",hData)
      IF ! HHasKey(hResult,"messageIds")         
         IF HHasKey(hResult,"message")
            Tr_MsgBox(hResult["message"],"Fehler beim Versenden der Emails")
            Alert(ValToPrg(hResult ))
            Alert(ValToPrg(hData))
         ELSE
            Tr_MsgBox("Fehler beim Versenden der Emails")
         ENDIF         
         //Alert(ValToPrg(hResult))
         RETURN   
      ENDIF
      IF nChoice == 4
         nCount := 0
         FOR nX := 1 TO Len(hPos)         
            hCustomer := HGetValueAt(hPos,nX)       
            FOR nP := 1 TO Len( hCustomer["people"])
               aPerson := HGetValueAt(hCustomer["people"],nP)
               IF ! HHasKey(aPerson,"messageid")
                  nCount++
                  aPerson["messageid"] := hResult["messageIds"][nCount]
                  IF nCount == Len(hResult["messageIds"])
                     EXIT
                  ENDIF
               ENDIF
            NEXT
            IF nCount == Len(hResult["messageIds"])
               EXIT
            ENDIF
         NEXT
      ENDIF

      MemoWrit(cFile,HB_JsonEncode(hSettings))
      Tr_MsgBox(LTrim(Str(Len(hResult["messageIds"])))+" Emails versendet")


      IF nChoice == 4
         EXIT
      ENDIF
   ENDDO

/*@ 27,00 SAY "Speichern..."
FOR EACH aCSV IN hData
   cLang := aCSV:__eNUmKey()
   cFile := Trim(Tr_Getini(1))+"\export\emails_"+IF(nType==1,Lower(CharRepl("*.\?:()|/\",Trim(cBegin)," __")),IF(nType==2,Trim(hManu[nManu]),Trim(cGroup)))+"_auftraege_"+cLang+".csv"
   DO WHILE (nH := Fopen(cFile,"W")) == 0 .AND. Tr_MsgBox("Datei kann nicht geîffnet werden",,{"wiederholen","abbrechen"}) != 2
   ENDDO
   IF nH != 0
      FClose(nH)     
      SaveAsCSV(cFile,aCSV)            
      WAPI_ShellExecute(NIL, "Open", cFile, "", "", 1)
   ENDIF   
NEXT
@ 27,14 SAY "abgeschlossen"
SET CURSOR ON

TR_MsgBox("Export abgeschlossen")*/

STATIC FUNCTION IsValidEmail(cEmail)
   LOCAL cPattern := "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"
   cEmail := Trim(cEmail)
   
   // Basic checks
   IF Empty(cEmail) .OR. AT("@", cEmail) == 0 .OR. AT(".", cEmail) == 0
      RETURN .F.
   ENDIF
   
   // More sophisticated validation using regex if available
   IF Type("HB_RegexMatch()") == "UI"
      RETURN HB_RegexMatch(cPattern, cEmail)
   ENDIF
   
   // Fallback: basic validation
   RETURN AT("@", cEmail) > 1 .AND. AT(".", cEmail) > AT("@", cEmail) + 1 .AND. Len(cEmail) - AT(".", cEmail) >= 2

STATIC Function __AddEntry(hPos,cKunde,cMatchcode,nPerson,hSettings,cMainMatch)
   LOCAL aPeople
   LOCAL cAnrede,cName,cEmail
   LOCAL nArtikelnr,nCount := 0
   LOCAL nArtRec := art->(Recno())
   LOCAL nPartRec := part->(Recno())
   //LOCAL lSub := .T.
   IF Empty(cMainMatch)
      cMainMatch := cMatchcode
      //lSub := .F.
   ENDIF
   IF Trim(cKunde) $ "" //"SELF TEST" 
      RETURN 0
   ENDIF
   ku->(dbSeek( cKunde+"K" ))
   IF ku->Language != hSettings:cLang
      RETURN 0
   ENDIF
   IF (hSettings:nType == 1 .AND. HB_RegexMatch(hSettings:cBegin,cMatchcode)) .OR. (hSettings:nType == 2 .AND. art->Manufactur == hSettings:nManu) .OR. (hSettings:nType == 3 .AND. art->Gruppe == hSettings:cGroup)               
      IF ! HHasKey(hPos,cKunde)
         hPos[cKunde] := {"kunde"=>cKunde,"artikel"=>{},"people"=>{=>}}
      ENDIF
      IF Ascan(hPos[cKunde]["artikel"],Trim(cMainMatch)) == 0
         Aadd(hPos[cKunde]["artikel"],Trim(cMainMatch))
      ENDIF
      IF ! hSettings:lAllContacts .OR. Len(hPos[cKunde]["people"]) == 0 //if we are adding all contact persons we only need to do it once         
         IF hSettings:lAllContacts .AND. Len(hPos[cKunde]["people"]) == 0
            aPeople := GetAddressContacts(.F.)[2]            
         ELSE
            aPeople := {nPerson}
         ENDIF
         conts->(dbSetOrder(2))
         FOR EACH nPerson IN aPeople               
            IF ! LTrim(Str(nPerson)) $ hPos[cKunde]["people"]
               IF conts->(dbSeek( Str(ku->Nummer,6)+Str(nPerson,4) )) .AND. conts->Anrede > 0
                  an->(dbGoto(conts->Anrede))
                  cAnrede := Trim(an->Anrede)+" "+Trim(conts->Name)
                  cName := Trim(conts->Name)
                  cEmail := Trim(conts->email)
               ELSEIF ! hSettings:lNoGeneral
                  cAnrede := IF(ku->Language=="D","Sehr geehrte Damen und Herren","Dear Sir or Madam")  
                  cName   := ""          
                  cEmail  := Trim(conts->email)               
               ELSE
                  cEmail := ""
               ENDIF
               IF ! Empty(cEmail) .AND. ! IsBlacklisted(cEmail,"B")
                  hPos[cKunde]["people"][LTrim(Str(nPerson))] := {"anrede"=>cAnrede,"name"=>cName,"email"=>cEmail,"nummer"=>nPerson}
                  nCount++
               ENDIF
            ENDIF
         NEXT
      ENDIF         
   ENDIF
   IF art->Bezug == 5      
      nArtikelnr := art->Artikelnr
      part->(dbSeek( Str(nArtikelnr,6) ))
      DO WHILE part->Listart == nArtikelnr
         art->(dbSeek( Str(part->Partart,6) ))
         nCount += __AddEntry(hPos,cKunde,art->Matchcode,nPerson,hSettings,cMainMatch)
         part->(dbSkip())
      ENDDO
      part->(dbGoto(nPartRec))
   ENDIF
   art->(dbGoto(nArtRec))
RETURN nCount



//----------------------------------------------------------------------------
// Blacklist the highlighted recipient from within the mailing browse and drop
// every recipient (across all customers) now matched by the blacklist.
//----------------------------------------------------------------------------
STATIC FUNCTION BlacklistFromBrowse(oBrowse,hPos)
   LOCAL hData, hPers, cEmail, nType, cReason, cValue, cKind, cScope

   IF oBrowse:CurrentDataRow() == NIL
      RETURN .T.
   ENDIF
   hData := hPos[oBrowse:CurrentDataRow()[1]]
   hPers := hData["people"][oBrowse:CurrentDataRow()[2]]

   IF HHasKey(hPers,"messageid")
      Tr_MsgBox("Email bereits versendet - kann nicht auf die Blacklist")
      RETURN .T.
   ENDIF
   cEmail := Lower(Trim(hPers["email"]))
   IF Empty(cEmail) .OR. AT("@",cEmail) == 0
      Tr_MsgBox("Keine gueltige Email-Adresse")
      RETURN .T.
   ENDIF

   nType := Tr_MsgBox("Auf die Blacklist setzen?",cEmail,{"Abbrechen","Email","Domain"})
   IF ! nType $ {2,3}
      RETURN .T.
   ENDIF
   IF nType == 3
      cValue := SubStr(cEmail,AT("@",cEmail)+1)
      cKind  := "D"
   ELSE
      cValue := cEmail
      cKind  := "E"
   ENDIF

   cReason := Trim(GetBox(Space(60),"Grund (optional)","@S60"))
   IF LastKey() == K_ESC
      RETURN .T.
   ENDIF
   cScope := AskBlacklistScope(cValue)
   IF Empty(cScope)
      RETURN .T.
   ENDIF
   IF ! AddToBlacklist(cValue,cKind,cReason,cScope)
      RETURN .T.
   ENDIF
RETURN PurgeBlacklisted(oBrowse,hPos)

STATIC FUNCTION PurgeBlacklisted(oBrowse,hPos)
   LOCAL nX, cKunde, cPersKey, hCustomer, hPers

   FOR nX := Len(oBrowse:aData) TO 1 STEP -1
      cKunde   := oBrowse:aData[nX][1]
      cPersKey := oBrowse:aData[nX][2]
      IF ! HHasKey(hPos,cKunde)
         LOOP
      ENDIF
      hCustomer := hPos[cKunde]
      IF ! HHasKey(hCustomer["people"],cPersKey)
         LOOP
      ENDIF
      hPers := hCustomer["people"][cPersKey]
      IF ! HHasKey(hPers,"messageid") .AND. IsBlacklisted(hPers["email"],"B")
         HB_HDel(hCustomer["people"],cPersKey,.T.)
         HB_ADel(oBrowse:aData,nX,.T.)
         IF Len(hCustomer["people"]) == 0
            HB_HDel(hPos,cKunde,.T.)
         ENDIF
      ENDIF
   NEXT

   IF Len(hPos) == 0 .OR. Len(oBrowse:aData) == 0
      RETURN .F.   // nothing left -> leave the browse
   ENDIF
   oBrowse:GoTop()
   oBrowse:Refresh := .T.
   oBrowse:RefreshAll()
RETURN .T.


#include 'x:\run\blacklist.prg'


#include 'x:\run\brevo.prg'
