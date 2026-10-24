PARAMETERS aWeights,lRech,nNr,nRechNr,lExpress

LOCAL cExDir := "Y:\DPD\import\"
LOCAL cImDir := "Y:\DPD\imported\"
LOCAL nX,xRetVal,aNummer := {},nTime
LOCAL cID := IF(lRech,"R"+StrZero(nRechnr,6),"E"+StrZero(nNr,6))
LOCAL nContact,hContacts,hContact
LOCAL aEnv := SaveEnv()
LOCAL aData,hData
LOCAL nStat,nOut,cStat,cOut
LOCAL cFile := cId+".csv"
LOCAL cExFile := cExDir+cFile
LOCAL cImFile := cImDir+cFile
LOCAL aSizes := {},aSize,cScr,nT,nL,nW
LOCAL cCol
LOCAL lEG := .T.

IF File(cImFile)
   TR_MsgBox(t("Sendung wurde bereits übergeben"))
   RETURN .F.
ENDIF

IF lRech
   nNr := nRechnr

   re->(dbSetOrder(4))
   re->(dbSeek( Str(nRechnr,6) ))
   GotoRechAddress(.T.) //Lieferaddresse

   NetUse("engauf","auf",.F.,0)
   auf->(dbSetOrder( 1 ))
   auf->(dbSeek( Str(re->abnr,6) ))
   nContact := auf->Person
ELSE
   lne->(dbSetOrder( 1 ))
   lne->(dbSeek( nNr ))
   ku->(dbSetOrder( 1 ))
   ku->(dbSeek( lne->Kunde+lne->Gruppe ))
   nContact := lne->Person
ENDIF

IF ku->CountryIso != "DE"
	NetUse("countri2","ctr")
	ctr->(dbSeek( ku->CountryIso ))
	lEG := ctr->EG
	IF ! lEG
	  cScr := SaveScreen()
	  cCol := SetColor(c_five)
	  nT := (MaxRow()-4)/2
	  nW := 18
	  nL := (MaxCol()-nW-2)/2
	  FOR nX := 1 TO Len(aWeights)
	     aSize := {0,0,0}

        @ nT,nL CLEAR TO nT+4,nL+nW
        @ nT,nL TO nT+4,nL+nW
        @ nT,nL+1 SAY t("[ Größe Paket "+LTrim(Str(nX,2))+" ]")
        @ nT+2,nL+1 SAY "L" GET aSize[1] PICTURE "999" VALID aSize[1] > 0
        @ nT+2,nL+1+6 SAY "B" GET aSize[2] PICTURE "999" VALID aSize[2] > 0
        @ nT+2,nL+1+12 SAY "H" GET aSize[3] PICTURE "999" VALID aSize[3] > 0
        READ
        IF LastKey() == 27
            RETURN .F.
        ENDIF
        Aadd(aSizes,aSize)

	  NEXT
	  RestScreen(,,,,cScr)
	  SetColor(cCol)
	ENDIF
ENDIF

If nContact == 0
   hContacts := ku->(GetAddressContacts())
   IF Len(hContacts[2]) > 0
      nContact := hContacts[2][1]
   ENDIF
ENDIF
hContact := ku->(GetContact(nContact))

hData := {=>}
aData := {}
FOR nX := 1 TO Len(aWeights)
   hData:ShipmentId := cID
   hData:SHIPTYPE   := "NP"
//   dpd->PARCELCOUN := 1
   hData:RNAME1     := ku->Name1
   hData:RNAME2     := ku->Name2
   hData:RSTREET    := ku-> Street
   hData:RPOSTAL    := _DPD_Postal()
   hData:RCITY      := ku->Town
   hData:RCONTACT   := Left(hContact["name"],35)
   hData:RPHONE     := ku->Telefon
   hData:RState     := _DPD_State()
   hData:RCOUNTRY   := ku->CountryIso
   hData:RADDRREF   := LTrim(Str(ku->Nummer,6))
   hData:WEIGHT     := aWeights[nX]

//   dpd->DELDATE    := DtoC(Date())
/*   dpd->SNAME1     := "Engelking Elektronik GmbH"
   dpd->SSTREET    := "Albstraße 16"
   dpd->SCOUNTRY   := "DE"
   dpd->SPOSTAL    := "78609"
   dpd->SCITY      := "Tuningen"*/
   IF lRech
      GotoRechAddress(.F.) //Rechnungsadresse
   ENDIF
   hData:INAME1     := ku->Name1
   hData:INAME2     := ku->Name2
   hData:ISTREET    := ku->Street
   hData:ICOUNTRY   := ku->CountryIso
   hData:IPOSTAL    := _DPD_Postal()
   hData:ISTATE     := _DPD_State()
   hData:ICITY      := ku->Town
   hTerms := {"DDP"=>2,"DAP"=>1}
   IF HHasKey(hTerms,ku->IncoTerm)
      hData:EICTERMS   := hTerms[ku->IncoTerm]
   ELSE
      hData:EICTERMS   :=  6
   ENDIF
   hData:EICPARCEL  := "P" //P=Parcel,D=Document
   IF lRech
      hData:EICUR      := Currate(re->Money,"X")
   ELSE
      hData:EICUR      := Currate(ku->Money,"X")
   ENDIF
   hData:EIAMOUNT   := IF(lRech,re->PosWt,5)

   hData:EICONTENT  := "Elektromechanische Bauelemente"
   hData:DP_STATUS  := ""
   hData:DP_OUTPUT  := ""

   hData:Length    := IF(!lEG,aSizes[nX][1],"")
   hData:Width    := IF(!lEG,aSizes[nX][2],"")
   hData:Height    := IF(!lEG,aSizes[nX][3],"")

   IF nX == 1
      Aadd(aData,HGetKeys(hData))
   ENDIF
   Aadd(aData,HGetValues(hData))
NEXT

SaveAsCSV(cExFile,aData)

TxtBox({"Warte auf DPD DeliSprint...",">ESC< zum abbrechen"})

nTime := Seconds()

DO WHILE Len(aNummer) < Len(aWeights) .AND. Inkey(1) != 27
   aNummer := {}
   IF File(cImFile)
      cData := MemoRead(cImFile)
      aData := {}
      FOR nX := 1 TO MlCount(cData,2000,,,.T.)
         Aadd(aData,HB_ATokens(MemoLine(cData,2000,nX,,,.T.),";",.T.,.T.))
      NEXT
      IF Len(aData) >= 2
         nStat := AScan(aData[1],'"DP_STATUS"')
         nOut  := AScan(aData[1],'"DP_OUTPUT"')
         IF nStat != 0 .AND. nOut != 0
            IF nStat <= Len(aData[2]) .AND. nOut <= Len(aData[2])
               cStat := StrTran(aData[2,nStat],'"')
               cOut  := StrTran(aData[2,nOut],'"')

               IF cStat == "Gedruckt"
                  aNummer := HB_ATokens(cOut,";")
               ELSEIF ! Empty(cStat)
                  TR_MsgBox(cOut,cStat)
               ENDIF
            ENDIF
         ENDIF
      ENDIF
   ENDIF
ENDDO
AEval(aNummer,{|cData,nX| aNummer[nX] := Trim(cData)})

TxtClear()

IF Len(aNummer) <  Len(aWeights)
   IF File(cExFile)
      FErase(cExFile)
   ENDIF
   TR_MsgBox("Sendung wurde nicht korrekt verarbeitet!")
   xRetVal := .F.
ELSE
   xRetVal := aNummer
ENDIF

RestEnv(aEnv,.F.)

//RETURN .F. //FOR TESTING ONLY
RETURN xRetVal

STATIC Function _DPD_State()
   IF ku->CountryIso == "US"
      RETURN Left(ku->PLZ,2)
   ENDIF
RETURN ""

STATIC Function _DPD_Postal()
   IF ku->CountryIso == "US"
      RETURN LTrim(StrTran(SubStr(ku->PLZ,3),"-",""))
   ENDIF
RETURN ku->PLZ
