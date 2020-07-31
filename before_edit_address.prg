//#include 'y:\harbour\trader\source\include\trget.ch'
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

FUNC HOOK_BEFORE_EDIT_ADDRESS(oAddress)

LOCAL aOpts,oSOAP,oCtr,oSearch
LOCAL aCompanies,oNode,oCompany
LOCAL cName := Space(25),cGericht := Space(20),cCompNo := Space(20)
LOCAL nMenu,aEnv := SaveEnv()
LOCAL getlist := {}
LOCAL oXML,oName,oCity,nCompany,nX,oReport,oBasic
LOCAL aTokens,cName1,cName2,lName1,oRegCity,cGer,oLegal,cLegal,oMisc

MEMVAR c_four,c_four_list

IF Tr_Getini(28) != 9
   //RETURN .T.
ENDIF



IF oAddress:lNew
   aOpts := Array(3)
   aOpts[1] := "manuelle Eingabe"
   aOpts[2] := "Suche nach Registernummer (nur D)"
   aOpts[3] := "Suche nach Name (nur D)"


   DO WHILE .T.
      SetColor( c_four )
      @ 01,02 CLEAR TO 26,78
	   @ 01,02 TO       26,78 DOUBLE

      //SetColor(c_five)
      nMenu := AChoice(02,03,05,37,aOpts)
      
      @ 02,03 CLEAR TO 25,77

      IF LastKey() == 27
         RestEnv(aEnv,.T.)
         RETURN .F.
      ELSEIF nMenu == 1
         RestEnv(aEnv,.T.)
         RETURN .T.
      ENDIF

      IF oSoap == NIL
         oSOAP := CreditSafe()

         oCtr := SOAPParameter():New("countries")
         oCtr:CreateChild("CountryCode","DE",,"http://schemas.datacontract.org/2004/07/Creditsafe.GlobalData")

      ENDIF

      oSearch := SOAPParameter():New("searchCriteria",,,"http://www.creditsafe.com/globaldata/operations")

      IF nMenu == 3
         @ 02,04 SAY "Name " GET cName VALID ! Empty(cName)
         READ
         IF LastKey() == 27
            LOOP
         ENDIF
         oSearch:CreateChild("Name",StrTran(cName,"&","&amp;"),{"MatchType"=>"MatchWords"},"http://www.creditsafe.com/globaldata/datatypes")
      ELSEIF nMenu == 2
         NetUse("gerichte","ger")

         @ 02,04 SAY "Registernummer " GET cCompNo VALID ! Empty(cCompNo)

         @ 03,04 SAY "Registergericht"
         @ 03,20,24,40 GET cGericht LISTBOX ALIAS ger ORDER 2 SEEK "DE" WHILE ger->Country == oAddress:CountryIso TEXT ger->Name VALUE ger->SimpleName DROPDOWN COLOR c_four_list STATE ReadUpdated(.T.) //WHEN lGericht
         //oGerList := ATail(getlist)
         READ
         IF LastKey() == 27
            LOOP
         ENDIF
         oSearch:CreateChild("RegistrationNumber",cCompNo,,"http://www.creditsafe.com/globaldata/datatypes")
         IF ! Empty(cGericht)
            Alert(cGericht)
            oSearch:CreateChild("Address",,,"http://www.creditsafe.com/globaldata/datatypes"):CreateChild("City",cGericht,,"http://www.creditsafe.com/globaldata/datatypes")
         ENDIF  
      ENDIF
      TxtBox(t("Suche läuft..."))
      oXML := oSOAP:Call("FindCompanies",{oCtr,oSearch})
      TxtClear()
      IF oXML == NIL
         Alert("Fehler bei der Suche - keine Daten erhalten")
      ELSEIF ! CS_Error(oXML)
            oCompany :=  TXmlIteratorScan():New(oXML:oRoot):Find("Companies"):oChild
            IF oCompany == NIL
               Alert("Keinen Eintrag gefunden")
               LOOP
            ENDIF

         //IF oCompany:oNext != NIL
            aCompanies := {}
            oNode := oCompany

            DO WHILE oNode != NIL
               oName := TXmlIteratorScan():New(oNode):Find("Name")
               oCity := TXmlIteratorScan():New(oNode):Find("City")
               Aadd(aCompanies,IF(oName!=NIl,oName:cData,"??")+" - "+IF(oCity!=NIL,oCity:cData,"??"))
               oNode := oNode:oNext
            ENDDO
            @ 05,04 SAY "Gefundene Unternehmen:"
            nCompany := AChoice(06,04,25,77,aCompanies)
            IF LastKey() == 27
               LOOP
            ENDIF
            oNode := oCompany
            FOR nX := 2 TO nCompany
               oNode := oNode:oNext
            NEXT
            //oCompany := oNode
            oAddress:SetCargo("id",oNode:GetAttribute("Id"))
            TxtBox("Daten werden abgerufen...")
            oSOAP := CreditSafe()
            oReport := CS_GetCompanyReport(oSoap,oAddress:GetCargo("id"),3)
            TxtClear()
            IF oReport != NIL
               oAddress:SetCargo("report",oReport)
                IF oAddress:HasCargo("report")
                  Alert(oAddress:GetCargo("report"))
               ELSE
                  Alert("NO REPORT")
               ENDIF
               oBasic := TXMLIteratorScan():New(oReport:oRoot):Find("BasicInformation")
               IF oBasic != NIL
                  cName := TXMLIteratorScan():New(oBasic):Find("BusinessName"):cData
   
                  aTokens := HB_ATokens(Trim(cName)," ")
                  cName1 := ""
                  cName2 := ""
                  lName1 := .T.
                  AEval(aTokens,{|cToken|
                     IF lName1 .AND. Len(cName1)+Len(cToken)+1<35
                        cName1 += cToken+" "
                     ELSE
                        lName1 := .F.
                        cName2 += cToken+" "
                     ENDIF
                     RETURN NIL
                  })
                  oAddress:Name1 := cName1
                  oAddress:Name2 := cName2
                  oAddress:CountryIso := "DE"

                  _SetValue(oAddress,"CompNo",oBasic,"CompanyRegistrationNumber")
                  oRegCity := TXMLIteratorScan():New(oReport:oRoot):Find("CommercialRegisterCity")
                  IF oRegCity != NIL
                     NetUse("gerichte","ger")
                     ger->(dbSetOrder(2))
                     IF AT(" ",oRegCity:cData) != 0
                        cGer := SubStr(oRegCity:cData,1,AT(" ",oRegCity:cData))
                     ELSE
                        cGer := Trim(oRegCity:cData)
                     ENDIF
                     cGer := CharRepl(HB_AnsiToOem("äüö"),Upper(cGer),HB_AnsiToOem("ÄÜÖ"))
                     IF ger->(dbSeek("DE"+cGer,.T.))
                        oAddress:Gericht := ger->No
                     ENDIF
                  ENDIF

                  _SetValue(oAddress,"Street",oBasic,"Street")
                  _SetValue(oAddress,"Town",oBasic,"City")
                  _SetValue(oAddress,"Plz",oBasic,"PostalCode")
                  _SetValue(oAddress,"Telefon",oReport:oRoot,"ContactTelephoneNumber")
                  _SetValue(oAddress,"Email",oReport:oRoot,"EmailAddress")
                  _SetValue(oAddress,"vatnr",oBasic,"VatRegistrationNumber")


                  oLegal := TXMLIteratorScan():New(oBasic):Find("LegalForm")
                  IF oLegal != NIL
                     cLegal := oLegal:cData
                     IF Tr_Getini(28) == 9
                        Alert(cLegal)
                     ENDIF
                     IF cLegal == "Private limited company" .OR. cLegal == HB_AnsiToOem("Gesellschaft mit beschränkter Haftung")
                        oAddress:CompForm := "GMBH"
                     ELSEIF cLegal == "Public limited company" .OR. cLegal == HB_AnsiToOem("Aktiengesellschaft")
                        oAddress:CompForm := "AG"
                     ELSEIF AT("General partnership",cLegal) == 1 .OR. cLegal == HB_AnsiToOem("Offene Handelsgesellschaft")
                        oAddress:CompForm := "OHG"
                     ELSEIF cLegal == "Registered merchant" .OR. cLegal == HB_AnsiToOem("Eingetragener Kaufmann")
                        oAddress:CompForm := "EK"
                     ELSEIF AT("Limited partnership",cLegal) == 1 ;
                        .OR. cLegal == HB_AnsiToOem("Kommanditgesellschaft");
                        .OR. cLegal == HB_AnsiToOem("UG (haftungsbeschränkt) & Co. KG")
                        oAddress:CompForm := "KG"
                     ENDIF
                  ENDIF 

                  oMisc := TXMLIteratorScan():New(oReport:oRoot):Find("Misc")
                  IF oMisc != NIL
                     _SetValue(oAddress,"Telefax",oMisc,"FaxNumber")
                  ENDIF

                  ku->(dbSetOrder( 9 ))
                  IF ! Empty(oAddress:CompNo) .AND. ku->(dbSeek( oAddress:CountryIso+Str(oAddress:Gericht,4,0)+Upper(oAddress:CompNo) ))
                     Tr_MsgBox("Firma bereits als "+Trim(ku->Kunde)+" angelegt. ")
                     LOOP
                  ENDIF

               ENDIF
//               gtSetClipboard(oReport:toString(1))
               EXIT
            ENDIF

         //ENDIF
      ENDIF
   ENDDO
ENDIF

RestEnv(aEnv,.T.)
RETURN .T.

STATIC FUNCTION _SetValue(oAddress,cName,oRoot,cSearch)
   LOCAL oNode := TXMLIteratorScan():New(oRoot):Find(cSearch)
   IF oNode != NIL
      oAddress:SetField(cName,oNode:cData)
   ENDIF
RETURN NIL


#include "X:\run\creditsafe.prg"