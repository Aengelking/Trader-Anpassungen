cUrl := "http:/"+"/localhost:8082"
oUrl := tUrl():New( cUrl )
oUrl:nPort := 8082
oHttp := TIpClientHttp():new( oUrl )
If oHttp:open() .AND. oHttp:Get()
	If ! GetConfigValue("batchmode")
  		Alert("UHTTPD already running")
	Endif
Else
	UHttpd()
Endif