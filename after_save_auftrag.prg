FUNCTION HOOK_AFTER_SAVE_AUFTRAG(oAuftrag)
   LOCAL oAddress,oVatAddress
   LOCAL nResult

   IF oAuftrag:Kunde:re_via == "EMAI" .AND. GetInvoiceContact(oAuftrag:Kunde:Nummer) == NIL
      Tr_MsgBox(t("Bitte Rechnungsempfänger festlegen, ohne diese kann keine Rechnung erstellt werden."),,{"OK"})
   ENDIF

   //Check VAT-ID
   GotoRechnungsTaxCustomer(oAuftrag:Kundma,oAuftrag:abnr,oAuftrag:DelAd)
   oAddress := Adresse():New()
   oAddress:Load(ku->Nummer)

   IF oAddress:TaxCode == 3 .AND. Left(oAddress:VatNr,2) != "DE"
      IF Val(oAddress:Group) >= 1 .AND. Val(oAddress:Group) <= 9 //Lieferadresse
         oVatAddress := oAuftrag:Kunde
      ELSE
         oVatAddress := oAddress
      ENDIF
      TxtBox("UST-Id Nr. wird geprft...")
      nResult := CheckVatID(oAddress:Vatnr,Trim(oVatAddress:cName),Trim(oVatAddress:Town))
      TxtClear()
      IF nResult != 0
         Tr_MsgBox(Str(nResult,3)+" "+HB_AnsiToOem(getVATIDErrorName(nResult)),"Fehler in der UST-Id.Nr.")
      ENDIF     
   ENDIF
RETURN NIL