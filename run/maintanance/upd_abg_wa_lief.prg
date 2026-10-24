PROC UPD_ABG_WA_LIEF
   LOCAL cFilter
   NetUse("engabg","abg")
   NetUse("werkauf","wer")
   cFilter := 'Trim(buart)=="WA" .AND. ! Empty(beleg) .AND. Empty(liefma)'
   //abg->(dbSetOrder(4))
   abg->(dbSetFilter({|| abg->(&(cFilter))},cFilter))
   //abg->(dbSeek("a",.T.))
   abg->(dbGoTop())
   DO WHILE ! abg->(EOF())      
      IF wer->(dbSeek( Str(abg->Besnr,6) )) .AND. ! Empty(wer->Liefma)
         ? abg->Besnr,abg->Beleg,wer->Liefma
         abg->(Rec_Lock())
         abg->Liefma := wer->Liefma
         abg->(dbUnLock())
      ENDIF
      abg->(dbSkip())
   ENDDO
   abg->(dbClearFilter())
   ? "done"
   SInkey(0)