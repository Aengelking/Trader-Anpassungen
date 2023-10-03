PROCEDURE RUN_UPDATE_CREDITSAFE
LOCAL nDays := 15
LOCAL nOpenOrders,hTurnOver
LOCAL aFiles
LOCAL aList := {},cList
LOCAL oCS,cStart,tLast,hList,hEntry,oSOAP,oReport
LOCAL lPrePay


NetUse("creditsafe","cs")
NetUse("engkund",   "ku")
NetUse("skontoa","sk")


Head(t("Aktualisierung Creditsafe Auskünfte"))

//cs->(dbSetFilter({|| cs->LastCheck < Date()-nDays},'lastcheck < StoD("'+DtoS(Date()-nDays)+'")'))
cs->(dbGoTop())

ku->(dbSetOrder( 8 ))
cList := ""

DO WHILE ! cs->(Eof()) 
   
   IF ku->(dbSeek( Str(cs->Kunde,6) ))
      cList += ku->Kunde
      ? ku->Kunde
   
      IF Empty(cs->LastCheck)
         aFiles := GetArchiveFiles({"KAM"=>cs->Kunde})
         cs->(Rec_Lock())
         IF Len(aFiles) >= 1         
            cs->LastCheck := ATail(aFiles)[3]         
         ELSE
            cs->LastCheck := Date()
         ENDIF         
         cs->(dbUnLock())
      ENDIF
      lPrePay := sk->(IsPrePay(ku->Skonto)) 
      IF ! lPrePay
         nOpenOrders := GetCustomerOpenOrders(ku->kunde)
         IF nOpenOrders == 0
            hTurnover := GetCustomerTurnover(ku->kunde)
         ENDIF
      ELSE
         nOpenOrders := 0
      ENDIF
      IF ! lPrePay .AND. (nOpenOrders != 0 .OR. hTurnover["12-month"] > 0)
         Aadd(aList,{SubStr(cs->ID,RAT("/",cs->Id)+1),,,ku->Nummer})
      ELSE
         cList += " nicht aktiv"
         ?? " nicht aktiv"
         cs->(Rec_Lock())
         cs->LastCheck := Date()
         cs->(dbUnLock())
      ENDIF      
   ELSE
      cList += "Kunde nicht gefunden "+Str(cs->Kunde)
      ? "Kunde nicht gefunden "+Str(cs->Kunde)
      cs->(Rec_Lock(0))
      cs->(dbDelete())
      cs->(dbUnLock())
   ENDIF
   cList += Chr(13)+Chr(10)
   
   cs->(dbSkip())
   
ENDDO

cs->(dbClearFilter())

SaveAsCSV(Path("export\csmonitor.csv"),aList)


oCS := CreditSafeApi():New()
IF oCS:Auth()   
   oCS:SyncMonitoringPortfolio(647123,"x:\export\csmonitor.csv","amos.engelking@engelking.de")
   SendMail({{"amos.engelking@engelking.de","Amos"}},"Creditsafe Montioring wird aktualisiert","Gesamt: "+Ltrim(Str(Len(aList)))+Chr(13)+Chr(10)+cList)

   ? "Downloading events"
   //download events
   tLast := StoT(GetValue("CS_LSTUPD",TtoS(DateTime()),"Last Update"))
   cStart := Str(Year(tLast),4)+"-"+StrZero(Month(tLast),2)+"-"+StrZero(Day(tLast),2)+"T00:00:00"
   hList := oCS:Execute("monitoring/notificationEvents","GET",{"startDate"=>cStart}) ["data"]
   
   cList := ""
   FOR EACH hEntry IN hList
      cList += hEntry["company"]["safeNumber"]
      ? ValToPrg(hEntry["company"]) //["safeNumber"]
      ? hEntry["company"]["safeNumber"]
      cs->(dbSetOrder( 2 ))
      IF cs->(dbSeek( "DE001/0/"+hEntry["company"]["safeNumber"] )) .AND. cs->LastCheck <= Date()-1
         oSOAP := CreditSafe()
         oReport := CS_GetCompanyReport(oSoap,cs->ID,3)
         cList += " "+Str(cs->Kunde,6)
         IF oReport != NIL            
            CS_SaveReport(cs->Kunde,oReport)
            cList += " gespeichert"
         ELSE
            cList += " Download fehlgeschlagen"
         ENDIF
      ELSE
         ? "nicht gefunden"
         cList += " nicht gefunden"
      ENDIF
      cList += Chr(13)+Chr(10)
   NEXT
   SetValue("CS_LSTUPD",TtoS(DateTime()))
   IF ! Empty(cList)
      SendMail({{"amos.engelking@engelking.de","Amos"}},"Creditsafe Aktualisierung",cList)
   ENDIF
ELSE   
   SendMail({{"amos.engelking@engelking.de","Amos"}},"Creditsafe Montioring fehlgeschlagen","Login nicht m”glich")
ENDIF


#include 'X:\run\creditsafe_rest.prg'
#include 'X:\run\creditsafe.prg'