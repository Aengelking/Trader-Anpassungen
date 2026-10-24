nX := 1
nMask := 2+128+516
	? NToC(nMask,2,24,"0")
Do While nX <= 8388608
	? nX,NToC(nX,2, 24, "0" ),NToC(nX & nMask,2,24,"0"),nX & nMask > 0

	nX *= 2
Enddo
Inkey(0,128)