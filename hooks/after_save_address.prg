PROCEDURE After_Save_address(oAddress,lNew)
//LOCAL cArchDir,nVorkass,oVatAddress
LOCAL lChange,nRec,cName,lJur
LOCAL lEG,nResult
LOCAL aList,oRechnung,nRechnr
LOCAL oCustom,oExtra,lUpDated,cError
LOCAL nNewSkonto

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

IF oAddress:GROUP == "K" //nur Bei Kunden 

   IF oAddress:HasCargo("report") //save the report, needs to be done before GetCustomerCreditLimit
      CS_SaveReport(oAddress:Nummer,oAddress:GetCargo("report"))
   ENDIF

   lChange := .F.
   nNewSkonto := 8
   oExtra := ku->(ExtraData():New(oAddress:Nummer))
   nRec := ku->(Recno())
   IF ku->Skonto != 8
      IF oExtra:Factoring .AND. ! ku->Skonto $ {0,7,9} //When factoring then only without cash discount possible
         Tr_MsgBox("Dieser Kunde ist fr Factoring angemeldet, daher k”nnen keine Zahlungsbedingungen mit Skonto gew„hlt werden auf 14 Tage netto umgestellt.")
         lChange := .T.
         nNewSkonto := 7
      ELSE
         IF GetCustomerCreditLimit(ku->Kunde) == 0
            Tr_MsgBox("Zahlungsbedingungen wegen fehlendem Kreditlimit auf Vorkasse umgestellt")
            lChange := .T.
         ELSEIF lNew
            cName := Upper(Trim(ku->Name1)+" "+ku->Name2)
            lJur := "MBH" $ cName .OR. "AG" $ cName .OR. "EG" $ cName .OR. "AKTIENGESELLSCHAFT" $ cName
            IF (ku->CountryIso != "DE" .OR. ! lJur) .AND. Tr_MsgBox("Zahlungsbedingungen auf Vorkasse stellen?",,{"JA","Nein"}) != 2
               lChange := .T.
            ENDIF
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
      ku->Skonto := nNewSkonto
      ku->(dbUnLock())
   ENDIF   

   IF ku->Money != "E"
      Tr_MsgBox("W„hrung wurde wieder auf EURO eingestellt")
      ku->(Rec_Lock(0))
      ku->Money := "E"
      ku->(dbUnLock())
   ENDIF
   
   IF Empty(ku->Branch)
      TxtBox("Branche wird aktualisiert...")
      IF ! UpdateBrancheWithAI(@cError)
         Tr_MsgBox(cError,"FEHLER")
      ENDIF
      TxtClear()
   ENDIF

   /*  Factoring-Kunden bei Tilta einrichten: Buyer, Ansprechpartner und
    *  Kreditfazilit„t. Die Logik steht in run\tilta_hook.prg, damit das
    *  Speichern der Adresse und das Setzen des Kennzeichens dasselbe tun
    *  (Hook after_save_extravalue).  */
   IF oExtra:Factoring
      __TiltaSetupKunde(oAddress:Nummer)
   ENDIF

ENDIF


IF oAddress:Group == "L"
   lUpdated := .F.
   IF ! lNew    
      IF oAddress:FieldUpdatedLastSave("IBAN") .OR. oAddress:FieldUpdatedLastSave("BIC")
         lUpDated := .T.      
      ENDIF
      IF oAddress:FieldUpdatedLastSave("SKONTO") 
         lUpDated := .T.
      ENDIF
   ENDIF 
   IF lNew .OR. lUpdated //Neuer Lieferant
      IF ku->Skonto != 9 .AND. (Empty(oAddress:IBAN) .OR. Empty(oAddress:BIC))
         Tr_MsgBox("Bitte IBAN und BIC hinterlegen.")
      ENDIF
      NetUse("skontob","skb")
      skb->(dbGoto(oAddress:Skonto+1))
      SendMail({{"amos.engelking@engelking.de","Amos"}},IF(lNew,"Neuer","Ge„nderter")+" Lieferant: "+Trim(oAddress:Kunde),"Name: "+oAddress:cName+Chr(10)+Chr(13)+skb->(SKONT(0,0,skb->Ziel1,skb->Ziel2,skb->Ziel3,skb->Rate1,skb->Rate2,skb->Rate3,"D",.F.))+Chr(10)+Chr(13)+"W„hrung: "+Currate(oAddress:Money,"X")+Chr(10)+Chr(13)+"IBAN: "+oAddress:IBAN+Chr(10)+Chr(13)+"BIC: "+oAddress:BIC)
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

IF oAddress:Group $ {"K","L"}
   //OdooSync_EnqueueAddress(oAddress,IF(lNew,"CREATE","UPSERT"))
ENDIF

#include "x:\run\tilta_hook.prg"
#include "X:\run\agorum.prg"
#include "X:\run\creditsafe.prg"
#include "x:\run\update_branch_ai.prg"
