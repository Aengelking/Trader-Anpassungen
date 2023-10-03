PROC RUN_MAINTANANCE_UPD_WDATUM
   LOCAL cFilter,dEnde
   LOCAL lMaybeExtend
   NetUSe("engauf","auf")
   cFilter := "Right(Str(dterm,4),2)=='99' .AND. folgeto == 0"
   auf->(dbSetFilter({|| auf->(&(cFilter))},cFilter))
   auf->(dbGoTop())
   DO WHILE ! auf->(EOF())      
      dEnde := CalWD(auf->Wterm)
      lMaybeExtend := .F.
      IF auf->VkQty != auf->ContrQty .AND. AddMonth(auf->Besda,12) <= Date() //k”nnte schon verl„ngert worden sein
         dEnde := Min(AddMonth(auf->sDatum,12),dEnde)
         lMaybeExtend := .T.
      ENDIF
      IF ! Empty(dEnde)
         ? auf->Abnr,auf->Itmnr,auf->SDatum,auf->WDatum,dEnde,IF(lMaybeExtend .AND. auf->VkQty != 0,"*","")
         auf->(Rec_Lock())
         auf->WDatum := dEnde
         auf->(dbUnLock())
         IF lMaybeExtend .AND. auf->VkQty != 0 .AND. auf->BeStat < 3
            
         ENDIF
      ENDIF
      auf->(dbSkip())
   ENDDO
   auf->(dbClearFilter())
   Sinkey(0)
RETURN