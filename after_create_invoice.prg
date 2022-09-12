PROC HOOK_AFTER_CREATE_INVOICE(oRechnung)
   LOCAL oExtra,nRenr
   LOCAL nNetto

   IF ValType(oRechnung) == "N"
      nRenr := oRechnung
      oRechnung := Rechnung():New()
      oRechnung:Load(nRenr)
   ELSE
      nRenr := oRechnung:Rechnr
   ENDIF

   oRechnung:oKunde:gotoRec()
   oExtra := ku->(ExtraData():New(ku->Nummer))

   IF oExtra:PortoUnter != 0
      nNetto := oRechnung:Brutto
      IF oRechnung:ReArt < 2
         nNetto -= oRechnung:MwSt
      ENDIF
      nNetto -= oRechnung:Porto
      IF nNetto >= oExtra:PortoUnter
         oRechnung:Porto := 0
         oRechnung:UpdateTotal(.T.)
      ENDIF
   ENDIF 
      
   If oRechnung:Brutto > 0 .AND. (GetConfigValue("BATCHMODE") .OR. Tr_MsgBox("Rechnung zum Versand freigeben?",,{"Ja","Nein"}) == 1)
      ShipInvoice(nRenr)
   ELSEIF oRechnung:Brutto <= 0
      Rechcha(oRechnung:Rechnr)
   Endif
