LOCAL cMatch := "",nArtnr :=0,nAngnr := 0

IF Tr_MsgBox("Staffelpreispositionen im Angebot akualisieren",,{"Ja","Nein"}) != 1
   RETURN
ENDIF

NetUse("angebot","ang")
ang->(dbSetOrder(1))
ang->(dbGoTop())

DO WHILE ! ang->(EOF())
   IF ang->Angnr == nAngnr .AND. Left(ang->Matchcode,1) == "@"  .AND. Left(cMatch,1) != "@" .AND. ang->vkPr != 0 .AND. ang->VkQty != 0
      ? ang->Angnr,cMatch
      ang->(Rec_Lock())
      ang->Matchcode := cMatch
      ang->Artikelnr := nArtnr
      ang->(dbUnLock())
   ELSE
      cMatch := ang->Matchcode
      nArtnr := ang->Artikelnr
   ENDIF
   nAngnr := ang->Angnr
   ang->(dbSkip())
ENDDO