PARAMETERS nArtnr,nTab,dDate,cKundma
LOCAL oExtra

IF Trim(cKundma) == "GESSMANN" .AND. AT("/59-",art->Matchcode) != 0 //! nTab $ {13,14,75}
   RETURN 14
ENDIF

IF ! Empty(cKundma)
   NetUse("engkund","ku")
   ku->(dbSeek( cKundma+"K" ))
   oExtra := ku->(ExtraData():New( ku->Nummer ))
ENDIF

IF (nTab == 12 .OR. nArtnr $ {15353}) .AND. oExtra != NIL .AND. oExtra:IecLock //! Empty(cKundma) .AND. "|"+Trim(cKundma)+"|" $ HB_AnsiToOem("|KASH|MERSCHJO|FR÷HLI|MONACOR|EFBELEK|KALTHOFF|HERWECK|HAWA|SCHULZKA|STAYONLI|BECHTLE|BECHTLEN|")
   nTab := 29 //change to IEC disti price list
   //Alert("HERE")
ELSEIF nTab == 75 .AND. ! Empty(cKundma) .AND. Trim(cKundma) $ {"MERSCHJO"}
   nTab := 10 //Engelking Distributor prices
ELSEIF (nTab == 1 .OR. nTab == 2 ) .AND. ! Empty(cKundma) .AND. "|"+Trim(cKundma)+"|" $ HB_AnsiToOem("|HARDYSRH|EFBELEK|MONACOR|")  //Elektrogroﬂhandel
   nTab := 3
ELSEIF nTab == 26 .AND.  ! Empty(cKundma) .AND. "|"+Trim(cKundma)+"|" $ HB_AnsiToOem("|RAPHAEL|")  //TECHNO H‰ndler
   nTab := 61
ENDIF

RETURN nTab