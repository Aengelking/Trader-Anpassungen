#define NL Chr(13)+Chr(10)
#define D Chr(59)
nMaxCount := 30
nX := 0
nArt := 1
cText := ""
nThresh := 0.1

NetUse("artikel","art",.F.,0)
NetUse("artlief","alil",.F.,0)
NetUse("rsstock","rsto",.F.,0)

cFileBase := Path("stock\")
aFiles := {}

SetColor(c_one)
CLS

Do While ! rsto->(Eof())
	@ 01,00 SAY rsto->Matchcode

	art->(dbSeek( rsto->Matchcode ))
	nRs := 0
	nFarnell := 0

	If alil->(dbSeek(Pad("RS",8)+Str(art->Artikelnr,6))) .AND. ! Empty(alil->artlief)
		@ 02,00 SAY "RS"
		nRs := GetLiefStock("RS",art->Artikelnr)
	Endif
	If alil->(dbSeek(Pad("FARNELL",8)+Str(art->Artikelnr,6))) .AND. ! Empty(alil->artlief)
		@ 02,00 SAY "Farnell"
		nFarnell := GetLiefStock("FARNELL",art->Artikelnr)
	Endif
	@ 02,00 SAY Space(50)

        cMe := Me(art->me)
        nH := 0
        cFile := cFileBase+StrTran(StrTran(Trim(rsto->Matchcode),'\','_'),'/','_')+".csv"
        lNew := .F.
        If ! File(cFile)
        	nH := FCreate(cFile)
        	lNew := .T.
	Else
		nH := FOpen(cFile,2)
	Endif
	If nH != 0 .OR. FError() != 0
        	Aadd(aFiles,cFile)
		FSeek(nH,0,2) //goto end of file
        	If lNew
        		FWrite(nH, Pad("Datum",8)+D+Pad("Zeit",8)+D+Pad("Farnell",12)+D+Pad("RS",12))
        	Endif
        	FWrite(nH, NL+DToC(Date())+D+Time()+D+Pad(If(nFarnell>0,Ltrim(Transform(nFarnell,cMe)),""),12)+D+If(nRS>0,Pad(LTrim(Transform(nRS,cMe)),12),Space(12)) )
        	FClose(nH)
        	@ 03,00 SAY "Using file: "+cFile
        Else
        	@ 03,00 CLEAR TO 03,79
		@ 03,00 SAY "Error "+If(lNew,"creating","opening")+" file "+cFile+" (Dos Error: "+LTrim(Str(Ferror()))+")"
		Inkey(2)
        Endif
	If (nFarnell > 0 .AND. (rsto->Farnell == 0 .OR. ABS((nFarnell-rsto->Farnell)/rsto->farnell) >=nThresh) ).OR. (nRS > 0 .AND. (rsto->RS == 0 .OR. ABS((nRS-rsto->RS)/rsto->RS) >=nThresh))
		If Empty(cText)
			cText := DToC(Date())+Chr(13)+Chr(10)
			cText += HB_AnsiToOem(Pad("Matchcode",25)+" "+Pad("RS",Len(cMe))+" "+Space(7)+" "+Pad("Alt RS",Len(cMe))+" "+Pad("Farnell",Len(cMe))+" "+Space(7)+" "+Pad("Alt Farnell",Len(cMe))+" "+"Letzte Abfrage")
		Endif
		cText += Chr(13)+Chr(10)
		cText += art->Matchcode+" "+TransForm(nRS,cMe)+" "
		cText += Str(If(rsto->RS != 0,ABS((nRS-rsto->RS)/rsto->RS),0)*100,6,2)+"% "
		cText += TransForm(rsto->RS,cMe)+" "+TransForm(nFarnell,cMe)+" "
                cText += Str(If(rsto->Farnell != 0,ABS((nFarnell-rsto->Farnell)/rsto->farnell),0)*100,6,2)+"% "
                cText += TransForm(rsto->Farnell,cMe)+" "+DToC(rsto->Date)+" "+rsto->Time

		rsto->(Rec_Lock(0))
		rsto->RS 	  := nRS
		rsto->Farnell     := nFarnell
		rsto->Date	  := Date()
		rsto->Time        := Time()
		rsto->(dbUnLock())
		nX++
	Endif
	rsto->(dbSkip())

Enddo

If ! Empty(cText)
	//cText := "Lagerbestände von RS und Farnell wurden aktuallisiert. Siehe Anhang."
	//Sendmail({{"amos.engelking@engelking.de","Amos Engelking"}},"RS/Farnell stock",HB_AnsiToOem(cText),aFiles)
Endif
//? cText
//Inkey(0)