PARAMETERS cUsername,cFile,oPrinter
LOCAL cGS,cProg

cTime := StrTran(Time(),":","_")

cTempPath := GetEnv("TEMP")
cDavidImp := "\\ek-server3\david\import"
cPdfOut := cTempPath+"\"+cUserName+"_"+DToS(Date())+"_"+cTime+".pdf"
//cImgOut := cTempPath+"\"+cUserName+"_"+DToS(Date())+"_"+cTime+"_img"
cImgOut := cDavidImp+"\"+cUserName+"_"+DToS(Date())+"_"+cTime+"_img"
//cFaxOut := cTempPath+"\"+cUserName+"_"+DToS(Date())+"_"+cTime+".fax"
cFaxOut := cDavidImp+"\"+cUserName+"_"+DToS(Date())+"_"+cTime+".fax"



nOutPdf := FCreate(cPdfOut,1)
If nOutPdf <= 0
	Alert("Error opening file "+cPdfOut+" (DOS Error "+LTrim(Str(Ferror()))+")")
	Return
Endif

cFile := StrTran(cFile,'"','')
nInPDF := FOpen(cFile,0)
If nInPdf <= 0
	Alert("Error opening file "+cFile+" (DOS Error "+LTrim(Str(Ferror()))+")")
	Return
Endif

cLine := ""
cRegex := "@@.*"
cCmds  := ""
Do While HB_FReadLine(nInPdf,@cLine) == 0
	Do While (nF := At("@@",cLine)) > 0 .AND. (nE := At("@@",SubStr(cLine,nF+2))) > 0
		cCmds += SubStr(cLine,nF,nE+3)+Chr(13)+Chr(10)
		cLine := SubStr(cLine,0,nF-1)+Space(nE+3)+SubStr(cLine,nE+nF+3)
	Enddo
	FWrite(nOutPdf,cLine+Chr(13)+Chr(10))
Enddo
FClose(nOutPDF)
FClose(nInPDF)

cGS := "c:\Programme\gs\gs8.54\bin\gswin32c.exe"
If ! File(cGS) //new server (leopard)
	cGS := '"C:\Program Files\gs\gs9.06\bin\gswin64c.exe"'
   If ! File(&cGS) //new server (camel)
   	cGS := '"C:\Program Files (x86)\gs\gs9.14\bin\gswin32c.exe"'
      IF ! File(&cGS)
         oErr := ErrorNew("TRADER",1,0,"RUN","Ghostscript not found")
         Throw(oErr)
      ENDIF
   Endif
Endif

cGS := cGS+" -dNOPAUSE -dBATCH -sDEVICE=pcxmono -r200"  //-g is required to scale the docs correctly, but then the auto-rotate does not work for attachements!

cProg := cGS+" -g1728x2286 -sOutputFile="+cImgOut+".%d "+cPdfOut //
__Run(cProg)

FErase(cPdfOut)

IF ValType(oPrinter) == "O"
   Alert(Len(oPrinter:Attachements))
   FOR nX := 1 TO Len(oPrinter:Attachements)
      cProg := cGS+" -sOutputFile="+cImgOut+".A"+Ltrim(str(nX))+"-%d X:\run\auto-rotate.ps "+oPrinter:Attachements[nX]
      __Run(cProg)
   NEXT
ENDIF

//Alert("TEST")

SET PRINTER TO (cFaxOut)
SET PRINTER ON
SET CONSOLE OFF

? cCmds //OUTPUT THE COMMANDS LIKE FAXNO
aDir := Directory( cImgOut+".*" )
AEval( aDir, {|a,n| If(n>1,QQout("@@SEITENENDE@@"),""),QQout("@@APIGRAFIK "+cDavidImp+"\"+a[1]+" DEL@@" ) } )

SET PRINTER TO
SET PRINTER OFF
SET CONSOLE ON

/*rem d:\DAVID\APPS\FAXWARE\OUT\IMG\

echo @@OWNERNAME %1@@ >>"%david_pcl_out%"
echo @@NUMMER %2@@ >>"%david_pcl_out%"

set count=0

for %%f in (%david_img_out%.*) do echo @@APIGRAFIK %%f DEL@@ @@SEITENENDE@@ >>"%david_pcl_out%"

@rem echo %2 "\\bull\david\import\%1_%date:~0%_%time:~0,2%_%time:~3,2%-%time:~6,2%-%time:~9,2%.pcl"
copy "%david_pcl_out%" "\\bull\david\import\%1_%date:~0,2%_%date:~3,2%_%date:~6,3%_%time:~0,2%_%time:~3,2%-%time:~6,2%-%time:~9,2%.pcl"


if errorlevel 1 pause
*/