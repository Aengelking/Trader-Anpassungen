FUNC HOOK_BEFORE_CREATE_INVOICE(oRechnung,lCredit)
   LOCAL hContacts
   LOCAL aMsg
   LOCAL nNetto

   MEMVAR mcInvoiceError
   PUBLIC mcInvoiceError

   Default(@lCredit,.F.)

   //Bei deutschen Kunden muss eine USt-Id-Nr. hinterlegt sein (nur Rechnungen, keine Gutschriften)
   IF ! lCredit .AND. ku->CountryIso == "DE" .AND. Empty(ku->Vatnr)
      IF ! GetConfigValue("BATCHMODE")
         Tr_MsgBox("Bei diesem deutschen Kunden ist keine USt-Id-Nr. hinterlegt. Bitte die USt-Id-Nr. in der Adresse erfassen, bevor eine Rechnung erstellt wird.","USt-Id-Nr. fehlt")
      ELSE
         mcInvoiceError := "USt-Id-Nr. fehlt fuer deutschen Kunden "+Trim(ku->Kunde)
      ENDIF
      RETURN .F.
   ENDIF

   //Bei MwSt-Schlssel 5 (Schweiz) muss die Ware auch wirklich in die Schweiz geliefert werden
   IF ! lCredit .AND. oRechnung:TaxCode == 5 .AND. oRechnung:oLieferAdresse:CountryIso != "CH"
      IF ! GetConfigValue("BATCHMODE")
         Tr_MsgBox("Der MwSt-Schlssel 5 (Schweiz) ist gesetzt, aber die Lieferadresse liegt nicht in der Schweiz (Land: "+Trim(oRechnung:oLieferAdresse:CountryIso)+"). Bitte den Steuerschlssel oder die Lieferadresse prfen.","Lieferung nicht in die Schweiz")
      ELSE
         mcInvoiceError := "MwSt-Schlssel 5 (Schweiz), aber Lieferadresse in "+Trim(oRechnung:oLieferAdresse:CountryIso)+" statt CH"
      ENDIF
      RETURN .F.
   ENDIF

   IF oRechnung:TaxCode == 0 //Export
      aMsg := {}
      //Prfen ob Kontaktdaten vorhanden sind
      IF Empty(ku->Telefon)
         Aadd(aMsg,"Telefonnummer fehlt")
      ENDIF
      //oRechnung:oRechnungsAdresse:GotoRec()
      hContacts := ku->(GetAddressContacts())
      IF Len(hContacts[2]) == 0
         Aadd(aMsg,"Keine Kontaktperson vorhanden")
      ENDIF
      IF Len(aMsg) > 0
         IF ! GetConfigValue("BATCHMODE")
            Tr_MsgBox(aMsg,"Kontaktdaten fehlen")
         ELSE
            mcInvoiceError := "Kontaktdaten fehlen: "
            AEval(aMsg,{|cMsg| mcInvoiceError += cMsg+"; "})
         ENDIF
         RETURN .F.
      ENDIF
   ENDIF
   IF Trim(oRechnung:oKunde:Kunde) == "CONRADSE"
      nNetto := oRechnung:Brutto
      IF oRechnung:ReArt < 2
         nNetto -= oRechnung:MwSt
      ENDIF
      nNetto -= oRechnung:Porto

      IF nNetto <= 85            
         oRechnung:Porto := 3
      ELSE
         oRechnung:Porto := 0
      ENDIF
      

   ELSEIF lCredit
      oRechnung:Porto := 0
      oRechnung:Versandart := 21
   ELSEIF oRechnung:Versandart == 10 //Abholung
      oRechnung:Porto := 0
   ELSEIF oRechnung:oKunde:Portok == "Y"
      IF sk->(IsPrepay(oRechnung:Skonto))
         oRechnung:Porto := 0
      ELSEIF oRechnung:oLieferAdresse:CountryIso == "DE"
         oRechnung:Porto := 9.6
      ELSEIF oRechnung:oLieferAdresse:CountryIso $ {"CH","AT"}
         oRechnung:Porto := 25
      ELSEIF oRechnung:oLieferAdresse:CountryIso $ {"FR"}
         oRechnung:Porto := 20
      ELSEIF oRechnung:oLieferAdresse:CountryIso $ {"GB"}
         oRechnung:Porto := 70
      ELSE
         oRechnung:Porto := 35
      ENDIF
   ENDIF

   IF oRechnung:Versandart $ {0,14}
      oRechnung:VersandArt := 1
   ENDIF


RETURN .T.