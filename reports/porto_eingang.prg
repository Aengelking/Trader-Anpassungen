LOCAL cLiefma := Space(8)
LOCAL getlist := {}
LOCAL hWeeks,nPorto,nYear := Year(Date())
LOCAL nTot := 0

Head("Eingangsfracht pro Woche")

NetUse("engrech","rech")
NetUse("engkund","ku")

@ 01,00 SAY "Lieferant" GET cLiefma PICTURE "@!" VALID ku->(Check(cLiefma+"L","ku->Name1",01,20,1,0))
@ 02,00 SAY "Jahr     " GET nYear PICTURE "9999"
READ

IF LastKey() == 27
   RETURN
ENDIF

rech->(dbSetOrder( 1 ))
rech->(dbSetFilter({|| Year(rech->rechdat) == nYear },"Year(rechdat) == "+Str(nYear,4) ))
rech->(dbSeek( cLiefma ))

hWeeks := {=>}

DO WHILE rech->Liefma == cLiefma
   cKW := CalWeek(rech->Rechdat)
   IF ! HHasKey(hWeeks,cKW)
      hWeeks[cKW] := 0
   ENDIF
   hWeeks[cKW] += rech->Porto
   rech->(dbSkip())
ENDDO

rech->(dbClearFilter())

ASort(hWeeks)

SetPos(02,00)

FOR EACH nPorto IN hWeeks
   ? nPorto:__eNumKey(),nPorto
   nTot += nPorto
NEXT
? Replicate("-",18)
? Space(4),nTot

Sinkey(0)