

Head("Planung Fertigung")



lUpDate := .F.
getlist := {}
@ 01,00 SAY "Neue Auftr„ge bernehmen?" GET lUpdate PICTURE "Y"
READ

If lUpDate == .T.
NetUse("artikel","art",.F.,0)
NetUse("engauf","auf",.F.,0)
NetUse("fertigung","fert",.T.,0)
nX := 0
aAuft := {}
*auf->(dbGoTop())
auf->(dbGoTo(5000))
Do While ! auf->(Eof())
  nX := nX+1
  @ 24,00 SAY nX
  art->(dbSeek(auf->Matchcode))
  If auf->Bestat < 3 .AND. art->Bezug >= 5 .AND. art->Bezug <= 7
    If ! fert->(dbSeek(Str(auf->Abnr,6)+Str(auf->Itmnr,3) ))
      fert->(Add_Rec(0))
    Endif
    nQty := auf->VkQty-auf->GelQty
    fert->Changed  := If(! auf->Matchcode == fert->Matchcode .OR. ! fert->Menge == nQty .OR. ! fert->term == auf->Dterm,.T.,.F.)
    fert->Date     := Date()
    fert->Abnr     := auf->Abnr
    fert->Posnr    := auf->Itmnr
    fert->Matchcode := auf->Matchcode
    fert->Menge    := nQty
    If At("REP",auf->Aufnr) == 1
      fert->Term     := 0
    Else
      fert->Term     := auf->DTerm
    Endif
    fert->(dbUnlock())
  Endif
  auf->(dbSkip())
Enddo
fert->(dbGoTop())
Do While ! fert->(Eof())
  If ! fert->Date == Date()
    fert->(dbDelete())
  Endif
  fert->(dbSkip())
Enddo

//Check stock
fert->(dbSetOrder(3)) //matchcode+Str(term,4)
fert->(dbGoTop())
Do While ! fert->(Eof())
  art->(dbSeek(fert->Matchcode))
  nStock := art->Bestand
  Do While fert->Matchcode == art->Matchcode
     If fert->Term > 0  //Reparaturen
       If nStock > fert->Menge .OR. nStock==fert->Menge
         nStock := nStock-fert->Menge
         fert->(dbDelete())
       Elseif nStock > 0
          fert->Menge := fert->Menge-nStock
          nStock := 0
       Endif
     Endif
     fert->(dbSkip())
  Enddo
Enddo

auf->(dbClosearea())
art->(dbClosearea())
fert->(dbClosearea())
Endif

ListPrint("FERTIGUNG")

