LOCAL nNr := 0
Head(t("Inventur zurücksetzen"))

IF Tr_Getini(28) != 9
   Tr_MsgBox("Zugang verweigert")
   RETURN
ENDIF

NetUse("artikel","art")
NetUse("lagerort","lago")
NetUse("lager","lag")

@ 01,00 SAY "Inventur Nummer" GET nNr VALID nNr != 0
READ
IF LastKey() == 27
   RETURN
ENDIF

art->(dbSetOrder(2))
lago->(dbSetOrder(2))
lag->(dbSetOrder(2))

lago->(dbSeek(Str(nNr,6)))

DO WHILE lago->Invnr == nNr
   ? lago->Lagerort
   lag->(dbSeek( lago->Lagerort ))
   DO WHILE lag->Lagerort == lago->Lagerort .AND. ! lag->(EOF())
      IF ! HasArtInventurLager(lag->Artikelnr,lago->Lagerort)  //keine andere Inventur
         art->(dbSeek( Str(lag->Artikelnr,6) ))
         ? art->Matchcode
         art->(Rec_Lock(0))
         art->Inventur := .F.
         art->(dbUnLock())
      ENDIF
      lag->(dbSkip())
   ENDDO
   lago->(Rec_Lock(0))
   lago->Inventur := .F.
   lago->(dbUnLock())
   lago->(dbSkip())
ENDDO