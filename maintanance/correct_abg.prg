FUNCTION HRBMAIN
CLS
NetUse("engabg","abg")
NetUse("lagerne","lne")
NetUse("muster","mus")
NetUse("engkund","ku")
NetUse("engbew","bew")

abg->(dbSetOrder( 5 ))
abg->(dbSetFilter( {|| abg->BuArt $ {"ENT","ENŽ"} .AND. ! Empty(abg->Liefma)},'buart $ {"ENT","ENŽ"} .AND. ! Empty(liefma)'))
abg->(dbSeek( "20160101" , .T.))

lne->(dbSetOrder(1))

DO WHILE ! abg->(EOF()) .AND. Inkey() != 27
   lne->(dbSeek(abg->Besnr))
   IF mus->(dbSeek(abg->Besnr))
      IF mus->Kunde == lne->Kunde .AND. mus->Kunde != abg->Liefma
         ku->(dbSeek(mus->Kunde+"K"))
         ? abg->Transdate,abg->Besnr,abg->Liefma,mus->Kunde,abg->Kundennr,ku->Nummer
         abg->(Rec_Lock())
         abg->Liefma := mus->Kunde
         abg->Kundennr := ku->Nummer
         abg->(dbUnLock())
      ENDIF
   ENDIF
   abg->(dbSkip())
ENDDO

? "Artikel Bewegungen abgeschlossen. Weiter mit beliebiger Taste"
IF SInkey(0) == 27
   RETURN NIL
ENDIF

? "Kunden Bewegungen"


bew->(dbSetFilter( {|| Trim(bew->BuArt) $ {"ENT","ENŽ"} .AND. ! Empty(bew->Liefma)},'Trim(buart) $ {"ENT","ENŽ"} .AND. ! Empty(liefma)'))
bew->(dbSetOrder(0))
bew->(dbGoTop())

DO WHILE ! bew->(EOF()) .AND. Inkey() != 27
   lne->(dbSeek(bew->Besnr))
   IF mus->(dbSeek(bew->Besnr))
      IF mus->Kunde == lne->Kunde .AND. mus->Kunde != bew->Liefma
         ku->(dbSeek(mus->Kunde+"K"))
         ? bew->Transdate,bew->Besnr,bew->Liefma,mus->Kunde,bew->Kundennr,ku->Nummer
         bew->(Rec_Lock())
         bew->Liefma := mus->Kunde
         bew->Kundennr := ku->Nummer
         bew->(dbUnLock())
      ENDIF
   ENDIF
   bew->(dbSkip())
ENDDO

? "Kunden Bewegungen abgeschlossen"

Sinkey(0)

RETURN NIL

