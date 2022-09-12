FUNC Hook_Firmclosed(nYear)
LOCAL aDays := {}
LOCAL nX,dDate

//add days between x-mas and new year
FOR nX := 24 TO 31
   dDate := StoD(StrZero(nYear,4)+"12"+Str(nX,2))
   IF ! Dow(dDate) == 1 .AND. ! DoW(dDate) == 7 .AND. ! IsFeiertag(dDate,"BW")
      Aadd(aDays,dDate)
   ENDIF
NEXT

IF nYear == 2013
   Aadd(aDays,StoD("20131223"))
ELSEIF nYear == 2014
   Aadd(aDays,StoD("20140102"))
   Aadd(aDays,StoD("20140103"))

   Aadd(aDays,StoD("20141219"))
   Aadd(aDays,StoD("20141222"))
   Aadd(aDays,StoD("20141223"))
ELSEIF nYear == 2015
   Aadd(aDays,StoD("20151218"))
   Aadd(aDays,StoD("20151221"))
   Aadd(aDays,StoD("20151222"))
   Aadd(aDays,StoD("20151223"))
ELSEIF nYear == 2016
   Aadd(aDays,StoD("20161220"))
   Aadd(aDays,StoD("20161221"))
   Aadd(aDays,StoD("20161222"))
   Aadd(aDays,StoD("20161223"))
ELSEIF nYear == 2017
   //sonderfeiertag
   Aadd(aDays,StoD("20171031"))

   //inventur
   Aadd(aDays,StoD("20171221"))
   Aadd(aDays,StoD("20171222"))
ELSEIF nYear == 2018
ELSEIF nYear == 2019

   //inventur
   Aadd(aDays,StoD("20191219"))
   Aadd(aDays,StoD("20191220"))
   Aadd(aDays,StoD("20191223"))
ELSEIF nYear == 2020
   Aadd(aDays,StoD("20200102"))
   Aadd(aDays,StoD("20200103"))   
   
ELSEIF nYear == 2021
   Aadd(aDays,StoD("20211223"))   
ENDIF

RETURN aDays