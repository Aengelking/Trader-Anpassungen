LOCAL cMatch := Pad("p7097.KONF",25)
LOCAL hSup   := {=>},hData,cBuart

NetUse("engabg","abg")
abg->(dbSetOrder( 3 ))
abg->(dbSeek( cMatch , .T. ))

DO WHILE abg->Matchcode == cMatch
	? abg->BuArt,abg->Menge,abg->Liefma
	IF ! HHasKey(hSup,abg->Liefma)
		hSup[abg->Liefma] := {"WE"=>{},"RE"=>{}}
	ENDIF
	IF Trim(abg->BuArt) $ "WE RE"
		Aadd(hSup[abg->Liefma][Trim(abg->BuArt)],{"DATUM"=>abg->Datum,"BELEG"=>abg->Beleg,"MENGE"=>abg->Menge})
	ENDIF
	abg->(dbSkip())
ENDDO

CLS
StartPrint()
SET PRINTER ON

FOR EACH hData IN hSup
	? hData:__eNumKey()
	FOR EACH cBuart IN {"WE","RE"}
		? IF(cBuart=="WE","Wareneingang","Rechnungen")
		ASort(hData[cBuart],,,{|x,y| x["DATUM"] < y["DATUM"] })
		nSum := 0
		FOR nX := 1 TO Len(hData[cBuart])
			nSum += hData[cBuart][nX]["MENGE"]
			? hData[cBuart][nX]["DATUM"],Str(hData[cBuart][nX]["MENGE"],8,2),hData[cBuart][nX]["BELEG"]
		NEXT
		? Space(8),Replicate("-",8)
		? Space(8),Str(nSum,8,2)
	NEXT
NEXT
SET PRINTER OFF
CopyPrint()