#include "y:\harbour\trader\source\include\trget.ch"

PROC RUN_RES_TIME_PER_MONTH
   LOCAL nPause := 0.5

   LOCAL nRes := 0
   LOCAL dDate := AddMonth(Date(),-1)
   LOCAL nMonth := Month(dDate)
   LOCAL nYear := Year(dDate)
   LOCAL dCurrent,tStart,tEnd
   LOCAL hMonth,aDays,nTotal
   LOCAL getlist := {}
   NetUse("watime","wat")

   

   DO WHILE .T.

      Head("Zeiten pro Person")

      @ 01,00 SAY "Person" GET nRes PICTURE "99"
      @ 02,00 SAY "Monat " GET nMonth PICTURE "99" VALID nMonth >= 1 .AND. nMonth <= 12
      @ 03,00 SAY "Jahr  " GET nYear PICTURE "9999" VALID nYear >= 2014 .AND. nYear <= Year(Date())
      READ

      IF LastKey() == 27
         EXIT
      ENDIF

      dDate := StoD(Str(nYear,4)+StrZero(nMonth,2)+"01")
      hMonth := {=>}
      nTotal := 0

      Select("wat")
      SET FILTER TO wat->Person == nRes .AND. StoD(wat->Start) >= dDate .AND. StoD(wat->End) <= EoM(dDate)
      wat->(dbGoTop())
      DO WHILE ! wat->(EOF())
         tStart := StoT(wat->Start)
         tEnd := StoT(wat->End)
         dCurrent := StoD(wat->Start)
         IF dCurrent != Date()
            IF ! HHasKey(hMonth,dCurrent)
               hMonth[dCurrent] := {"START"=>tStart,"END"=>tEnd}
            ENDIF
            hMonth[dCurrent]["START"] := Min(StoT(wat->Start),hMonth[dCurrent]["START"])
            hMonth[dCurrent]["END"]   := Max(StoT(wat->end),hMonth[dCurrent]["END"])
         ENDIF
         wat->(dbSkip())         
      ENDDO
      aDays := HGetKeys(hMonth)
      ASort(aDays)
      SetPos(04,00)
      FOR EACH dCurrent IN aDays
         ? dCurrent,SubStr(TtoC(hMonth[dCurrent]:Start),10,5),SubStr(TtoC(hMonth[dCurrent]:End),10,5), _NtoT((hMonth[dCurrent]:End-hMonth[dCurrent]:Start)*24),_NtoT((hMonth[dCurrent]:End-hMonth[dCurrent]:Start)*24-nPause)
         nTotal += (hMonth[dCurrent]:End-hMonth[dCurrent]:Start)*24-nPause
      NEXT
      ? "Durchschnitt:",_NtoT(nTotal/Len(aDays))
      Sinkey(0)
   ENDDO
RETURN

STATIC FUNCTION _NtoT(nTime)
//RETURN Str(nTime,5,2)
RETURN Str(Int(nTime),2)+":"+StrZero(Mod(nTime,1)*60,2)
