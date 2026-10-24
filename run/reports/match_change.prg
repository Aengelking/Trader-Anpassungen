FUNCTION RUN_REPORT_MATCH_CHANGE()
   LOCAL cFilter
   LOCAL cVon := Space(25)
   LOCAL cBis := Replicate("x",25)
   LOCAL getlist := {}
   LOCAL nArtnr,cMatch
   LOCAL aData := {}

   Head("Artikel mit Matchcode„nderung")

   NetUse("engabg","abg")
   NetUse("artikel","art")

   @ 01,00 SAY "Von Matchcode" GET cVon VALID Empty(cVon) .OR. ValidVar(@cVon,01,12) 
   ATail( getlist ):Reader := {| oGet, oGetlist, oMenu, oGetMsg| SwapReader( oGet, oGetList, oMenu, oGetMsg ) }
   @ 02,00 SAY "Bis Matchcode" GET cBis VALID cVon <= cBis //.AND. ValidVar(@cVon,01,12) 
   ATail( getlist ):Reader := {| oGet, oGetlist, oMenu, oGetMsg| SwapReader( oGet, oGetList, oMenu, oGetMsg ) }
   READ

   If LastKey() == 27
      RETURN .T.
   ENDIF

   abg->(dbSetOrder( 3 ))

   cFilter := 'Trim(beleg) == "MATCHNEU" .AND. buart == "STD"'
   abg->(dbSetFilter( {|| abg->(&(cFilter)) }, cFilter ))
   abg->(dbSeek( cVon , .T. ))  

   Aadd(aData,{"Alte Bezeichnung","Neue Bezeichnung","Datum"})

   DO WHILE ! abg->(EOF()) .AND. abg->Matchcode >= cVon .AND. abg->Matchcode <= cBis
      nArtnr := abg->Artikelnr
      cMatch := abg->Matchcode
      DO WHILE abg->Artikelnr == nArtnr .AND. ! abg->(EOF()) 
         IF ! Empty(abg->Info)
            ? abg->Info,"->",cMatch,abg->TransDate
            Aadd(aData,{abg->Info,cMatch,abg->TransDate})            
         ENDIF
         cMatch := Pad(abg->Info,25)
         abg->(dbSkip())
      ENDDO
   ENDDO

   SaveAsCSVInterface(aData)
   SInkey(0)