cUrl := "https://tracking.dpd.de/parcelstatus?query="+Trim(mcBoxNumber)+"&locale=de_DE"
Wapi_ShellExecute(NIL,"open",cUrl,"","")
