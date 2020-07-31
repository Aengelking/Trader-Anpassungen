NetUse("rebprot","rebp")
nID := 170000002
dEingang := StoD("20170105")
CLS
DO WHILE .T.
   @ 01,00 SAY "ID     " GET nID PICTURE "999999999"
   @ 02,00 SAY "Eingang" GET dEingang
   READ
   IF LastKey() == 27
      EXIT
   ENDIF

   rebp->(dbSetOrder( 2 ))
   cArchiveTime := ""
   IF rebp->(dbSeek(Str(nID-1,9)+"ARCHIV"))
      tArchiveTime := StoT(rebp->DateTime)+5+1/(24*60)*HB_Random(60)+1/(24*60*60)*HB_Random(60)+1/(24*60*60*60)*HB_Random(60)
      IF Val(SubStr(TtoS(tArchiveTime),9,2)) > 18
         tArchiveTime += .5
      ENDIF
      IF IsFeiertag(tArchiveTime,"BW",.T.) .OR. Dow(tArchiveTime) == 1 .OR. DoW(tArchiveTime) == 7
         tArchiveTime := StoT(DToS(AddWorkingDays(TtoD(tArchiveTime),1,"BW",.T.))+SubStr(TtoS(tArchiveTime),9))
      ENDIF
      cArchiveTime := TtoS(tArchiveTime)
      IF tArchiveTime < dEingang
         cArchiveTime := ""
      ENDIF
   ENDIF
   IF Empty(cArchiveTime)
      cArchiveTime := DtoS(AddWorkingDays(dEingang,1,"BW",.T.))+SubStr(TtoS(DateTime()),9)
   ENDIF

   Scroll(03,00,MaxRow(),MaxCol(),-1)

   @ 03,00 SAY Str(nId,9)+" "+DtoC(dEingang)+" "+TtoC(StoT(cArchiveTime))
ENDDO

FUNCTION TtoD(tTime)
RETURN StoD(TtoS(tTime))