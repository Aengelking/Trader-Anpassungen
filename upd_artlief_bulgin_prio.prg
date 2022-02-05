PROC UPD_ARTLIEF_BULGIN_PRIO
   LOCAL cLief := Pad("BULGIN",8)
   LOCAL cWald := Pad("WALDOM",8)
   LOCAL cFilter
   NetUSe("artlief","ali")
   NetUse("buyprice","bpr")

   ali->(dbSeek(cLief))
   cFilter := "Empty(EndDate) .OR. EndDate >= Date()"
   bpr->(dbSetFilter({|| bpr->(&(cFilter)) },cFilter))
   DO WHILE ali->Kunde == cLief .AND. ! ali->(EOF())
      IF ali->Priority != 9 .AND. ! bpr->(dbSeek( cLief+Str(ali->Artikelnr,6) )) .AND. bpr->(dbSeek( cWald+Str(ali->Artikelnr,6) ))
         ? ali->Matchcode,ali->Priority
         ali->(Rec_Lock(0))
         ali->Priority := 9
         ali->(dbUnlock())
      ENDIF
      ali->(dbSkip())
   ENDDO
   Sinkey(0)
RETURN