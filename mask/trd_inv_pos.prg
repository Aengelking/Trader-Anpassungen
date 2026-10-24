FUNC MASK_TRD_INV_POS
   LOCAL nT := 10,nL := 10

   MEMVAR c_five

   SetColor( c_five )

   @ nT,nL CLEAR TO nT+20,nL+60
   @ nT,nL TO nT+20,nL+60

   @ ++nT,nL+1 SAY "Bestellung"
   @ nT,nL+15 SAY LTrim(Str(rpos->Besnr))
   @ ++nT,nL+1 SAY "Position"
   @ nT,nL+15 SAY LTrim(Str(rpos->Posnr))

   nL++
   IF rpos->Menge*rpos->Ekpr < 0
      @ ++nT,nL SAY "Verechnete Positionen"
      rver->(dbSetOrder( 2 ))
      rver->(dbSeek( rpos->Liefma+rpos->Beleg+Str(rpos->BelegPos,3) ))
      Do While rver->Liefma == rpos->Liefma .AND. rver->VerBeleg == rpos->Beleg .AND. rver->VerPos == rpos->BelegPos .AND. ! rver->(Eof())
         ? rver->Beleg,rver->BelegPos,rver->Menge
         rver->(dbSkip())
      Enddo   
   ENDIF

   Sinkey(0,128)
RETURN .T.