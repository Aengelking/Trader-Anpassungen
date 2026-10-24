nYEAR := YEAR(DATE())
Scroll( 0, 0 ) ; SetPos( 0, 0 )
DevPos( 1, 0 ) ; DevOut( "AB JAHR" ) ; SetPos( Row(), Col() + 1 ) ; AAdd( GetList, _GET_( nYEAR, "nYEAR", "9999",, ) ) ; ATail(GetList):Display()
ReadModal( GetList, NIL,,,,, ) ; GetList := {}
NETUSE("ENGLSRE","RE",.F.,0)
nRec := re->(lastrec())
re->(dbSetOrder(0))

IF nYear == 1989
  re->(DBGOTO(2542))
ELSEIF nYear == 1990
  re->(DBGOTO(5462))
ELSEIF nYear == 1991
  re->(DBGOTO(10088))
ELSEIF nYear == 1992
  re->(DBGOTO(12501))
ELSEIF nYear == 1993
  re->(DBGOTO(17980))
ELSEIF nYear == 1994
  re->(DBGOTO(24153))
ELSEIF nYear == 1995
  re->(DBGOTO(36722))
ELSEIF nYear == 1996
  re->(DBGOTO(50588))
ELSEIF nYear == 1997
  re->(DBGOTO(66334))
ELSEIF nYear == 1998
  re->(DBGOTO(85474))
ELSEIF nYear == 1999
  re->(DBGOTO(101209))
ELSE
  re->(DBGOTOP())
ENDIF

NetUse("umsatz","um",.F.,0)
while ! um->(EOF())
  IF um->year >= STR(nYear,4)
    um->(REC_LOCK(0))
    um->umsatz := 0
    um->pay := 0
    um->ek := 0
    um->(DBUNLOCK())
  ENDIF
  um->(DBSKIP(1))
ENDDO

NetUse("artikel","art",.F.,0)
art->(dbSetOrder(2))


DevPos( 10, 15 ) ; DevOut( "VON "+STR(NREC,10) )
while ! re->(EOF()) .AND. ! LastKey() = 27 .AND. ! Inkey() = 27
  DevPos( 10, 0 ) ; DevOut( STR(RE->(RECNO()),10) )
  If RE->REPOSNR <> 0
    if art->(dbSeek(Str(re->ArtikelNr,6)))

      cFind := art->Gruppe+Str(Year(re->RechDat),4)+Str(Month(re->RechDat),2)
      IF ! um->(dbSeek(cFind))
        um->(Add_Rec(0))
        um->Branch  := ART->GRUPPE
        um->Month   := STR(MONTH(RE->RECHDAT),2)
        um->Year    := STR(YEAR(RE->RECHDAT),4)
        um->(dbUnlock())
      ENDIF

      um->(Rec_Lock(0))
      um->Umsatz := UM->UMSATZ+(RE->PREIS*currate(re->money,"V")*re->aoqty/re->pe)
      um->ek := um->ek+(art->letzte_ek*currate(art->money,"E")*re->aoqty/art->pe)
      IF re->status >= 2
        um->pay := um->pay+(re->preis*currate(re->money,"V")*re->aoqty/re->pe)
      ENDIF
      um->(dbUnlock())
    endif
  ENDIF
  re->(dbSkip(1))
ENDDO
