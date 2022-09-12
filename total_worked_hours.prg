PROC RUN_TOTAL_WORKED_HOURS
   LOCAL cBoy,cEOY,nYear := Year(Date())-1
   LOCAL getlist := {}
   LOCAL cFilter
   LOCAL nTot := 0,nTotEur := 0
   LOCAL hPeople := {=>}
   LOCAL nHours


   NetUse( "watime", "wat" )
   NetUse( "buyer","buy" )
   
   CLS

   @ 01,00 SAY "Jahr" GET nYear PICTURE "9999" VALID nYear >= 1997 .AND. nYear <= Year(Date())
   READ
   IF LastKey() == 27
      RETURN
   ENDIF
   
   cBOY := Str(nYear,4)+"0101000000000"
   cEOY := Str(nYear,4)+"1231235959999"

   ? StoT(cBoy),StoT(cEOY)

   cFilter := "StoT(start) >= StoT('"+cBOY+"') .AND. StoT(end) <= StoT('"+cEOY+"') .AND. ! Empty(end)"

   ? cFilter

   wat->(dbSetFilter({|| wat->(&(cFilter)) },cFilter))
   wat->(dbGoTop())
   DO WHILE ! wat->(EOF()) .AND. Inkey(,128) != 27
      IF StoT(wat->start) > StoT(wat->End)
         ? "Error: ",wat->WaNr,StoT(wat->start),StoT(wat->end),wat->(&(cFilter))
      ELSE
         nHours := (StoT(wat->end)-StoT(wat->start))*24
         //? TtoC(StoT(wat->start)),TtoC(StoT(wat->end)),(StoT(wat->end)-StoT(wat->start))*24
         nTot += nHours
         IF ! HHasKey(hPeople,wat->Person)
            hPeople[wat->Person] := 0
         ENDIF
         hPeople[wat->Person] += nHours
      ENDIF
      wat->(dbSkip())
   ENDDO
   FOR EACH nHours IN hPeople
      buy->(dbGoTo( nHours:__eNumKey() ))
      ? Str(nHours:__eNumKey(),2),Str(nHours,8,2),Str(nHours*buy->VerrSatz,8,2),buy->VerrSatz
      nTotEur += nHours*buy->VerrSatz
   NEXT
   ? "  ",Str(nTot,8,2),Str(nTotEUR,10,2)
   //? ValToPrg(LETO_SUM("StoT(end)-StoT(start)",cFilter))
   Sinkey(0)