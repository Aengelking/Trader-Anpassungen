PROC RUN_UPD_BUYPRICE_MATCHCODE
   LOCAL cOld := Space(8)
   LOCAL cNew := Space(8)

   Head("Matchcode in der Preistabelle korrigieren")

   NetUSe("buyprice","bpr",.F.,0)

   @ 01,00 SAY "Alter Matchcode" GET cOld PICTURE "@!" VALID ! Empty(cOld)
   @ 02,00 SAY "Neuer Matchcode" GET cNew PICTURE "@!" VALID ! Empty(cNew)

   READ

   IF LastKey() == 27
      RETURN
   ENDIF

   bpr->(dbSetOrder( 1 ))
   IF ! bpr->(dbSeek( cOld ))
      Alert("Keine Eintr„ge gefunden")
   ENDIF
   IF Tr_MsgBox("Wirklich durchfhren?",,{"Nein","Ja"}) == 2
      DO WHILE bpr->Liefma == cOld .AND. ! bpr->(EOF())
         bpr->(dbSkip())       
         nNextRec := bpr->(Recno())
         bpr->(dbSkip(-1))
   
         @ 24,00 SAY Str(bpr->Artikelnr)+Str(bpr->Qty)
         bpr->(Rec_Lock())
         bpr->Liefma := cNew
         bpr->(dbUnLock())

         bpr->(dbGoto(nNextRec))
      ENDDO

      Sinkey(0)
   ENDIF