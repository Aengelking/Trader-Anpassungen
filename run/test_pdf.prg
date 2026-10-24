StartPrint(,,"PDF")
oPdf := GetCurrentPrinterObject():Data

oPdf:NewPage()
oPdf:AtSay("Hello World")
Alert(Trim(Tr_Getini(1))+"\images\eklogo.jpg")
oPdf:Image(Trim(Tr_Getini(1))+"\images\eklogo.jpg",,,'R')

CopyPrint()