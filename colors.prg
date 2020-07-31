/*aColors := {"B","B+","BG","BG+","G","G+","GR","GR+","N+","N","R","R+","RB","RB+","U","W","W+"}
nX := 1
CLS
Do While nX <= Len(aColors)
	@ nX,00 SAY aColors[nX]
	@ nX,03 SAY Space(20) COLOR "N/"+StrTran(aColors[nX],"+","*")
	nX++
Enddo
Inkey(0,128)*/
c_one 	:= 'N/W,N/B+,N+/W*,N+/BG,N/W*'             //DCOL1

