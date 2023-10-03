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

Head("Ansprechpartner mit Email Adressen exportieren")

@ 06,00 SAY "Muster"
@ 06,27 GET lMuster CHECKBOX
@ 07,00 SAY "Angebote"
@ 07,27 GET lAngebot CHECKBOX
@ 08,00 SAY t("Auftr‰ge")
@ 08,27 GET lAuftrag CHECKBOX
@ 09,00 SAY "Alle Kontakte"
@ 09,27 GET lAllContacts CHECKBOX
@ 10,00 SAY "Allgemeine ausschlie·en"
@ 10,27 GET lNoGeneral CHECKBOX
READ


IF LastKey() == 27
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
      __AddEntry(hPos,"order",CalWD(auf->Dterm),auf->Kundma,auf->person)

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
Aadd(hData[cLang][1],"Land")

Aadd(hData[cLang][1],"Letzte Bestellung")
Aadd(hData[cLang][1],"Letztes Muster")
Aadd(hData[cLang][1],"Letztes Angebot")

Aadd(hData[cLang][1],"Letzte persînliche Bestellung")
Aadd(hData[cLang][1],"Letztes persînliches Muster")
Aadd(hData[cLang][1],"Letztes persînliches Angebot")

Aadd(hData[cLang][1],"Hersteller")
Aadd(hData[cLang][1],"Artikel")

aku->(dbSetOrder( 3 ))
nX := 1
Do While nX <= Len(hPos)
   @ 26,11 SAY Str(nX,10)
   cKunde := HGetKeyAt(hPos,nX)
   If ! Trim(cKunde) $ "SELF TEST"      
		ku->(dbSeek( cKunde+"K" ))
      nP := 1
      IF lAllContacts
         aPeople := GetAddressContacts(.F.)[2]
      ELSE
         aPeople := HGetKeys(hPos[cKunde]["people"])
      ENDIF
      conts->(dbSetOrder(2))
      Do While nP <= Len(aPeople)
         IF aPeople[nP] != 0 .OR. Len(aPeople) == 1
            
            cLang := ku->Language

            IF conts->(dbSeek( Str(ku->Nummer,6)+Str(aPeople[nP],4) )) .AND. conts->Anrede > 0
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
               nP++
               IF nP > Len(aPeople)
                  EXIT
               ENDIF
               LOOP
            ELSE
               cAnrede := IF(ku->Language=="D","Sehr geehrte Damen und Herren","Dear Sir or Madam")  
               cName   := ""          
               cEmail  := Trim(conts->email)               
            ENDIF
			
				IF ! Empty(cEmail)

               
               aRec := {cAnrede,cName,cEmail}
               
               AAdd(aRec,Trim(ku->Kunde))
               AAdd(aRec,Trim(Trim(ku->Name1)+" "+ku->Name2))
               AAdd(aRec,Trim(ku->Street))
               AAdd(aRec,Trim(ku->Plz))
               AAdd(aRec,Trim(ku->Town))
               AAdd(aRec,Trim(GetCountryname(ku->CountryIso)))
               Aadd(aRec,IF(Empty(hPos[cKunde]["lastorder"]),"",DToC(hPos[cKunde]["lastorder"])))
               Aadd(aRec,IF(Empty(hPos[cKunde]["lastsample"]),"",DToC(hPos[cKunde]["lastsample"])))
               Aadd(aRec,IF(Empty(hPos[cKunde]["lastquote"]),"",DToC(hPos[cKunde]["lastquote"])))

               IF HHasKey(hPos[cKunde]["people"],aPeople[nP])
                  Aadd(aRec,"") //DToC(hPos[cKunde]["people"][aPeople[nP]]["lastorder"]))
                  Aadd(aRec,"") //DToC(hPos[cKunde]["people"][aPeople[nP]]["lastsample"]))
                  Aadd(aRec,"") //DToC(hPos[cKunde]["people"][aPeople[nP]]["lastquote"]))
               ELSE
                  FOR nZ := 1 To 3
                     Aadd(aRec,DtoC(StoD("")))
                  NEXT                  
               ENDIF

               cString := ""
               AEval(hPos[cKunde]["manufacturers"],{|cManu|                   
                  cString+="|"+Trim(cManu)
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
			Endif
			nP++
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

STATIC Function __AddEntry(hPos,cType,dDate,cKunde,nPerson)
   IF ! HHasKey(hPos,cKunde)
      hPos[cKunde] := {"kunde"=>cKunde,"artikel"=>{},"people"=>{=>},"manufacturers"=>{},"groups"=>{},"lastorder"=>StoD(""),"lastsample"=>StoD(""),"lastquote"=>StoD("")}
   ENDIF
   
   hPos[cKunde]["last"+cType] := Max(hPos[cKunde]["last"+cType],dDate)

   IF Ascan(hPos[cKunde]["artikel"],art->Matchcode) == 0
      Aadd(hPos[cKunde]["artikel"],art->Matchcode)
   ENDIF
   

   IF ! HHasKey(hPos[cKunde]["people"],nPerson) 
      hPos[cKunde]["people"][nPerson] := {"lastorder"=>StoD(""),"lastsample"=>StoD(""),"lastquote"=>StoD("")}
   ENDIF
   hPos[cKunde]["people"][nPerson]["last"+cType] := Max(hPos[cKunde]["last"+cType],dDate)

   manu->(dbSeek( Str(art->Manufactur,5) ))
   IF Ascan(hPos[cKunde]["manufacturers"],manu->Short) == 0
      Aadd(hPos[cKunde]["manufacturers"],manu->Short)
   ENDIF
   IF Ascan(hPos[cKunde]["groups"],art->Gruppe) == 0
      Aadd(hPos[cKunde]["groups"],art->Gruppe)
   ENDIF
RETURN NIL
