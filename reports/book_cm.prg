LOCAL nSum,nYear
LOCAL hBook
LOCAL nCount := 0
LOCAL aData := {}

NetUse("engkund","ku")
NetUSe("engauf","auf")

Head("Bookings YTD pro Kunde")

cFile := Trim(Tr_Getini(1))+"\export\book_ytd.csv"

DO WHILE LastKey() != 27 .AND. (nHandle := FCreate(cFile)) == -1 .AND. TR_MsgBox("Could not open file",,{"Retry","Cancel"}) == 1
ENDDO
IF nHandle == -1
   RETURN
ENDIF

ku->(dbSetOrder( 2 ))
ku->(dbSeek( "K" ))

/*auf->(dbSetFilter({|| auf->Pe == 0 },"pe == 0"))
auf->(dbGoTop())
DO WHILE ! auf->(EOF())
   ? auf->Abnr
   auf->(dbSkip())
ENDDO
auf->(dbClearFilter())*/

auf->(dbSetOrder( 2 ))

Aadd(aData,{"Kunde","2015 YTD","2016 YTD"})

DO WHILE ku->Group == "K" //.AND. nCount < 10
   //? ku->Kunde
   hBook := {=>}
   FOR nYear := 2015 TO 2016
      auf->(dbGoTop())
      aVal := auf->(LETO_SUM("#,1/pe*vkpr*vkqty",'besda>=StoD("'+LTrim(Str(nYear,4))+'0101") .AND. besda<=StoD("'+LTrim(Str(nYear,4))+StrZero(Month(Date()),2)+StrZero(Day(Date()),2)+'")',ku->Kunde,ku->kunde))
      hBook[nYear] :=  aVal[2]
   NEXT
   IF hBook[2015] != 0 .OR. hBook[2016] != 0
      ? ku->Kunde,hBook[2015],hBook[2016]
      Aadd(aData,{Trim(ku->Kunde),hBook[2015],hBook[2016]})
      nCount++
   ENDIF
   ku->(dbSkip())
ENDDO

FClose(nHandle)

SaveAsCSV(cFile,aData)

WAPI_ShellExecute(,"open",cFile)