FUNCTION HOOK_After_Pack( nNr,lRech,nVersandArt,nPerson,aPakete,aGewichte,aPreise )

LOCAL oExtra
LOCAL lUpdateFreight,oRechnung,nPorto,lPorto,nNetto
LOCAL cMessage,aContact,cNr

HB_SYMBOL_UNUSED( nPerson )
HB_SYMBOL_UNUSED( aGewichte )

IF lRech //Rechnung

   IF Len(aPakete) > 1
      StickPrint("BOXES",Len(aPakete))      
   ENDIF
   
   NetUse("engslre","re")
   NetUse("artikel","art")
   NetUse("engkund","ku" )
   NetUse("skontoa","sk")
   
   re->(dbSetOrder( 12 ))
   re->(dbSeek( Str(nNr,6)+Str(0,3) ))
   ku->(dbSetOrder( 1 ))
   ku->(dbSeek( re->Kunde+"K" ))
   oExtra := ku->(ExtraData():New( ku->Nummer ))
   IF ! sk->(IsPrePay(re->Skonto)) .AND. (re->PosWt > 0 .OR. Trim(re->Kunde) == "TEST")//nur bei rechnungen
      lUpdateFreight := .F.
      
      oRechnung := Rechnung():New()
      oRechnung:Load(nNr)

       //set flag back, until freight is saved
      oRechnung:Versandt := .F.
      oRechnung:Save()

      IF (Trim(ku->Kunde) == "FP" .AND. nVersandart == 2) .OR. oExtra:PortoAufwa
         lUpdateFreight := .T.
      ELSEIF ! ku->Portok $ "Nn" .AND. ! nVersandart $ {10,44,46,49,56}
         lPorto := .T.
         IF oExtra:PortoUnter != 0
            nNetto := oRechnung:Brutto
            IF oRechnung:ReArt < 2
               nNetto -= oRechnung:MwSt
            ENDIF
            nNetto -= oRechnung:Porto
            IF nNetto >= oExtra:PortoUnter
               lPorto := .F.
            ENDIF
         ENDIF 
         IF lPorto .AND. oRechnung:Versandart != 10 .AND. oRechnung:Versandart != -1 //Porto und keine Abholung oder Verweis
            art->(dbSetOrder( 2 ))
            re->(dbSkip(1))
            DO WHILE re->Rechnr == nNr .AND. ! re->(EOF()) .AND. ! lUpdateFreight
               art->(dbSeek( Str(re->Artikelnr,6) ))
               IF re->AoQty != 0 .AND. art->Lagerart .AND. (art->Gruppe == "KANK" .OR. AT("NZ/",art->Matchcode) == 1  .OR. art->Manufactur == 14) //Netzkabel oder Onpow (nicht Engelking China)
                  lUpdateFreight := .T.
               ENDIF
               re->(dbSkip())
            ENDDO
         ENDIF
      ENDIF
      IF lUpdateFreight
         nPorto := 0
         AEval(aPreise,{|x| nPorto += x })
         DO WHILE nPorto <= 0
            nPorto := GetBox(nPorto,"Frachtkosten eingeben","9999.99")
         ENDDO
         IF nVersandart == 57 .OR. nVersandart == 58 .OR. nVersandart == 40 //Spedition
            nPorto *= 1.1 //Aufschlag für Maut usw.
            nPorto += Len(aPakete)*6  //Pauschale für Verpackungsmaterial
         ELSE
            nPorto += Len(aPakete)*1 //Pauschal pro Karton für Verpackungsmaterial
         ENDIF
         nPorto := Max(nPorto,6) //mindestens 6€ pro Sendung
         oRechnung:Porto := nPorto
         oRechnung:Save()

         oRechnung:UpdateTotal()
      ENDIF
      oRechnung:Versandt := .T.
      oRechnung:Save()

      //Send Notification
      IF oExtra:ShipNotify //Trim(re->Kunde) == "HERWECK"
         MBaseRun(Trim(Tr_Getini(1))+"\run\ship_notification",{nNr,1})
      ENDIF

      IF oExtra:Factoring 
         MBaseRun(Path("run\factoring.prg"),{oRechnung})
      ENDIF
   ENDIF
ELSE
   NetUse("muster","mus",.F.,0)
   NetUse("mushead","muh")
	mus->(dbSetOrder( 1 ))
	If mus->(dbSeek( nNr ))  .AND. muh->(dbSeek( Str(nNr,6) )) //Musterauftrag vorhanden?
		NetUse("engkund","ku",.F.,0)
		ku->(dbSetOrder( 1 ))
		ku->(dbSeek( mus->Kunde+"K" ))
		//oExtra := ku->(ExtraData():New( ku->Nummer ))
		/*dDate := Date()+3  
		If Dow(dDate) == 7 //saturday
			dDate += 2
		Elseif Dow(dDate) == 1 //sunday
			dDate += 1
      Endif*/
      #define CRLF Chr(13)+Chr(10)
      cMessage := "Musterauftrag: "+LTrim(Str(mus->Nummer))+CRLF      
      cMessage += "Kunde: "+ku->Name1+CRLF
      IF ! Empty(muh->Beleg)
         cMessage += "Referenz: "+Trim(muh->Beleg)+CRLF
      ENDIF
		aContact := GetContact(mus->Person)
		cMessage += "Ansprechpartner: "+aContact["name"]+CRLF
		cMessage += "Telefon: "+aContact["fullphone"]+CRLF
      cMessage += "Versandt am: "+DToC(Date())+CRLF
      cMessage += "Transportunternehemn: "+VerShow(nVersandArt)+CRLF
      cMessage += "Tracking-Nummer"+IF(Len(aPakete)>1,"n:+CRLF",":")
      FOR EACH cNr IN aPakete
         cMessage += cNr +CRLF
      NEXT

      //AddWiedervorlage(dDate,"Muster an "+Trim(ku->Name1)+" ausgeliefert",cMessage,"MUS:"+LTrim(Str(mus->Nummer)),,mus->Buyer)
      NetUse("buyer","buy")
      buy->(dbGoto( mus->Buyer ))
      SendMail({{buy->Email,buy->Buyer}},"Muster an "+Trim(ku->Name1)+" ausgeliefert",cMessage,,,,.F.)
	Endif
Endif

//VDA Etiketten
IF oExtra != NIL .AND. oExtra:PrintVDA
   MBaseRun(Trim(Tr_Getini(1))+"\run\print_vda",{nNr,lRech})
ENDIF