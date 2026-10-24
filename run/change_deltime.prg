PROC RUN_CHANGE_DELTIME
LOCAL aManu,nManu := 1
LOCAL nLZ := 1
LOCAL nCount
LOCAL cMatchcode := Space(25)
LOCAL nType := 1
LOCAL getlist := {}
LOCAL cFilter

NetUse("manufact","manu")
NetUse("artikel","art")

aManu := GetManufacturerArray()

Head(t("Beschaffungszeit bei allen Produkten eines Herstellers ändern"))

@ 01,00 SAY "Hersteller "
@ 01,12,23,40 GET nManu LISTBOX aManu[2] DROPDOWN
@ 02,00 SAY "Matchcode "
@ 02,12 GET cMatchcode
@ 03,00 SAY "Art"
@ 03,12,07,35 GET nType LISTBOX {"Neue Lieferzeit","Wochen addieren"} DROPDOWN
@ 04,00 SAY "Wochen "
@ 04,12 GET nLZ PICTURE "99"
READ

IF LastKey() == 27 .OR. Tr_MsgBox(t("Wirklich alle Produkte von % ändern",Trim(aManu[2][nManu])),,{"Nein","Ja"}) != 2
   RETURN
ENDIF

cFilter := "Manufactur == "+LTrim(Str(aManu[1][nManu]))+" .AND. ! Obsolete"
IF ! Empty(cMatchcode)
   cFilter += " .AND. AT('"+Trim(cMatchcode)+"',Matchcode) == 1"
ENDIF
art->(dbSetFilter( {|| art->(&(cFilter)) }, cFilter ))
art->(dbGoTop())
nCount := 0
DO WHILE ! art->(EOF())
   @ MaxRow(),00 SAY art->Matchcode
   art->(Rec_Lock())
   IF nType == 1
      art->LZ := nLZ
   ELSE
      art->LZ += nLZ
   ENDIF
   art->(dbUnLock())
   art->(dbSkip())
   nCount++
ENDDO

art->(dbClearFilter())

? nCount,t("Produkte geändert")

SInkey(0)