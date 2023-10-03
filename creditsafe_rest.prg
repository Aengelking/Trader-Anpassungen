#include 'hbclass.ch'

PROC Test_CSRest
   LOCAL oCS := CreditSafeApi():New()
   LOCAL tLast := StoT("20230427000000"),cStart
   IF oCS:Auth()
      Alert("Login successful")
      //Alert(ValToPRg(oCS:SyncMonitoringPortfolio(647123,"x:\export\csmonitor.csv","amos.engelking@engelking.de")))
      Alert(TtoC(tLast))
      cStart := Str(Year(tLast),4)+"-"+StrZero(Month(tLast),2)+"-"+StrZero(Day(tLast),2)+"T"+Right(TtoC(tLast),5)+":00"
      Alert(cStart)
      Alert(ValToPRg(oCS:Execute("monitoring/notificationEvents","GET",{"startDate"=>cStart}))) //,"endDate"=>TtoS(DateTime())})))
   ELSE
      Alert("Login failed")
   ENDIF
RETURN


CLASS CreditSafeApi FROM RestAPI
   METHOD New
   METHOD Auth
   METHOD Execute
   METHOD SyncMonitoringPortfolio
   
   DATA cToken

   PROTECTED:
   DATA cKeyName INIT "CS_API"
END CLASS

METHOD New()
   ::cBaseUrl := "https://connect.creditsafe.com/v1/" //GetValue("CS_URL","https://egl.teufels-werk.de/api/","URL of the Shopware installation")
RETURN ::Super:New()

METHOD SyncMonitoringPortfolio(nPortfolio,cFile,cEmail)
   Local cCmd,cData,cLine,nStdOUT,nProc,nBytes
   cCmd := '"C:\Program Files\curl\bin\curl.exe" -H "Authorization: Bearer '+::cToken+'" -X POST -k -F importCSV=@"'+cFile+'" '
   IF ! Empty(cEmail)
      cCmd += "-F email="+cEmail
   ENDIF
   cCmd += " "+::cBaseUrl+'monitoring/portfolios/'+Ltrim(Str(nPortFolio))+'/sync'

   cData := ""
   nProc := HB_OpenProcess(cCmd,,@nStdOut,,.T.)
   DO WHILE HB_ProcessValue(nProc,.F.) == -1
      cLine := Space( 1000 )
      nBytes := Fread( nStdOUT, @cLine, Len(cLine) )
      cData += SubStr(cLine,1,nBytes)
   ENDDO
RETURN HB_JsonDecode(cData)

METHOD Auth()   
   LOCAL hResponse := ::Execute("authenticate","POST",{"username" => "$USERNAME$","password" => "$PASSWORD$"}) 
   IF ValType(hResponse) == "H" .AND. hHasKey(hResponse,"token")
      ::cToken := hResponse["token"]
      RETURN .T.
   ELSE
      Alert(ValToPrg(hResponse))
   ENDIF
RETURN .F.

METHOD Execute(cUrl,cMethod,hData)
   LOCAL aHeaders := {'Content-Type: application/json'}

   IF ! Empty(::cToken)
      Aadd(aHeaders,"Authorization: Bearer "+::cToken)
   ENDIF

RETURN HB_JsonDecode( ::Super:Execute(cUrl,cMethod,hData,aHeaders,.T.) )


   
