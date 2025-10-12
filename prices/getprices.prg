
FUNCTION GetPricesCompet(cLief,lDbg,nError)
   LOCAL hPrices
   LOCAL nAliRec := ali->(Recno())
   LOCAL nKurec := ku->(Recno())
   LOCAL oExtra,oApi,cData,nSecs,hData,hPrice,cUrl
   LOCAL aHeaders := {"Authorization: Bearer 9ba19df2-a263-4251-8022-9d70ab149610:993b190c-2209-414c-8698-c50c50adbed7"}
   LOCAL nS,cID,aOffers
   LOCAL nX

   LOCAL hNimble := {;
      "FARNELL"=>{"URL"=>"https://de.farnell.com/x/x/x/dp/"+Trim(ali->Artlief),"RENDER"=>.T.};
   }

   Default(@lDbg,.F.)

   IF Tr_GetINi(28) == 9 //.AND. ! GetConfigValue("BATCHMODE")
      //Alert("GetPricesCompet for "+cLief)
   ENDIF

   ku->(dbSetOrder( 1 ))
   ku->(dbSeek( Pad(Upper(cLief),8)+"L" ))
   oExtra := ku->(ExtraData():New(ku->Nummer))
   ali->(dbSeek(Pad(Upper(cLief),8)+Str(art->Artikelnr,6)))
   
   IF lDbg .OR. ! cmp2->(dbSeek( Str(art->Artikelnr,6)+Str(ku->Nummer,6) )) ;
      .OR. AddWorkingDays(cmp2->Datum,HB_RandomInt(15,25)) < Date() ;
      .OR. ValType(HB_DeSerialize(cmp2->Daten)) != "H" .OR. HGetKeyAt(HB_DeSerialize(cmp2->Daten),1) == 0;
         .OR. HGetValueAt(HB_DeSerialize(cmp2->Daten),1) == 0
   
      IF ! Empty(oExtra:BRAI_ENGIN) .AND. (! Empty(oExtra:BRAI_URL) .OR. Trim(cLief) == "CONRAD")
         IF "%artlief%" $ oExtra:BRAI_URL .AND. (! ali->(Found()) .OR. Empty(ali->Artlief))
            IF lDbg
               Alert("No Artlief for "+cLief+" "+Trim(ali->Artikelnr)+" "+Trim(art->Matchcode))
            ENDIF
            hPrices := {=>}
         ELSE            
            cUrl := StrTran(StrTran(Trim(oExtra:BRAI_URL),"%artlief%",Trim(ali->Artlief)),"%match%",Trim(art->Matchcode))

            IF Trim(oExtra:BRAI_ENGIN)=="NIMBLE"  //If this works we most likely could implement this for all suppliers, at least ones which have a logical URL structure
               oApi := RestApi():New()
               oApi:cBaseUrl := "https://api.webit.live/api/v1/realtime/web" //nimbleway.com
               cData := oApi:Execute("","POST",{;
                  "parse"=>.T.,;            
                  "url"=>hNimble[Trim(ku->Kunde)]:Url,;   //This is the URL of the supplier's website, which is stored in a hash table hNimble with the supplier's name as the key.
                  "format"=>"json",;   
                  "render"=>hNimble[Trim(ku->Kunde)]:Render,;
                  "country"=>"DE",;
                  "locale"=>"de";
               },{;
                  "Authorization: Basic YWNjb3VudC1lbmdlbGtpbmdfZWxla3Ryb25pa19nbWJoX25pejZxdC1waXBlbGluZS1uaW1ibGVhcGk6WkExMTFjbDIzUVc4",;
                  "Content-Type: application/json";
               },.T.)
               
               hPrices := {=>}
               //gtSetClipboard(cData)
               hData := HB_JsonDecode(cData)            
               IF HHasKey(hData,"status") .AND. hData["status"] == "success"
                  IF Len(hData["parsing"]["entities"]) == 0
                     //parsing error?
                     IF hData["status_code"] == 400 .OR. AT("gesuchte Seite nicht gefunden",hData["html_content"]) > 0                        
                        IF ali->(Rec_Lock(5)) //product is not found, so we delete it
                           ali->(dbDelete())
                           ali->(dbUnLock())
                        ENDIF
                        //SendMail({{"amos.engelking@engelking.de","Amos"}},Trim(ku->Kunde)+" Artikel nicht gefunden",Trim(art->Matchcode))
                     ELSE
                        //Alert(hNimble[Trim(ku->Kunde)]:Url)
                        SendMail({{"amos.engelking@engelking.de","Amos"}},Trim(ku->Kunde)+" unbekannter Fehler "+Trim(art->Matchcode),cData)
                     ENDIF
                     hPrices := {=>}
                  ELSE     
                     IF ValType(hData["parsing"]["entities"]["Product"][1]["offers"]) == "A"
                        FOR nX := 1 TO Len(hData["parsing"]["entities"]["Product"][1]["offers"])
                           IF hData["parsing"]["entities"]["Product"][1]["offers"][nX]["@type"]== "AggregateOffer"
                              aOffers := hData["parsing"]["entities"]["Product"][1]["offers"][nX]["offers"][1]            
                              FOR nX := 1 TO Len(aOffers)               
                                 hPrices[aOffers[nX]["eligibleQuantity"]["minValue"]] := Val(aOffers[nX]["price"])
                              NEXT
                           ENDIF
                        NEXT
                     ELSE
                        hPrices[a1] := hData["parsing"]["entities"]["Product"][1]["offers"]["highPrice"]
                     ENDIF
                  ENDIF
               ELSE
                  IF lDbg
                     Alert("Error;"+ValToPrg(hData))
                  ENDIF               
               ENDIF            
            ELSEIF Trim(oExtra:BRAI_ENGIN) == "BROWSEAI" .AND. ! Empty(oExtra:BrowseAI) //.AND. ! Empty(oExtra:BRAI_URL)
               TxtBox("Preisabfrage "+cLief)
               nSecs := Seconds()
               //IF GetConfigValue("BATCHCMODE")
                  cData := NIL
                  oApi := RestApi():New()
                  oApi:cBaseUrl := "https://api.browse.ai/v2/robots/"+Trim(oExtra:BrowseAI)+"/tasks"
                  
                  cData := oApi:Execute("","POST",{"inputParameters"=>{"originUrl"=>cUrl}},aHeaders,.T.)
            
                  hData := HB_JsonDecode(cData)            
                     
                  

                  IF ! HHasKey(hData,"result") .OR. ! HHasKey(hData["result"],"status")
                     IF lDbg
                        Alert("No result or status")
                     ENDIF
                     IF HHasKey(hData,"statusCode") .AND. hData["statusCode"] == 403
                        SendMail({{"amos.engelking@engelking.de","Amos"}},"BrowseAI Abfrage Limit erreicht",cData)
                     ENDIF
                     RETURN {=>}
                  ELSE            
                     nS := 1
                     cID := hData["result"]["id"]
                     DO WHILE hData["result"]["status"] != "successful"               
                        @ MaxRow()/2+1,MaxCol()/2-5 SAY Replicate(".",nS)+Replicate(" ",11-nS)
                        Inkey(2,128)
                        cData := oApi:Execute("/"+cId,"GET",{=>},aHeaders)
                        nS++
                        IF nS > 11
                           nS := 1
                        ENDIF
                        IF cData == NIL
                           EXIT               
                        ELSE
                           //? cData
                           hData := HB_JsonDecode(cData)
                        ENDIF
                        IF ! HHasKey(hData,"result") 
                           SendMail({{"amos.engelking@engelking.de","Amos"}},"BrowseAI Abfrage",cData)
                        ELSE
                           IF HHasKey(hData["result"],"status") .AND. hData["result"]["status"] == "failed"
                              IF hData["result"]["retriedByTaskId"] != NIL
                                 cId := hData["result"]["retriedByTaskId"]
                              ELSE
                                 cData := NIL 
                                 EXIT                                 
                              ENDIF
                           ENDIF
                        ENDIF                  
                     ENDDO
                     IF cData != NIL .AND. hData["result"]["status"] == "failed"
                        IF lDbg
                           Alert(ValToPrg(hData["result"]))
                           Alert("Task failed "+hData["result"]["id"])
                        ENDIF
                        //SendMail({{"amos.engelking@engelking.de","Amos"}},"BrowseAI Task failed",ValToPrg(hData))
                        RETURN {=>}
                        
                     ENDIF
                  ENDIF
                  IF lDbg
                     Alert("BrowseAI took: "+Str(Seconds()-nSecs)+"s")
                     Alert(ValToPrg(hData["result"]))
                  ENDIF

                  hPrices := {=>}
                  IF Trim(cLief) != "CONRAD" .OR. hData["results"]["capturesTexts"]["Seller"] != "Engelking"                     
                     IF HHasKey(hData["result"]["capturedLists"],"Preise")           
                        FOR EACH hPrice IN hData["result"]["capturedLists"]["Preise"]
                           //Alert(ValToPrg(hPrice))
                           IF ValType(hPrice["Preis"]) == "C"
                              hPrices[Val(hPrice["Menge"])] := Val(StrTran(hPrice["Preis"],",","."))
                           ELSEIF ValType(hPrice["Preis"]) == "N"
                              hPrices[Val(hPrice["Menge"])] := hPrice["Preis"]
                           ELSEIF hPrice["Menge"] != NIL
                              hPrices[Val(hPrice["Menge"])] := 0
                           ENDIF
                        NEXT            
                     ENDIF
                  ENDIF
               /*ELSE
                  hPrices := {=>}                  
                  cScreen := SaveScreen()
                  cColour := SetColor(c_four)
                  @ 10,09 CLEAR TO 22,70
                  @ 10,09 TO 22,70 DOUBLE
                  @ 11,10 SAY "Preisabfrage nicht m”glich bitte Preise manuell erfassen:"
                  nX := 1
                  DO WHILE nX <= 10                     
                     nMenge := 0
                     nPreis := 0
                     @ 11+nX,10 SAY "Menge" GET nMenge PICTURE "99999"
                     @ 11+nX,30 SAY "Preis" GET nPreis PICTURE "999.99"
                     READ
                     IF LastKey() == 27 
                        IF Tr_MsgBox("Abbrechen?",,{"Ja","Nein"}) == 1
                           hPrices := NIL
                           EXIT
                        ENDIF
                        LOOP
                     ENDIF
                     IF nMenge == 0 .OR. nPreis == 0
                        EXIT
                     ENDIF
                     hPrices[nMenge] := nPreis
                     nX++
                  ENDDO
                  SetColor(cColour)
                  RestScreen(,,,,cScreen)
                  RETURN hPrices
               ENDIF*/
               TxtClear()
            ENDIF 
         ENDIF
      ELSE
         IF Tr_Getini(28) == 9 
            //Alert("No API data for "+cLief)
         ENDIF
         hPrices := MBaseRun(Trim(Tr_Getini(1))+"\run\prices\"+cLief,{art->Artikelnr,ali->Artlief,art->Matchcode,@nError})
         IF Tr_Getini(28) == 9 .AND. ! GetConfigValue("BATCHMODE")
            //Alert(ValType(hPrices))
         ENDIF
      ENDIF
      IF ValType(hPrices) == "H" .AND. Len(hPrices) != 0
         IF ! cmp2->(dbSeek( Str(art->Artikelnr,6)+Str(ku->Nummer,6) ))
            cmp2->(Add_Rec(0))
            cmp2->Artikelnr := art->Artikelnr
            cmp2->Lieferant := ku->Nummer
         ELSE
            cmp2->(Rec_Lock())
         ENDIF
         cmp2->Datum := Date()
         cmp2->Daten := HB_Serialize(hPrices)
         cmp2->(dbUnLock())
      ELSEIF cmp2->(Found()) .AND. cmp2->Datum >= Date()-15 //nicht „lter als 15 Tage
         nError := 0
         hPrices := HB_DeSerialize(cmp2->Daten)
         IF Tr_GetIni(28) == 9 .AND. ! GetConfigValue("BATCHMODE")
            //Alert(ValToPrg(hPrices))
         ENDIF
         IF ValType(hPrices) != "H" .OR. (Len(hPrices) == 1 .AND. HGetValueAt(hPrices,1) == 0 .AND. HGetKeyAt(hPrices,1) == 1) //this looks like an error which was not handled correctly
            hPrices := NIL
         ENDIF            
         //SendMail({{"amos.engelking@engelking.de","Amos"}},"Preise von "+cLief+" konnten fuer "+Trim(art->Matchcode)+" nicht geladen werden","Es wurden jedoch historische Daten vom "+DtoC(cmp2->Datum)+" benutzt. ")
      ENDIF
   ELSE
      //Alert("HERE")
      nError := 0
      hPrices := HB_DeSerialize(cmp2->Daten)
      //Alert(ValToPrg(hPrices))
   ENDIF

   ali->(dbGoto(nAliRec))
   ku->(dbGoTo(nKurec))
   
RETURN hPrices