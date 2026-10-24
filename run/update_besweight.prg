LOCAL nBesnr := 0,nPosnr := 0
LOCAL lUsingPrice := .T.

MEMVAR mcErrorLog
PRIVATE mcErrorLog := ""

NetUse("engkund","ku")
NetUse("engbes","bes")
NetUse("manufact","manu")
NetUse("artikel","art")

DO WHILE .T.
   Head("Gewichtung EK Folgeartikel neu berechnen")
   @ 01,00 SAY "Bestellung" GET nBesnr PICTURE "999999"
   @ 02,00 SAY "Position  " GET nPosnr PICTURE "999" VALID bes->(Check(Str(nBesnr,6)+Str(nPosnr,3),"bes->Matchcode",02,15,1))
//   @ 03,00 SAY "Preis als Basis" GET lUsingPrice PICTURE "Y"
   READ

   IF LastKey() == 27
      RETURN
   ENDIF

   _UpdateBesWeights(nBesnr,nPosnr) //,lUsingPrice)
   Alert(mcErrorLog)
ENDDO

RETURN

STATIC Function _UpdateBesWeights(nBesnr,nPosnr) //,lUsingPrice)
   LOCAL nTotWeight
   //LOCAL nArtRec := art->(Recno())
   LOCAL aEnv := SaveEnv()
  
   LOCAL lUsingPrice

   MEMVAR mcErrorLog
   
   ku->(dbSetOrder( 8 ))

   bes->(dbSetOrder(1))
   bes->(dbSeek( Str(nBesnr,6)+Str(nPosnr,3)))

   //Folgepositionen
   bes->(dbSkip())
   IF bes->Folgeto == nPosnr
      art->(dbSetOrder( 1 ))
      nTotWeight := 0
      DO WHILE bes->besnr == nBesnr .AND. bes->FolgeTo == nPosnr
         art->(dbSeek( bes->Matchcode ))
         nPrice := 0

         IF lUsingPrice != .F.
            nPE :=1
            ? art->Manufactur
            IF manu->(dbSeek( Str(art->Manufactur,5) )) .AND. ku->(dbSeek( Str(manu->Address,6) ))
               ? ku->Kunde
               GetBuyPrice( ku->Kunde, art->Artikelnr, -1, @nPrice, @nPE, , bes->Besda )
            ENDIF
         ENDIF
         IF nPrice != 0 .OR. lUsingPrice == .T.
            nWeight := nPrice/nPe
            lUsingPrice := .T.
         ELSEIF lUsingPrice == NIL
            lUsingPrice := .F.
         ENDIF
         IF lUsingPrice == .F.
            nWeight := art->Gewicht
         ENDIF
         IF nWeight == 0
            mcErrorLog += art->Matchcode+" kein Gewicht;"
         ELSE
            nTotWeight += nWeight*bes->BeQty
            bes->(Rec_Lock())
            bes->Weight := nWeight
            bes->(dbUnLock())
         ENDIF
         bes->(dbSkip())
      ENDDO

      IF bes->(dbSeek( Str(nBesnr,6)+Str(nPosnr,3)))
         nTotWeight /= bes->BeQty
         IF nTotWeight > 99999.999999
            Alert(bes->Matchcode+Str(nTotWeight)+"g")
         ELSE
         bes->(Rec_Lock())
         bes->Weight := nTotWeight
         bes->(dbUnLock())
         ENDIF
      ENDIF
   ELSE
      bes->(dbSkip(-1))
      art->(dbSetOrder( 1  ))
      art->(dbSeek( bes->Matchcode ))
      bes->(Rec_Lock(0))
      bes->Weight := art->Gewicht
      bes->(dbUnlock())
      nTotWeight := bes->Weight
   ENDIF
   //art->(dbGoto(nArtRec))
   RestEnv(aEnv,.F.)
RETURN nTotWeight