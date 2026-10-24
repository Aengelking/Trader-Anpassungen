/*oPDF := CreateObject("AcroExch.PDDoc") //CreateObject("AcroExch.App")
oPDF:Open("C:\Users\Amos\Downloads\N_en.pdf")
Alert(Str(oPdf:GetNumPages()))*/

//wapi_CreateWindowEx( 0, "TraderPDFView", "123", nStyle, nLeft, nTop, nWidth, nHeight, hWnd, 0 )

oPDF := CreateObject("AcroExch.AVDoc") //CreateObject("AcroExch.App")
Alert(ValToPrg(oPDF:Open("C:\Users\Amos\Downloads\N_en.pdf","")))
oPDF:BringToFront()
Alert("Waiting...")
oPdf:Close()



