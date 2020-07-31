cUrl := "http://192.168.2.200/Amos%20Engelking/pda.htm"
oUrl := tUrl():New( cUrl )
oUrl:cUserID := "amos"
oUrl:cPassWord := ""

oHttp := TIpClientHttp():new( oUrl )

oHttp:UseBasicAuth()
oHttp:open()
oHttp:Post("\024\0005\t\b\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\017\000\004\001<\000\000d\f\000\000\000\206Y\n"+Chr(13)+Chr(10)+"\021S\035i\353\031\346\321\3451\000\000\024\001\000\000\000C\000\000D257e68f9590f03b06a82845170c87e3b434302efba386a7c404d36b2ab366709\000J\000\000DAmos\342\200\231s iPhone\000")
oHttp:readAll()
oHttp:close()