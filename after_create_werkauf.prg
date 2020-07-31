PARAMETERS nNr,lFehl,lChange,cMissing

#define CRLF  "<BR>" //Chr(13)+Chr(10)

LOCAL cDir  := "Y:\Technik\Prozessdoku\"
LOCAL cText := ""
//LOCAL aTo   := {{"GF","Geschäftsführung"}} 
LOCAL aTO   := {{"hp@engelking.de","HP"}}
LOCAl nW

IF ValType(lChange) != "L"
	lChange := .F.
ENDIF

IF ! lChange .AND. ! Empty(wer->Liefma) .AND. Trim(wer->Liefma) $ "WETEC HECK"

	art->(dbSetOrder( 2 ))
	IF ! art->(dbSeek( Str(wer->artno,6) ))
		Tr_MsgBox("Artikel "+Ltrim(str(wer->artno))+" nicht gefunden")
	ENDIF
	
	IF ! Left(art->Gruppe,2) == "KO" .OR. Empty(art->Zeichnung)  //Bei Konfektionen reicht eine Endzeichnung
		//Lohnartikel suchen
		we->(dbSeek( Str(wer->aufno,6) ))
		DO WHILE we->aufno == wer->aufno
			IF we->pos == -1
				art->(dbSetOrder( 2 ))
				IF ! art->(dbSeek( Str(we->partart,6) ))
					Tr_MsgBox("Artikel "+Ltrim(str(we->partart))+" nicht gefunden")
				ENDIF
				EXIT
			ENDIF
			we->(dbSkip())
		ENDDO
	ENDIF
	cFile := MBAseRun(Trim(Tr_Getini(1))+"\run\getdrawing") //cDir+Trim(art->Zeichnung)+".pdf"
	IF Empty(cFile) // .OR. ! File(cFile))
		nW := 19
		cText := CRLF+t("Für den nachfolgenden Werkstattsauftrag fehlt die Arbeitsanweisung.")+CRLF+CRLF
		cText += Pad("Werkstattsauftrag:",nW)+LTrim(Str(wer->aufno))+CRLF
		cText += Pad("Fertiger:",nW)+wer->Liefma+CRLF
		cText += Pad("Arbeitsschritt:",nW)+art->Matchcode+CRLF
		cText += Space(nW)+art->Artikel+CRLF
		art->(dbSeek( Str(we->listart,6) ))
		cText += Pad("Fertigteil:",nW)+art->Matchcode+CRLF
		cText += Space(nW)+art->Artikel+CRLF
		cText += Pad(t("Stückzahl:"),nW)+LTrim(Transform(wer->Qty,Me(art->Me)))+" "+art->Me+CRLF
		cText += Pad("Fertigungsbeginn:",nW)+DToC(CalWD( wer->Termin ))+CRLF
		IF  Empty(art->Zeichnung)
			cText += "Keine Zeichnungsnummer vorhanden!"
		ELSE
			cText += Pad("Zeichnung:",nW)+art->Zeichnung+" "+art->ZeichIndex
		ENDIF
	ENDIF

	IF ! Empty(cText)
		SendMail(aTo,"Fehlende Arbeitsanweisung",cText,,,2,.T.)
	ENDIF
ENDIF

If wer->Termin <= Val(CalWeek(DATE())) .AND. ! lFehl 
   IF Tr_MsgBox("Auftrag zum Richten freigeben?",,{"Ja","Nein"})==1
	/*lne->(dbSetOrder(1))
	If lne->(dbSeek( wer->LagNum ))
		UpdateLNEStatus(lne->Nummer,1)
	Endif*/
      IF Hook("before_start_werkauf",{wer->Aufno,wer->artno},.T.)
         WAStart(wer->Aufno,.F.)
      ENDIF
   ENDIF
ELSEIF lFehl
   IF cMissing != NIL

      cScreen := SaveScreen()
      SetColor(c_five)
      @ 09,09 TO 31,61
      MemoEdit(cMissing,10,10,30,60,.F.)
      RestScreen(,,,,cScreen)
      SetColor(c_one)

   ELSE
      Tr_MsgBox("Auftrag wird nicht gefertigt werden k”nnen")
   ENDIF
Endif


