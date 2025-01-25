PROC TEST_EMAIL_FROM
      Alert(HB_CmdArgArgV())
   //Alert(ValToPrg(GetConfigValue("LOCALDOMAINS")))
   Alert(GetConfigValue("EMAIL-FROM_SALESINVOICE"))
   Alert(GetConfigValue("EMAIL-FROM_SALESQUOTE"))
   Alert(GetConfigValue("EMAIL-FROM_SALESORDER"))
   RETURN 