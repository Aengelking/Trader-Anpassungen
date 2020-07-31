LOCAL aCust := {},hManu := {=>}
LOCAL nStKw,nEnKw,cYear,nY,nR,nC
LOCAL cKundma := "",aManu

Head("Anzahl Kunden")

NetUse("engauf","auf")
NetUse("manufact","manu")
NetUse("artikel","art")

auf->(dbSetOrder( 10 )) // Str(Dterm,4)+Kundma
art->(dbSetOrder( 1 ))
@ 02,00 SAY "GESAMT"
manu->(dbGoTop())
nR := 3
DO WHILE ! manu->(EOF())
   @ nR++,00 SAY manu->Short
   manu->(dbSkip())
ENDDO

FOR nY := 0 TO 4
   aCust := {}
   hManu := {=>}
   cYear := Right(Str(Year(Date())-nY,4),2)
   nStKW := Val(cYear+"01")
   nEnKW := Val(cYear+"99")
   auf->(dbSeek( Str(nStKw,4) ))
   DO WHILE auf->DTerm >= nStKW .AND. auf->DTerm <= nEnKW .AND. ! auf->(EOF())
      art->(dbSeek( auf->Matchcode ))

      IF auf->Kundma != cKundMa
         IF AScan(aCust,auf->Kundma) == 0
            Aadd(aCust,auf->Kundma)
         ENDIF
         cKundma := auf->Kundma
      ENDIF
      //bAddManu := {||
         IF ! HHasKey(hManu,art->Manufactur)
            hManu[art->Manufactur] := {}
         ENDIF
         IF AScan(hManu[art->Manufactur],auf->Kundma) == 0
            Aadd(hManu[art->Manufactur],auf->Kundma)
         ENDIF
      //}
      auf->(dbSkip())
   ENDDO

   nC := 15+5*nY-1
   @ 01,nC SAY Str(Year(Date())-nY,4)
   @ 02,nC SAY LTrim(Str(Len(aCust)))
   manu->(dbGoTop())
   nR := 3
   DO WHILE ! manu->(EOF())
      @ nR++,nC SAY IF(HHasKey(hManu,manu->ID),LTrim(Str(Len(hManu[manu->Id]))),"-")
      manu->(dbSkip())
   ENDDO
NEXT

Tone(700,10);WaitPeriod(10);Tone(900,10);WaitPeriod(10);Tone(1100,10)


Sinkey(0)