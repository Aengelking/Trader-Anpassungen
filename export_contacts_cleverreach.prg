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

STATIC s_hBlackEmail
STATIC s_hBlackDomain

PROCEDURE RUN_Export_Contacts_Cleverreach

LOCAL getlist := {}
LOCAL lMuster := .T.
LOCAL lAngebot := .T.
LOCAL lAuftrag := .T.

LOCAL hPos,cFile,nX,cKunde,nP,nZ

LOCAL lAllContacts := .T.
LOCAL lNoGeneral := .T.,aPeople

LOCAL aRec,cString

LOCAL hData := {=>},nCount,cAnrede,cEmail,cName
LOCAL cLang,aCSV,nH

LOCAL cStart := "20210101"
LOCAL dStart := StoD(cStart)
LOCAL cWeek  := CalWeek(dStart)
LOCAL nPerson
LOCAL hTurnOver
LOCAL hBranchen := GetBranchen()

Head("Ansprechpartner mit Email Adressen exportieren")

/*@ 06,00 SAY "Muster"
@ 06,27 GET lMuster CHECKBOX
@ 07,00 SAY "Angebote"
@ 07,27 GET lAngebot CHECKBOX
@ 08,00 SAY t("Auftr‰ge")
@ 08,27 GET lAuftrag CHECKBOX
@ 09,00 SAY "Alle Kontakte"
@ 09,27 GET lAllContacts CHECKBOX*/
//@ 10,00 SAY "Allgemeine ausschlie·en"
//@ 10,27 GET lNoGeneral CHECKBOX
/*READ
IF LastKey() == 27
   RETURN
ENDIF*/

IF Tr_MsgBox("Export starten?",,{"Nein","Ja"}) != 2   
   RETURN
ENDIF

hPos := {=>}

NetUse("engauf","auf",.F.,0)
auf->(dbSetOrder( 10 ))

NetUse("lagerne","lne",.F.,0)

NetUse("artkund","aku")

NetUse("engkund","ku",.F.,0)
ku->(dbSetOrder( 1 ))
NetUse("artikel","art")
art->(dbSetOrder( 2 ))
NetUse("angebot","ang")
NetUse("contacts","conts")
NetUse("anrede","an")   
NetUse("manufact","manu")   
NetUse("groupmain","grm")
NetUse("plzbl","plzbl")
NetUse( "bundesl" , "bl" )
NetUse("parts","part")


SET CURSOR OFF

nCount := 0
IF lAuftrag
   auf->(dbSetFilter({|| auf->VkPr != 0 },"VkPr != 0"))
   auf->(dbSeek( cWeek ))
   @ 23,00 SAY "Auftrag"
   Do While ! auf->(EOF()) .AND. auf->DTERM >= Val(cWeek) .AND. Left(Str(auf->Dterm,4),2) <= "52"
      nCount++

      art->(dbSeek( Str(auf->Artikelnr,6) ))

      @ 23,14 SAY Str(auf->Abnr,6)+" ("+LTrim(Str(nCount))+")"
      //__AddEntry(hPos,"order",CalWD(auf->Dterm),auf->Kundma,auf->person)
      __AddEntry(hPos,"order",auf->Besda,auf->Kundma,auf->person)

      auf->(dbSkip())
   Enddo
   auf->(dbClearFilter())
ENDIF


IF lMuster
   nCount := 0
   @ 24,00 SAY "Musterauftrag"
   lne->(dbSetFilter({|| lne->Versand .AND. lne->Datum >= dStart .AND. lne->Gruppe == "K"},"Versand .AND. Datum >= StoD('"+cStart+"') .AND. Gruppe == 'K'"))
   lne->(dbGoTop())
   Do While ! lne->(Eof())
      art->(dbSeek( Str(lne->Artikelnr,6) ))
      
      nCount++
      @ 24,14 SAY Str(lne->Nummer,6)+" ("+LTrim(Str(nCount))+")"
   	__AddEntry(hPos,"sample",lne->Datum,lne->Kunde,lne->Person)
   	
   	lne->(dbSkip())
   Enddo
   lne->(dbClearFilter())
ENDIF

IF lAngebot
   nCount := 0
   @ 25,00 SAY "Angebote"
   ang->(dbSetFilter({|| ang->Besda >= dStart },"Besda >= StoD('"+cStart+"')"))   
   ang->(dbGoTop())
   
   Do While ! ang->(Eof())
      
      art->(dbSeek( Str(ang->Artikelnr,6) ))
      
      
      nCount++
      @ 25,14 SAY Str(ang->Angnr,6)+" ("+LTrim(Str(nCount))+")"
      IF ang->Angnr == 39533
         //Sinkey(0)
      ENDIF
      __AddEntry(hPos,"quote",ang->Besda,ang->Kundma,ang->Person)
   	
   	ang->(dbSkip())
   Enddo
   ang->(dbClearFilter())
ENDIF

@ 26,00 SAY "Exportiere"
@ 26,21 SAY "/"+LTrim(Str(Len(hPos)))

cLang := "D"
hData[cLang] := {}
Aadd(hData[cLang],{"Anrede","Name","Email"})
Aadd(hData[cLang][1],"Matchcode")
Aadd(hData[cLang][1],"Firma")
Aadd(hData[cLang][1],"Stra·e")
Aadd(hData[cLang][1],"PLZ")
Aadd(hData[cLang][1],"Stadt")
Aadd(hData[cLang][1],"Bundesland")
Aadd(hData[cLang][1],"Land")

Aadd(hData[cLang][1],"Branche")

Aadd(hData[cLang][1],"Letzte Bestellung")
Aadd(hData[cLang][1],"Letztes Muster")
Aadd(hData[cLang][1],"Letztes Angebot")

Aadd(hData[cLang][1],"Letzte persînliche Bestellung")
Aadd(hData[cLang][1],"Letztes persînliches Muster")
Aadd(hData[cLang][1],"Letztes persînliches Angebot")

Aadd(hData[cLang][1],"Umsatz "+Str(Year(Date()),4))
Aadd(hData[cLang][1],"Umsatz "+Str(Year(Date())-1,4))

Aadd(hData[cLang][1],"Allgemeine Adresse")

Aadd(hData[cLang][1],"Hersteller")
Aadd(hData[cLang][1],"Produktgruppen")
Aadd(hData[cLang][1],"Artikel")



aku->(dbSetOrder( 3 ))
nX := 1
Do While nX <= Len(hPos)
   @ 26,11 SAY Str(nX,10)
   cKunde := HGetKeyAt(hPos,nX)   
   If ! Trim(cKunde) $ "SELF TEST"      
      hTurnOver := GetCustomerTurnOver(cKunde)
		ku->(dbSeek( cKunde+"K" ))
      /*nP := 1
      IF lAllContacts
         aPeople := GetAddressContacts(.F.)[2]
      ELSE
         aPeople := {}
         FOR EACH nPerson IN GetAddressContacts(.T.)[2]
            IF nPerson $ HGetKeys(hPos[cKunde]["people"])
               Aadd(aPeople,nPerson)
            ENDIF
         NEXT
         //aPeople := 
      ENDIF*/
      conts->(dbSetOrder(2))
      conts->(dbSeek( Str(ku->Nummer,6) ))
      //Do While nP <= Len(aPeople)
      DO WHILE conts->Address == ku->Nummer .AND. ! conts->(EOF())
         //IF aPeople[nP] != 0 .OR. Len(aPeople) == 1
         IF lAllContacts .OR. conts->Number $ hPos[cKunde]["people"]           
            cLang := ku->Language

            IF /*conts->(dbSeek( Str(ku->Nummer,6)+Str(aPeople[nP],4) )) .AND.*/ conts->Anrede > 0
               an->(dbGoto(conts->Anrede))               
               cAnrede := Trim(an->Anrede)
               cName := Trim(conts->Name)
               cEmail := Trim(conts->email)

               IF cLang != "E" .AND. conts->Anrede == 3
                  cLang := "E"
               ELSEIF cLang == "E" .AND. conts->Anrede != 3
                  cLang := "D"
               ENDIF               
            ELSEIF lNoGeneral
               /*nP++
               IF nP > Len(aPeople)
                  EXIT
               ENDIF
               LOOP*/
               cEmail := "" //this will cause it to jump to the next record
            ELSE
               cAnrede := IF(ku->Language=="D","Sehr geehrte Damen und Herren","Dear Sir or Madam")  
               cName   := ""          
               cEmail  := Trim(conts->email)               
            ENDIF
            IF ! conts->Active
               cLang := "INAKTIV"
            ENDIF
			
				IF ! Empty(cEmail) .AND. ! IsBlacklisted(cEmail,"C")

               
               aRec := {cAnrede,cName,cEmail}
               
               AAdd(aRec,Trim(ku->Kunde))
               AAdd(aRec,Trim(Trim(ku->Name1)+" "+ku->Name2))
               AAdd(aRec,Trim(ku->Street))
               AAdd(aRec,Trim(ku->Plz))
               AAdd(aRec,Trim(ku->Town))
               IF ku->CountryIso == "DE" .AND. plzbl->( dbSeek( StrZero( Val( StrTran( ku->PLZ, "D-" ) ), 5 ) ) ) .AND. bl->( dbSeek( plzbl->BL ) )
                  AAdd(aRec,Trim(bl->Short))
               ELSE
                  Aadd(aRec,"")
               ENDIF
               AAdd(aRec,Trim(GetCountryname(ku->CountryIso)))
               
               IF HHasKey(hBranchen,Trim(ku->Branch))
                  Aadd(aRec,Trim(hBranchen[ku->Branch]))
               ELSE
                  Aadd(aRec,"")
               ENDIF

               Aadd(aRec,IF(Empty(hPos[cKunde]["lastorder"]),"",DToC(hPos[cKunde]["lastorder"])))
               Aadd(aRec,IF(Empty(hPos[cKunde]["lastsample"]),"",DToC(hPos[cKunde]["lastsample"])))
               Aadd(aRec,IF(Empty(hPos[cKunde]["lastquote"]),"",DToC(hPos[cKunde]["lastquote"])))

               IF HHasKey(hPos[cKunde]["people"],conts->Number) //HHasKey(hPos[cKunde]["people"],aPeople[nP])
                  /*Aadd(aRec,"") //DToC(hPos[cKunde]["people"][aPeople[nP]]["lastorder"]))
                  Aadd(aRec,"") //DToC(hPos[cKunde]["people"][aPeople[nP]]["lastsample"]))
                  Aadd(aRec,"") //DToC(hPos[cKunde]["people"][aPeople[nP]]["lastquote"]))*/
                  Aadd(aRec,DToC(hPos[cKunde]["people"][conts->Number]["lastorder"]))
                  Aadd(aRec,DToC(hPos[cKunde]["people"][conts->Number]["lastsample"]))
                  Aadd(aRec,DToC(hPos[cKunde]["people"][conts->Number]["lastquote"]))
               ELSE
                  FOR nZ := 1 To 3
                     Aadd(aRec,DtoC(StoD("")))
                  NEXT                  
               ENDIF
               
               Aadd(aRec,hTurnover["current"])
               Aadd(aRec,hTurnover["last"])          
               
               Aadd(aRec,IF(conts->Anrede==0,"Ja","Nein"))

               cString := ""
               AEval(hPos[cKunde]["manufacturers"],{|cManu|                   
                  cString+="|"+Trim(cManu)
                  RETURN .T.
               })
               cString += "|"
               Aadd(aRec,cString)

               cString := ""
               AEval(hPos[cKunde]["groups"],{|cGroup|                   
                  cString+="|"+Trim(cGroup)
                  RETURN .T.
               })
               cString += "|"
               Aadd(aRec,cString)

               cString := ""
               AEval(hPos[cKunde]["artikel"],{|cArt|                   
                  cString+="|"+Trim(cArt)
                  RETURN .T.
               })
               cString += "|"
               Aadd(aRec,cString)

                  /*
                  ASort(hPos[cKunde]["artikel"])
                  Do While nA <= Len(hPos[cKunde]["artikel"])
                     ?? Chr(59)+Trim(hPos[cKunde]["artikel"][nA])+Chr(59)
                     IF aku->(dbSeek( cKunde+hPos[cKunde]["artikel"][nA] ))
                     ?? aku->Artlief
                     ENDIF
      //					?? Chr(59) //+Chr(59)
                     nA++
                  Enddo*/
               IF ! HHasKey(hData,cLang)
                  hData[cLang] := {AClone(hData["D"][1])} //create header for this language
               ENDIF
   
               Aadd(hData[cLang],aRec)
               
            ENDIF
			ENDIF
			//nP++
         conts->(dbSkip())
		Enddo
	Endif
	nX++
Enddo

//SET PRINTER TO
//SET PRINTER OFF
@ 27,00 SAY "Speichern..."
FOR EACH aCSV IN hData
   cLang := aCSV:__eNUmKey()
   cFile := Trim(Tr_Getini(1))+"\export\cleverreach_"+cLang+".csv"
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

TR_MsgBox("Export abgeschlossen")

IF Tr_MsgBox("Adressen jetzt direkt zu CleverReach senden (API)?",,{"Nein","Ja"}) == 2
   CleverReachPush(hData)
ENDIF

STATIC Function __AddEntry(hPos,cType,dDate,cKunde,nPerson)
   LOCAL cGroup

   IF ! HHasKey(hPos,cKunde)
      hPos[cKunde] := {"kunde"=>cKunde,"artikel"=>{},"groups"=>{},"people"=>{=>},"manufacturers"=>{},"groups"=>{},"lastorder"=>StoD(""),"lastsample"=>StoD(""),"lastquote"=>StoD("")}
   ENDIF
   
   hPos[cKunde]["last"+cType] := Max(hPos[cKunde]["last"+cType],dDate)

   IF Ascan(hPos[cKunde]["artikel"],art->Matchcode) == 0
      Aadd(hPos[cKunde]["artikel"],art->Matchcode)
   ENDIF

   grm->(dbSeek(Left(art->Gruppe,2)))
   cGroup := Trim(grm->Name)
   IF AScan(hPos[cKunde]["groups"],cGroup) == 0
      Aadd(hPos[cKunde]["groups"],cGroup)
   ENDIF
   

   IF ! HHasKey(hPos[cKunde]["people"],nPerson) 
      hPos[cKunde]["people"][nPerson] := {"lastorder"=>StoD(""),"lastsample"=>StoD(""),"lastquote"=>StoD("")}
   ENDIF
   hPos[cKunde]["people"][nPerson]["last"+cType] := Max(hPos[cKunde]["last"+cType],dDate)

   manu->(dbSeek( Str(art->Manufactur,5) ))
   IF Ascan(hPos[cKunde]["manufacturers"],manu->Short) == 0
      Aadd(hPos[cKunde]["manufacturers"],manu->Short)
   ENDIF

   /*IF art->Bezug == 5 //Fertigungsartikel
      part->(dbSeek( Str(art->Artikelnr,6) ))
      DO WHILE part->Partart == art->Artikelnr

   ENDIF*/
RETURN NIL



//----------------------------------------------------------------------------
// Push the collected buckets to CleverReach via the REST API.
//   hData["D"] / ["E"]  -> upsert as ACTIVE receivers into the DE / EN group
//   hData["INAKTIV"]    -> upsert as INACTIVE (deactivate) in both groups
// Blacklisted contacts were already dropped during collection (channel "C").
//----------------------------------------------------------------------------
STATIC FUNCTION CleverReachPush(hData)
   LOCAL cToken, nDE, nEN, cErr := ""

   cToken := CR_EnsureToken()
   IF Empty(cToken)
      Tr_MsgBox("Keine Verbindung zu CleverReach")
      RETURN .F.
   ENDIF

   nDE := CleverReachFindGroupId(cToken,"Engelking Kundenstamm DE")
   nEN := CleverReachFindGroupId(cToken,"Engelking Kundenstamm EN")
   IF Empty(nDE) .OR. Empty(nEN)
      Tr_MsgBox("CleverReach Empfaengergruppe(n) nicht gefunden - abgebrochen")
      RETURN .F.
   ENDIF

   @ 26,00 SAY "CleverReach: sende Adressen..."

   IF HHasKey(hData,"D") .AND. ! CR_PushBucket(cToken,nDE,hData["D"],.T.,@cErr)
      Tr_MsgBox("Fehler beim Senden (DE): "+cErr)
      RETURN .F.
   ENDIF
   IF HHasKey(hData,"E") .AND. ! CR_PushBucket(cToken,nEN,hData["E"],.T.,@cErr)
      Tr_MsgBox("Fehler beim Senden (EN): "+cErr)
      RETURN .F.
   ENDIF
   // Inactive contacts: deactivate in both language groups (see documentation)
   IF HHasKey(hData,"INAKTIV")
      CR_PushBucket(cToken,nDE,hData["INAKTIV"],.F.,@cErr)
      CR_PushBucket(cToken,nEN,hData["INAKTIV"],.F.,@cErr)
   ENDIF

   Tr_MsgBox("CleverReach Sync abgeschlossen")
RETURN .T.

// Upsert one bucket (batched). aBucket[1] is the header row, data from row 2.
STATIC FUNCTION CR_PushBucket(cToken,nGroupId,aBucket,lActive,cError)
   LOCAL aHeader, aReceivers := {}, nI, lOk := .T.
   cError := ""
   IF Empty(aBucket) .OR. Len(aBucket) < 2
      RETURN .T.
   ENDIF
   aHeader := aBucket[1]
   FOR nI := 2 TO Len(aBucket)
      IF Len(aBucket[nI]) >= 3 .AND. CR_ValidEmail(aBucket[nI][3])   // valid email required
         Aadd(aReceivers,CR_BuildReceiverFromRow(aHeader,aBucket[nI],lActive))
      ENDIF
      IF Len(aReceivers) >= 100
         lOk := CleverReachUpsert(cToken,nGroupId,aReceivers,@cError)
         IF ! lOk
            RETURN .F.
         ENDIF
         aReceivers := {}
      ENDIF
   NEXT
   IF Len(aReceivers) > 0
      lOk := CleverReachUpsert(cToken,nGroupId,aReceivers,@cError)
   ENDIF
RETURN lOk

// Map one export row (columns 1..23) onto a CleverReach receiver.
// Column order is fixed by the export header (see hData["D"][1]).
STATIC FUNCTION CR_BuildReceiverFromRow(aHeader,aRow,lActive)
   LOCAL hGlobal := {=>}, hAttr := {=>}, nI, cKey, xVal
   LOCAL cEmail := Trim(aRow[3])

   hGlobal["salutation"] := hb_strToUtf8(Trim(aRow[1]))
   hGlobal["lastname"]   := hb_strToUtf8(Trim(aRow[2]))
   hGlobal["company"]    := hb_strToUtf8(Trim(aRow[5]))
   hGlobal["street"]     := hb_strToUtf8(Trim(aRow[6]))
   hGlobal["zip"]        := Trim(aRow[7])
   hGlobal["city"]       := hb_strToUtf8(Trim(aRow[8]))
   hGlobal["state"]      := hb_strToUtf8(Trim(aRow[9]))
   hGlobal["country"]    := hb_strToUtf8(Trim(aRow[10]))

   // Custom attributes: columns 11.. keyed by a sanitized header name.
   // NOTE: these keys must match the attribute tags configured on the
   // CleverReach group; adjust CR_AttrKey() if your tags differ.
   FOR nI := 11 TO Len(aHeader)
      IF nI > Len(aRow)
         EXIT
      ENDIF
      cKey := CR_AttrKey(aHeader[nI])
      IF ! Empty(cKey)
         xVal := aRow[nI]
         DO CASE
         CASE ValType(xVal) == "N"
            xVal := AllTrim(Str(xVal))
         CASE ValType(xVal) == "D"
            xVal := DToC(xVal)
         CASE ValType(xVal) != "C"
            xVal := ""
         ENDCASE
         hAttr[cKey] := hb_strToUtf8(Trim(xVal))
      ENDIF
   NEXT
RETURN CleverReachReceiver(cEmail,hGlobal,hAttr,lActive)

// Turn a header label into a CleverReach attribute key (lowercase, ascii, _).
STATIC FUNCTION CR_AttrKey(cName)
   LOCAL c := Lower(AllTrim(cName)), cOut := "", nI, ch
   c := StrTran(c,"Ñ","ae")
   c := StrTran(c,"î","oe")
   c := StrTran(c,"Å","ue")
   c := StrTran(c,"·","ss")
   FOR nI := 1 TO Len(c)
      ch := SubStr(c,nI,1)
      IF (ch >= "a" .AND. ch <= "z") .OR. (ch >= "0" .AND. ch <= "9")
         cOut += ch
      ELSEIF ch $ " -/"
         cOut += "_"
      ENDIF
   NEXT
   DO WHILE "__" $ cOut
      cOut := StrTran(cOut,"__","_")
   ENDDO
RETURN cOut


#include 'x:\run\blacklist.prg'
#include 'x:\run\cleverreach_api.prg'
