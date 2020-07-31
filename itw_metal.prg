LOCAL oRec,oCopy
NetUse("artlief","ali")
netUse("artikel","art")

art->(dbSetOrder( 2 ))

ali->(dbSeek( "ITW" ))

DO WHILE Trim(ali->Kunde) == "ITW" .AND. ! ali->(EOF())
   oRec := ali->(Record():New())

   IF ! ali->(dbSeek( "ITWMETAL"+Str(ali->Artikelnr,6) ))
      art->(dbSeek( Str(oRec:Artikelnr,6) ))
      ? art->Matchcode

      oCopy := ali->(Record():New(.T.))
      oCopy:Copy(oRec)
      oCopy:Kunde := "ITWMETAL"
      oCopy:Save()
   ENDIF
   oRec:GotoRec()
   ali->(dbSkip())
ENDDO