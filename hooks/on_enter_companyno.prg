#include 'y:\hb34\contrib\hbcurl\hbcurl.ch'

FUNCTION HOOK_ON_ENTER_COMPANYNO(oAddress,aGetList)
LOCAL cRegArt,cCompNo,cContent,hGerichte,nGericht
LOCAL hPost,cUrl,oHttp,nPos,aMatches,cMsg,aTokens,cName1,cName2,lName1
LOCAL oSearch,cGericht
LOCAL oSOAP,oCtr,oXML,oCompany
LOCAL pCurl,cPost,item,nErr
#include "gerichte.ch"

IF  oAddress:CountryIso == "DE"
   //cofrm->(dbSetOrder( 1 ))
   //cofrm->(dbSeek( oAddress:CountryIso+oAddress:CompForm ))

   /* registerart  ''=alle,  HRA, HRB, GnR, PR, VR */
   
   IF Trim(oAddress:CompForm) $ {"GMBH","AG","UG","KGaA","SE"}
      cRegart := "HRB"
   ELSEIF Trim(oAddress:CompForm) $ {"KG","EK","OHG"}
      cRegArt := "HRA"
   ELSEIF Trim(oAddress:CompForm) == "EV"
      cRegArt := "VR"
   ELSEIF Trim(oAddress:CompForm) == "EG"
      cRegArt := "GnR"
   ELSE
      Return .T.
   ENDIF
   IF At(cRegArt,oAddress:CompNo) != 1
      Tr_MsgBox(t("Registernummer muß mit % beginnen",cRegArt))
      Return .F.
   ENDIF
   cCompNo := Alltrim(SubStr(oAddress:CompNo,Len(cRegArt)+1))
   oAddress:CompNo := cRegart+" "+cCompNo

   ku->(dbSetOrder( 9 ))

   Select("ku")
   
   ku->(dbSetFilter( {|| ku->group == oAddress:Group },'group == "'+oAddress:Group+'"'))
   
   IF ! Empty(oAddress:CompNo) .AND. ku->(dbSeek( oAddress:CountryIso+Str(oAddress:Gericht,4,0)+Upper(oAddress:CompNo) )) .AND. ku->Nummer != oAddress:Nummer
      Tr_MsgBox("Firma bereits als "+Trim(ku->Kunde)+" angelegt. ")
      RETURN .F.
   ENDIF
   ku->(dbClearFilter())

   IF Tr_getini(28) == 9 .OR. ((GetActive():Changed .AND. oAddress:FieldUpdated("CompNo"))  .OR. oAddress:FieldUpdated("Gericht")) .AND. ! Empty(cRegArt)
      NetUse("creditsafe","cs")
      IF cs->(dbSeek( Str(oAddress:Nummer,6) ))         
         cs->(Rec_Lock())         
         cs->ID := ""
         cs->(dbUnLock())
      ENDIF

      /**
      Abruf Handelsregister

      UPDATE 07.04.22
      handelsregister.de hat seine Seite ge„ndert und dies funktioniert nicht mehr.

      **/
      
      /*
      ger->(dbSetOrder( 1 ))
      ger->(dbSeek( oAddress:CountryIso+Str(oAddress:Gericht,4) ))
      cGericht := ger->SimpleName
      nGericht := HB_HScan(hGerichte,HB_OemToAnsi(ger->Name))
      IF nGericht == 0
         Tr_msgBox("Gericht nicht gefunden")
         RETURN .T.
      ENDIF

      TxtBox("Handelsregister wird berprft... ")
      hPost := { ;
         "suchTyp"=>"n",;
         "registerArt"=>cRegArt,;
         "registerNummer"=>Trim(cCompNo),;
         "registergericht"=>HGetKeyAt(hGerichte,nGericht),;
         "schlagwoerter"=>"","schlagwortOption"=>"1","ergebnisseProSeite"=>"10","btnSuche"=>"Suchen";
         }         

      cUrl := "https://www.handelsregister.de/rp_web/search.do"     

      cPost := ""
      FOR EACH item IN hPost
         cPost += ;
            tip_URLEncode( AllTrim( hb_CStr( item:__enumKey() ) ) ) + "=" + ;
            tip_URLEncode(          hb_CStr( item ) )
         IF ! item:__enumIsLast()
            cPost += "&"
         ENDIF
      NEXT

      pCurl := Curl_Easy_init()
      Curl_Easy_SetOpt(pCurl,HB_CURLOPT_URL,cUrl)
      Curl_Easy_SetOpt(pCurl, HB_CURLOPT_SSL_VERIFYPEER, .F. )
      curl_easy_setopt(pCurl, HB_CURLOPT_DL_BUFF_SETUP )
      Curl_Easy_SetOpt(pCurl,HB_CURLOPT_POSTFIELDS,cPost)
      nErr := Curl_Easy_Perform(pCurl)
      curl_easy_setopt( pCurl, HB_CURLOPT_DL_BUFF_GET, @cContent )
      Curl_Easy_CleanUp(pCurl)

      TxtClear()

      nPos := At("RegPortErg_FirmaKopf",cContent)
      IF nPos == 0         
         Tr_MsgBox("Firma nicht gefunden!")
         IF Tr_getini(28) == 9
            gtSetClipboard(cContent)
         ENDIF
         RETURN .F.
      ENDIF
      
      cContent := StrTran(cContent,"&amp;","&")

      aMatches := HB_RegExAll("RegPortErg_FirmaKopf[^>]*>([^<]*)",cContent)
      IF StrTran(Upper(aMatches[1,2])," ","") != StrTran(Upper(oAddress:cName)," ","")
         cMsg := 'Abweichender Firmenname "'+Trim(aMatches[1,2])+'"'
         IF Len(Trim(aMatches[1,2])) < 70 
            IF Alert(cMsg,{t("übernehmen"),t("abbrechen")}) == 1
               aTokens := HB_ATokens(Trim(aMatches[1,2])," ")
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
               AEval(aGetList,{|oGet| 
                  IF Upper(oGet:name) $ "OADDRESS:NAME1 OADDRESS:NAME2"
                     oGet:Display()
                  ENDIF
                  RETURN NIL
               })
            ENDIF
         ELSE
            
            RETURN Alert(cMsg,{"abbrechen",t("trotzdem übernehmen")}) == 2
         ENDIF
      ENDIF      
      */

      /**
      Suche in Creditsafe falls aus Deutschland
      **/

      IF oAddress:CountryIso == "DE"
         TxtBox("Kreditauskunft wird gesucht...")
         oSOAP := CreditSafe()

         oCtr := SOAPParameter():New("countries")
         oCtr:CreateChild("CountryCode","DE",,"http://schemas.datacontract.org/2004/07/Creditsafe.GlobalData")
         oSearch := SOAPParameter():New("searchCriteria",,,"http://www.creditsafe.com/globaldata/operations")
         //Alert(cRegart+" "+cCompNo+" "+cGericht)
         oSearch:CreateChild("RegistrationNumber",cRegart+" "+cCompNo,,"http://www.creditsafe.com/globaldata/datatypes")         
         oSearch:CreateChild("Address",,,"http://www.creditsafe.com/globaldata/datatypes"):CreateChild("City",cGericht,,"http://www.creditsafe.com/globaldata/datatypes")
         
         oXML := oSOAP:Call("FindCompanies",{oCtr,oSearch})
         IF oXML == NIL
            Alert("Fehler bei der Abfrage der Kreditasuksunft")
         ELSEIF ! CS_Error(oXML)
            oCompany :=  TXmlIteratorScan():New(oXML:oRoot):Find("Companies"):oChild            
            IF oCompany == NIL
               Alert("Keinen Eintrag bei der Kreditauskunft gefunden")            
               //Alert(oXML:toString())
            ELSEIF oCompany:oNext != NIL //there is a second entry
               Alert("Keinen eindeutigen Eintrag bei der Kreditauskunft gefunden")
            ELSE            
               IF Tr_Getini(28) == 9
                  Alert("Company name:"+oCompany:toString())
               ENDIF
               //oAddress:SetCargo("id",oCompany:GetAttribute("Id"))
               /*IF cs->(dbSeek( Str(oAddress:Nummer,6)))                  
                     cs->(Rec_Lock())
               ELSE
                  cs->(Add_Rec(0))
                  cs->Kunde := oAddress:Nummer  
               ENDIF
               cs->ID := oCompany:GetAttribute("Id")
               cs->(dbUnLock()) */              
            ENDIF
            //oReport := CS_GetCompanyReport(oSoap,oAddress:GetCargo("id"),3)
         ENDIF
         TxtClear()
      ENDIF
   ENDIF
ENDIF

RETURN .T.

#include "X:\run\creditsafe.prg"