LOCAL oPos
LOCAL nVk,nApe,nDiscount


If TR_getini(28) != 9
	Tr_MsgBox("Zugang verweigert!")
	Return
Endif

IF ProcName(8) $ "ENGAUFT ENGBEST"
   lAuftrag := ProcName(8) == "ENGAUFT"
ELSE
   Tr_MsgBox(t("Kein Auftrag geöffnet"))
   RETURN
Endif

IF ! lAuftrag .AND. bes->GelQty != 0
   Tr_MsgBox("Bereits beliefert!")
   RETURN
ENDIF

art->(dbSetOrder( 1 ))
art->(dbSeek( IF(lAuftrag,auf->Matchcode,bes->Matchcode) ))

fol->(dbSetOrder( 1 ))
If ! fol->(dbSeek( Str(art->Artikelnr,6) ))
   Tr_MsgBox("Artikel "+Trim(art->Matchcode)+" hat keine Folgeartikel!")
   Return
Endif

If Tr_MsgBox("Folgeartikel von Pos. "+Ltrim(Str(auf->Itmnr))+" "+Trim(art->Matchcode)+" aktualisieren?",,{"Nein","Ja"}) != 2
   Return
Endif

nFCount := 0
Do While ! fol->(Eof()) .AND. fol->Artikelnr == art->Artikelnr
   nFCount ++
   fol->(dbSkip())
Enddo

SetColor(c_five)
@ 10,10 CLEAR TO 40,50
@ 10,10 To 40,50

nR := 11

IF lAuftrag
   nPos := auf->ItmNr
   nRec := auf->(Recno())
   nAbnr := auf->AbNr
   
   auf->(dbSkip())
   Do While auf->FolgeTo == nPos .AND. auf->AbNr == nAbnr .AND. ! auf->(Eof())
      @ nR++,11 SAY t("Lösche Pos. "+LTrim(Str(auf->Itmnr))+" "+Trim(auf->Matchcode))
      auf->(Rec_Lock())
      auf->(dbDelete())
      auf->(dbUnLock())
      auf->(dbSkip())
   Enddo

   aRec := {}

   If auf->AbNr == nAbnr .AND. auf->ItmNr != nPos+nFCount+1
      nNewPos := nPos+nFCount+1
      Do While auf->Abnr == nAbnr .AND. ! auf->(Eof())
   	  Aadd(aRec,{"old"=>auf->Itmnr,"new"=>nNewPos++})
         auf->(dbSkip())
      Enddo
   Endif

   FOR nX := Len(aRec) TO 1 STEP -1
       @ nR++,11 SAY t("Verschiebe Pos. "+LTrim(Str(aRec[nX]["old"]))+"->"+LTrim(Str(aRec[nX]["new"])) )
       IF auf->(dbSeek( Str(nAbnr,6)+Str(aRec[nX]["old"],3) ))
       	auf->(Rec_Lock())
       	auf->Itmnr := aRec[nX]["new"]
       	IF ! Empty(auf->Folgeto) .AND. (nY := AScan(aRec,{|x| x["old"] == auf->Folgeto})) != 0 //check if the parent position has been moved
            auf->FolgeTo := aRec[nY]["new"]
       	ENDIF
       	auf->(dbUnLock())
       ENDIF
   NEXT

   nArtnr := art->Artikelnr
   nNewPos := nPos+1

   auf->(dbGoto( nRec ))

   oPos      := AuftragPos():New(.F.)
   nVk       := 0
   nApe      := 0
   nDiscount := 0


   auf->(dbGoTo( nRec ))
   fol->(dbSeek( Str(nArtnr,6) ))
   Do While fol->Artikelnr == nArtnr .AND. ! fol->(Eof())
         art->(dbSetOrder(2))
         art->(dbSeek(Str(fol->Folgeart,6)))

         @ nR++,11 SAY t("Füge "+Trim(art->Matchcode)+" hinzu ("+LTrim(Str(nNewPos))+")")

         aku->(dbSetOrder(1))
         aku->(dbSeek( oPos:KundMa+Str( art->Artikelnr,6 )))
         If aku->(Found())
           nVk       := aku->lastprice
           nApe      := aku->pe
           nDiscount := aku->rabatt
         Else
           nVk       := if(ku->kundenart == 0,ART->letzte_vk,art->vkpreis2)
           nApe      := art->pe
           nDiscount := 0
         Endif

         IF nApe == 0
            nApe := 1
         ENDIF

         auf->(Add_Rec(0))

         auf->Kundma    := oPos:KundMa
         auf->Matchcode := ART->MATCHCODE
         auf->Abnr      := nAbnr
         auf->Itmnr     := nNewPos++
         auf->Besda     := oPos:Besda
         auf->Aufnr     := oPos:Aufnr
         auf->Artikelnr := ART->ARTIKELNR
         auf->Money     := oPos:Money
         auf->Rate      := currate(oPos:Money,"V")
         auf->Vkpr      := IF(FOL->PREIS,nVk,0)
         auf->Dterm     := oPos:Dterm
         auf->Wterm     := oPos:Wterm
         auf->WDatum    := oPos:Wdatum
         auf->BDatum    := oPos:BDatum
         auf->Pe        := nApe
         auf->Rabatt    := nDiscount
         auf->Delad     := oPos:Delad
         auf->ReLiefAdr := oPos:ReLiefAdr
         auf->Buyer     := oPos:Buyer
         auf->Folge      := .T.
         auf->FolgeTo    := nPos
         auf->FolgeFakto := fol->Faktor
         auf->Vkqty     := oPos:VkQty*FOL->FAKTOR
         auf->Person    := oPos:Person
         auf->Head       := "N"
         auf->( dbUnlock() )

         fol->(dbSkip())
   Enddo
ELSE
   nPos := bes->Posnr
   nRec := bes->(Recno())
   nBesnr := bes->Besnr

   bes->(dbSkip())
   DO WHILE bes->FolgeTo == nPos .AND. bes->Besnr == nBesnr .AND. ! bes->(Eof())
      @ nR++,11 SAY t("Lösche Pos. "+LTrim(Str(bes->Posnr))+" "+Trim(art->Matchcode))
      bes->(Rec_Lock())
      bes->(dbDelete())
      bes->(dbUnLock())
      bes->(dbSkip())
   ENDDO

   aRec := {}


   IF bes->Besnr == nBesnr .AND. bes->Posnr != nPos+nFCount+1 //there is not enough space for the required records
      nNewPos := nPos+nFCount+1
      Alert(nNewPos)
      DO WHILE bes->Besnr == nBesnr .AND. ! bes->(Eof())
   	  Aadd(aRec,{"old"=>bes->Posnr,"new"=>nNewPos++}) //save the new position
        bes->(dbSkip())
      ENDDO
   ENDIF

   FOR nX := Len(aRec) TO 1 STEP -1
       @ nR++,11 SAY t("Verschiebe Pos. "+LTrim(Str(aRec[nX]["old"]))+"->"+LTrim(Str(aRec[nX]["new"])) )
       IF bes->(dbSeek( Str(nBesnr,6)+Str(aRec[nX]["old"],3) ))
       	bes->(Rec_Lock())
       	bes->Posnr := aRec[nX]["new"]
       	bes->(dbUnLock())
       ENDIF
   NEXT

   nArtnr := art->Artikelnr
   nNewPos := nPos+1

   bes->(dbGoto( nRec ))
   oBes := { ;   //temp solution until we create a bestellung DB
      "DATE"=>bes->Besda,;
      "LIEFMA"=>bes->Liefma,;
      "PERSON"=>bes->Person,;
      "ABNR"=>bes->Abnr,;
      "PAY"=>bes->Pay,;
      "RAHMEN"=>bes->Rahmen,;
      "MONEY"=>bes->Money,;
      "BUYER"=>bes->Buyer,;
      "BEQTY"=>bes->BeQty,;
      "WTERM"=>bes->WTerm,;
      "LTERM"=>bes->Lterm;
   }

   bes->(dbGoTo( nRec ))
   fol->(dbSeek( Str(nArtnr,6) ))
   Do While fol->Artikelnr == nArtnr .AND. ! fol->(Eof())
         art->(dbSetOrder(2))
         art->(dbSeek(Str(fol->Folgeart,6)))

         @ nR++,11 SAY t("Füge "+Trim(art->Matchcode)+" hinzu ("+LTrim(Str(nNewPos))+")")

         bes->(Add_Rec(0))
         bes->besnr     := nBesnr
         bes->posnr     := nNewPos++
         bes->liefma    := oBes:Liefma
         bes->besda     := oBes:Date
         bes->matchcode := art->matchcode
         bes->artikelnr := art->Artikelnr
         bes->buyer     := oBes:Buyer
         bes->confirmed := IF(EMPTY(oBes:AbNr),"N","Y")
         bes->pay       := oBes:Pay
         bes->abnr      := oBes:AbNr
         bes->person    := oBes:Person
         bes->Printed   := .F.
         bes->beqty     := oBes:BeQty*fol->Faktor
         bes->wterm     := oBes:WTerm
         bes->LTerm     := oBes:LTerm
         bes->Mahnen    := .F.
         bes->Pe        := 1
         bes->money     := oBes:Money
         bes->rate      := currate(oBes:Money,"E")
         bes->FolgeTo   := nPos
         bes->FolgeFakto  := fol->Faktor
         bes->( dbUnlock() )

         fol->(dbSkip())
   Enddo


ENDIF

@ 39,11 SAY "Aktualisierung abgeschlossen"
@ 40,11 SAY "[ Weiter mit >ENTER< ]"

Do While Inkey(0) != 13
Enddo