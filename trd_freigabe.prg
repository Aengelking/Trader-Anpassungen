
PROC MASK_TRD_FREIGABE
   LOCAL nR
   MEMVAR c_five
NetUse("ppfdat","ppfd",.F.,0)

NetUse("engkund","ku",.F.,0)
ku->(dbSetOrder( 8 ))

SetColor(c_five)

Box( 10,05,MaxRow()-1,93,,.T.,1)

ku->(dbSeek( Str(ppf->Lieferant,6) ))

@ 10,79 SAY PadL("[ "+LTrim(Str(ppf->Nummer,10))+" ]",14,Chr(196))
@ 11,06 SAY "Zeichnung:"
@ 11,17 SAY Trim(ppf->Zeichnung)+" Ind. "+Trim(ppf->ZeichIndex)

If ppf->Lieferant != 0
	@ 11,45 SAY Pad(Trim(ku->Name1)+" "+ku->Name2,30)
	@ 12,45 SAY ku->Town
Endif

@ 12,06 SAY "Status...:"
@ 12,17 SAY GetFreigabeStatusText(GetFreigabeStatus())
@ 14,06 SAY "Datum"
@ 14,15 SAY "Status"
@ 14,45 SAY "Benutzer"
@ 14,76 SAY "Eingetragen"
@ 15,06 SAY Replicate(Chr(196),87)

ppfd->(dbSetOrder( 2 ))
ppfd->(dbSeek( Str(ppf->Nummer,10) ))
nR := 16
Do While ppfd->PPF == ppf->Nummer
	//@ nR,00 SAY ppfd->Type

	@ nR,06 SAY ppfd->Datum
	@ nR,15 SAY GetFreigabeStatusText({Trim(ppfd->Type),ppfd->Free})
   @ nR,45 SAY Pad(Buy(ppfd->User,.T.),30)
   @ nR,76 SAY DtoC(ppfd->AnlDatum)
   @ nR,85 SAY Pad(ppfd->AnlZeit,8)
	If ! Empty(ppfd->Address)
		nR++
		ku->(dbSeek( Str(ppfd->Address,6) ))
		@ nR,15 SAY Pad(Trim(Trim(ku->Name1)+" "+ku->Name2),60)
		@ ++nR,15 SAY GetContact(ppfd->Contact)["name"]
	Endif
	If Trim(ppfd->Type) == "DONE" .AND. ppf->Sonderfrei
		@ ++nR,15 SAY t("Sonderfreigabe")
		If ppf->Menge != 0
			@ ++nR,17 SAY t("für % %",{LTrim(Transform(ppf->Menge,Me(art->Me))),art->Me})
			@ ++nR,17 SAY t("verbraucht % %",{LTrim(Transform(ppf->Verbraucht,Me(art->Me))),art->Me})
		Endif
		If ppf->Bis > STod("")
			@ ++nR,17 SAY DToC(ppf->Bis)
		Endif
   Endif
   
	ppfd->(dbSkip())
	nR++
Enddo

SInkey(0,128)