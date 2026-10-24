PROC RUN_SHOW_MARGIN
   LOCAL hMarg := {=>}
   LOCAL hYear,nR,cYear,nC,nX
   LOCAL aManu := {},nM,aYears

   NetUse("manufact","man")

   CLS
   NetUse("umsatz","um")
   //um->(dbSeek("2019 1"))
   um->(dbGoTop())
   DO WHILE ! um->(EOF())
      IF Val(um->Year) <= Year(Date())
         IF ! um->Year $ hMarg
            hMarg[um->Year] := {=>}
         ENDIF
         IF ! um->Manufactur $ aManu
            Aadd(aManu,um->Manufactur)
         ENDIF
         IF ! um->Manufactur $ hMarg[um->Year]
            hMarg[um->Year][um->Manufactur] := {"turn"=>0,"db"=>0}
         ENDIF
         hMarg[um->Year][um->Manufactur]["turn"] += um->Umsatz
         hMarg[um->Year][um->Manufactur]["db"] += um->UmsatzDB
      ENDIF
      um->(dbSkip())
   ENDDO

   FOR nM := 1 TO Len(aManu)
      man->(dbSeek( Str(aManu[nM],5) ))
      @ nM,00 SAY Pad(man->Short,20)
   NEXT

   aYears := HGetKeys(hMarg)
   Asort(aYears)
   nC := 0
   FOR nX := Len(aYears) TO Len(aYears)-10 STEP -1
   //FOR EACH cYear IN aYears
      cYear := aYears[nX]
      @ 00,20+09*nC SAY PadL(cYear,8)
      hYear := hMarg[cYear]
      FOR nM := 1 TO Len(aManu)       
         IF HHasKey(hYear,aManu[nM]) .AND. hYear[aManu[nM]]["turn"] > 0
            @ nM,20+09*nC SAY Str( hYear[aManu[nM]]["db"]/ hYear[aManu[nM]]["turn"] *100,7,2)+"%"
         ELSE
            @ nM,20+09*nC SAY PadL("-",8)
         ENDIF
      /*FOR EACH hGroup IN hYear  
         man->(dbSeek( Str(hGroup:__eNumKey(),5) ))
         nC := (hGroup:__eNumIndex()-1)*9+5
         ? man->Short
         IF hGroup["turn"] > 0
            ?? Str(hGroup["db"]/hGroup["turn"] *100,7,2)+"%"            
         ENDIF*/
      NEXT
      //? ""
      nC++
   NEXT
   SiNkey(0)
RETURN