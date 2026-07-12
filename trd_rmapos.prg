PROC MASK_TRD_RMAPOS
   LOCAL nR,cBeleg
   MEMVAR c_five

   NetUse("engabg","abg")
   NetUse("lagerne","lne")

   SetColor( c_five )

   @ 01,04 CLEAR TO 20,60
   @ 01,04 TO 20,60
   @ 02,05 SAY "RMA Nr.  "+LTrim(Str(rmp->nummer,6))
   @ 03,05 SAY "Pos.     "+LTrim(Str(rmp->Pos,6))
   @ 04,05 SAY "AB       "+LTrim(Str(rmp->AbNr,6))
   @ 05,05 SAY "Rechnung "+LTrim(Str(rmp->Rechnung,6))+" Pos. "+LTrim(Str(rmp->repos))

   NetUse("englsre","re")
   re->(dbSetOrder( 12 ))
   IF re->(dbSeek( Str(rmp->Rechnung,6)+Str(rmp->Repos,3) ))
      @ Row(),Col()+1 SAY "("+LTrim(Str(re->Preis/re->PE))+" "+Currate(re->Money,"X")+")"
   ENDIF

   
   abg->(dbSetORder( 6 ))
   cBeleg := Str(rmp->nummer,6)+'-'+StrZero(rmp->Pos,3)
   
   //cFilter := 'Trim(buart)=="RMA" .AND. Trim(beleg) == "'++'"'
   //abg->(dbSetFilter({|| abg->(&(cFilter)) },cFilter))
   @ 07,05 SAY "Eing„nge"
   nR := 07
   IF ! abg->(dbSeek( "RMA"+cBeleg)) //! abg->(dbSeek( rmp->Matchcode ))
      @ ++nR,05 SAY "kein Wareneingang gefunden"
   ELSE
      @ ++nR,05 SAY "Datum    Menge  Info"
      DO WHILE abg->Buart == "RMA" .AND. Trim(abg->Beleg) == cBeleg .AND. ! abg->(EOF())
         @ ++nR,05 SAY DtoC(abg->Datum)+" "+Transform(abg->Menge,Me(art->Me))+" "+abg->Info
         abg->(dbSkip())
      ENDDO
   ENDIF

   lne->(dbSetORder( 7 ))
   IF lne->(dbSeek( "RM"+Str(rmp->Nummer,6)+Str(rmp->Pos,3) ))
      nR += 2
      @ nR++,05 SAY "Rcklieferungen"
      @ nR++,05 SAY "Datum    Menge  Nummer"
      DO WHILE lne->RefTyp == "RM" .AND. lne->RefBeleg == rmp->Nummer .AND. lne->RefPos == rmp->Pos .AND. ! lne->(EOF())
         @ nR++,05 SAY DtoC(lne->Datum)+" "+Transform(lne->Menge,Me(art->Me))+" "+Str(lne->Nummer,6)    
         lne->(dbSkip())
      ENDDO
   ENDIF




SInkey(0,128)