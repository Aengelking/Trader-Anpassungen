PROC REPORT_SERIES_USAGE
   LOCAL dStart := Date()-365
   LOCAL cSeries,nUsage
   LOCAL hSeries := {=>}
   LOCAL nC,nR

   Head("Verbrauch pro Serie")
   
   NetUse("artikel","art")

   art->(dbSeek("CM",.T.))

   DO WHILE Left(art->Matchcode,2) == "CM"
      cSeries := Left(art->Matchcode,AT("/",art->Matchcode)-1)
      IF ! Empty(cSeries)
         abg->(dbSetOrder( 3 ))      
         abg->(dbSeek( art->Matchcode+DtoS(dStart), .T. ))
         nUsage := 0      
         DO WHILE abg->Matchcode == art->Matchcode .AND. abg->TransDate >= dStart .AND. ! abg->(EOF())
            IF Trim(abg->BuArt) $ {"RNR","ENT","ENŽ","RAŽ"}            
               nUsage += abg->Menge
            ELSEIF Trim(abg->Buart) $ {"ENL"}
               nUsage -= abg->Menge
               //? "Žnderung: "+abg->BuArt+" "+abg->Matchcode+" "+Str(abg->Menge,10,2)  
               //Sinkey(0)
            ENDIF
            abg->(dbSkip())
         ENDDO
         IF ! HB_HHasKey(hSeries,cSeries)
            hSeries[cSeries] := nUsage
         ELSE
            hSeries[cSeries] += nUsage
         ENDIF
      ENDIF
      art->(dbSkip(.T.))
   ENDDO

   CLS
   @ 0,0 SAY "Verbrauch pro Serie seit "+DtoC(dStart)
   nR:= 1
   nC := 0

   

   FOR EACH cSeries IN HB_HKeys(hSeries)
      @ nR,nC SAY Pad(cSeries,5)+" "+Str(hSeries[cSeries],10,2)
      nR++
      IF nR >= MaxRow()-1
         nR := 1
         nC += 20
      ENDIF      
   NEXT
   //? "Fertig"
   Sinkey(0)
RETURN