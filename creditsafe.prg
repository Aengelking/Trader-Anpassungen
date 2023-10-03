

//URL for downloading PDF: http://app.creditsafede.com/CSDEWebsite/Company/Print/DE01679628?saveReport=save
//most likely after login with the Username and password


FUNCTION CreditSafe
   LOCAL oUrl,oSOAP,cService
   MEMVAR mcCSLastError
   PRIVATE mcCSLastError := ""

   //Test Service
   /*oUrl := tUrl():New("https://testwebservices.creditsafe.com/GlobalData/1.3/MainServiceBasic.svc")
   oUrl:cUserId := "engelkingtest"
   oUrl:cPassword := "engelking558989"*/


   //Live Service
   oUrl := tUrl():New("https://webservices.creditsafe.com/GlobalData/1.3/MainServiceBasic.svc")
   oUrl:cUserId := "engelkinglive"
   oUrl:cPassword := "engelkinglive6985"

   
   oSOAP := SOAPHttpClient():New(oUrl)
   oSOAP:bSOAPAction := {|cNS,cMethod|
      cService := ""
      IF cMethod+" " $ "GetCountries FindCompanies GetPossibleSearchCriteria GetReportCustomDataSchema "
         cService := "DataBrowsingService"
      ELSEIF cMethod+" " $ "RetrieveCompanyOnlineReport TryRetrieveCompanyOnlineReport OrderCompanyOfflineReport GetReportboxContents GetReportboxReports RemoveReportboxReports "
         cService := "CompanyDataAccessService"
      ELSEIF cMethod+" " $ "GetPortfolios ListMonitoredCompanies CreatePortfolio RemovePortfolios GetPortfolioSettings SetPortfolioSettings AddCompaniesToPortfolios ImportCompaniesToPortfolio RemoveCompaniesFromPortfolios ChangeCompaniesReferenceStrings GetSupportedChangeEvents GetMonitoringRules SetMonitoringRules SetDefaultChangesCheckPeriod "
         cService := "CompanyMonitoringService"
      ENDIF
      RETURN cNS+"/"+cService+"/"+cMethod
   }
   oSOAP:cStdNameSpace := "http://www.creditsafe.com/globaldata/operations"
//   oSOAP:oHttp:nConnTimeout := 15000
RETURN oSOAP

FUNCTION CS_ListMonitoredCompanies(oSoap,aPortfolioIds,lChangedOnly,dChangedSince,nFirstPosition,nPageSize)
   LOCAL aP := {},nId,oList

   
   Default(@lChangedOnly,.F.)
   Default(@nFirstPosition,1)
   Default(@nPageSize,100)
   
   Aadd(aP,SOAPParameter():New("changedOnly",lChangedOnly))
   Aadd(aP,SOAPParameter():New("firstPosition",nFirstPosition))
   Aadd(aP,SOAPParameter():New("pageSize",nPageSize))
   IF ValType(aPortfolioIds) == "A"
      Aadd(aP,SOAPParameter():New("porfolioIds"))
      FOR EACH nId IN aPortfolioIds
         ATail(aP):CreateChild("unsignedInt",nId,,"http://www.creditsafe.com/globaldata/datatypes")
      NEXT
   ENDIF
   IF ValType(dChangedSince) == "D"
      Aadd(aP,SOAPParameter():New("changedSince",dChangedSince))
   ENDIF

   BEGIN SEQUENCE
   oList := oSOAP:Call("ListMonitoredCompanies",aP)
   RECOVER
   END
   

RETURN oList

FUNCTION CS_GetCompanyReport(oSoap,cID,nReason)
   LOCAL aP := {}
   LOCAL oEntries,oReport
   LOCAL cText,i
   //LOCAL bErrorBlock
   NetUse("cslog","cslog")

   

   Default(nReason,2)
   
   //correct ID, there was a bug in saving the ID, this will only work if the company is a German Kapitalgesellschaft, the others will have to be corrected by hand
   IF ! HB_RegexMatch("[A-Z]{2}[0-9]{3}\/[0-9]\/[A-Z]{2}[0-9]{8}",cID) .AND. At("DE",cID) == 1
      cID := Trim("DE001/0/"+cID)
   ELSE
      cID := cID
   ENDIF
   //Alert(cID)

   IF cslog->(dbSeek( cID ))
      DO WHILE cslog->Id == cID .AND. ! cslog->(EOF())
         cslog->(dbSkip())
      ENDDO
      cslog->(dbSkip(-1)) //go back to last record for this id
      IF StoT(cslog->TimeStamp) >= DateTime()-30/24/60  //has we received a report in the last 30min
         //we could get it from the archive but we do not have the customer no at this point
         //so we will return NIL
         cText := ""
         I := 1
         DO while ( !Empty(ProcName(i)) )
            cText += Chr(13)+Chr(10)+"Called from "+Trim(ProcName(i)) + " ("+Trim(ProcFile(i))+" ";
                     +LTRIM(Str(ProcLine(i))) + ")  "
           i++
         endDO
         SendMail({{"amos.engelking@engelking.de","Amos"}},"Doppelabruf Creditsafe "+cID,cText)
         RETURN NIL
      ENDIF
   ENDIF

   Aadd(aP,SOAPParameter():New("companyId",cId))
   Aadd(aP,SOAPParameter():New("reportType","Full"))
   Aadd(aP,SOAPParameter():New("language","DE"))
   Aadd(aP,SOAPParameter():New("customData"))
   oEntries := ATail(aP):CreateChild("Entries",,,"http://www.creditsafe.com/globaldata/datatypes")
   IF AT("DE",cID) == 1
      oEntries:CreateChild("Entry",Str(nReason,1),{"key"=>"de_reason_code"},"http://www.creditsafe.com/globaldata/datatypes")
   ENDIF
   oEntries:CreateChild("Entry","pdf",{"key"=>"binary_attachment"},"http://www.creditsafe.com/globaldata/datatypes")

   Aadd(aP,SOAPParameter():New("chargeReference",""))
   Aadd(aP,SOAPParameter():New("storeInReportbox","false"))

   //bErrorBlock := ErrorBlock({|| .T. }) //do not report errors or do anything, /this just crashes the programm
   
   BEGIN SEQUENCE
   oReport := oSOAP:Call("RetrieveCompanyOnlineReport",aP)
   RECOVER
   END
   //ErrorBlock(bErrorBlock)
   IF oReport == NIL
      IF ! GetConfigValue("BATCHMODE")
         Alert("Error retrieving report")
      ENDIF
   ELSEIF ! CS_Error(oReport)
      cslog->(Add_Rec(0))
      cslog->Id := cId
      cslog->TimeStamp := TtoS(DateTime())
      cslog->Date := Date()
      cslog->(dbUnLock())
      RETURN oReport
   ENDIF
RETURN NIL

FUNCTION CS_DownloadAndSavePdfReport(oXML,nReason,nKuNummer)
   LOCAL cFileName,cNewFile := "",cPDF
   LOCAL oLogin,oHttp,oUrl
   LOCAL nFH
   LOCAL aReason := {"CreditEnquiry","BusinessRelationship","SolvencyCheck","CommercialCreditInsurance","Contract","RentContract","InsuranceContract","Claim"}
   LOCAL hQuery := {=>}
   LOCAL oIter,oNode,nX,cID,cValue,lReg,hCookies
   
   MEMVAR mcCSLastError

   oIter := TXMLIteratorScan():New(oXml:oRoot)
   oNode :=  oIter:Find("Number")
   IF oNode != NIL
      cID := oNode:cData
   ELSE
      Alert("Error in report data")
      RETURN ""
   ENDIF

   oIter:rewind()
   lReg := oIter:Find("CompanyRegistrationNumber") != NIL

   oLogin := TipClientHttp():New("http://www.creditsafede.com/CSDEWebSite")
   IF oLogin:Open()
      oLogin:Post( {"User.UserName"=>"EngelKing","User.Password"=>"PzaO4WLM"} )
      IF oLogin:nReplyCode == 200
         FOR nX := 1 TO 2
            oUrl := TUrl():New("http://app.creditsafede.com/CSDEWebsite/Company"+IF(!lReg,"/NRegCompany","")+"/Print/"+AllTrim(cID))
            hQuery["saveReport"] := "save"
            hQuery["PrintCompanySummary"] := "true"
            IF lReg
               hQuery["PrintCurrentDirectors"] := "true"
               hQuery["PrintCurrentShareholders"] := "true"
               hQuery["PrintBeneficialOwnerships"] := "true"
               hQuery["PrintPreviousDirectors"] := "true"
               hQuery["PrintPerformanceIndicators"] := "true"
               hQuery["PrintFinancials"] := "true"
               hQuery["PrintIndividualFinancials"] := "true"
               hQuery["PrintHGBFinancials"] := "true"
            ENDIF
            oUrl:AddGetForm(hQuery)
            oHttp := TipClientHttp():New(oUrl)
            hCookies := HGetValueAt(HGetValueAt(oLogin:hCookies,1),1)
            cValue := ""
            FOR EACH cValue IN hCookies
               oHttp:setCookie(cValue:__enumKey()+"="+cValue)
            NEXT
            oLogin:close()
            oHttp:Open()
            IF nX == 1
               oHttp:Post({ "ReportReason"=>aReason[nReason] })  //first time post the reason, second get PDF
            ELSE
               cFileName := GetEnv("TEMP")+"\CS_"+StrTran(cID,"/","")+"_"+TtoS(DateTime())+".pdf"
               oHttp:Get()
               cPDF := oHttp:ReadAll()
               IF oHttp:nReplyCode != 200 .AND. oHttp:nReplyCode != 0
                  Alert("Error downloading PDF report "+ValToPrg(oHttp:nReplyCode))
                  MemoEdit(cPDF)
                  //Alert(oURl:BuildAddress())
               ELSE
                  nFH := FCreate(cFileName)
                  FWrite(nFH,cPdf)
                  FClose(nFH)

                  cNewFile :=AddFileToArchive("KA",nKuNummer,cFileName,.F.)
                  IF Empty(cNewFile)
                     mcCSLastError := "Error archiving report"
                     IF ! GetConfigValue("batchmode")
                        Tr_MsgBox(mcCSLastError)
                     ENDIF
                  ELSEIF FErase(cFileName) != 0
                     mcCSLastError := "Error deleting file "  +Str(FError())
                     IF ! GetConfigValue("batchmode")
                        Tr_MsgBox(mcCSLastError)
                     ENDIF
                  ENDIF
               ENDIF
            ENDIF
            oHttp:Close()
         NEXT
      ENDIF
   ENDIF
RETURN cNewFile

FUNCTION CS_SaveReport(nKuNummer,oXML,oOldXML,lForceSave)
   LOCAL cFileName,nFH,cNewFile := ""
   LOCAL oNode,oIter,oOldNode,lSave := .T.,cID
   LOCAL cPDF
   
   MEMVAR mcCSLastError
   
//   DEFAULT lForceSave TO .F.

   oIter := TXMLIteratorScan():New(oXml:oRoot)

//   oNode := oXml:oRoot:oChild:oChild
   oNode := oIter:Find("Reports"):oChild
   IF oNode != NIL
      cID := oNode:GetAttribute("CompanyId")
   /*oNode :=  oIter:Find("Number")
   IF oNode != NIL
      cID := oNode:cData*/
   ELSE
      Alert("Error in report data")
      RETURN ""
   ENDIF
   IF ValType(cID) != "C"
      Alert("Error in Company ID "+ValType(cID))
      Alert(oNode:toString())
      RETURN ""
   ENDIF

   NetUse("creditsafe","cs")

   oOldXML := CS_GetCompanyReportFromArchive(nKuNummer)
   IF oOldXML != NIL .AND. lForceSave != .T.
      oIter:rewind()
      oNode := oIter:Find("DateOfLatestRatingChange")
      oOldNode := TXMLIteratorScan():New(oOldXml:oRoot):Find("DateOfLatestRatingChange")

      IF oOldNode != NIL .AND. oNode:cData == oOldNode:cData
         //Alert("Report not changed")
         lSave := .F.
      ENDIF
   ENDIF

   IF cs->(dbSeek( Str(nKuNummer,6)))
      cs->(Rec_Lock())
   ELSE
      cs->(Add_rec(0))
      cs->Kunde := nKuNummer
   ENDIF
   cs->LastCheck := Date()
   cs->ID    := cID
   cs->(dbUnLock())

   IF lSave
      cFileName := GetEnv("TEMP")+"\CS_"+StrTran(cID,"/","")+"_"+TtoS(DateTime())+".pdf"
      oIter:Rewind()
      oNode := oIter:Find("BinaryAttachment")
      IF oNode != NIL
         cPDF := hb_base64decode( oNode:cData )
         nFH := FCreate(cFileName)
         FWrite(nFH,cPdf)
         FClose(nFH)

         cNewFile :=Hook("add_archive_file",{"KA",nKuNummer,cFileName},"")
         IF Empty(cNewFile)
            mcCSLastError := "Error archiving report"
            IF ! GetConfigValue("batchmode")
               Tr_MsgBox(mcCSLastError)
            ENDIF

            RETURN ""
         ELSEIF FErase(cFileName) != 0
            mcCSLastError := "Error deleting file "  +Str(FError())
            IF ! GetConfigValue("batchmode")
               Tr_MsgBox(mcCSLastError)
            ENDIF
         ENDIF

         cFileName := GetEnv("temp")+"\CS_report_"+TtoS(DateTime())+".xml"
         nFH := FCreate(cFileName)
         FWrite(nFH,oXML:oRoot:toString(1))
         FClose(nFH)

         cNewFile :=Hook("add_archive_file",{"KAM",nKuNummer,cFileName},"")
         IF Empty(cNewFile)
            mcCSLastError := "Error archiving report"
            IF ! GetConfigValue("batchmode")
               Tr_MsgBox(mcCSLastError)
            ENDIF

         ELSEIF FErase(cFileName) != 0
            mcCSLastError := "Error deleting file "  +Str(FError())
            IF ! GetConfigValue("batchmode")
               Tr_MsgBox(mcCSLastError)
            ENDIF

         ENDIF
      ELSE
         mcCSLastError := "No PDF contained in report"
         IF ! GetConfigValue("batchmode")
            Tr_MsgBox(mcCSLastError)
         ENDIF
      ENDIF
   ENDIF
RETURN cNewFile

FUNCTION CS_GetCompanyReportFromArchive(nKuNummer)
   LOCAL oReport,aFiles := GetArchiveFiles({"KAM"=>nKuNummer})
   IF Len(aFiles) >= 1 .AND. ATail(aFiles)[3] >= AddMonth(Date(),-12)
      oReport :=  TXmlDocument():New( MemoRead(ATail(aFiles)[6]) )
   ENDIF
RETURN oReport

FUNCTION CS_GetLastError()
   MEMVAR mcCSLastError
RETURN mcCSLastError

Function CS_Error(oXML)
   LOCAL lError := .F.
   LOCAL oMsgs := TXmlIteratorScan():New(oXML:oRoot):Find("Messages")
   LOCAL oIter,oMsg
   MEMVAR mcCSLastError

   IF oMsgs != NIL
      oIter := TXmlIteratorScan():New(oXML:oRoot)
      oMsg := oIter:Find("Message")
      DO WHILE oMsg != NIL
         IF oMsg:GetAttribute("Type") == "Error"
            mcCSLastError := oMsg:cData
            IF ! GetConfigValue("batchmode")
               Tr_MsgBox(oMsg:cData,"Error")
            ENDIF
            lError := .T.
         ENDIF
         oMsg := oIter:Next()
      ENDDO
   ENDIF
RETURN lError

FUNCTION EditCSNumber()   
   LOCAL cCSNR,oSoap
   LOCAL cCSPre,cPic
   LOCAL oReport

   IF ku->CountryIso == "DE"
      cCSNR := "DE"+Space(8)
      cPic := "!!"+Replicate("9",8)
      cCSPre := ku->CountryIso+"001/"  
      IF Trim(ku->CompForm) $ {"GMBH","AG","EK","KG","KGaA","OHG","SE","UG"}
         cCSPre += "0/"
      ELSE
         cCSPre += "1/"
      ENDIF   
   ELSEIF ku->CountryIso == "AT"
      cCSNr := Space(7)
      cPic := "9999999"
      cCSPre := "AT025/X/"
   ELSE
      Tr_MsgBox("Land nicht untersttzt")
      RETURN .T.
   ENDIF   

   NetUse("creditsafe","cs")
   IF cs->(dbSeek( Str(ku->Nummer,6) )) .AND. ! Empty(cs->ID)
      cCSNr := Right(cs->Id,10)
   ENDIF
   DO WHILE .T.      
      cCSNr := GetBox(cCSNr,"Creditsafe Nr.",cPic,,,,{|x|! Empty(x) .OR. Tr_MsgBox("Nummer l”schen?",,{"Nein","Ja"}) == 2 })
      IF LastKey() == 27 .OR. (cs->(dbSeek( Str(ku->Nummer,6) )) .AND. cs->ID == cCsNr)  //ESC pressed or no change
         RETURN NIL
      ENDIF
      IF ! Empty(cCSnr)
         TxtBox("Auskunft wird geladen")
         oSOAP := CreditSafe()
         oReport := CS_GetCompanyReport(oSoap,cCsPRE+cCSNr,3)
         IF oReport == NIL
            Tr_MsgBox("Fehler beim laden...")
         ELSE
            IF cs->(dbSeek( Str(ku->Nummer,6) ))
               cs->(Rec_Lock())
            ELSE
               cs->(Add_Rec())
               cs->Kunde := ku->Nummer
            ENDIF
            cs->Id := cCSPre+cCSNR
            cs->(dbUnlock())
            CS_SaveReport(ku->Nummer,oReport)
            TxtClear()
            EXIT
         ENDIF
         TxtClear()              
      ELSEIF cs->(dbSeek( Str(ku->Nummer,6) ))
         cs->(Rec_Lock())
         cs->Id := ""
         cs->(dbUnlock())
      ENDIF      
   ENDDO   
      
RETURN NIL 