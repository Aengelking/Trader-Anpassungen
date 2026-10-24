FUNC AGORUM_ACTION(cAction,cId)
   LOCAL oAgorum
   LOCAL nResponse,cResponse,hData,cData
   LOCAL hMetaData,oAuftrag,oKunde
   CLS

//cId := "518f43d0-8736-11ec-b196-00000a71680a"
//cId := "621688b0-93f4-11ec-b196-00000a71680a"

   ? "Action:",cAction
   ? "UUID:",cId
   cAction := Upper(cAction)

   oAgorum := AgorumCustomApi():New() 
   //oAgorum := AgorumAPi():New()
   //LOCAL hData

   /*IF oAgorum:Connect()
      //Alert("Connected")
   ELSE
      Alert("Not connected")
      RETURN 
   ENDIF
   
   ? ValToPrg(oAgorum:Execute("object/"+Ltrim(Str(nId)),"GET",{"properties[0]"=>"name","properties[1]"=>"historyCount"},.T.,.T.))*/
   //Execute(cUrl,cMethod,hData,lJson,lAsUsr

   //+"?listFileHistoies"
   hData := oAgorum:Execute("engelking.customers.customerService.noauth/"+cId,"GET",hData,@nResponse,@cResponse,@cData)
   ? "Response Body:",ValToPrg( hData  )
   ? "Response Status:",nResponse,cResponse
   IF nResponse == 200 .AND. cAction == "AUFTRAG" //.AND. ! HHasKey(hData,"ag_metadata_collection")
      oAuftrag := Auftrag():New()
      oAuftrag:Load(61067)
      oKunde := Adresse():New()
      oKunde:LoadMatchcode(oAuftrag:Kundma,"K")
      oAdrExtra := ku->(ExtraData():New(oKunde:Nummer))

      //has the address been created on Agorum already?
      IF Empty(oAdrExtra:AgorumID)      
         oAgorum:SaveAddress(oKunde)      
      ENDIF
      hMetaData := {=>}
      hMetaData["ag_metadata_collection"] := "ek_customer_order"
      hMetaData["ek_customer_number"] := LTrim(Str(oKunde:Nummer))
      hMetaData["ek_customer_name"] := Trim(oKunde:cName)
      hMetaData["ek_order_number"] := oAuftrag:Aufnr
      hMetaData["ek_order_date"] := oAuftrag:Besda
      hMetaData["ek_order_confirmation_number"]  := LTrim(Str(oAuftrag:ABNr))
      oAgorum:Execute("engelking.customers.customerService.noauth/?filingFile="+cId,"PUT",hMetaData,@nResponse,@cResponse,@cData)
      IF nResponse != 200
         ? "Error setting metadata",nResponse,cResponse,cData
      ELSE
         ? cData
      ENDIF
   ENDIF
   Sinkey(0)
RETURN NIL