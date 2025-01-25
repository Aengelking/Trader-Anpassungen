PROC Bericht_Ausschuss()

	LOCAL dEnd := Date()
	LOCAL dStart   := Boy(dEnd)
   LOCAL hArtikel := {=>},aArtikel
   LOCAL aList := {}
   LOCAL getlist := {}

   Head("Ausschuss interne Fertigungsauftraege")

   @ 01,00 SAY "Startdatum" GET dStart VALID dStart <= Date()-1
   @ 02,00 SAY "Enddatum  " GET dEnd VALID dEnd > dStart .AND. dEnd <= Date()
   READ

   IF LastKey() == 27
      RETURN
   ENDIF

	NetUSe("werkauf","wer")
   NetUse("artikel","art")

	wer->(dbSetOrder( 4 )) //date
   art->(dbSetOrder( 2 )) //artno

	wer->(dbSeek( dStart, .T. ))

	DO WHILE !wer->(Eof())
      IF wer->StartDate >= dStart .AND. wer->StartDate <= dEnd               
         IF ! HHasKey(hArtikel,wer->Artno)
            hArtikel[wer->Artno] := {"TOTAL"=>0,"BAD"=>0,"PLANBAD"=>0}
         ENDIF
         hArtikel[wer->Artno]["TOTAL"] += wer->Qty
         hArtikel[wer->Artno]["PLANBAD"] += wer->Planbad
         hArtikel[wer->Artno]["BAD"] += wer->BadQty
		   ? wer->Date,wer->StartDate,wer->Artno,wer->Qty,wer->BadQty
      ENDIF
		wer->(dbSkip())
	ENDDO

   Aadd(aList,{"Artikel","Gesamt","Ausschuss","Ausschuss %","Geplanter Ausschuss","Ausschuss ber Plan %"})

   FOR EACH aArtikel IN hArtikel      
      art->(dbSeek( Str(aArtikel:__eNumKey(),6) ))      
      ? art->Matchcode,aArtikel["TOTAL"],aArtikel["BAD"],aArtikel["BAD"]/aArtikel["TOTAL"]*100
      Aadd(aList,{Trim(art->Matchcode),aArtikel["TOTAL"],aArtikel["BAD"],aArtikel["BAD"]/aArtikel["TOTAL"]*100,aArtikel["PLANBAD"],IF(aArtikel["BAD"]-aArtikel["PLANBAD"]!=0,aArtikel["PLANBAD"]/(aArtikel["BAD"]-aArtikel["PLANBAD"])*100,"")})
   NEXT


   SaveToOO_Interface(aList)

	//? "Press a key to continue"


	//Sinkey(0)
   