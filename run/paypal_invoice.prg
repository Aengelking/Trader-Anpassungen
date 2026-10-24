PARAMETERS cFile
cApp := "C:\Program Files (x86)\gotomaxx\maxxPDFMAILER\PDFMailerApp.exe"
#ifndef __XHARBOUR_
	WAPI_ShellExecute(,"open",cApp,cFile)
#else
	ShellExecute(,"open",cApp,cFile)
#endif