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

PROCEDURE RUN_Export_Email_Mailing
LOCAL nType := 1
LOCAL aTypes := {"Matchcode (Regex)","Hersteller","Produktgruppe"}
LOCAL hManu := GetManufacturerHash()
LOCAL nManu := 1
LOCAL cBegin := Space(50)
LOCAL getlist := {}
LOCAL lMuster := .T.
LOCAL lAngebot := .T.
LOCAL lAuftrag := .T.
//LOCAL lTel := .F.
LOCAL cGroup := Space(4)
LOCAL hPos,cWeek,cFile,nX,cKunde,nP
LOCAL hContact,nA
LOCAL lAllContacts := .F.
LOCAL lNoGeneral := .F.,aPeople
LOCAL lNurEmail := .T.
LOCAL aCSV := {},nCount,cAnrede,cEmail,cName

Head("Ansprechpartner mit Email Adressen exportieren")

@ 01,00 SAY "Auswahlart"
@ 01,27,10,50 GET nType LISTBOX aTypes DROPDOWN
@ 02,00 SAY "Regex"
@ 02,27 GET cBegin WHEN nType == 1 //VALID HB_IsRegexString(cBegin)
@ 03,00 SAY "Hersteller"
@ 03,27,22,40 GET nManu LISTBOX hManu ASSOCIATIVE WHEN nType == 2
@ 04,00 SAY "Produktgruppe"
@ 04,27 GET cGroup PICTURE "@!" WHEN nType == 3
//@ 05,00 SAY t("Telefonnummern exportieren")
//@ 05,27 GET lTel CHECKBOX
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
@ 11,00 SAY "Nur mit Email"
@ 11,27 GET lNurEmail CHECKBOX
READ


IF LastKey() == 27
   RETURN
ENDIF

//cBegin := Trim(GetBox(Space(50),"Regex Matchcode"))
//aList := {"MP0025","PX0742/P/75OHM","SX0793","SX0782/63","QX2290","MP0025/2","PX0743/S/75OHM","SX0793/63","SX0783","QX2447/1","MP0025/3","PX0759/S/75OHM","SX0794","SX0783/63","QX2571","MP0025/F2","PX0763/S/75OHM","SX0794/63","SX0784","QX2611/10","MP0034","SX0780","SM0319","SX0784/63","QX2612/10","MP0034/2","SX0780/63","SM0319/63","SX0786/63","QX2613/10","MP0034/3","SX0781/63","SM0319/D","SX0790","QX2614/10","MPD031","SX0782","SM0320","SX0790/63","QX3453","MPL025","SX0782/63","SM0320/D","SX0791","QX3526","MPL027","SX0783","SM0324/2","SX0792","QX3637/A58","MPL031","SX0783/63","SM0324/2/D","SX0792/63","QX3720","MPL034","SX0784","SM0365/63","SX0793","QX3340","MPL038","SX0784/63","SX0550/RD","SX0793/63","SM0446/2/INS/BK","PX0741/S/50OHM","SX0786/63","SX0686","SX0794","SM0446/2/INS/BL","PX0742/P/50OHM","SX0790","SX0686/D","SX0794/63","SM0446/2/INS/RD","PX0743/S/50OHM","SX0790/63","SX0780","SX0904","PX0759/S/50OHM","SX0791","SX0780/63","SX0904/GN","PX0763/S/50OHM","SX0792","SX0781/63","SX0904/RD","PX0741/S/75OHM","SX0792/63","SX0782","QX2230/50","SM0446/2/INS/BK","SM0446/2/INS/BL","SM0446/2/INS/RD"}
//cBegin := "BULOBS"

cBegin := Trim(cBegin)

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

cWeek := CalWeek(Date()-365)

SET CURSOR OFF

nCount := 0
IF lAuftrag
   auf->(dbSetFilter({|| auf->VkPr != 0 },"VkPr != 0"))
   auf->(dbSeek( cWeek ))
   @ 23,00 SAY "Auftrag"
   Do While ! auf->(EOF()) .AND. auf->DTERM >= Val(cWeek) .AND. Left(Str(auf->Dterm,4),2) < "50"
      IF nType >= 2
         art->(dbSeek( Str(auf->Artikelnr,6) ))
      ENDIF
   
   	IF (nType == 1 .AND. HB_RegexMatch(cBegin,auf->Matchcode)) .OR. (nType == 2 .AND. art->Manufactur == nManu) .OR. (nType == 3 .AND. art->Gruppe == cGroup)
   	//IF AScan(aList,Trim(auf->Matchcode)) != 0
         nCount++   
         @ 23,14 SAY Str(auf->Abnr,6)+" ("+LTrim(Str(nCount))+")"
         __AddEntry(hPos,auf->Kundma,auf->Matchcode,auf->person)
         
   	Endif
   	auf->(dbSkip())
   Enddo
   auf->(dbClearFilter())
ENDIF


IF lMuster
   nCount := 0
   @ 24,00 SAY "Musterauftrag"
   lne->(dbSetFilter({|| lne->Versand .AND. lne->Datum >= Date()-365 .AND. lne->Gruppe == "K"},"Versand .AND. Datum >= Date()-365 .AND. Gruppe == 'K'"))
   lne->(dbGoTop())
   Do While ! lne->(Eof())
      IF nType >= 2
         art->(dbSeek( Str(lne->Artikelnr,6) ))
      ENDIF
   	If /*lne->Versand .AND. lne->Datum >= Date()-365 .AND. lne->Gruppe == "K" .AND.*/ (nType == 1 .AND. HB_RegexMatch(cBegin,lne->Matchcode)) .OR. (nType == 2 .AND. art->Manufactur == nManu) .OR. (nType == 3 .AND. art->Gruppe == cGroup)
         nCount++
         @ 24,14 SAY Str(lne->Nummer,6)+" ("+LTrim(Str(nCount))+")"
   		__AddEntry(hPos,lne->Kunde,lne->Matchcode,lne->Person)
   	Endif
   	lne->(dbSkip())
   Enddo
   lne->(dbClearFilter())
ENDIF

IF lAngebot
   nCount := 0
   @ 25,00 SAY "Angebote"
   ang->(dbSetFilter({|| ang->Datum >= Date()-365 },"Datum >= Date()-365"))
   ang->(dbGoTop())
   Do While ! ang->(Eof())
      IF nType >= 2
         art->(dbSeek( Str(ang->Artikelnr,6) ))
      ENDIF
      IF (nType == 1 .AND. HB_RegexMatch(cBegin,lne->Matchcode)) .OR. (nType == 2 .AND. art->Manufactur == nManu) .OR. (nType == 3 .AND. art->Gruppe == cGroup)
         nCount++
   		@ 25,14 SAY Str(ang->Angnr,6)+" ("+LTrim(Str(nCount))+")"
         __AddEntry(hPos,ang->Kundma,ang->Matchcode,ang->Person)
   	Endif
   	ang->(dbSkip())
   Enddo
   ang->(dbClearFilter())
ENDIF

cFile := Trim(Tr_Getini(1))+"\export\"+IF(nType==1,Lower(CharRepl("*.\?:()|/\",Trim(cBegin)," __")),IF(nType==2,Trim(hManu[nManu]),Trim(cGroup)))+"_auftraege.csv"
//SET PRINTER TO (cFile)
//SET PRINTER ON
@ 26,00 SAY "Exportiere"
@ 26,21 SAY "/"+LTrim(Str(Len(hPos)))

Aadd(aCSV,{"Sprache","Anrede","Name","Email"})
/*IF lTel
   Aadd(aCSV[1],"Telefon")
ENDIF*/
Aadd(aCSV[1],"Matchcode")
Aadd(aCSV[1],"Firma")
Aadd(aCSV[1],"Stra·e")
Aadd(aCSV[1],"PLZ")
Aadd(aCSV[1],"Stadt")
Aadd(aCSV[1],"Land")

aku->(dbSetOrder( 3 ))
nX := 1
Do While nX <= Len(hPos)
   @ 26,11 SAY Str(nX,10)
   cKunde := HGetKeyAt(hPos,nX)
	If ! Trim(cKunde) $ "SELF GEKOA PGPOWER TEST"
		ku->(dbSeek( cKunde+"K" ))
      nP := 1
      IF lAllContacts
         aPeople := GetAddressContacts(.F.)[2]
      ELSE
         aPeople := hPos[cKunde]["people"]
      ENDIF
      conts->(dbSetOrder(2))
      Do While nP <= Len(aPeople)
         IF aPeople[nP] != 0 .OR. Len(aPeople) == 1
         
            IF conts->(dbSeek( Str(ku->Nummer,6)+Str(aPeople[nP],4) )) .AND. conts->Anrede > 0
               an->(dbGoto(conts->Anrede))
               cAnrede := Trim(an->Anrede)
               cName := Trim(conts->Name)
               cEmail := Trim(conts->email)
               
            ELSEIF lNoGeneral
               nP++
               LOOP
            ELSE
               cAnrede := IF(ku->Language=="D","Sehr geehrte Damen und Herren","Dear Sir or Madam")  
               cName   := ""          
               cEmail  := Trim(conts->email)               
            ENDIF
			
				nA := 1
            //hContact := GetContact(aPeople[nP])
            IF ! lNurEmail .OR. ! Empty(cEmail)
               Aadd(aCSV,{{"D"=>"DE","E"=>"EN"," "=>"DE"}[ku->Language],cAnrede,cName,cEmail})
               
               /*IF lTel
                  AAdd(ATail(aCSV),hContact["fullphone"])
               ENDIF*/
               AAdd(ATail(aCSV),Trim(ku->Kunde))
               AAdd(ATail(aCSV),Trim(Trim(ku->Name1)+" "+ku->Name2))
               AAdd(ATail(aCSV),Trim(ku->Street))
               AAdd(ATail(aCSV),Trim(ku->Plz))
               AAdd(ATail(aCSV),Trim(ku->Town))
               AAdd(ATail(aCSV),Trim(GetCountryname(ku->CountryIso)))
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
            ENDIF
			Endif
			nP++
		Enddo
	Endif
	nX++
Enddo

//SET PRINTER TO
//SET PRINTER OFF
DO WHILE (nH := Fopen(cFile,"W")) == 0 .AND. Tr_MsgBox("Datei kann nicht geîffnet werden",,{"wiederholen","abbrechen"}) != 2
ENDDO
IF nH != 0
   FClose(nH)
   @ 27,00 SAY "Speichern..."
   SaveAsCSV(cFile,aCSV)
   @ 27,14 SAY "abgeschlossen"
   WAPI_ShellExecute(NIL, "Open", cFile, "", "", 1)
ENDIF
SET CURSOR ON

TR_MsgBox("Export abgeschlossen")

STATIC Function __AddEntry(hPos,cKunde,cMatchcode,nPerson)
   IF ! HHasKey(hPos,cKunde)
      hPos[cKunde] := {"kunde"=>cKunde,"artikel"=>{},"people"=>{}}
   ENDIF
   IF Ascan(hPos[cKunde]["artikel"],cMatchcode) == 0
      Aadd(hPos[cKunde]["artikel"],cMatchcode)
   ENDIF
   IF Ascan(hPos[cKunde]["people"],nPerson) == 0
      Aadd(hPos[cKunde]["people"],nPerson)
   ENDIF
RETURN NIL
