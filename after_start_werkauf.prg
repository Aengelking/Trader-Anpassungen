PARAMETERS nWnr

wer->(dbSetOrder(1))
wer->(dbSeek( str(nWnr,6) ))
IF ! Empty(wer->Liefma)
  lne->(dbSetOrder(1))
  lne->(dbSeek(wer->LagNum))

  lFremdOnly := .T.

  DO WHILE lne->Nummer == wer->Lagnum .AND. lFremdOnly
     IF lne->Menge != GetEntFremdLagerQty(lne->Nummer,lne->Pos)
        lFremdOnly := .F.
     ENDIF
     lne->(dbSkip())
  ENDDO

  IF lFremdOnly .AND. LockEntity("LNE",wer->Lagnum)
      IF ! GetConfigValue("BATCHMODE")
         Tr_MsgBox("Beistellware bereits beim Lieferanten, bitte Bestellung versenden.")
      ENDIF
      wer->(Rec_Lock())
      wer->Status := 3
      wer->(dbUnLock())
      mirpt := wer->besnr
      mibesnr := wer->besnr
      enbedr(wer->Besnr,,.F.)
      IF ! GetConfigValue("BATCHMODE")
         EINFUG(0,wer->LagNum,.T.,.T.)
      ENDIF
      UnLockEntity("LNE",wer->Lagnum)
  ENDIF
ENDIF
