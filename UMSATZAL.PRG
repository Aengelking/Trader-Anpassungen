Scroll( 0, 0 ) ; SetPos( 0, 0 )
Head("Umsatz pro Artikelgruppe")
lBill := .T.
lBook := .T.
@ 01,00 SAY "Billings" GET lBill PICTURE "Y"
@ 02,00 SAY "Bookings" GET lBook PICTURE "Y"
READ
If LastKey() == 27
  Return
Endif

// clean umsatz and bookings file
If ! Select("bk") == 0
  bk->(dbCloseArea())
Endif
NetUse("bookings","bk",.T.,0)
If lBook
  bk->(__dbZap())
Endif
bk->(dbCloseArea())


If ! Select("um") == 0
  um->(dbCloseArea())
Endif
NETUSE("umsatz","um",.T.,0)
If lBook .AND. lBill
  um->(__dbZap())
Else
  um->(dbGoTop())
  Do While ! um->(Eof())
    If lBook
      um->umsatz := 0
      um->Booking := 0
      um->pay := 0
    Endif
    If lBill
      REPLACE um->Booking WITH 0, um->pay WITH 0
    Endif
    um->(dbSkip())
  Enddo

  DELETE FOR um->Branch=="SUMM"
  um->(__dbPack())
Endif
um->(dbCloseArea())

NetUse("umsatz","um",.F.,0)
um->(dbSetorder(1))

NetUse("bookings","bk",.F.,0)

NetUse("artikel","art",.F.,0)
art->(dbSetOrder(2))

nkey := 0
If lBill
NETUSE("ENGLSRE","RE",.F.,0)
re->(dbSetOrder(0))
RE->(DBGOTOP())
nRec := re->(lastrec())
@ 09,01 SAY "Billings"
@ 10,15 SAY "VON "+STR(NREC,10)
while ! re->(EOF()) .AND. ! (nKey := Inkey()) == 27
  @ 10,0 SAY STR(re->(Recno()),10)
  If RE->REPOSNR <> 0 .AND. !(re->Kunde $ "ENGELKEL ENGELKIN")
    art->(dbSeek(Str(re->ArtikelNr,6)))
    cFind := art->Gruppe+Str(Year(re->RechDat),4)+Str(Month(re->RechDat),2)
    IF ! um->(dbSeek(cFind))
      um->(Add_Rec(0))
      um->Branch  := ART->GRUPPE
      um->Month   := STR(MONTH(RE->RECHDAT),2)
      um->Year    := STR(YEAR(RE->RECHDAT),4)
    ELSE
      um->(Rec_Lock(0))
    ENDIF
    um->Umsatz := UM->UMSATZ+(RE->PREIS*currate(re->money,"V")*re->aoqty/If(re->Pe==0,1,re->pe))
*    um->ek := um->ek+(art->letzte_ek*currate(art->money,"E")*re->aoqty/If(art->pe==0,1,art->pe))
    IF re->status >= 2
      um->pay := um->pay+(re->preis*currate(re->money,"V")*re->aoqty/If(re->pe==0,1,re->pe))
    ENDIF
    um->(dbUnlock())

  ENDIF
  re->(dbSkip(1))
ENDDO
re->(dbCloseArea())
Endif

nkey2 := 0
If lBook
NetUse("engauf","auf",.F.,0)
auf->(dbSetOrder(0))
auf->(dbGoTop())
nRec := auf->(lastrec())

@ 12,01 SAY "Bookings"
@ 13,15 SAY "VON "+STR(NREC,10)

Do While ! auf->(EOF()) .AND. ! nKey = 27 .AND. ! (nKey2 := Inkey()) == 27
  @ 13,00 SAY STR(auf->(Recno()),10)
  If !(auf->Kundma $ "ENGELKEL ENGELKIN")
    art->(dbSeek(Str(auf->ArtikelNr,6)))
    cFind := art->Gruppe+Str(Year(auf->BesDa),4)+Str(Month(auf->BesDa),2)
    IF ! um->(dbSeek(cFind))
      um->(Add_Rec(0))
      um->Branch  := ART->GRUPPE
      um->Month   := STR(MONTH(auf->BesDa),2)
      um->Year    := STR(YEAR(auf->BesDa),4)
    ELSE
      um->(Rec_Lock(0))
    ENDIF
    nQty := auf->VkQty
    If bestat >= 3 //when order is erledigt only used the delivered qty
      nQty := auf->GelQty
    Endif
    nAuf_book := (auf->VkPr*currate(auf->money,"V")*nqty/If(auf->Pe==0,1,auf->pe))
    um->Bookings := um->Bookings+nAuf_Book
*    um->ek := um->ek+(art->letzte_ek*currate(art->money,"E")*nqty/If(art->Pe==0,1,art->pe))
    um->(dbUnlock())

    If ! bk->(dbSeek(Left(art->Gruppe,2)+Str(Year(auf->BesDa),4)))
      bk->(Add_Rec(0))
      bk->Group := Left(art->gruppe,2)+Str( Year(auf->Besda), 4)
    Else
      bk->(Rec_Lock(0))
    Endif
    //cField := "bk->M_"+Strzero(Month(auf->BesDa),2)
    //(cField) := (cField)+nAuf_Book
    //Alert( &(cField) )
    nMonth := Month(auf->Besda)
    If nMonth == 1
      bk->M_01 := bk->M_01+nAuf_Book
    Elseif nMonth == 2
      bk->M_02 := bk->M_02+nAuf_Book
    Elseif nMonth == 3
      bk->M_03 := bk->M_03+nAuf_Book
    Elseif nMonth == 4
      bk->M_04 := bk->M_04+nAuf_Book
    Elseif nMonth == 5
      bk->M_05 := bk->M_05+nAuf_Book
    Elseif nMonth == 6
      bk->M_06 := bk->M_06+nAuf_Book
    Elseif nMonth == 7
      bk->M_07 := bk->M_07+nAuf_Book
    Elseif nMonth == 8
      bk->M_08 := bk->M_08+nAuf_Book
    Elseif nMonth == 9
      bk->M_09 := bk->M_09+nAuf_Book
    Elseif nMonth == 10
      bk->M_10 := bk->M_10+nAuf_Book
    Elseif nMonth == 11
      bk->M_11 := bk->M_11+nAuf_Book
    Elseif nMonth == 12
      bk->M_12 := bk->M_12+nAuf_Book
    Endif
  Endif
  auf->(dbSkip(1))
ENDDO
auf->(dbCloseArea())
Endif

//totals
@ 14,01 SAY "Summen"
um->(dbSetOrder(0))
um->(dbGoTop())
@ 15,15 SAY "VON "+Str(um->(LastRec()),10)
um->(dbSetOrder(1))
um->(dbGoTop())
nX:=0
Do While ! um->(Eof()) .and. ! nKey == 27 .AND. ! nKey2 == 27 .AND. ! Inkey() == 27
 If ! um->Branch == "SUMM"
  nX := nX+1
  @ 15,00 SAY Str(nX,10)
  nRec := um->(Recno())
  cYear := um->Year
  cMonth := um->Month
  nUmsatz := um->Umsatz
  nBook := um->Bookings
  nEk := um->Ek
  nPay := um->Pay

  cFind := "SUMM"+cYear+cMonth
  If ! um->(dbSeek(cFind))
    um->(Add_Rec(0))
    um->Branch  := "SUMM"
    um->Month   := cMonth
    um->Year    := cYear
  Else
    um->(Rec_Lock(0))
  Endif
  um->Umsatz := um->Umsatz+nUmsatz
  um->Ek := um->Ek+nEk
  um->Pay := um->Pay+nPay
  um->Bookings := um->Bookings+nBook
  um->(dbUnlock())
  um->(dbGoto(nRec))
  Endif
  um->(dbSkip())
Enddo

um->(dbCloseArea())
? "Beliebige Taste drcken..."
Inkey(0)
