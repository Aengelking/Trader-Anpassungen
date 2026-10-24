FUNCTION RUN_SHIP_UPS(aWeights,lRech,nNr,nRechNr, aPakData, cService, lBillCustomer)

LOCAL lWA := .F.
LOCAL oExtra
LOCAL TAB,NL,nF,cFile,cFileBase,nX,cEnd,oXml,oNode,oIter,lIter,oSubNode
LOCAL aNummer,oCost,aEnv,cStatus,nB,nWeight,nShipment,lEU
LOCAL cCustAccount,lMultiShip,aRegex,lAtlas,cMRN,nBox,lAusland
LOCAL hContacts,hContact,nContact

MEMVAR del_ad


IF ValType(aPakData) == "C" //backwards compatability
   lBillCustomer := cService
   cService := aPakData 
ENDIF

#ifndef __XHARBOUR__
	#xtranslate SecondsSleep(<x>) => hb_idleSleep(<x>)
#endif
If ValType(cService) != "C"
	cService := "ST" //Standard
Endif
If ValType( lBillCustomer ) != "L"
	lBillCustomer := .F.
Endif

cFileBase := "\\EK-SERVER4\UPS\Import\"+If(lRech,"R","E")+LTrim(Str(If(lRech,nRechNr,nNr)))

aEnv := SaveEnv()




lAtlas := .F.
aNummer := {}
del_ad := 0
cMRN := ""
nShipment := 1
lMultiShip := .F.

If lRech
	re->(dbSetOrder(4))
	re->(dbSeek( Str(nRechnr,6) ))

	//nTotal := re->PosWt
	lAusland := re->TaxCode == 0
	lEU := re->TaxCode == 3
	lAtlas := lAusland .AND. re->poswt >= 1000

	GotoRechAddress(.T.)
	NetUse("engauf","auf",.F.,0)
	auf->(dbSetOrder( 1 ))
	auf->(dbSeek( Str(re->abnr,6) ))
   nContact := auf->Person
   IF Tr_GetIni(28) == 9; Alert("Auftragskontakt "+Str(auf->Person)); ENDIF

	If del_ad != 0
		nContact := 0
	Endif
Else
	lne->(dbSetOrder( 1 ))
	lne->(dbSeek( nNr ))
	ku->(dbSetOrder( 1 ))
	ku->(dbSeek( lne->Kunde+lne->Gruppe ))
   nContact := lne->Person
	lAusland := ku->TaxCode == 0
	lEU := ku->TaxCode == 3
	lWA := lne->RefTyp == "WA"
Endif


oExtra := ku->(ExtraData():New( ku->Nummer ))

IF oExtra:HasField("UPSCONTACT") .AND. oExtra:UpsContact != 0
   nContact := oExtra:UpsContact
ENDIF

If ku->CountryISO != "DE"  //.AND. ! lAusland
	lAusland := .T.
Endif

If cService == "ST" .AND. ku->CountryIso $ {"TW","US"}   //expedited
   cService := "EX"
Endif

If nContact == 0
   hContacts := ku->(GetAddressContacts())
   IF Len(hContacts[2]) > 0
      nContact := hContacts[2][1]
   ENDIF
ENDIF
IF ! lRech .AND. Val(lne->Gruppe) != 0 //Lieferadresse, da werden die Kontaktpersonen aber von der Hauptadresse Åbernommen
   ku->(dbSeek( lne->Kunde+"K" ))
ENDIF
hContact := ku->(GetContact(nContact))
IF ! lRech //Zeiger wieder zurÅck
   ku->(dbSeek( lne->Kunde+lne->Gruppe ))
ENDIF

IF lAusland .AND. Empty(Trim(hContact["name"]))
   Tr_MsgBox("Bitte Kontaktdaten hinterlegen. "+ku->Kunde+" "+ku->Group+" "+Str(nContact))
   IF Tr_GetIni(28) == 9
      //Alert(ValToPrg(hContacts))
   ENDIF
   RETURN .F.
ENDIF

IF ! lAusland .AND. AT("POSTFACH",Upper(ku->street)) != 0
   Tr_MsgBox(t("Versand an Postfach mit UPS nicht mˆglich"))
   Return .F.
ENDIF

/*If Tr_getini(28) == 9
	Alert(LTrim(Str(nContact))+" "+hContact["name"]+" "+ku->Kunde+ku->Group)
	RETURN .F.
Endif*/

If lAtlas
	Do While Empty(cMRN)
		//The number consists of 18 alphanumeric characters.
    		//The third and fourth character shows the origin ISO country, which is DE for Germany.
		cMRN := GetBox(Space(20),"MRN","NNDE"+Replicate("N",14) )
		//Alert("MRN in Ordnung")
	Enddo
Endif

cCustAccount := Space(6)
If lBillCustomer
   
   IF oExtra:HasField("SPEDKONTO") 
      IF Empty(oExtra:SpedKonto)  //get it out of the old database
         NetUse("upsaccou","upsac",.F.,0)
         cCustAccount := Space(6)
         If upsac->(dbSeek( Str(ku->Nummer,6) ))
            cCustAccount := upsac->Ups
         Endif
      ELSE
         cCustAccount := oExtra:SpedKonto
      ENDIF
   ELSE
      cCustAccount := Space(6)
   ENDIF

   Do While Len(Trim(cCustAccount)) < 6
      cCustAccount := GetBox(cCustAccount,t("UPS Kundennummer des Empf‰ngers"),"NNNNNN")
   Enddo
   
   IF oExtra:HasField("SPEDKONTO") 
      IF cCustAccount != oExtra:SpedKonto .AND. (Empty(oExtra:SpedKonto) .OR. Tr_MsgBox(t("UPS Kundennummer aktualisieren?"),,{t("Ja"),t("Nein")}) == 1)
         oExtra:SpedKonto := cCustAccount
         oExtra:Save()
      ENDIF
   ENDIF

/*	If upsac->(dbSeek( Str(ku->Nummer,6) ))
		If cCustAccount != upsac->UPS .AND. Tr_MsgBox(t("UPS Kundennummer aktualisieren?"),,{t("Ja"),t("Nein")}) == 1
			upsac->(Rec_Lock())
			upsac->Ups := cCustAccount
			upsac->(dbUnLock())
		Endif
	Else
		upsac->(Add_Rec())
		upsac->KuNummer := ku->Nummer
		upsac->Ups := cCustAccount
		upsac->(dbUnLock())
	Endif*/

Endif

IF ku->CountryIso == "HU" .AND. AScan(aWeights,{|x| x > 40}) != 0
   Alert(t("F¸r Ungarn m¸ssen alle Pakete unter 40kg wiegen! (EKAER Bedingung)"))
	RestEnv(aEnv,.F.)
   RETURN .F.
ENDIF


//Datei erstellen
cFile := cFileBase

//nSucc := -1
nX := 0
IF nRechnr != 37892

Do While FErase(cFile+".xxx")-FErase(cFile+".out") < 0 .OR. File(cFile+".xxx") .OR. File(cFile+".out")
	cFile := cFileBase+"_"+LTrim(Str(nX))
   nX++
Enddo

nF := FCreate(cFile+".xml")
If nF <= 0 //Error
	Alert("Fehler beim Erstellen der Datei!")
	RestEnv(aEnv,.F.)
	Return .F.
Endif

If cService == "ST" .AND. (! lAusland .OR. ! lEu) //split it into multiple shipments as this is cheaper!
//	lMultiShip := .T.  //not cheaper any more
Endif

nWeight := 0
If ! lMultiShip
	AEval(aWeights,{|x| nWeight += x })
Endif

//Alert("Sendung als "+If(lMultiShip,"Einzelpakete","Gesamtsendung")+" versenden. "+cService+" "+If(lAusland,"ins Ausland","inland"))
//FClose(nF)
//Return .F.

NL := Chr(13)+Chr(10)
TAB := Chr(9)

FWrite(nF,'<?xml version="1.0" encoding="windows-1252"?>'+NL)
FWrite(nF,'<OpenShipments xmlns="x-schema:OpenShipments.xdr">'+NL)

Do While nShipment <= If(lMultiShip,Len(aWeights),1)
	If ! lMultiShip //if the shipment is beeing sent as a whole we start at box 1
		nBox := 1
	Else //otherweise move on to the next box and set the weight of the shipment to the weight of this box
		nBox := nShipment
		nWeight := aWeights[nBox]
	Endif

	//shipment
	FWrite(nF,TAB+'<OpenShipment ShipmentOption="SC" ProcessStatus="">'+NL)
	FWrite(nF,TAB+TAB+'<ShipTo>'+NL)
	//FWrite(nF,TAB+TAB+TAB+'<CustomerID>'+LTrim(Str(ku->Nummer))+'</CustomerID>'+NL)
	FWrite(nF,TAB+TAB+TAB+'<CompanyOrName>'+Pad(StrTran(HB_OemToAnsi(Trim(Trim(ku->name1))+' '+ku->Name2),'&','+'),35)+'</CompanyOrName>'+NL)
	FWrite(nF,TAB+TAB+TAB+'<Attention>'+Pad(HB_OemToAnsi(Trim(hContact["name"])),35)+'</Attention>'+NL)
	FWrite(nF,TAB+TAB+TAB+'<Address1>'+Pad(HB_OemToAnsi(Trim(ku->street)),35)+'</Address1>'+NL)
	FWrite(nF,TAB+TAB+TAB+'<CountryTerritory>'+ku->CountryISO+'</CountryTerritory>'+NL)
	IF ku->CountryIso == "US"
	   aRegex := HB_Regex("[0-9]{5,10}",ku->PLZ)
	   IF Len(aRegex) == 0
	      Alert(t("PLZ ung¸ltig"))
      ENDIF
	   //Alert(aRegex[1])
      FWrite(nF,TAB+TAB+TAB+'<PostalCode>'+aRegex[1]+'</PostalCode>'+NL)
   ELSE
   	FWrite(nF,TAB+TAB+TAB+'<PostalCode>'+ku->PLZ+'</PostalCode>'+NL)
   ENDIF   
	FWrite(nF,TAB+TAB+TAB+'<CityOrTown>'+Pad(StrTran(HB_OemToAnsi(Trim(ku->Town)),'/',' '),30)+'</CityOrTown>'+NL)
	//required for USA?
	IF ku->CountryIso == "US"
	   aRegex := HB_Regex("[A-Z]{2}",Upper(ku->PLZ))
	   IF Len(aRegex) == 0
	      Alert("Bitte Staat in der PLZ hinterlegen")
	      FClose(nF)
	      RETURN .F.
      ENDIF
       FWrite(nF,TAB+TAB+TAB+'<StateProvinceCounty>'+aRegex[1]+'</StateProvinceCounty>'+NL)
   ELSEIF ku->CountryIso == "CA"
      aRegex := HB_Regex(",\s*([A-Z]{2})",Upper(ku->Town))
      IF Len(aRegex) == 0
         Alert("Bitte Provinz als KÅrzel (2 Buchstaben) mit Komma getrennt bei der Stadt hinterlegen")
	      FClose(nF)
         RETURN .F.
      ENDIF
      FWrite(nF,TAB+TAB+TAB+'<StateProvinceCounty>'+aRegex[2]+'</StateProvinceCounty>'+NL)
   ENDIF
	FWrite(nF,TAB+TAB+TAB+'<Telephone>'+Pad(ku->Telefon,15)+'</Telephone>'+NL)
	FWrite(nF,TAB+TAB+TAB+'<FaxNumber>'+Pad(ku->TeleFax,15)+'</FaxNumber>'+NL)
	FWrite(nF,TAB+TAB+TAB+'<EmailAddress>'+Pad(HB_OemToAnsi(Trim( StrTran(StrTran(hContact["email"],Chr(13),''),Chr(10),'') )),50)+'</EmailAddress>'+NL)
	If ! Empty(cCustAccount)
		FWrite(nF,TAB+TAB+TAB+'<ReceiverUpsAccountNumber>'+cCustAccount+'</ReceiverUpsAccountNumber>'+NL)
	Endif
	FWrite(nF,TAB+TAB+TAB+'<ResidentialIndicator>0</ResidentialIndicator>'+NL)
	FWrite(nF,TAB+TAB+'</ShipTo>'+NL)
   FWrite(nF,TAB+TAB+'<ShipmentInformation>'+NL)   
   IF ku->CountryIso == "DE" .AND. ! lBillCustomer
      FWrite(nF,TAB+TAB+TAB+'<CarbonNeutral>1</CarbonNeutral>'+NL)
   ENDIF
	FWrite(nF,TAB+TAB+TAB+'<ServiceType>'+cService+'</ServiceType>'+NL) //ST=Standard, SV=Express Saver, ES=Express
	FWrite(nF,TAB+TAB+TAB+'<PackageType>CP</PackageType>'+NL) //CP=Paket
	FWrite(nF,TAB+TAB+TAB+'<NumberOfPackages>'+If(lMultiShip,"1",LTrim(Str(Len(aWeights))))+'</NumberOfPackages>'+NL)
	If nWeight < 1
		nWeight := 1
	Endif
	FWrite(nF,TAB+TAB+TAB+'<ShipmentActualWeight>'+LTrim(Str(Round(nWeight,0)))+'</ShipmentActualWeight>'+NL)
	FWrite(nF,TAB+TAB+TAB+'<DescriptionOfGoods>Elektromech. Bauelemente</DescriptionOfGoods>'+NL)
	FWrite(nF,TAB+TAB+TAB+'<Reference1>'+If(lRech,'Rechnung ','')+LTrim(Str(If(lRech,nRechnr,nNr)))+'</Reference1>'+NL)
	//<Reference2>108</Reference2>
	//<Reference3>UPS</Reference3>
	//<DocumentOnly />
	//<GoodsNotInFreeCirculation />
	//<SpecialInstructionForShipment />
	//<ShipperNumber />

	FWrite(nF,TAB+TAB+TAB+'<BillingOption>PP</BillingOption>'+NL)
	FWrite(nF,TAB+TAB+TAB+'<BillTransportationTo>'+If(lBillCustomer,'REC','SHP')+'</BillTransportationTo>')
   
   IF ! lEU
      //Bill duty and tax to us if it is a supply of material for a manufacturing order
   	FWrite(nF,TAB+TAB+TAB+'<BillDutyTaxTo>'+IF(lWa,'SHP','REC')+'</BillDutyTaxTo>')
   ENDIF
   
	If lAtlas
		//Die MRN kann per XML nicht an WorldShip ¸bergeben werden. Deshalb verwenden wir daf¸r Referenz Feld 2
		FWrite(nF,TAB+TAB+TAB+'<Reference2>'+Trim(cMRN)+'</Reference2>'+NL)
	Endif


	FWrite(nF,TAB+TAB+'</ShipmentInformation>'+NL)

	nB := nBox
	Do While nB <= If(lMultiShip,nBox,Len(aWeights))
		FWrite(nF,TAB+TAB+'<Package>'+NL)
		nWeight := If(aWeights[nB]<1,1,aWeights[nB])
		FWrite(nF,TAB+TAB+TAB+'<Weight>'+LTrim(Str(Round(nWeight,0)))+'</Weight>'+NL)
		FWrite(nF,TAB+TAB+'</Package>'+NL)
		nB++
	Enddo

   FWrite(nF,TAB+TAB+'<InternationalDocumentation>'+NL)
   FWrite(nF,TAB+TAB+TAB+'<CreateAnInvoice>0</CreateAnInvoice>'+NL)
   //FWrite(nF,TAB+TAB+TAB+'<Currency>USD</Currency>'+NL)
   FWrite(nF,TAB+TAB+'</InternationalDocumentation>'+NL)


	FWrite(nF,TAB+'</OpenShipment>'+NL)
	//end of shipment
	nShipment++
Enddo

FWrite(nF,'</OpenShipments>')

FClose(nF)
ELSE
   nX := 0
   cFile := cFileBase
   Do While File(cFile+".xxx") .OR. File(cFile+".out")
      nX++
   	cFile := cFileBase+"_"+LTrim(Str(nX))
   Enddo
   IF nX == 1
      cFile := cFileBase
   ELSE
      cFile := cFileBase+"_"+LTrim(Str(nX-1))
   ENDIF
   ALERT(cFile)
ENDIF

TxtBox("Warte auf UPS Worldship...")
cEnd := ".xxx"
Do While Inkey(.5,128) != 27
	If File(cFile+cEnd)
		TxtClear()
		If cEnd == ".xxx"
			TxtBox("UPS Worldship verarbeitet die Sendung...")
			cEnd := ".OUT"
		Else
			EXIT
		Endif
	Endif
Enddo
If LastKey() == 27
	Return .F.
Endif
TxtBox("Verarbeitung wird abgeschlossen...")
SecondsSleep(5)
Do While Fopen(cFile+".out",2) <= 0  //wait until file is unlocked
Enddo
TxtClear()
     // FileSize(cFile+".xxx") >= FileSize(cFile+".out") .AND.

oXml := TXmlDocument():New()
oXml:Read(MemoRead(cFile+".out"))

oNode := oXml:findFirst( "OpenShipment" )

cStatus := oNode:aAttributes["ProcessStatus"]  //Fail To Import | Processed

If cStatus != "Processed"
	oNode := oXml:findFirst("ErrorMessage")
	If oNode == NIL
		Tr_MsgBox("Unbekannter Fehler")
	Endif
	Do While oNode != NIL
		Tr_MsgBox(HB_AnsiToOem(oNode:cData),"Fehler!")
		oNode := oXml:findNext()
	Enddo
Else  //Read Tracking numbers
	oNode := oXml:findFirst("TrackingNumbers")
	If oNode == NIL
		Tr_MsgBox("Keine Sendungsnummern gefunden")
		Return .F.
	Endif
	Do While oNode != NIL
		oIter := TXmlIterator():new( oNode )
		oIter:Rewind()
		lIter := .T.
		Do While lIter
			oSubNode := oIter:next()
			If oSubNode == NIL
				lIter := .F.
			Else
				Aadd(aNummer,{"NUMMER"=>oSubNode:cData,"PREIS"=>0})
			Endif
		Enddo
		oNode := oXml:findNext()
	Enddo

   oNode := oXml:findFirst("ShipperCharges")
	If oNode == NIL
		Tr_MsgBox("Keine Kosten gefunden")
		Return .F.
	Endif
	nX := 1
	Do While oNode != NIL
      oCost := oNode:oChild:oChild:oNext
      IF nX <= Len(aNummer) //.AND. ku->CountryIso != "DE" //.AND. aNummer[nX]["PREIS"] == 0
      	aNummer[nX]["PREIS"] := Val(StrTran(oCost:cData,",","."))
      ENDIF
      oNode := oXml:FindNext()
   	nX++
	Enddo

	//Alert( Len(aNummer) )
Endif


//oNode := TXmlNode():New(,'OpenShipments') xmlns="x-schema:OpenShipments.xdr">*/

RestEnv(aEnv,.F.)

If Len(aNummer) == Len(aWeights)
	Return aNummer
ELSEIF cStatus == "Processed"
   Tr_MsgBox({t("Anzahl Packst¸cke stimmt nicht ¸berein."),t("Sendung konnte nicht verarbeitet werden."),t("Ist: ")+Ltrim(Str(Len(aNummer)))},"Fehler")
Endif
Return .F. //Array(Len(aWeights))
