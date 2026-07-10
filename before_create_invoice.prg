FUNC HOOK_BEFORE_CREATE_INVOICE(oRechnung,lCredit)
   LOCAL hContacts
   LOCAL aMsg

   MEMVAR mcInvoiceError
   PUBLIC mcInvoiceError

   Default(@lCredit,.F.)

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
   IF lCredit
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