PROC TEST_EMAIL_FROM
   Alert(ValToPrg(GetConfigValue("LOCALDOMAINS")))
   Alert(GetConfigValue("EMAIL-FROM_SALESINVOICE"))
   RETURN 