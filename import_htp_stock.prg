cFileName := "D|/Dokumente%20und%20Einstellungen/Amos/Eigene%20Dateien/Downloads/HTP_srl_Stock_List_online_dated_25.07.2011.xls"

oServiceManager := win_OleCreateObject( "com.sun.star.ServiceManager" )
If ValType(oServiceManager) != "O"
	Alert("Error loading OpenOffice;"+WIN_OLEERRORTEXT())
	Return
Endif
oDesktop := oServiceManager:createInstance( "com.sun.star.frame.Desktop" )

aArg := {}

oDocument := oDesktop:loadComponentFromURL( cFilename, "_blank", "0", aArg )