PARAMETERS nArtnr,cArtlief
aSites := {"de","uk","fr"}
lD := .F. //Tr_Getini(28) == 9
nX := 1
nQty := 0
lFound := .F.
lQuit := .F.
nP := 29

//http://de.mouser.com/search/include/aoo_popup.aspx?mouserpartnumber=167-PX0731%2fS

nY := 1
cUrl := ""
cUrl := "http://www.mouser.de/search/include/aoo_popup.aspx?mouserpartnumber="+Trim(cArtlief)

oHttp := TIpClientHttp():new( cUrl )
If oHttp:open()

	cData := oHttp:ReadAll()
	If lD
	//	MemoEdit(cData)
	Endif
	If ValType(cData) == "C"
	lFound := .T.
		cQty := ""
		//If aSites[nX] != "fr"
			cMarker := "MouserProductAvail"
			cQty := SubStr(cData,At(cMarker,cData)+Len(cMarker),100)

			cMarker := "<br /><br />"
//			cMarker := " />"
			cQty := StrTran(SubStr(cQty,At(cMarker,cQty)+Len(cMarker),100),".","")

		If lD
			Alert(cQty)
		Endif

			cQty := SubStr(cQty,0,At(" ",cQty)-1)
		/*Else
			cQty := cData
		Endif*/
//						nQty += Val(SubStr(cData,RAt("|",cData)+1))
		If Type("nR") == "N"
			cMarker := "ContentMain_tdAvail"

                        cText := SubStr(cData,At(cMarker,cData)+Len(cMarker),100)

			cMarker := "<br /><br />"
			cText := SubStr(cText,At(cMarker,cText)+Len(cMarker)-1,100)

			cText := SubStr(cText,0,At("<br",cText)-1)

			If Val(LTrim(SubStr(cText,At(" ",cText)))) != 0
				@ nR,nP SAY LTrim(cText)
			Endif
			nP += Len(cText)+1

		Endif
		nQty += Val(cQty)
	Endif
Endif

oHttp:close()
nY++

if lQuit
	Return -2
ElseIf lFound
	Return nQty
Else
	Return -1
Endif
