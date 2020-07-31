PROC RUN_CHECK_REB
LOCAL hUsers := {=>},nCount
NetUse("reb","reb")

Head("Rechnungseingangsbuch berprfen")

reb->(dbSetFilter( {|| reb->Status != 9 },"status != 9" ))
reb->(dbGotop())
DO WHILE ! reb->(EOF())
   IF ! HHasKey(hUsers,reb->Person)
      hUsers[reb->Person] := 1
   ELSE
      hUsers[reb->Person]++
   ENDIF
   reb->(dbSkip())
ENDDO

FOR EACH nCount IN hUsers
   ? Buy(nCount:__enumkey(),.T.),GetUserEmail(nCount:__enumkey()),nCount
   IF ! EMPTY(Buy(nCount:__enumkey(),.T.))
      Sendmail({{GetUserEmail(nCount:__enumkey()),Buy(nCount:__enumkey(),.T.)}},LTrim(Str(nCount))+" Rechnung"+IF(nCount>1,"en","")+" im Eingangsbuch")
   ENDIF
NEXT

