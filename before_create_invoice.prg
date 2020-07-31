PROC HOOK_BEFORE_CREATE_INVOICE(oRechnung,lCredit)
   LOCAL oExtra

   Default(@lCredit,.F.)

   IF lCredit
      oRechnung:Porto := 0
      oRechnung:Versandart := 21
   ELSEIF oRechnung:oKunde:Portok == "Y"
      IF sk->(IsPrepay(oRechnung:Skonto))
         oRechnung:Porto := 0
      ELSEIF oRechnung:oKunde:CountryIso == "DE"
         oRechnung:Porto := 9.6
      ELSEIF oRechnung:oKunde:CountryIso $ {"CH","AT"}
         oRechnung:Porto := 25
      ELSEIF oRechnung:oKunde:CountryIso $ {"FR"}
         oRechnung:Porto := 20
      ELSE
         oRechnung:Porto := 35
      ENDIF
   ENDIF

   IF oRechnung:Versandart $ {0,14}
      oRechnung:VersandArt := 1
   ENDIF
RETURN