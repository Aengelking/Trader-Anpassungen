PROC RUN_GEFAHRSTOFF
   LOCAL aArt := GetIdsWithExtraField("art","GEFAHR")
   LOCAL aArt2 := GetIdsWithExtraField("art","SDS")
   LOCAL oExtra
	LOCAL nX,nMont

	NetUse("artikel","art")
   NetUse("lager","lag")
   NetUse("werkauf","wer")
   NetUse("werks","we")

	art->(dbSetOrder( 2 ))
   lag->(dbSetOrder( 2 ))

   CLS
   @ 00,07 SAY "Produkt"
   @ 00,43 SAY "Menge"
   @ 01,43 SAY "Lager"
   @ 00,55 SAY "Menge"
   @ 01,55 SAY "Montage"

	FOR nX := 1 TO Len(aArt)
		IF art->(dbSeek( Str(aArt[nX],6) ))
         oExtra := art->(ExtraData():New(art->Artikelnr))
         IF oExtra:Gefahr
            nMont := 0
            IF lag->(dbSeek( Pad("097/",12)+Str(art->Artikelnr,6) ))
		         nMont := lag->LagerMenge            
            ENDIF
            we->(dbSetOrder( 2 ))
            wer->(dbSetOrder( 9 ))
            wer->(dbSeek( Str(1,1), .T. ))
            DO WHILE wer->Status <= 3 .AND. ! wer->(EOF())
               IF we->(dbSeek(Str(wer->Aufno,6)+Str(art->Artikelnr,6)))
                  nMont += we->BookQty
              ENDIF
               wer->(dbSkip())
            ENDDO
            
            ? aArt[nX],art->artikel,Pad(Transform(art->Bestand-nMont,Me(art->Me)),12),Pad(Transform(nMont,Me(art->Me)),12),art->Me
         ENDIF
      ENDIF
	NEXT
   
   ?
   ? "-- NUR SICHERHEITSDATENBLATT --"
   FOR nX := 1 TO Len(aArt2)
      //IF !aArt2[nX] $ aArt
		   IF art->(dbSeek( Str(aArt2[nX],6) )) 
            oExtra := art->(ExtraData():New(art->Artikelnr))
            IF ! oExtra:Gefahr
		         ? aArt2[nX],art->artikel,Transform(art->Bestand,Me(art->Me)),art->Me
            ENDIF
         ENDIF
      //ENDIF
	NEXT

	Sinkey(0)

	