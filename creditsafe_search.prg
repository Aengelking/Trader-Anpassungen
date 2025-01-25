#command @ <top>, <left>, <bottom>, <right> GET <v> LISTBOX ALIAS <alias> [ORDER <order> SEEK <seek>] WHILE <while> TEXT <text> VALUE <value>;
   [VALID <valid>] [WHEN <when>] ;
   [COLOR <clr>] ;
   [FOCUS <fb>] [STATE <sb>] [<dd:DROPDOWN>] [<sbar:SCROLLBAR>] ;
   [SEND <snd>] [GUISEND <gsnd>] => ;
AAdd( GetList, DBLB_Get():New( <top>,<left>, {|xValue| IIf( xValue==NIL, <v>, <v> := xValue ) },  <(v)> ) ) ;;
[ATail(getlist):preBlock := <{when}> ;];
[ATail(getlist):postBlock := <{valid}>;];
ATail(getList):Control := DBListBox():New(<top>,<left>,<bottom>,<right>,<.dd.>,<(alias)>,<order>,<{seek}>,<{while}>,<{text}>,<{value}>) ;;
[ATail(getList):Control:colorSpec := <clr>;];
[ATail(getList):Control:sBlock := <{sb}>;];
[ATail(getList):Control:fBlock := <{fb}>;];
[ ATail(GetList):<snd> ;] [ ATail(GetList):Control:<gsnd> ;] ;
ATail(GetList):reader := {| a, b, c, d | GuiReader( a, b, c, d ) } ;;
ATail(GetList):Control:LoadData();;
ATail(GetList):Control:Select(ATail(GetList):VarGet());;
ATail(GetList):Control:Display()

#command @ <top>,<left>,<bottom>,<right> GET <var> LISTBOX <hash> ASSOCIATIVE ;
	[VALID <valid>];
	[WHEN <when>];
	[COLOR <color>];
;
=> GET_AssociativeListBox(getlist,<top>,<left>,<bottom>,<right>,{|v| If(v==NIL,<var>,<var>:=v)},<hash>,<{valid}>, <{when}>,<color>)

FUNC CS_Search(cName,cCountryIso,nTop,nLeft)

LOCAL aOpts,oSOAP,oCtr,oSearch
LOCAL aCompanies,oNode,oCompany
LOCAL cGericht := Space(20),cCompNo := Space(20)
LOCAL nMenu,aEnv := SaveEnv()
LOCAL getlist := {}
LOCAL oName,oCity,nCompany,nX,oXML
//LOCAL aTokens,cName1,cName2,lName1,oRegCity,cGer,oLegal,cLegal,oMisc
LOCAL hCountries := {=>}
LOCAL aCountries := {"DE","AD","BE","BG","DK","EE","FI","FR","GR","GB","IE","IS","IT","HR","LV","LI","LT","LU","MT","MC","NL","NO","AT",;
   "PL","PT","RO","SM","SE","CH","SK","SI","ES","CZ","HU","CY","AU","JP","CA","NZ","US"}
LOCAL cMatchType
LOCAL lCountry := .T.
MEMVAR c_four,c_four_list
LOCAL nRight,nBottom

Default(@nLeft,02)
Default(@nTop,01)


Default(@cName,"")
IF cCountryIso == NIL .OR. ! cCountryIso $ aCountries
   cCountryIso := "DE"
   lCountry := .F.
ENDIF
cName := Pad(cName,25)

AEval(aCountries,{|cIso| hCountries[cIso] := GetCountryName(cIso) })

aOpts := Array(3)
aOpts[1] := "manuelle Eingabe"
aOpts[2] := "Suche nach Name"
IF ! lCountry .OR. cCountryIso == "DE"
   aOpts[3] := "Suche nach Registernummer (nur D)"
ENDIF

nBottom := nTop+25
nRight := nLeft+76   

DO WHILE .T.
   SetColor( c_four )
   @ nTop,nLeft CLEAR TO nBottom,nRight
   @ nTop,nLeft TO       nBottom,nRight DOUBLE

   //SetColor(c_five)
   nMenu := AChoice(nTop+1,nLeft+1,nTop+4,nLeft+36,aOpts)
   
   @ nTop+1,nLeft+1 CLEAR TO nBottom-1,nRight-1

   IF LastKey() == 27
      RestEnv(aEnv,.T.)
      RETURN NIL
   ELSEIF nMenu == 1
      RestEnv(aEnv,.T.)
      RETURN NIL
   ENDIF

   
   oSOAP := CreditSafe()

   oCtr := SOAPParameter():New("countries")

   oSearch := SOAPParameter():New("searchCriteria",,,"http://www.creditsafe.com/globaldata/operations")

   IF nMenu == 2
      @ nTop+1,nLeft+2 SAY "Name " GET cName VALID ! Empty(cName)
      
      
      @ nTop+2,nLeft+2 SAY "Land " 
      @ nTop+2,nLeft+8,nTop+6,nLeft+28 GET cCountryIso LISTBOX hCountries ASSOCIATIVE COLOR c_four_list WHEN ! lCountry
                  
      READ
      IF LastKey() == 27
         LOOP
      ENDIF

      oCtr:CreateChild("CountryCode",cCountryIso,,"http://schemas.datacontract.org/2004/07/Creditsafe.GlobalData")
      
      //Find the Possible Search Criteria
      oXML := oSOAP:Call("GetPossibleSearchCriteria",{oCtr})
      oName :=  TXmlIteratorScan():New(oXML:oRoot):Find("Name")
      IF "ClosestKeywords" $ oName:toString()
         cMatchType := "ClosestKeywords"         
      ELSEIF "MatchBlockOrWords" $ oName:toString()
         cMatchType := "MatchBlockOrWords"
      ELSEIF "MatchWords" $ oName:toString()
         cMatchType := "MatchWords"
      ELSEIF "MatchBeginning" $ oName:toString()
         cMatchType := "MatchBeginning"
      ELSE
         IF Tr_Getini(28) == 9
            Alert("SearchType: "+oName:toString())
         ENDIF  
         Alert("Land scheint nicht untersttzt zu werden") 
         LOOP
      ENDIF
      oSOAP := CreditSafe()
      //cMatchType := IF(cCountryIso${"FR","LI"},"ClosestKeywords",IF(cCountryIso=="HR","MatchBlockOrWords","MatchWords"))

      oSearch:CreateChild("Name",Trim(StrTran(cName,"&","&amp;")),{"MatchType"=>cMatchType},"http://www.creditsafe.com/globaldata/datatypes")
   ELSEIF nMenu == 3
      NetUse("gerichte","ger")

      @ nTop+1,nLeft+2 SAY "Registernummer " GET cCompNo VALID ! Empty(cCompNo)

      @ nTop+2,nLeft+2 SAY "Registergericht"
      @ nTop+2,nLeft+18,nBottom-2,nLeft+38 GET cGericht LISTBOX ALIAS ger ORDER 2 SEEK "DE" WHILE ger->Country == "DE" TEXT ger->Name VALUE ger->SimpleName DROPDOWN COLOR c_four_list STATE ReadUpdated(.T.) //WHEN lGericht
      //oGerList := ATail(getlist)
      READ
      IF LastKey() == 27
         LOOP
      ENDIF
      oSearch:CreateChild("RegistrationNumber",cCompNo,,"http://www.creditsafe.com/globaldata/datatypes")
      IF ! Empty(cGericht)
         oSearch:CreateChild("Address",,,"http://www.creditsafe.com/globaldata/datatypes"):CreateChild("City",cGericht,,"http://www.creditsafe.com/globaldata/datatypes")
      ENDIF  
      cCountryIso := "DE"
      oCtr:CreateChild("CountryCode",cCountryIso,,"http://schemas.datacontract.org/2004/07/Creditsafe.GlobalData")
   ENDIF

   TxtBox(t("Suche läuft..."))
   oXML := oSOAP:Call("FindCompanies",{oCtr,oSearch})
   TxtClear()
   IF oXML == NIL
      Alert("Fehler bei der Suche - keine Daten erhalten")
   ELSEIF ! CS_Error(oXML)
      oCompany :=  TXmlIteratorScan():New(oXML:oRoot):Find("Companies"):oChild
      IF oCompany == NIL
         Alert("Keinen Eintrag gefunden") //+oXML:oRoot:toString())
         LOOP
      ENDIF

      
      aCompanies := {}
      oNode := oCompany

      DO WHILE oNode != NIL
         oName := TXmlIteratorScan():New(oNode):Find("Name")
         oCity := TXmlIteratorScan():New(oNode):Find("City")
         //Alert(oNode:toString())
         Aadd(aCompanies,IF(oName!=NIl,oName:cData,"??")+" - "+IF(oCity!=NIL,oCity:cData,"??")+IF(Tr_Getini(28)==9," "+oNode:GetAttribute("Id"),""))
         oNode := oNode:oNext
      ENDDO
      @ nTop+4,nLeft+2 SAY "Gefundene Unternehmen:"
      nCompany := AChoice(nTop+5,nLeft+2,nBottom-1,nRight-1,aCompanies)
      IF LastKey() == 27
         LOOP
      ENDIF
      oNode := oCompany
      FOR nX := 2 TO nCompany
         oNode := oNode:oNext
      NEXT
      RestEnv(aEnv,.T.)
      RETURN oNode:GetAttribute("Id")
   ENDIF 
ENDDO        
RestEnv(aEnv,.T.)
RETURN ""


//#include "X:\run\creditsafe.prg"