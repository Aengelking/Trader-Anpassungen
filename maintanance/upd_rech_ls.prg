PROC RUN_UPD_RECH_LS
   LOCAL cLiefma := Pad("WHTECH",8)
   LOCAL dStart
   LOCAL dEnd
   LOCAL nMenge,nRasMenge
   LOCAL dDelDate
   LOCAL nYear := 2021
   LOCAL nMonth := 1
   LOCAL getlist := {}
   LOCAL aData

   @ 01,00 SAY "Jahr " GET nYear PICTURE "9999" VALID nYear >= 2021 .AND. nYear <= Year(Date())
   @ 02,00 SAY "Month" GET nMonth PICTURE "99" VALID nMonth >= 1 .AND. nMonth <= 12 .AND. (nYear != Year(Date()) .OR. nMonth <= Month(Date()))
   READ
   IF LastKey() == 27
      RETURN
   ENDIF
   dStart := StoD(Str(nYear,4)+StrZero(nMonth,2)+"01")
   dEnd := EoM(dStart)

   NetUse("engrech","rech")
   NetUse("rechpos","rpos")
   NetUse("lspos","lsp")
   NetUse("engabg","abg")

   lsp->(dbSetOrder( 3 ))

   ? "Lieferscheine aktualisieren"
   rech->(dbSeek( cLiefma+DtoS(dStart), .T. ))

   DO WHILE rech->Liefma == cLiefma .AND. rech->Rechdat >= dStart .AND. rech->Rechdat <= dEnd
      ? rech->Rechnr,rech->Rechdat
      rpos->(dbSetFilter( {|| Empty(rpos->Delnote) },"Empty(delnote)"))
      rpos->(dbSeek( cLiefma+rech->Rechnr ))

      DO WHILE rpos->Liefma == cLiefma .AND. rpos->Beleg == rech->Rechnr
         ? " ",rpos->Belegpos,rpos->Menge
         nMenge := rpos->Menge
         IF lsp->(dbSeek( Str(rpos->Besnr,6)+Str(rpos->posnr,3) ))
            DO WHILE lsp->Besnr == rpos->Besnr .AND. lsp->Bespos == rpos->Posnr .AND. nMenge > 0
               nRasMenge := RasGetDelNoteQty(cLiefma,lsp->Beleg,lsp->Pos)               
               ? "   ",lsp->Beleg,lsp->Pos,lsp->Geliefert-nRasMenge
               
               IF lsp->Geliefert-nRasMenge >= nMenge //only one positon
                  ?? "update"
                  rpos->(Rec_Lock(0))
                  rpos->DelNote := lsp->Beleg
                  rpos->DelNotePos  := lsp->Pos
                  rpos->(dbUnLock())
               ENDIF
               nMenge -= lsp->Geliefert-nRasMenge
               lsp->(dbSkip())
            ENDDO
         ENDIF
         rpos->(dbSkip())
      ENDDO

      rpos->(dbClearFilter())

      rech->(dbSkip())

   ENDDO

   Sinkey(0)

   aData := {{"Invoice","Invoice date","Receive date"}}
   ? "Lieferdaten"
   ? Pad("Rechnung",14),Pad("R.datum",8),"Lieferdatum"
   rech->(dbSeek( cLiefma+DtoS(dStart), .T. ))
   abg->(dbSetOrder( 3 ))

   DO WHILE rech->Liefma == cLiefma .AND. rech->Rechdat >= dStart .AND. rech->Rechdat <= dEnd
      IF rech->Gramt > 0
         ? rech->Rechnr,rech->Rechdat
         rpos->(dbSeek( cLiefma+rech->Rechnr ))
         dDelDate := StoD("")
         DO WHILE rpos->Liefma == cLiefma .AND. rpos->Beleg == rech->Rechnr
            //? " ",rpos->Belegpos,rpos->Menge,rpos->Delnote,rpos->DelNotepos
            IF Empty(rpos->Delnote)
               //? "    Keine Lieferung",rpos->Matchcode,rpos->Menge
               dDelDate := StoD("")  //Lieferdatum zurck setzen
               EXIT //mindestens eine Lieferung fehlt, dann k”nnen wir abbrechen
            ELSE
               abg->(dbSetFilter( {|| Trim(abg->BuArt) == "WE".AND. abg->Liefma == rech->Liefma .AND. abg->Beleg == Pad(rpos->Delnote,15) }))
               abg->(dbSeek( rpos->matchcode, .T. ))
               nMenge := 0
               DO WHILE ! abg->(EOF()) .AND. abg->Matchcode == rpos->Matchcode .AND. nMenge < rpos->Menge
                  nMenge += abg->Menge
                  //? "    ",abg->Menge,abg->Datum
                  dDelDate := Max(dDelDate,abg->Datum)
                  IF nMenge >= rpos->Menge
                     EXIT //exit before skip to speed up
                  ENDIF
                  abg->(dbSkip())
               ENDDO
            ENDIF
            //? "done"
            
            rpos->(dbSkip())
         ENDDO
         ?? "",dDelDate
         Aadd(aData,{rech->Rechnr,DtoC(rech->Rechdat),DtoC(dDelDate)})
      ENDIF

      rech->(dbSkip())

   ENDDO

   SaveAsCsvInterface(aData)
   Sinkey(0)