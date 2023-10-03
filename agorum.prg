


PROC Agorum_Test
   LOCAL oCustom := AgorumCustomApi():New() 
   LOCAL oObject,aFiles
   //LOCAL nX
   //LOCAL oAddress,oExtra
   //LOCAL getlist := {},cGroup := "K",cMatchcode := Space(8)
   LOCAL oAddress //,nAddress,aAddresses
   LOCAL cQuery

   LoadModules()

   CLS

   //Matchcode „ndern
   /*oAddress := Adresse():New()
   oAddress:Load(14670)  //
   cOld := oAddress:Kunde
   IF Trim(oAddress:Kunde) == "TEST"
      oAddress:Kunde := "6TEST"      
   ELSE
      oAddress:Kunde := "TEST"
   ENDIF
   ? cOld,"->",oAddress:Kunde   
   IF ! oCustom:ChangeMatchcode(oAddress,cOld)
      ? oCustom:nError,oCustom:cErrorText
   ELSE
      oAddress:Save()
   ENDIF*/
   //Sinkey(0)

   //Adressen aktualisieren
   /*? "Adressen aktualisieren..."
   //aAddresses := GetIdsWithExtraField("KU","AGORUMID")
   aAddresses := {14696}
   FOR EACH nAddress IN aAddresses
      ? nAddress
      oAddress := Adresse():New()
      oAddress:Load(nAddress)
      oCustom:SaveAddress(oAddress)
      IF Inkey() == 27
         EXIT
      ENDIF
   NEXT*/

   //SUCHE TESTEN
   //Kunden
   /*? "Auftragsbest„tigung"
   cQuery := "ek_order_confirmation_number:62832"
   ? ValToPrg(oCustom:Execute("engelking.customers.customerService.noauth/searchFiles?query="+cQuery,"GET"))
   //Lieferanten
   ? "Bestellung"
   cQuery := "ek_order_number:57116"
   ? ValToPrg(oCustom:Execute("engelking.suppliers.supplierService.noauth/searchFiles?query="+cQuery,"GET"))
   Sinkey(0)
   */
   
   //TEST DOKUMENTENABLAGE 
   aFiles := {}
   oObject := Bestellung():New()
   nNr := 56775
   oOBject:Load(nNr)
   Aadd(aFiles,{"BES","Y:\Archive\Bestellungen\Bestellung_"+StrZero(nNr,6)+"__"+Trim(oObject:Liefma)+".pdf",oObject})
   
   //THESE WORKED    
   /*oObject := Quote():New()   
   oOBject:Load(2)
   Aadd(aFiles,{"QT","Y:\Archive\Eeinkaufsngebote\QT000002_RE  Re 2  SPR Gessmann.eml",oObject})*/

   /*oObject := Auftrag():New()
   nNr := 63078
   oObject:Load(nNr)
   Aadd(aFiles,{"AB","Y:\Archive\Auftragsbest„tigungen\AB"+StrZero(nNr,6)+"_.pdf",oObject})*/
   
   /*oObject := Rechnung():New()
   nNr := 65471
   oOBject:Load(nNr)
   Aadd(aFiles,{"LS","Y:\Archive\Lieferscheine\LS"+StrZero(nNr,6)+"_.pdf",oObject})
   Aadd(aFiles,{"RE","Y:\Archive\Rechnungen\RE"+StrZero(nNr,6)+"_.pdf",oObject})
   */
   /*NETUSE("angebot","ang")
   ang->(dbSeek( Str(42413,6) ))
   oObject := ang->(Record():New())      
   Aadd(aFiles,{"ANG","Y:\Archive\Angebote\Angebot_042413__ATBGMBH.pdf",oObject})*/
   
   
   /*? "Dateien werden archiviert... "
   FOR nX := 1 TO Len(aFiles)
      ? aFiles[nX,1],aFiles[nX,2]
      IF oCustom:AddFile(aFiles[nX,1],aFiles[nX,2],aFiles[nX,3])
         ?? " erfolgreich"
      ELSE
         ?? " fehlgeschlagen",oCustom:cErrorText
      ENDIF
   NEXT
   ? "abgeschlossen"*/

   
   /*Head("Adresse in Agorum anlegen")

   NetUse("engkund","ku")
   ku->(dbSetOrder( 2 ))

   @ 01,00 SAY "Gruppe   " GET cGroup VALID cGroup $ {"L","K"}
   @ 02,00 SAY "Matchcode" GET cMatchcode PICTURE "@!" VALID ku->(Findad(cMatchcode,cGroup,02,30))
   READ

   IF LastKey() == 27
      RETURN
   ENDIF
      
   oAddress := Adresse():New(.F.)      
   oExtra := ku->(ExtraData():New(oAddress:Nummer))        

   IF oCustom:SaveAddress(oAddress)
      ? ku->Kunde,"gespeichert"
   ELSE
      ? ku->Kunde,oCustom:cErrorText
   ENDIF*/

   
   /*oAgorum := AgorumAPi():New()
   //LOCAL hData

   Head("Agorum API Test")
   IF oAgorum:Connect()
      Alert("Connected")
   ELSE
      Alert("Not connected")
      RETURN 
   ENDIF*/
   //? ValToPrg(oAgorum:Execute("object","GET",{"provider"=>"search","query"=>"Volvo*","properties[0]"=>'name',"properties[1]"=>"baseName"}))
/**/
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
   Sinkey(0)
RETURN
/*
#include '\\ek-server4\data\hb34\include\hbclass.ch'
#include '\\ek-server4\data\hb34\contrib\hbcurl\hbcurl.ch'


CLASS AgorumCustomAPi FROM RestAPI

   METHOD SaveAddress
   METHOD DeleteAddress
   METHOD ChangeMatchcode
   METHOD AddFile
   METHOD Search

   METHOD Execute
   METHOD New

   DATA cBaseUrl
   DATA cToken

   DATA cErrorText INIT ""
   DATA cErrorType INIT ""
   DATA nError     INIT 0

   DATA hMap       INIT  {;
      "AB"=>{"service"=>"customer","collection"=>"ek_customer_order_confirmation","meta_no"=>"ek_order_confirmation_number"},;      
      "BES"=>{"service"=>"supplier","collection"=>"ek_supplier_order","meta_no"=>"ek_order_number"},;
      "LS"=>{"service"=>"customer","collection"=>"ek_customer_delivery_note","meta_no"=>"ek_delivery_note_number"},;
      "RE"=>{"service"=>"customer","collection"=>"ek_customer_invoice","meta_no"=>"ek_invoice_number"},;
      "QT"=>{"service"=>"supplier","collection"=>"ek_supplier_offer","meta_no"=>"ek_offer_number"},;
      "ANG"=>{"service"=>"customer","collection"=>"ek_customer_offer","meta_no"=>"ek_offer_number"};
   }
ENDCLASS

METHOD New CLASS AgorumCustomAPi
//   ::cApiKey := GetValue("NOCRM_APIKEY","ff10f687005e643fc6a53f01cd06a646a5440986af412916","API Key set in noCRM")
   ::cBaseUrl := "http://engelking.intern.agorumcloud.com/api/rest/custom/"
   
   ::cToken := GetValue("AGORUM_CUSTOM_TOKEN","","Token for the agorum custom API")

    
RETURN ::Super:New()

METHOD ChangeMatchcode(oAddress,cOldMatch) CLASS AgorumCustomApi
   //LOCAL oExtra := ku->(ExtraData():New(oAddress:Nummer)) 
   LOCAL nResponse,cResponse,cData
   ::Execute("engelking."+AC_ADR_TYPE+"s."+AC_ADR_TYPE+"Service.noauth/editMatchcode","PUT",{"oldMatchCode"=>Trim(cOldMatch),"newMatchCode"=>Trim(oAddress:Kunde)},@nResponse,@cResponse,@cData)
   IF nResponse == 404
      ::cErrorText := "Adresse nicht vorhanden"
      ::nError     := 1
      RETURN .F.
   ELSEIF nResponse == 405
      ::cErrorText := "Methode nicht erlaubt"
      ::nError     := 2
      RETURN .F.
   ELSEIF nResponse == 422
      ::cErrorText := "Nicht verarbeitbar"
      ::nError     := 2
      RETURN .F.
   ELSEIF nResponse != 200
      ::cErrorText := "Unbekannter Fehler. "+cData
      ::nError     := 4
      RETURN .F.
   ENDIF
RETURN .T.

METHOD SaveAddress(oAddress) CLASS AgorumCustomApi
   LOCAL oExtra := ku->(ExtraData():New(oAddress:Nummer)) 
   LOCAL hContacts,hContact
   LOCAL hData := {=>}
   LOCAL cResponse,nResponse
   LOCAL cUUID,hRet


   ::nError := 0
   ::cErrorText := ""
   ::cErrorType := ""

   IF ! oAddress:Group $ {"K","L"}  //we can only save customers and suppliers
      ::nError := 4
      ::cErrorText := "Wrong address group "+oAddress:Group
      RETURN .F.
   ENDIF

   hData["ek_"+AC_ADR_TYPE+"_name"] := hb_strtoutf8(Trim(Trim(oAddress:Name1)+" "+oAddress:Name2))
   hData["ek_"+AC_ADR_TYPE+"_number"] := LTrim(Str(oAddress:Nummer,6)) //+100000
   hData["ek_matchcode"] := hb_strtoutf8( Trim(oAddress:Kunde) )
   hData["ek_"+AC_ADR_TYPE+"_mail_addresses"] := {}
   IF ! Empty(oAddress:Email)
      Aadd(hData["ek_"+AC_ADR_TYPE+"_mail_addresses"],Trim(oAddress:Email))      
   ENDIF
   oAddress:GotoRec()
   hContacts := GetAddressContacts(.F.,.T.)
   FOR EACH hContact IN hContacts
      IF ! Empty(hContact["email"]) .AND. ! Trim(hContact["email"]) $ hData["ek_"+AC_ADR_TYPE+"_mail_addresses"]
         Aadd(hData["ek_"+AC_ADR_TYPE+"_mail_addresses"],Trim(hContact["email"]))         
      ENDIF
   NEXT


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
      ELSEIF hRet["ek_matchcode"] != Trim(oAddress:Kunde)  //Matchcode wurde ge„ndert
         //Matchcode wird auch in Agorum ge„ndert, jedoch wird der Ordner nicht verschoben
      ENDIF         
   ENDIF
   //Alert(HB_JsonEncode(hData))
   hUUID := ::Execute("engelking."+AC_ADR_TYPE+"s."+AC_ADR_TYPE+"Service.noauth"+IF(!Empty(oExtra:AgorumId),"/"+Trim(oExtra:AgorumId),""),IF(!Empty(oExtra:AgorumId),"PUT","POST"),hData,@nResponse,@cResponse)
   //Alert(Str(nResponse)+ValToPrg(hUUID))
   IF hUUID == NIL .AND. nResponse > 299
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
      IF nResponse == 201  .AND. ! Empty(hUUID['uuid']) //created         
         oExtra:AgorumId := hUUID['uuid']
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

METHOD Search(cDocType,nNo)
   LOCAL cQuery
   IF cDocType $ ::hMap
      cQuery := ::hMap[cDocType]["meta_no"]+":"+LTrim(Str(nNo))
      //Alert(cQuery)
      //Alert(::cBaseUrl+'engelking.'+::hMap[cDocType]["service"]+'s.'+::hMap[cDocType]["service"]+'Service.noauth/searchFiles?query='+cQuery)
      RETURN ::Execute('engelking.'+::hMap[cDocType]["service"]+'s.'+::hMap[cDocType]["service"]+'Service.noauth/searchFiles?query='+cQuery,"GET")
   ENDIF
RETURN {}


METHOD AddFile(cDocType,cFile,oObject)
   LOCAL oAddress
   LOCAL hData,hTargetData
   LOCAL nResponse,cResponse
   LOCAL oAdrExtra
   LOCAL cCmd,cData,nStdOut,cLine,nBytes,nProc
   LOCAL cFileName
   LOCAL oACD
   LOCAL cNo,nNo
   LOCAL cItem,cKey,lBody,aMatch,cBody
   LOCAL lUpDate := .F.

   IF ! cDocType $ ::hMap
      RETURN .F.
   ENDIF


   IF cDocType == "AB"
      oAddress  := oObject:Kunde
      nNo       := oObject:AbNr      
   ELSEIF cDocType == "ANG"
      oAddress := Adresse():New()
      oAddress:LoadMatchcode(oObject:Kundma,"K")
      nNo       := oObject:Angnr
   ELSEIF cDocType == "BES"
      oAddress := oObject:oLieferant
      nNo       := oObject:BesNr  
   ELSEIF cDoctype $ {"LS","RE"}
      oAddress := oObject:oRechnungsAdresse      
      nNo       := oObject:Rechnr      
   ELSEIF cDoctype == "QT"
      oAddress := Adresse():New()
      oAddress:LoadMatchcode(oObject:Liefma,"L")
      nNo := oObject:No
      cNo := Trim(oObject:QuoteNo)
   ENDIF
   
   IF ! cDocType $ {"QT"}
      cNo := LTrim(Str(nNo))
   ENDIF

   
   //Documententyp fehlt in Agorum
   //"ANG"  done
   //"PI" 
   //BA  (Belastungsanzeige) 
   //TA (Termin„nderung) -> (oder sollen wir das als Auftragsbest„tigung archivieren)
   //KA (Kreditauskunft)
   //"COC"=> (Werksbescheinigung)
   
   //Wird aktuell noch nicht archiviert, muss noch in Trader implementiert werden, kann daher nicht getestet werden
   //Liefermahnung (Ausgehend)  

   //Was machen wir hiermit
   //"NT"=>{"PREFIX"=>"NT","NAME"=>"Notiz","DIR"=>HB_AnsiToOem("Notizen"),"KEEPFOR"=>6},;

   //Die hier sollten direkt aus Agorum archiviert werden
   //"AUF"=>{"PREFIX"=>"AUF","NAME"=>"Auftrag","DIR"=>HB_AnsiToOem("Aufträge"),"KEEPFOR"=>6},;
   //"AUFMAHN"=>{"PREFIX"=>"AUFMAHN","NAME"=>"Mahhnung","DIR"=>HB_AnsiToOem("Auftragsmahnung"),"KEEPFOR"=>6},;
   //"ANF"=>{"PREFIX"=>"ANF_","NAME"=>"Anfrage","DIR"=>"Anfragen","KEEPFOR"=>6},;
   //"BB"=>{"PREFIX"=>"BB","NAME"=>"Bestellbestätigung","DIR"=>HB_AnsiToOem("Bestellbestätigungen"),"KEEPFOR"=>6},;
   //ER (Eingangsrechnung)         
   

   

   IF ! File(cFile)
      ::cErrorText := "File not found"
      RETURN .F.
   ENDIF

   NetUse("ac_doc","acd")

   IF ! acd->(dbSeek(Pad(cDocType,7)+Str(nNo,6)))
      oACD := acd->(Record():New(.T.))
      oACD:DocType := cDocType
      oACD:No := nNo      
   ELSE  //aktualiserung vom Dokument noch nicht untersttzt
      oACD := acd->(Record():New(.F.))
      oACD:UpToDate := .F.
      oACD:Save()   
      IF ! Empty(oACD:UUID)
         lUpdate := .T.   
         Alert("Update "+oACD:UUID)             
      ENDIF
   ENDIF

   oAdrExtra := ku->(ExtraData():New(oAddress:Nummer))

   //has the address been created on Agorum already?
   IF Empty(oAdrExtra:AgorumID)      
      ::SaveAddress(oAddress)      
   ENDIF

   oAddress:gotoRec()


   hData := {;     
      "ek_matchcode"=>Trim(oAddress:Kunde),;      
      "ek_"+AC_ADR_TYPE+"_number"=>LTrim(Str(oAddress:Nummer)),; 
      ::hMap[cDocType]["meta_no"]=>cNo,;          
      "ag_metadata_collection"=>::hMap[cDocType]["collection"]}

      //"ek_"+AC_ADR_TYPE+"name"=>HB_StrToUtf8(Trim(oAddress:Name1+" "+Trim(oAddress:Name2))),;     

   //on the invoice we can save a little bit more information
   IF cDoctype == "RE"
      hData["invoice_vat_rate"] := oObject:MwStRate
      hData["invoice_vat_amount"] := oObject:MwSt
      hData["invoice_gross_amount"] := oObject:Brutto
      hData["invoice_net_amount"] := oObject:Brutto-oObject:MwSt
      hData["invoice_date"] := oObject:Rechdat
   ELSEIF cDocType == "BES"
      //hData["ek_delivery_note_date"] := Date()
   ENDIF

   HB_FNameSplit(cFile,,@cFileName)
   //upload file
   //to do this via the curl lib, the curl lib nees updating
   cCmd := "C:\Curl\bin\curl -X POST -k -i "
   cCmd += ' -H "Authorization: Bearer '+::cToken+'"'      
   FOR EACH cItem IN hData  
      cKey := cItem:__eNumKey()
      IF "[" $ cKey
         cKey := SubStr(cKey,1,RAt("[",cKey)-1)
      ENDIF
      IF ValType(cItem) != "C"
         cItem := hb_jsonEncode(cItem)
      ENDIF
      cCmd += ' -F "'+cKey+"="+cItem+'"'
   NEXT           
   cCmd += ' -F "file"=@"'+cFile+'"' //'+cFileName+'
   cCmd += ' '+::cBaseUrl+'engelking.'+::hMap[cDocType]["service"]+'s.'+::hMap[cDocType]["service"]+'Service.noauth/'+IF(!lUpdate,'addFile','?updateFile='+oACD:UUID) //upload?uploadTarget='+hTargetData["uploadTarget"]

   //read the header & body from the call
   cData := ""
   nStdOUT := 0
   nProc := HB_OpenProcess(cCmd,,@nStdOut,,.T.)
   lBody := .F.
   nResponse := 0
   cResponse := ""
   cBody := ""
   DO WHILE HB_ProcessValue(nProc,.F.) == -1
      cLine := Space( 1000 )
      nBytes := Fread( nStdOUT, @cLine, Len(cLine) )         
      cData += SubStr(cLine,1,nBytes)        
   ENDDO

   FOR nX := 1 TO MlCount(cData)
      cLine := MemoLine(cData,,nX)
      IF ! lBody         
         IF nResponse == 0
            aMatch := HB_Regex('HTTP/[0-9\.]+ ([0-9]+) (.*)',cLine)
            IF Len(aMatch) > 1
               nResponse := Val(aMatch[2])
               cResponse := aMatch[3]
            ENDIF
         ELSEIF Empty(cLine)               
            IF nResponse == 100                  
               nResponse := 0
            ELSE
               lBody := .T.
            ENDIF
         ENDIF
      ELSE
         cBody += cLine
      ENDIF
   NEXT
   
   //save returned UUID of the document   
   IF nResponse == 200 //.AND. ! Empty(cData)       
      Alert(cData)
      IF ! lUpDate
         oACD:UUID := cBody 
      ENDIF
      oACD:UpToDate := .T.
      oACD:Save()
      RETURN .T. //success
   ELSEIF nResponse == 404 .AND. lUpDate //file does not exist any more
      oACD:UUID := ""
      oACD:UpToDate := .F.
      oACD:Save()
      
      RETURN ::AddFile(cDocType,cFile,oObject) //try again as new
   ELSE
      ::cErrorText := "Error uploading file. "+Str(nResponse)+" "+cResponse+cBody
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

FUNCTION EncodeFormData(hData)
   LOCAL cItem,cKey
   LOCAL cPostData := ""
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
RETURN cPostData*/


/*************************************************************************************************************/
/*
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

   hData := ::Execute("session","POST",{"username"=>"Administrator","password"=>"abiftae"},.T.,.F.) 
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
      cPostData := EncodeFormData(hData)
      
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
RETURN aReturn*/