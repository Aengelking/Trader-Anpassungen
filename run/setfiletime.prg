PARAMETERS cFile,cDate
dDate := CToD(cDate)

Alert(cFile)
Alert(DtoC(dDate))
IF ! File(cFile)
   Alert("file not found")
ENDIF

SetFDaTi(cFile,dDate,dDate)