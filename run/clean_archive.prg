PROCEDURE HRBMAIN
LOCAL nAB,aList,nX
LOCAL nR

NetUSe("auftrag","ab")

/* 
   AUFTRGE
*/
CLS
nAB := 3153
nR := 0
DO WHILE LastKey() != 27
   @ MaxRow(),00 SAY nAB
   aList := GetArchiveFiles({"AB"=>nAb,"PI"=>nAB,"AUF"=>nAB,"TA"=>nAB})
   FOR nX := 1 TO Len(aList)
      IF ! ab->(dbSeek( Str(nAb,6) )) .OR. Empty(ab->Kundma) //.OR. Year(ab->Besda) < Year(Date())-10
         @ nR++,00 SAY aList[nX][6]
         IF nR == MaxRow()-1
            Scroll(00,00,MaxRow()-1,MaxCol(),1)
            nR := MaxRow()-1
         ENDIF
      ENDIF
   NEXT
   IF Upper(Chr(Inkey())) == "P"
      SInkey(0)
   ENDIF
   nAB++
ENDDO