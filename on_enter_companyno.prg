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

   IF ((GetActive():Changed .AND. oAddress:FieldUpdated("CompNo"))  .OR. oAddress:FieldUpdated("Gericht")) .AND. ! Empty(cRegArt)
      NetUse("creditsafe","cs")
      IF cs->(dbSeek( Str(oAddress:Nummer,6) ))
         //IF Tr_Getini(28) == 9; Alert("Deleting CS ID"); ENDIF
         cs->(Rec_Lock())
         //cs->(dbDelete())
         cs->ID := ""
         cs->(dbUnLock())
      ENDIF

      ger->(dbSetOrder( 1 ))
      ger->(dbSeek( oAddress:CountryIso+Str(oAddress:Gericht,4) ))
      cGericht := ger->SimpleName
      nGericht := HB_HScan(hGerichte,HB_OemToAnsi(ger->Name))
      IF nGericht == 0
         Tr_msgBox("Gericht nicht gefunden")
         RETURN .T.
      ENDIF

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

      

      /*oHttp := TipClientHttp():new( cUrl )
      oHttp:open()
      oHttp:Post(hPost)
      cContent := StrTran(StrTran(hb_utf8tostr(oHttp:ReadAll()),"&quot;",'"'),"&amp;","&")*/
      nPos := At("RegPortErg_FirmaKopf",cContent)
      IF nPos == 0         
         Tr_MsgBox("Firma nicht gefunden!")
         RETURN .F.
      ENDIF

      aMatches := HB_RegExAll("RegPortErg_FirmaKopf[^>]*>([^<]*)",cContent)
      IF StrTran(Upper(aMatches[1,2])," ","") != StrTran(Upper(oAddress:cName)," ","")
         cMsg := 'Abweichender Firmenname "'+Trim(aMatches[1,2])+'"'
//         MemoEdit(cContent)
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
               //aGetList := __GetListActive():aGetList
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
      //oAddress:SetCargo("COMPNOCHANGED",.T.)
         //delete existing report
      /*IF cs->(dbSeek( Str(ku->Nummer,6)))
         cs->(Rec_Lock())
         cs->ID := ""
         cs->(dbUnLock())
      ENDIF*/
      IF oAddress:CountryIso == "DE"
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
      ENDIF
   ENDIF
ENDIF

RETURN .T.

#include "X:\run\creditsafe.prg"