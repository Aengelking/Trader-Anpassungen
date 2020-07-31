#include 'hbgtinfo.ch'

cFile := GetBox(Space(10),"Maskfile")
aMsk := MaskArr(Trim(cFile))
aDisp := {}
AEval(aMsk,{|cMsk,nX| Aadd(aDisp,Str(nX,3)+" "+cMsk) })
nX := 1
Do While LastKey() != 27
	nX := AChoice(0,0,MaxRow(),MaxCol(),aDisp,,,nX)
	If nX > 0 .AND. nX <= Len(aMsk)
		//gtSetClipboard( aMsk[nX] )
		hb_gtinfo( HB_GTI_CLIPBOARDDATA, aMsk[nX] )
	Endif
Enddo
