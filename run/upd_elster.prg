cWgetBin = "C:\Program Files (x86)\GnuWin32\bin\wget.exe"
dLastDate := SToD( MemoRead(Path("elster.txt") ))

cUrl := "http://support.lexware.de/produkte/buchhalter/aktualisierungen-detail?ID=000000000018182"
oHttp := TIpClientHttp():new( cUrl )
IF oHttp:open()
   cData := oHttp:ReadAll()
   nPos := AT("Datum:",cData)
   dNewDate := CToD(SubStr(cData,nPos+7,10))
   IF dNewDate > dLastDate
//      Alert("New Elster available!")
        Alert(GetEnv('temp'))
        HB_ChDir(GetEnv('temp'))
      WAPI_ShellExecute(,'open',cWgetBin,'http//download.lexware.de/pub/support/Financial_Office/elster_upd.exe')
   ENDIF
ENDIF
