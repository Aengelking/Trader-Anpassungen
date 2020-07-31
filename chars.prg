CLS
Alert(HB_SetCodePage())
HB_SetCodePage("DEWIN")
//wvt_SetCodePage(255)
nC := 0
nR := 0
nX := 0
Do While nX <= MaxRow()*MaxCOl() //HexToNum("FFFF")
 @ nR,nC SAY Chr(nX)
 nC++
 nX++
 If nC > MaxCol()
 	nR++
 	nC := 0
 Endif
 If nR > MaxRow()
 	Inkey(0,128)
	CLS
	nC := 0
	nR := 0
 Endif

Next
Inkey(0,128)