PARAMETERS oPrinter,cType,cText,nSize

cSize := Ltrim(Str(nSize))

cDir := "d:\Programme\ImageMagick-6.6.4-Q16\"
If ! File(cDir+"convert.exe")
	cDir := "C:\Program Files\ImageMagick-7.0.7-Q8\"
Endif
cFont := ""

cOutfile := Trim(Tr_getini(1))+"\images\barcode\"+cType+"_"+HB_MD5(cText)+"_"+cSize+".jpg"
//cOutfile := GetEnv("temp")+cType+"_"+TtoS(DateTime())+"_"+cSize+".jpg"

If cType == "C39"
	nX := 0
	cFont := "c:\windows\fonts\code39.ttf"
	cText := Barcode_Code39(cText)
Elseif cType == "C128"
	//for code 128 we will need to calculate the checksum
	cFont := "c:\windows\fonts\code128_0.ttf"
//	cFont := "c:\windows\fonts\luccon.ttf"
   cText := Barcode_Code128(cText)
Endif


If ! Empty(cText)
	//Escape quotes
   cText := StrTran(cText,'"','\"')
   
   //Alert(cType+";"+cText)

	nRet := 0
	If ! File(cOutFile) .OR. FileDate( cOutFile ) < SToD("20190124") //only create if it does not exist, files before the 1.10.15 could be defect
	  cCP := HB_CDPSelect("DEWIN")
	  cText := StrTran(cText,"\","\\")
	  cText := StrTran(cText,'"','\"')

	  nRet := Wapi_ShellExecute(NIL,"open",cDir+"magick","convert -font "+cFont+" -density 600 -pointsize "+cSize+' label:"'+cText+'" "'+cOutFile+'"',cDir)

	  HB_CDPSelect(cCP)
	Endif
	nTime := 0
	Do While ! File(cOutFile) .AND. nTime <= 2 .AND. nRet > 32
//		SecondsSleep(0.2)
		Inkey(0.2)
		nTime += .2
	Enddo
	If File( cOutFile ) //.AND. FileDate( cOutFile ) >= Date()-30
		oPrinter:Data:Image(cOutFile)
	Else
	   IF Tr_getini(28) == 9
   		Alert(HB_AnsiToOem("Kein Barcode erstellt für ")+cText)
   	ENDIF
		//Alert("Return code:"+Str(nRet))
	Endif
Endif
//Endif

Return ""