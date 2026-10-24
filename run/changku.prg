PROCEDURE RUN_CHANGKU
   LOCAL aFiles,hLiefAd,hContacts,cField,hNewContacts,nLief
   LOCAL cKunde1,cKunde2,nKunde1,nKunde2,nContact,lYes,nI,nNumber
   LOCAL getlist := {}
   LOCAL oBrowse
   LOCAL oRec,oNewRec,nX,bField,xData

   MEMVAR c_one

   Head("Kundenadressen verschmelzen")

   IF Tr_GetIni(28) != 9
      Tr_MsgBox("Zugang verweigert")
      RETURN
   ENDIF

   NetUse( "ENGKUND", "ku" )
   NetUse( "CONTACTS", "conts" )

   NetUse( "ANGEBOT", "ang")
   NetUse( "ENRAS"  , "ras")
   NetUse( "ENGAUF" , "auf")
   NetUSe( "AUFTRAG", "ab" )
   NetUse( "ENGLSRE", "re" )
   NetUSe( "Rechnung","reh")
   NetUse( "ARTKUND", "aku")
   NetUse( "ENGBEW" , "bew")
   NetUse( "ENGABG" , "abg")
   NetUse( "LAGERNE", "lne")
   NetUse( "MUSTER",  "mus")
   NetUse( "QS"     , "qs")
   NetUse( "rma"     , "rma")

   //1==Kundma,2==Kunde
   //"ORDER"=>,"SEEK"=>{|| cKunde1 },"FIELDS"=>{"NUMMER"=>,"MATCH"=>"KUNDMA","PERSON"=>}
   //"ORDER"=>,"SEEK"=>{|| cKunde1 },"FIELDS"=>{"NUMMER"=>,"MATCH"=>"KUNDE","PERSON"=>}

   aFiles := { ;
      { "ALIAS"=>"ang", "ORDER"=>2,"SEEK"=>{|| cKunde1 },"FIELDS"=>{"MATCH"=>"KUNDMA","PERSON"=>"PERSON"} },;
      { "ALIAS"=>"ras", "ORDER"=>1,"SEEK"=>{|| cKunde1 },"FIELDS"=>{"MATCH"=>"KUNDE"} },;
      { "ALIAS"=>"auf", "ORDER"=>2,"SEEK"=>{|| cKunde1 },"FIELDS"=>{"MATCH"=>"KUNDMA","PERSON"=>"PERSON","LIEFAD"=>"DELAD"}},;
      { "ALIAS"=>"ab" , "ORDER"=>2,"SEEK"=>{|| cKunde1 },"FIELDS"=>{"MATCH"=>"KUNDMA","PERSON"=>"PERSON","LIEFAD"=>"DELAD"}},;
      { "ALIAS"=>"re" , "ORDER"=>1,"SEEK"=>{|| cKunde1 },"FIELDS"=>{"MATCH"=>"KUNDE","LIEFAD"=>"DELAD"}},;
      { "ALIAS"=>"reh" , "ORDER"=>1,"SEEK"=>{|| cKunde1 },"FIELDS"=>{"MATCH"=>"KUNDE","LIEFAD"=>"DELAD"}},;
      { "ALIAS"=>"aku", "ORDER"=>1,"SEEK"=>{|| cKunde1 },"FIELDS"=>{"MATCH"=>"KUNDE"}} ,;
      { "ALIAS"=>"bew", "ORDER"=>1,"SEEK"=>{|| Str(nKunde1,6) },"FIELDS"=>{"NUMMER"=>"KUNDENNR","MATCH"=>"LIEFMA"}},;
      { "ALIAS"=>"abg", "ORDER"=>4,"SEEK"=>{|| cKunde1+"K" },"FIELDS"=>{"NUMMER"=>"KUNDENNR","MATCH"=>"LIEFMA"} },;
      { "ALIAS"=>"lne", "ORDER"=>5,"SEEK"=>{|| cKunde1+"K" },"FIELDS"=>{"MATCH"=>"KUNDE","PERSON"=>"PERSON"} },;
      { "ALIAS"=>"mus", "ORDER"=>5,"SEEK"=>{|| cKunde1 },"FIELDS"=>{"MATCH"=>"KUNDE","PERSON"=>"PERSON"}}, ;
      { "ALIAS"=>"QS" , "ORDER"=>3,"SEEK"=>{|| cKunde1 },"FIELDS"=>{"MATCH"=>"kunde"}},;
      { "ALIAS"=>"rma" , "ORDER"=>1,"SEEK"=>{|| Str(nKunde1,6) },"FIELDS"=>{"NUMMER"=>"KUNDE"}};
   }

   Do While ! LastKey() == 27
      cKunde1 := Space(8)
      cKunde2 := Space(8)
      hLiefAd := {=>}
      hContacts := {=>}

      @ 02,00 SAY "Kunde 1 " GET cKunde1 PICTURE "@!"
      @ 03,00 SAY "Kunde 2 " GET cKunde2 PICTURE "@!"
      @ 03,20 SAY "<-- endgltiger Matchcode"
      READ
      If ku->(dbSeek(cKunde1+"K"))
         nKunde1 := ku->Nummer
         @ 04,00 SAY ku->Name1
         @ 05,00 SAY ku->Name2
         @ 06,00 SAY ku->Street
         @ 07,00 SAY ku->PLZ+" "+ku->Town
         @ 08,00 SAY GetCountryName(ku->CountryIso)
         @ 09,00 SAY ku->Telefon
         @ 10,00 SAY ku->Telefax
         @ 11,00 SAY ku->Turnover
         @ 12,00 SAY ku->Turnoverol
         @ 13,00 SAY ku->Compno

         If ku->(dbSeek(cKunde2+"K"))
            nKunde2 := ku->Nummer
            hNewContacts := GetAddressContacts(.T.,.T.)
            @ 04,35 SAY ku->Name1
            @ 05,35 SAY ku->Name2
            @ 06,35 SAY ku->StrEET
            @ 07,35 SAY ku->PLZ+" "+ku->Town
            @ 08,35 SAY GetCountryName(ku->CountryIso)
            @ 09,35 SAY ku->Telefon
            @ 10,35 SAY ku->Telefax
            @ 11,35 SAY ku->Turnover
            @ 12,35 SAY ku->Turnoverol
            @ 13,35 SAY ku->Compno

            IF conts->(dbSeek( Str(nKunde1,6),.T. ))
               @ 14,00 SAY "Kontaktpersonen zuordnen (nicht zugeordnete werden neu angelegt)"
               oBrowse := conts->(TBrowseTr():New(15,00,23,54))
               oBrowse:NewColumn( Nil, {|| Pad(conts->Name,25)+" -> "+Pad(IF(HHasKey(hContacts,conts->Number),hNewContacts[hContacts[conts->Number]]["name"],""),25) } )
               oBrowse:lBox := .F.
               oBrowse:WhileBlock := {|| conts->address == nKunde1}
               oBrowse:ColorSpec := c_one //"W/B+,N+/B+,,N/W,N+/W"
               oBrowse:AddKey(27,{|| .F. })
               oBrowse:AddKey(13,{||
                  LOCAL cScreen := SaveScreen()
                  nContact := IF(HHasKey(hContacts,conts->Number),hContacts[conts->Number],0)
                  GET_Contact(getlist,14+oBrowse:rowPos,29,{|v| If(v==NIL,nContact,nContact:=v)},.F.)
                  READ
                  IF LastKey() != 27
                     IF nContact != 0
                        hContacts[conts->Number] := nContact
                     ELSEIF HHasKey(hContacts,conts->Number)
                        HDel(hContacts,conts->Number)
                     ENDIF
                  ENDIF
                  RestScreen(,,,,cScreen)
                  RETURN .T.
               })
               oBrowse:EventLoop()
            ENDIF

            lYes := .F.
            @ 16,00 SAY "Wirklich verschmelzen" GET lYes PICTURE "Y"
            READ
            If lYes
               nLief := 0
               @ 24,00 SAY "Lieferadressen"
               // Lieferantenadressen
               FOR nI := 1 TO  9
                  @ 24,30 SAY nI
                  If ku->( dbSeek( cKunde2+Transform( nI,"9") ))
                     nLief := nI
                  Endif
               NEXT
               FOR nI := 1 TO 9
   //               @ 24,30 SAY nI
                  If ku->( dbSeek( cKunde1+Transform( nI,"9") ))
                     nLief++
                     hLiefAd[nI] := nLief
                     ? nI,"=>",nLief
                     ku->(Rec_Lock(0))
                     ku->Kunde := cKunde2
                     ku->Group := Str(nLief,1)
                     ku->(dbUnLock())
                  Endif
               Next
   //            Inkey(0,128)
               @ 24,00 CLEAR
               @ 24,00 SAY "Kontaktpersonen"
               conts->(dbSeek( Str(nKunde2,6),.T. ))
               nNumber := 1
               while conts->Address == nKunde2
                  nNumber := Max(nNumber,conts->Number)
                  conts->(dbSkip())
               enddo

               conts->(dbSeek( Str(nKunde1,6),.T. ))
               DO WHILE conts->address == nKunde1
                  IF ! HHasKey(hContacts,conts->Number)
                     nNumber++

                     oRec := conts->(Record():New(.F.))
                     oNewRec := conts->(Record():New(.T.))
                     oNewRec:Copy(oRec)
                     oNewRec:Number := nNumber
                     oNewRec:Address := nKunde2

                     hContacts[conts->Number] := nNumber
                     oNewRec:Save()
                  ENDIF
                  conts->(dbSkip())
               ENDDO
               FOR nI := 1 TO LEN( aFiles )
                  @ 24,00 SAY nI
                  dbSelectArea(aFiles[nI]:Alias)
                  dbSetOrder(aFiles[nI]:Order)
                  nX := 0
                  Do While (aFiles[nI]:Alias)->(dbSeek( Eval(aFiles[nI]:Seek) ))
                     nX++
                     @ 24,05 SAY nX
                     @ 25,00 ClEAR
                     (aFiles[nI]:Alias)->(Rec_Lock(0))
                     ? aFiles[nI]:Alias,":"
                     FOR EACH cField in aFiles[nI]["FIELDS"]
                        bField := FieldWBlock(cField,Select(aFiles[nI]:Alias))
                        ? cField,Eval(bField)
                        SWITCH cField:__eNumKey()
                           CASE "MATCH"
                              xData := cKunde2
                              EXIT
                           CASE "NUMMER"
                              xData := nKunde2
                              EXIT
                           CASE "PERSON"
                              IF Eval(bField) == 0
                                 xData := 0
                              ELSE
                                 xData := hContacts[ Eval(bField) ]
                              ENDIF
                              EXIT
                           CASE "LIEFAD"
                              IF Eval(bField) != 0
                                 IF ! HHasKey(hLiefAd,Eval(bField))
                                    Tr_MsgBox("Liefadresse "+Eval(bField)+" nicht gefunden")
                                 ELSE
                                    xData := hLiefAd[ Eval(bField) ]
                                 ENDIF
                              ELSE
                                 xData := 0
                              ENDIF
                              EXIT
                           OTHERWISE
                              LOOP
                        END
                        ?? xData
                        Eval(bField,xData)
                     NEXT

                     (aFiles[nI]:Alias)->(dbUnLock())
                  ENDDO
                  nI := nI+1

               NEXT
               IF ! ku->(dbSeek(cKunde1+"K"))
                  Alert("Kunde nicht gefunden!")
                  LOOP
               ENDIF
               ku->(Rec_Lock(0))
               //ku->(dbDelete())  //we do not delete it anymore - just mark as not used
               ku->KSperren := "Y"
               ku->Name1 := "[SIEHE:"+LTrim(Str(nKunde2))+"]"+ku->Name1
               ku->(dbUnLock())
               /*conts->(dbSeek( Str(nKunde1,6),.T. ))
               while conts->Address == nKunde1
                  conts->(Rec_Lock())
                  conts->(dbDelete())
                  conts->(dbUnlock())
                  conts->(dbSkip())
               enddo*/

               @ 30,00 SAY cKunde1+"-->"+cKunde2+" abgeschlossen"
            Endif
         Else
            @ 24,00 SAY "Kunde nicht gefunden "+cKunde2
         Endif
      Else
      @ 24,00 SAY "Kunde nicht gefunden "+cKunde1
      Endif
   Enddo
RETURN