PROC RUN_WERKAUF_LOAD
   LOCAL cFilter
   LOCAL cStart := "20170601"
   LOCAL cEnd   := "20191031"
   LOCAL dStart := StoD(cStart)
   LOCAL dEnd   := StoD(cEnd)   
   LOCAL hMonths := {=>},cMonth,oArt,nHours,nH,nMonth
   LOCAL nDefQuota,nAvgTime,tEnd
   LOCAL aData := {}
   NetUse("werkauf","wer")
   NetUse("watime","wat")

   cFilter := ' Start >= "'+TtoS(StoT(cStart))+'" .AND. start <= "'+TtoS(StoT(cEnd))+'"'
   wat->(dbSetFilter({|| wat->(&(cFilter))},cFilter))
   

   wat->(dbGoTop())
   Aadd(aData,{"Auftrag","Monat","Arbeitsschritt","Mitarbeiter","Start","Ende","Stunden"})
   DO WHILE ! wat->(EOF())                  
      IF wat->End >= wat->Start //if this is not the case this is most likely work in progress
         cMonth := Str(Year(StoT(wat->Start)),4)+"-"+StrZero(Month(StoT(wat->Start)),2)
         tEnd := StoT(Left(wat->Start,8)+SubStr(wat->End,9))
         nH := (tEnd-StoT(wat->Start))*24

         Aadd(aData,{wat->WaNr,cMonth,wat->Job,wat->Person,Left(TtoC(StoT(wat->Start)),14),Left(TtoC(tEnd),14),nH})
         IF ! HHasKey(hMonths,cMonth)
            hMonths[cMonth] := 0
         ENDIF

         hMonths[cMonth] += nH
      ENDIF
      wat->(dbSkip())
   ENDDO


   CLS
   FOR nMonth := 1 TO Len(hMonths)
      ? HGetKeyAt(hMonths,nMonth),HGetValueAt(hMonths,nMonth)
   NEXT

   SaveAsCsvInterface(aData)
   Sinkey(0)
