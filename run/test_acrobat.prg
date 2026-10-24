oPDF := CreateObject("AcroExch.PDDoc")
IF ValType(oPDF) == "O"
   Alert("Object created")
   oPDF:Open("\\EK-SERVER4\data\Dokumente und Einstellungen\Amos\Eigene Dateien\Zahlungen\zahlung.pdf")
   //nPages := oPdf:GetNumPages()
//   Alert("AcroExch API not found")
ENDIF
