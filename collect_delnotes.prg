//#ifndef __XHARBOUR__
//	#include 'xhb.ch'
//	#include 'y:\hb32\include\hbcompat.ch'
//#endif
#define UPDATE

NetUse("engabg","abg",.F.,0)
NetUse("artikel","art",.F.,0)

#ifdef UPDATE
   NetUse("ls","ls")
   NetUse("lspos","lsp")
   NetUse("lsbook","lsbk")
#else
   If Tr_MsgBox("This will replace all records in 'ls.dbf', 'lspos.dbf' and 'lsbook.dbf'. Continue?",,{"No","Yes"}) != 2
   	Return
   Endif
   
   DO WHILE .T.
   	TRY
   	NetUse("ls","ls",.F.,0)
   	NetUse("lspos","lsp",.T.,0)
   	ZAP
   	NetUse("lsbook","lsbk",.T.,0)
   	ZAP
   	CATCH
   		? "Error opening files"
   		IF Inkey(5) == 27
   			RETURN
   		ENDIF
   		LOOP
   	END
   	EXIT
   ENDDO
#endif

abg->(dbSetOrder( 4 ))
abg->(dbSeek("1"))

CLS

hDelNotes := {=>}

nCount := 0

Do While ! abg->(Eof())
	If Trim(abg->BuArt) == "WE" .AND. ! Empty(abg->Liefma) //.AND. abg->Datum >= StoD("20100101")
		@ 01,00 SAY abg->Liefma+abg->Beleg
		//? abg->Liefma+" "+abg->Beleg+" "+DToC(abg->Datum)
		cKey := abg->Liefma+abg->Beleg
		If ! hb_HHASKEY(hDelNotes,cKey)
			hDelNotes[cKey] := {}
		Endif
		Aadd(hDelNotes[cKey],{"liefma"=>abg->Liefma,"beleg"=>abg->Beleg,"date"=>abg->Datum,"matchcode"=>abg->Matchcode,"menge"=>abg->Menge,"besnr"=>abg->Besnr,"pos"=>abg->bespos})
		nCount++
	Endif
	abg->(dbSkip())
Enddo

#ifdef UPDATE
   @ 23,00 SAY "Suche nach neuen Lieferscheine"
aKey := hb_HKEYS(hDelNotes)

//remove any exisiting delivery notes,
FOR nX := 1 TO Len(aKey)
   @ 24,00 SAY aKey[nX]
   IF ls->(dbSeek( aKey[nX] ))
      HDel(hDelNotes,aKey[nX],.T.)
   ENDIF
NEXT
#endif


nX := 1

aKey := HGetKeys(hDelNotes)
ASort(aKey)



lsp->(dbSetOrder( 2 ))

CLS
nLsPos := 1

@ 23,00 CLEAR

@ 23,00 SAY "Einlesen neuer Lieferscheine"

Do While nX <= Len(aKey)

	aData := hDelNotes[aKey[nX]]
//	? aData[1]["liefma"],aData[1]["beleg"],aData[1]["date"]
	@ 24,00 SAY LTrim(Str(nX))+"/"+LTrim(Str(Len(aKey)))
	If ! ls->(dbSeek( aKey[nX] ))
		ls->(Add_Rec(0))
		ls->Liefma := aData[1]["liefma"]
		ls->Beleg  := aData[1]["beleg"]
		ls->Datum  := aData[1]["date"]
		ls->(dbUnLock())
	Endif

	nD := 1
	nPos := 1
	lNew := .F.
	Do While nD <= Len(aData)
		@ 24,30 SAY nD

		art->(dbSeek( aData[nD]["matchcode"] ))
		
		IF aData[nD]["besnr"] == 0 .OR. aData[nD]["pos"] == 0
		   lsp->(dbSetOrder( 2 ))
         lNew := ! lsp->(dbSeek( aData[nD]["liefma"]+aData[nD]["beleg"]+aData[nD]["matchcode"] ))
      ELSE
         lsp->(dbSetOrder( 4 ))
         lNew := ! lsp->(dbSeek( aData[nD]["liefma"]+aData[nD]["beleg"]+Str(aData[nD]["besnr"],6)+Str(aData[nD]["pos"],3) ))
      ENDIF

		IF ! lNew
			lsp->(Rec_Lock(0))
      ELSE
       	lsp->(Add_Rec(0))
       	lsp->LsPosnr   := nLsPos
			lsp->Liefma    := aData[nD]["liefma"]
			lsp->Beleg     := aData[nD]["beleg"]
			lsp->Matchcode := aData[nD]["matchcode"]
			lsp->Artnr     := art->Artikelnr
			lsp->Besnr     := aData[nD]["besnr"]
			lsp->Bespos    := aData[nD]["pos"]
			lsp->Pos := nPos
		Endif
		lsp->Menge     += aData[nD]["menge"]
		lsp->Geliefert += aData[nD]["menge"]
		lsp->(dbUnLock())

		/*If lsbk->(dbSeek( Str(nLsPos,10)+Str(aData[nD]["besnr"])+Str(aData[nD]["pos"]) ))
			lsbk->(Rec_Lock())
		Else*/
			lsbk->(Add_Rec())
      	lsbk->LsPosnr := nLsPos
      	lsbk->Datum   := aData[nD]["date"]
			lsbk->Besnr   := aData[nD]["besnr"]
			lsbk->BesPos  := aData[nD]["pos"]
			lsbk->Ok      := .T.
			lsbk->Status  := "BOOK"
		//Endif
		lsbk->Menge     += aData[nD]["menge"]
		lsbk->Geliefert += aData[nD]["menge"]
		lsbk->(dbUnLock())

//		? Space(8),nD,aData[nD]["matchcode"],aData[nD]["menge"]
		nD++
		If lNew
			nPos++
	                nLsPos++
	        Endif
	Enddo
	nX ++
Enddo

? "Finished"
IF ! GetConfigValue("BATCHMODE")
   SInkey(0)
ENDIF

