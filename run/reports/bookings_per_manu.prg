PROC RUN_REPORT_BOOKINGS_PER_MANU
LOCAL aData := {}

LOCAL nEnd   := Year(Date())
LOCAL nStart := nEnd-5

LOCAL aBase,cFile

Head("Bookings pro Monat und Hersteller")

NetUse("umsatz","um")
um->(dbSetOrder( 2 ))

NetUse("manufact","manu")

aBase := Array(12*(nEnd-nStart+1)+1)
AFill(aBase,0)

Aadd(aData,AClone(aBase))
ATail(aData)[1] := "Hersteller"
AEval(ATail(aData),{|x,nX| ATail(aData)[nX] := Str(nStart+Int((nX-2)/12),4)+"-"+StrZero(Mod(nX-2,12)+1,2) },2)

um->(dbSetFilter({|| um->Group != "SUMM" },'group != "SUMM"'))
um->(dbSeek( Str(nStart,4) ))
DO WHILE ! um->(EOF()) .AND. Val(um->Year) <= nEnd
   manu->(dbSeek( Str(um->Manufactur,5) ))
   nX := AScan(aData,{|x| x[1] == manu->Short})
   IF nX == 0
      Aadd(aData,AClone(aBase))
      nX := Len(aData)
      aData[nX][1] := manu->Short
   ENDIF
//   ? nX,12*(Val(um->Year)-nStart)+Val(um->Month),um->Year,um->Month,um->Bookings

   aData[nX][12*(Val(um->Year)-nStart)+Val(um->Month)+1] += um->Bookings


   um->(dbSkip())
ENDDO
um->(dbClearFilter())

/*IF AT(".",cFile) == 0
   cFile += ".csv"
ENDIF*/
SaveAsCSVInterface(aData,,@cFile)
WAPI_ShellExecute(,"open",cFile)
