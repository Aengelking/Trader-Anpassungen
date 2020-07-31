PROCEDURE RUN_UPDATE_CREDITSAFE
LOCAL nDays := 15
LOCAL nnoOrdersDays := 25  //25.11. increase the number of days on customer who do not have an open order
LOCAL nMax  := 5
LOCAL nTries := 3
LOCAL nTry
LOCAL nOpenOrders,hTurnOver
LOCAL aFiles,nCount := 0
LOCAL oReport,oOldReport,nOldRating,nNewRating
LOCAL oNode,oIter,oSoap
LOCAL nStart,nMS
LOCAL cList := "<pre>"
LOCAL aList := {}


NetUse("creditsafe","cs")
NetUse("engkund",   "ku")


Head(t("Aktualisierung Creditsafe Auskünfte"))

nMax := Max(nMax,Round(cs->(LastRec())/nDays,0)+1) //make sure we update all records within the givin time

cs->(dbSetFilter({|| cs->LastCheck < Date()-nDays},'lastcheck < StoD("'+DtoS(Date()-nDays)+'")'))
cs->(dbGoTop())

ku->(dbSetOrder( 8 ))

//oSOAP := CreditSafe()
//MemoEdit(oSoap:Call("CreatePortfolio",{SOAPParameter():New("settings",,{"Enabled"=>"true","Name"=>"Test"})}):toString())


//oSOAP := CreditSafe()
//MemoEdit(oSoap:Call("GetPortfolios",{}):toString())

//oSOAP := CreditSafe()
//MemoEdit(CS_ListMonitoredCompanies(oSoap):toString()) //,aPortfolioIds,lChangedOnly,dChangedSince,nFirstPosition,nPageSize))

nMS := HB_MILLISECONDS()

//aP := {SOAPParameter():New("companies")}

DO WHILE ! cs->(Eof())

   ku->(dbSeek( Str(cs->Kunde,6) ))
   //cList += ku->Kunde
   ? ku->Kunde
   
   //aP[1]:createChild("Company",ku->Kunde,{"key"=>SubStr(cs->ID,RAT("/",cs->Id)+1)})


   IF Empty(cs->LastCheck)
      aFiles := GetArchiveFiles({"KAM"=>cs->Kunde})
      cs->(Rec_Lock())
      IF Len(aFiles) >= 1         
         cs->LastCheck := ATail(aFiles)[3]         
      ELSE
         cs->LastCheck := Date()
      ENDIF
      cs->(dbUnLock())
   ELSE
      nOpenOrders := GetCustomerOpenOrders(ku->kunde)
      IF nOpenOrders == 0
         hTurnover := GetCustomerTurnover(ku->kunde)
      ENDIF
      IF nOpenOrders != 0 .OR. (cs->LastCheck < Date()-nNoOrdersDays .AND. hTurnover["12-month"] > 0) //hTurnover["current"]+hTurnover["last"] > 0
         /*nStart := HB_MilliSeconds()
         oReport := NIL
         FOR nTry := 1 TO nTries
            BEGIN SEQUENCE
               oReport := CS_GetCompanyReport(oSoap,cs->ID,3)
            END
            IF oReport != NIL
               EXIT
            ENDIF
         NEXT
         IF oReport == NIL
            cList += " Fehler beim Herunterladen<br/>"
            IF AT("DE001",cs->ID) != 1 .AND. AT("DE",cs->ID) == 1  //old record with false data which is not corrected by CS_GetCompanyReport (non registered firms)
               cs->(Rec_Lock())
               cs->ID := "DE001/1/"+cs->ID
               cs->(dbUnLock())
               ? 15.1*1000-(HB_MILLISECONDS()-nStart)
               hb_idleSleep((15.1*1000-(HB_MILLISECONDS()-nStart))/1000)
               //LOOP
            ENDIF
            cs->(dbSkip())
            LOOP
            //EXIT
         ELSEIF Empty(CS_SaveReport(ku->Nummer,oReport,@oOldReport))
            cList += " Keine neuen Daten vorhanden"
         ELSE
            cList += " Daten aktualisiert. Rating neu: "

            oIter := TXmlIteratorScan():New(oReport:oRoot)
            oNode := oIter:Find("DECurrentRating")
            IF oNode != NIL
               nNewRating := Val(oNode:cData)
               cList += oNode:cData
            ENDIF
            cList += " alt: "
            nOldRating := 0
            IF oOldReport != NIL
               oIter := TXmlIteratorScan():New(oOldReport:oRoot)
               oNode := oIter:Find("DECurrentRating")
               IF oNode != NIL
                  cList += oNode:cData
                  nOldRating := Val(oNode:cData)
               ENDIF
            ENDIF
            IF nOldRating != 0 .AND. (nNewRating-nOldRating > 0.4 .OR. (nOldRating < nNewRating .AND. nNewRating > 3) .OR. nNewRating == 0)//hat sich deutlich verschlechtert
               SendMail({{"amos.engelking@engelking.de","Amos"}},"Rating "+ku->Kunde,"Hallo,<br/>das Rating von "+Trim(Trim(ku->Name1)+" "+ku->Name2)+" hat sich von "+Str(nOldRating,3,1)+" auf "+Str(nNewRating,3,1)+" verschlechtert.",,,,.T.)
            ENDIF
         ENDIF
         nCount++
         IF nMax > 20 .AND. nCount < nMax .AND. HB_MilliSeconds()-nStart < 15.5*1000 //at least 15s between request so we do not reach the limit of 20 request per 5 minutes
            ? 15.1*1000-(HB_MILLISECONDS()-nStart)
            hb_idleSleep((15.1*1000-(HB_MILLISECONDS()-nStart))/1000)
         ENDIF*/
         Aadd(aList,{SubStr(cs->ID,RAT("/",cs->Id)+1)})
      ELSE
         cList += " nicht aktiv"
         cs->(Rec_Lock())
         cs->LastCheck := Date()
         cs->(dbUnLock())
      ENDIF
      cList += "<br/>"
      IF nCount >= nMax
         EXIT
      ENDIF
   ENDIF
   cs->(dbSkip())
   
ENDDO

/*oSOAP := CreditSafe()
Aadd(aP,SOAPParameter():New("portfolioIds"))
ATail(aP):CreateChild("unsignedInt",26004,,"http://www.creditsafe.com/globaldata/datatypes")
MemoEdit(oSoap:Call("AddCompaniesToPortfolios",aP))*/
SaveAsCSV(Path("export\csmonitor.csv"),aList)

//cList += "</pre><br/>Dauer: "+LTrim(Str((HB_MILLISECONDS()-nMS)/1000))+"s"
&&SendMail({{"amos.engelking@engelking.de","Amos"}},"Aktualisierung Creditsafe",cList,,,,.T.)


#include 'X:\run\creditsafe.prg'