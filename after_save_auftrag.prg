FUNCTION HOOK_AFTER_SAVE_AUFTRAG(oAuftrag)
   LOCAL oAddress,oVatAddress
   LOCAL nResult

   MEMVAR mlCGI
   MEMVAR maHookWarnings
   
   IF Type("maHookWarnings") != "A"
      maHookWarnings := {}
   ENDIF

   IF oAuftrag:Kunde:re_via == "EMAI" .AND. GetInvoiceContact(oAuftrag:Kunde:Nummer) == NIL
      IF ! mlCGI
         Tr_MsgBox(t("Bitte Rechnungsempfänger festlegen, ohne diese kann keine Rechnung erstellt werden."),,{"OK"})
      ELSE
         Aadd(maHookWarnings, t("Bitte Rechnungsempfänger festlegen, ohne diese kann keine Rechnung erstellt werden."))
      ENDIF      
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
      IF ! mlCGI
         TxtBox("UST-Id Nr. wird geprft...")
      ENDIF
      nResult := CheckVatID(oAddress:Vatnr,Trim(oVatAddress:cName),Trim(oVatAddress:Town))
      IF ! mlCGI
         TxtClear()
      ENDIF
      IF nResult != 0
         IF mlCGI
            //Tr_MsgBox(t("Die UST-Id.Nr. ist ungltig: ")+oAddress:VatNr+" ("+getVATIDErrorName(nResult)+")",,{"OK"})
            Aadd(maHookWarnings, t("Die UST-Id.Nr. ist ungltig: ")+oAddress:VatNr+" ("+getVATIDErrorName(nResult)+")")
         ELSE
            Tr_MsgBox(Str(nResult,3)+" "+HB_AnsiToOem(getVATIDErrorName(nResult)),"Fehler in der UST-Id.Nr.")
         ENDIF
      ENDIF     
   ENDIF
   
RETURN NIL