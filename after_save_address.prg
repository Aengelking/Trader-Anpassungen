PROCEDURE After_Save_address(oAddress,lNew)
//LOCAL cArchDir,nVorkass,oVatAddress
LOCAL lChange,nRec,cName,lJur
LOCAL lEG,nResult
LOCAL aList,oRechnung,nRechnr
LOCAL oCustom,oExtra

NetUse("rechnung","reh")
NetUse("englsre","re")

taxit(oAddress:TaxCode,0,Date(),.F.,@lEG) //Abrufen ob die Adresse als Steuerfrei-EG eingestellt ist

NetUse("phonebook","pbk")
pbk->(dbSetOrder(2))
IF ! pbk->(dbSeek( Str(oAddress:Nummer,6)+Str(0,4) ))
   pbk->(Add_Rec(0))
   pbk->Address := oAddress:Nummer
ELSE
   pbk->(Rec_Lock(0))
ENDIF
pbk->Number := NormalizeTelNo(oAddress:Telefon)
pbk->(dbUnLock())


   

IF lEG .AND. ! Empty(oAddress:Vatnr) //bei EG Adressen prfen wir die Richtigkeit der UST-Id Nr. aber nur wenn der Benutzer diese nicht leer gelassen hat
   IF Left(oAddress:VatNr,2) != "DE"
      /*IF Val(oAddress:Group) >= 1 .AND. Val(oAddress:Group) <= 9 //Lieferadresse
         oVatAddress := Adresse():New()
         oVatAddress:LoadMatchcode(oAddress:Kunde,"K")
      ELSE
         oVatAddress := oAddress
      ENDIF*/
      TxtBox("UST-Id Nr. wird geprft...")
      nResult := CheckVatID(oAddress:Vatnr,oAddress:cName,oAddress:Town)
      TxtClear()
      IF nResult != 0
         Tr_MsgBox(Str(nResult,3)+" "+HB_AnsiToOem(getVATIDErrorName(nResult)),"Fehler in der UST-Id.Nr.")
      ELSE
         //?? " OK"
      ENDIF
   ELSEIF oAddress:CountryIso != "DE"
      Tr_MsgBox("Deutsche UST-Id.Nr. bei nicht deutscher Adresse!")
   ENDIF
ENDIF

IF ku->GROUP == "K" //nur Bei Kunden 

   IF oAddress:HasCargo("report") //save the report, needs to be done before GetCustomerCreditLimit
      CS_SaveReport(oAddress:Nummer,oAddress:GetCargo("report")) //this also downloads the PDF and saves it
   ENDIF

   lChange := .F.
   nRec := ku->(Recno())
   IF ku->Skonto != 8
      IF GetCustomerCreditLimit(ku->Kunde) == 0
         Tr_MsgBox("Zahlungsbedingungen wegen fehlendem Kreditlimit auf Onlinekauf umgestellt")
         lChange := .T.
      ELSEIF lNew
         cName := Upper(Trim(ku->Name1)+" "+ku->Name2)
         lJur := "MBH" $ cName .OR. "AG" $ cName .OR. "EG" $ cName .OR. "AKTIENGESELLSCHAFT" $ cName
         IF (ku->CountryIso != "DE" .OR. ! lJur) .AND. Tr_MsgBox("Zahlungsbedingungen auf Onlinekauf stellen?",,{"JA","Nein"}) != 2
            lChange := .T.
         ENDIF
      ENDIF
   ENDIF

   NetUse("skontoa","ska")
   IF Left(oAddress:Name1,3) == "EFG" .AND. (! ska->(HasSpecialPay(oAddress:Skonto)) .OR. Len(ska->(GetSkonto(oAddress:Skonto,Date(),Date()))) == 0)
      SendMail({{"amos.engelking@engelking.de","Amos"}},"After Save address","Kunde: "+oAddress:Kunde+" Name1: "+oAddress:Name1)
      Tr_MsgBox("Dieser Kunde ist Mitglied der GC Gruppe - hier gelten Sonderzahlungsbedingungen. Bitte durch Amos hinterlegen lassen")
   ENDIF

   IF oAddress:Charge < 0 //Kundenrabatt prfen
      IF ! ska->(IsPrePay(oAddress:Skonto)) //keine Vorkasse, dann auch kein Kundenrabatt
         Tr_MsgBox("Kundenrabatt wurde gel”scht")
         oAddress:Charge := 0
         oAddress:Save()
      ELSEIF oAddress:Charge < -3 //Ist Vorkasse, dann max. 3%
         Tr_MsgBox("Rabatt zu hoch, wurde auf 3% reduziert")
         oAddress:Charge := -3
         oAddress:Save()
      ENDIF   
   ENDIF


   re->(dbSetOrder( 2 ))
   re->(dbSetFilter({|| ! re->Packed},"!packed"))
   re->(dbSeek( Str(0,3)+oAddress:Kunde ))
   aList := {}
   DO WHILE re->Reposnr == 0 .AND. re->Kunde == oAddress:Kunde .AND. ! reh->(EOF())
      Aadd(aList,re->Rechnr)
      re->(dbSkip())
   ENDDO
   re->(dbClearFilter())

   FOR EACH nRechnr IN aList
      IF LockEntity("RE",nRechnr)
         oRechnung := Rechnung():New()
         oRechnung:Load(nRechnr)
         oRechnung:Rabatt := oAddress:Charge
         oRechnung:UpdateTotal()
         UnLockEntity("RE",nRechnr)
      ENDIF
   NEXT

   IF lChange
      ku->(dbGoto( nRec ))
      ku->(Rec_Lock())
      ku->Skonto := 8
      ku->(dbUnLock())
      oExtra := ku->(ExtraData():New(ku->Nummer))
      oExtra:OnlineKauf := .T.
      oExtra:Save()
   ENDIF
ENDIF

IF oAddress:Group $ {"K","L"} .AND. (lNew .OR. oAddress:FieldUpdatedLastSave("NAME1") .OR. oAddress:FieldUpdatedLastSave("NAME2"))
   TxtBox("Agorum Core wird aktualisiert")
   oCustom := AgorumCustomApi():New()
   IF ! oCustom:SaveAddress(oAddress)
      SendMail({{"amos.engelking@engelking.de","Amos"}},"Fehler beim Speichern der Adresse in Agorum Core","Adresse: "+LTrim(Str(oAddress:Nummer))+Chr(10)+Chr(13)+oCustom:cErrorText)
      //Tr_MsgBox({"Fehler beim Speichern der Adresse in Agorum Core.",oCustom:cErrorText})
   ENDIF
   TxtClear()
ENDIF

#include "X:\run\agorum.prg"
#include "X:\run\creditsafe.prg"
