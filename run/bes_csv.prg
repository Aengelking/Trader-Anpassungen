PROCEDURE RUN_BES_CSV
   LOCAL cLiefma,cFile,nH,cArtLief,cME
NetUse("artikel","art",.F.,0)
NetUse( "opttext","otx",.F.,0 )
NetUse( "option","op",.F.,0 )
NetUse("artlief","ali",.F.,0)
NetUse("engkund","ku",.F.,0)
NetUse("btrans","tr",.F.,0)
NetUse( "engtext2","tx",.F.,0 )
NetUse("lagerne","lne",.F.,0)
NetUse("engbes","bes",.F.,0)
NetUse("werkauf","wer",.F.,0)
NetUse("me","me",.F.,0)

cLiefma := Space(8)


	cLiefma := GetBox(cLiefma,"Lieferant","@!")
	If LastKey() == 27
		Return
	Endif

	bes->(dbSetOrder(6)) //liefma+besnr+posnr
	art->(dbSetOrder( 2 ))

	bes->(dbSeek( cLiefma ))
	If bes->Liefma != cLiefma
		Tr_MsgBox("Keine Bestellungen gefunden")
		RETURN
	Endif

	cFile := Trim(Tr_Getini(1))+"\export\"+trim(bes->Liefma)+"_bestellungen.csv"
	nH := FCreate(cFile)
	If nH == 0
		Alert(t("Datei (%) kann nicht erstellt werden",cFile))
	Endif
	FWrite(nH,"Datum,Nummer,Position,AB,Artikel,Artikel Lieferant,Wunschtermin,Termin,Bestätigt,Menge,Geliefert,Beistellware,Preis,PE")
        FWrite(nH,Chr(13)+Chr(10))

	Do While bes->Liefma == cLiefma
		If bes->bestat < 3 .AND. bes->beqty-bes->gelqty > 0
			art->(dbSeek( Str(bes->artikelnr,6) ))
			cArtLief := ""
			If ali->(dbSeek( bes->liefma+STR( bes->Artikelnr,6 )))
                        	cArtLief := Trim(ali->Artlief)
                        Endif
                        cMe := Me(art->Me)
			FWrite(nH,DToC(bes->Besda)+","+Str(bes->besnr,6)+","+Str(bes->posnr,3)+","+bes->abnr+","+Trim(art->Matchcode)+","+cArtLief+","+NiceWeek(bes->WTerm)+","+NiceWeek(bes->LTerm)+",")
			FWrite(nH,t(If(bes->Confirmed=="Y","Ja","Nein"))+","+Transform(bes->BeQty,cMe)+","+Transform(bes->GelQty,cMe)+",")
			wer->(dbSetOrder(6))
			If wer->(dbSeek(Str(bes->besnr,6)))
				If lne->(dbSeek(wer->LagNum))
					FWrite(nH,DToC(lne->Datum))
				Else
					FWrite(nH,"ausstehend")
				Endif
			Endif
			FWrite(nH,","+Str(bes->EkPr,12,2)+","+Str(bes->Pe,4))
			FWrite(nH,Chr(13)+Chr(10))
		Endif
		bes->(dbSkip())
	Enddo

	FClose(nH)

