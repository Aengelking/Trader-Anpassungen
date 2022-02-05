#define AC_ADR_TYPE IF(oAddress:Group=="L","supplier","customer")

PROC Agorum_Test
   LOCAL oCustom := AgorumCustomApi():New() 
   //LOCAL oAuftrag  
   LOCAL oAddress,oExtra
   LOCAL getlist := {},cGroup := "K",cMatchcode := Space(8)

   CLS

   /*
   //TEST DOKUMENTENABLAGE 
   oAuftrag := Auftrag():New()
   oAuftrag:Load(53223)

   ? "Datei wird archiviert... "
   
   IF oCustom:AddFile("AB",53223,"Y:\Archive\Auftragsbest„tigungen\AB053223.pdf",oAuftrag)
      ?? "erfolgreich"
   ELSE
      ?? "fehlgeschlagen"
   ENDIF*/
   
   Head("Adresse in Agorum anlegen")

   NetUse("engkund","ku")
   ku->(dbSetOrder( 2 ))

   @ 01,00 SAY "Gruppe   " GET cGroup VALID cGroup $ {"L","K"}
   @ 02,00 SAY "Matchcode" GET cMatchcode PICTURE "@!" VALID ku->(Findad(cMatchcode,cGroup,02,30))
   READ

   IF LastKey() == 27
      RETURN
   ENDIF
      
   //ku->(dbSeek( "L" ))
   //DO WHILE ku->Group $ {"L","K"} .AND. ku->Kunde < "B"
      oAddress := Adresse():New(.F.)      
      oExtra := ku->(ExtraData():New(oAddress:Nummer))        

      //IF ku->Turnover+ku->TurnoverOL != 0 //during test we only create addresses beeing used
         IF oCustom:SaveAddress(oAddress)
            ? ku->Kunde,"gespeichert"
         ELSE
            ? ku->Kunde,oCustom:cErrorText
         ENDIF
      /*ELSEIF ! Empty(oExtra:AgorumID)
         ? ku->Kunde,""
         IF oCustom:DeleteAddress(oAddress) ///nResponse == 200
            ?? "gel”scht"
         ELSE
            ?? "Fehler",oCustom:cErrorText //nResponse
         ENDIF
         oExtra:AgorumID := ""
         oExtra:Save()
      ENDIF
      ku->(dbSkiP())
   ENDDO*/

   
   /*LOCAL oAgorum := AgorumAPi():New()
   LOCAL hData

   Head("Agorum API Test")
   IF oAgorum:Connect()
      Alert("Connected")
   ELSE
      Alert("Not connected")
      RETURN 
   ENDIF
   //? ValToPrg(oAgorum:Execute("object","GET",{"provider"=>"search","query"=>"Volvo*","properties[0]"=>'name',"properties[1]"=>"baseName"}))

   //#define WAIT ? ValToPrg(hData);? "Press any key...";  Sinkey(0)

   //Create an address data object
   /*hData := oAgorum:Execute("object","POST",{"handler"=>"object","properties"=>"target","data"=>{;
      "createtarget"=>.F.,;      
      "name"=>"Test-Trader",;
      "classname"=>"d4wAddressData",;      
      "country"=>"DE",;
      "street1"=>"Albstrasse 16",;
      "city"=>"Tuningen",;
      "zip"=>"78606";
   }})

   WAIT

   //Create an organisation
   hData := oAgorum:Execute("object","POST",{"handler"=>"object","properties"=>"d4wAddressData","data"=>{;
      "createtarget"=>.F.,;
      "name"=>"Test-Trader2",;
      "classname"=>"D4wAddressOrganisation",;
      "target"=>"/agorum/roi/Files",;
      "d4wAddressData"=>Val(hData["data"]["id"]);      <-- this did not work!
   }}) */

   //Alert(MemoRead("Y:\Archive\Rechnungen\RE059852.pdf"))
/*
   hData := oAgorum:Execute("object","POST",{"handler"=>"object","data"=>{;
      "createtarget"=>.F.,;
      "name"=>"RE059852.txt",;
      "classname"=>"FileObject",;
      "target"=>"/agorum/roi/Files",;
      "contentString"=>"Hello World"; //MemoRead("Y:\Archive\Rechnungen\RE059852.pdf")
   }})*/
   
   WAIT
RETURN

#include 'y:\hb34\include\hbclass.ch'
#include 'y:\hb34\contrib\hbcurl\hbcurl.ch'

CLASS AgorumAPi
   METHOD Execute
   METHOD New

   METHOD Connect   

   DATA cBaseUrl
   DATA cSessionId

   DATA cErrorText
   DATA cErrorType
   DATA nError
ENDCLASS

METHOD New CLASS AgorumAPi
//   ::cApiKey := GetValue("NOCRM_APIKEY","ff10f687005e643fc6a53f01cd06a646a5440986af412916","API Key set in noCRM")
   ::cBaseUrl := "https://engelking.intern.agorumcloud.com/api/rest/" //GetValue("AGORUM_URL","https://192.168.56.101/api/rest/","URL of the Agorum instance")
RETURN ::Super:New()


METHOD Connect CLASS AgorumAPi
   
   LOCAL hData

   hData := ::Execute("session","POST",{"username"=>"Administrator","password"=>""},.T.,.F.) 
   IF ! HHasKey(hData,"success") .OR. ! hData["success"]
      ::cSessionId := ""
      RETURN .F.
   ENDIF     
   ::cSessionId := hData["sessionId"]
   
RETURN .T.

METHOD Execute(cUrl,cMethod,hData,lJson,lAsUsr) CLASS AgorumAPi
   LOCAL cData,cItem
   LOCAL aReturn
   LOCAL cPostData
   LOCAL oErr
   LOCAL pCurl
   LOCAL aHeader,nRet,cKey

   Default(@cMethod,"GET")
   Default(@lJson,.T.)
   Default(@lAsUsr,.T.)
   Default(@hData,{=>})

   aHeader := {} //"X-API-KEY: "+IF(lAsUsr .AND. ! Empty(::cUsrToken),::cUsrToken,::cApiKey)}

   IF lAsUsr
      hData["sessionId"] := ::cSessionId
   ENDIF

   pCurl := Curl_Easy_Init()

   curl_easy_setopt(pCurl, HB_CURLOPT_SSL_VERIFYPEER,0)
   
   IF cMethod == "POST" 
      curl_easy_setopt(pCurl, HB_CURLOPT_POST, 1)      
   ELSEIF cMethod != "GET"
      curl_easy_setopt(pCurl, HB_CURLOPT_CUSTOMREQUEST, cMethod)                    
   ENDIF
   IF lJson
      Aadd( aHeader, "Accept: application/json" ) 
   ENDIF
   curl_easy_setopt(pCurl, HB_CURLOPT_DL_BUFF_SETUP )
    
   curl_easy_setopt(pCurl, HB_CURLOPT_HTTPHEADER, aHeader )          

   IF ! Empty(hData)
      cPostData := ""
      FOR EACH cItem IN hData  
         IF cItem:__eNumIndex() > 1
               cPostData += "&"
         ENDIF
         cKey := cItem:__eNumKey()
         IF "[" $ cKey
            cKey := SubStr(cKey,1,RAt("[",cKey)-1)
         ENDIF
         IF ValType(cItem) != "C"
            cItem := hb_jsonEncode(cItem)
         ENDIF
         cPostData += tip_URLEncode(cKey)+"="+tip_URLEncode(cItem)
      NEXT
    
      IF cMethod == "GET"           
         cUrl += "?"+cPostData
      ELSE              
         //Alert(cPostData)
         curl_easy_setopt(pCurl, HB_CURLOPT_POSTFIELDS, cPostData )         
      ENDIF    
   ENDIF

   //remove this later to verify the SSL certificate
   curl_easy_setopt(pCurl, HB_CURLOPT_SSL_VERIFYPEER , 0)
   curl_easy_setopt(pCurl, HB_CURLOPT_SSL_VERIFYHOST, 0 )

   curl_easy_setopt(pCurl, HB_CURLOPT_URL, ::cBaseUrl+cUrl )
   nRet := Curl_Easy_Perform(pCurl)
   IF nRet != 0
        oErr := ErrorNew()
        oErr:SubSystem   := "AGORUM-API"
        oErr:Description := "Error connecting to server. Curl Error: "+LTrim(Str(nRet))
        oErr:Args        := {cUrl,cData}
        Throw(oErr)   
   ENDIF

   curl_easy_setopt(pCurl, HB_CURLOPT_DL_BUFF_GET, @cData )   
   Curl_Easy_CleanUp(pCurl)

   IF ! lJson
      RETURN cData
   ENDIF

   aReturn := HB_JSonDecode(cData)      
   
   IF ! Valtype(aReturn) $ "AH" .OR. Len(aReturn) == 0
      oErr := ErrorNew()
      oErr:SubSystem   := "AGORUM-API"
      oErr:Description := "Error executing command. "+cData
      oErr:Args        := {cUrl,cData}
      Throw(oErr)   
   ELSEIF ValType(aReturn) == "H" .AND. HHasKey(aReturn,"success") .AND. ! aReturn["success"]
      oErr := ErrorNew()
      oErr:SubSystem   := "AGORUM-API"
      oErr:Description := aReturn["message"]
      //oErr:nError := aReturn["errorCode"]
      //oErr:cErrorType := aReturn["errorClass"]
      Throw(oErr)      
   ENDIF
RETURN aReturn


CLASS AgorumCustomAPi FROM RestAPI

   METHOD SaveAddress
   METHOD DeleteAddress
   METHOD AddFile

   METHOD Execute
   METHOD New

   DATA cBaseUrl
   DATA cToken

   DATA cErrorText
   DATA cErrorType
   DATA nError
ENDCLASS

METHOD New CLASS AgorumCustomAPi
//   ::cApiKey := GetValue("NOCRM_APIKEY","ff10f687005e643fc6a53f01cd06a646a5440986af412916","API Key set in noCRM")
   ::cBaseUrl := "http://engelking.intern.agorumcloud.com/api/rest/custom/"
   
   ::cToken := GetValue("AGORUM_CUSTOM_TOKEN","","Token for the agorum custom API")
RETURN ::Super:New()

METHOD SaveAddress(oAddress) CLASS AgorumCustomApi
   LOCAL oExtra := ku->(ExtraData():New(oAddress:Nummer)) 
   LOCAL hData := {=>}
   LOCAL cResponse,nResponse
   LOCAL hRet

   ::nError := 0
   ::cErrorText := ""
   ::cErrorType := ""

   hData["ek_"+AC_ADR_TYPE+"_name"] := Trim(Trim(oAddress:Name1)+" "+oAddress:Name2)
   hData["ek_"+AC_ADR_TYPE+"_number"] := LTrim(Str(oAddress:Nummer,6)) //+100000
   hData["ek_matchcode"] := hb_strtoutf8( oAddress:Kunde )

   IF ! Empty(oExtra:AgorumID)  //Prfen ob der Eintrag wirklich vorhanden ist
      hRet := ::Execute("engelking."+AC_ADR_TYPE+"s."+AC_ADR_TYPE+"Service.noauth/"+Trim(oExtra:AgorumId),"GET",,@nResponse,@cResponse)
      IF nResponse == 404  //nicht gefunden, Referenz l”schen, dies k”nnte verwaiste Eintr„ge in AC erzeugen - eine einder L”sung gibt es aber nicht
         oExtra:AgorumId := ""
         oExtra:Save()
      ELSEIF hRet == NIL
         ::cErrorText := "Unbekannter Fehler ("+Ltrim(Str(nResponse))+" "+cResponse+")"
         ::nError     := 1
         RETURN .F.
      ELSEIF ! HHasKey(hRet,"ek_"+AC_ADR_TYPE+"_number") //wahrscheinlich wurde der Typ ge„ndert
         //in diesem Fall wird die Adresse neu angelegt
         oExtra:AgorumId := ""
         oExtra:Save()
      ELSEIF Val(hRet["ek_"+AC_ADR_TYPE+"_number"]) != oAddress:Nummer  //Adressnr. stimmt nicht berein
         //in diesem Fall wird die Adresse neu angelegt
         oExtra:AgorumId := ""
         oExtra:Save()
      ELSEIF hRet["ek_matchcode"] != oAddress:Kunde  //Matchcode wurde ge„ndert
         //Matchcode wird auch in Agorum ge„ndert, jedoch wird der Ordner nicht verschoben
      ENDIF         
   ENDIF
   hRet := ::Execute("engelking."+AC_ADR_TYPE+"s."+AC_ADR_TYPE+"Service.noauth"+IF(!Empty(oExtra:AgorumId),"/"+Trim(oExtra:AgorumId),""),IF(!Empty(oExtra:AgorumId),"PUT","POST"),hData,@nResponse,@cResponse)
   IF hRet == NIL .AND. nResponse > 299
      IF nResponse == 404 //nicht vorhanden, kann eigenlich nicht vorkommen, da wir das oben geprft haben
         ::cErrorText := "Adresse wurde gel”scht"
         ::nError := 2
         RETURN .F.
      ELSEIF nResponse == 409  //Conflict error, d.h. der Matchcode ist bereits vorhanden
         ::cErrorText := "Matchcode bereits vorhanden"
         ::nError := 3
         RETURN .F.
      ELSE
         ::cErrorText := "Unbekannter Fehler ("+Ltrim(Str(nResponse))+" "+cResponse+")"
         ::nError     := 1
         RETURN .F.
      ENDIF
   ELSE
      IF nResponse == 201  //created
         oExtra:AgorumId := hRet["uuid"]
         oExtra:Save()
      ELSE
         //updated current record
      ENDIF
   ENDIF
RETURN .T.

METHOD DeleteAddress(oAddress) CLASS AgorumCustomApi
   LOCAL oExtra := ku->(ExtraData():New(oAddress:Nummer)) 
   LOCAL nResponse,cResponse

   IF Empty(oExtra:AgorumId)
      ::cErrorText := "Kein Eintrag in Agorum Core"
      ::nError := 2
      RETURN .F.
   ENDIF

   ::Execute("engelking."+AC_ADR_TYPE+"s."+AC_ADR_TYPE+"Service.noauth/"+Trim(oExtra:AgorumId),"DELETE",,@nResponse,@cResponse)
   oExtra:AgorumID := ""
   oExtra:Save()
   IF nResponse == 200; //l”schen erfolgreih      
      .OR. nResponse == 404 //nicht gefunden, muss schon gel”scht sein
      RETURN .T.
   ENDIF
   ::cErrorText := "Unbekannter Fehler ("+Ltrim(Str(nResponse))+" "+cResponse+")"
   ::nError     := 1
   
RETURN .F.

METHOD AddFile(cDocType,nNo,cFile,oObject)
   LOCAL oAddress
   LOCAL hData,hTargetData
   LOCAL nResponse,cResponse
   LOCAL oAdrExtra
   LOCAL cCmd,cData,nStdOut,cLine,nBytes,nProc
   LOCAL cFileName
   LOCAL oACD
   LOCAL hMap := {;
      "AB"=>{"collection"=>"ek_customer_order_confirmation","meta_no"=>"ek_order_confirmation_number"},;
      "BES"=>{"coolection"=>"supplier_order","meta_no"=>"ek_order_number"},;
      "LS"=>{"coolection"=>"customer_delivery_note","meta_no"=>"ek_delivery_note_number"},;
      "RE"=>{"coolection"=>"","meta_no"=>"ek_invoice_number"};
   }   

   /*
   ANG
   BA
   PI
   TA
   KA
   ER      
   
   ?Liefermahnung (Ausgehend) 
   Bestellnummer(n) ek_order_numbers Liste, Text 
   */

   IF ! cDocType $ hMap
      RETURN .F.
   ENDIF

   NetUse("ac_doc","acd")

   IF cDocType == "AB"
      oAddress := oObject:Kunde
   ELSEIF cDocType == "BES"
      oAddress := oObject:oLieferant
   ELSEIF cDoctype $ {"LS","RE"}
      oAddress := oObject:oRechnungsAdresse      
   ENDIF   


   IF ! acd->(dbSeek(Pad(cDocType,7)+Str(nNo,6)))
      oACD := acd->(Record():New(.T.))
      oACD:DocType := cDocType
      oACD:No := nNo
   ELSE  //aktualiserung vom Dokument noch nicht untersttzts
      oACD := acd->(Record():New(.F.))
      oACD:UpToDate := .F.
      oACD:Save()
      RETURN .F.
//      oACD := acd->(Record():New(.F.))
   ENDIF

   oAdrExtra := ku->(ExtraData():New(oAddress:Nummer))

   //has the address been created on Agorum already?
   IF Empty(oAdrExtra:AgorumID)
      ::SaveAddress(oAddress)
   ENDIF

   hData := {;
      "ek_matchcode"=>oAddress:Kunde,;
      "ek_"+AC_ADR_TYPE+"_number"=>LTrim(Str(oAddress:Nummer)),;
      "ek_"+AC_ADR_TYPE+"name"=>HB_StrToUtf8(Trim(oAddress:Name1+" "+Trim(oAddress:Name2))),;
      hMap[cDocType]["meta_no"]=>LTrim(Str(nNo)),;
      "ag_metadata_collection"=>hMap[cDocType]["collection"]}

   //on the onvoice we can save a little bit more information
   IF cDoctype == "RE"
      hData["invoice_vat_rate"] := oObject:MwStRate
      hData["invoice_vat_amount"] := oObject:MwSt
      hData["invoice_gross_amount"] := oObject:Brutto
      hData["invoice_net_amount"] := oObject:Brutto-oObject:MwSt
      hData["invoice_date"] := oObject:Rechdat
   ENDIF
   

   //upload metadata
   hTargetData := ::Execute("engelking.customers.customerService.noauth/upload","POST",hData,@nResponse,@cResponse)

   IF nResponse == 200
      HB_FNameSplit(cFile,,@cFileName)

      //upload file
      //to do this via the curl lib, the curl lib nees updating
      cCmd := "C:\Curl\bin\curl -X POST -k "
      cCmd += ' -H "Authorization: Bearer '+::cToken+'"'
      cCmd += ' -F "'+cFileName+'"=@"'+cFile+'"'
      cCmd += ' '+::cBaseUrl+'engelking.customers.customerService.noauth/upload?uploadTarget='+hTargetData["uploadTarget"]

      //read the body from the call
      cData := ""
      nStdOUT := 0
      nProc := HB_OpenProcess(cCmd,,@nStdOut,,.T.)
      DO WHILE HB_ProcessValue(nProc,.F.) == -1
         cLine := Space( 1000 )
         nBytes := Fread( nStdOUT, @cLine, Len(cLine) )
         cData += SubStr(cLine,1,nBytes)        
      ENDDO
      
      //save returned UUID of the document
      hData := HB_JSonDecode(cData)
      IF HHasKey(hData,"uuids") .AND. Len(hData["uuids"]) > 0
         oACD:UUID := hData["uuids"][1]
         oACD:UpToDate := .T.
         oACD:Save()
         RETURN .T. //success
      ENDIF
   ENDIF
RETURN .F.


METHOD Execute(cUrl,cMethod,hData,nResponse,cResponse,cData,cFile) CLASS AgorumCustomAPi
   LOCAL aReturn
   LOCAL aHeader

   Default(@cMethod,"GET")
   Default(@hData,{=>})

   aHeader := {} //"X-API-KEY: "+IF(lAsUsr .AND. ! Empty(::cUsrToken),::cUsrToken,::cApiKey)}

   Aadd(aHeader,"Authorization: Bearer "+::cToken)  //token cannot be saved in the Keychain as it is too long

   Aadd( aHeader, "Content-Type: application/json" )    
   Aadd( aHeader, "Accept: application/json" ) 
   
   //remove this later to verify the SSL certificate   
   ::lVerifySSL := .F.
   
   cData := ::Super:Execute(cUrl,cMethod,hData,aHeader,.T.,@nResponse,@cResponse,cFile)

   IF nResponse > 299
      RETURN NIL
   ENDIF

   aReturn := HB_JSonDecode(cData)      
   
RETURN aReturn