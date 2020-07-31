NetUse("engauf","auf")
auf->(dbSetOrder( 10 ))

aList := {}

FOR nYear := 14 TO 16
   cKw   := Str(nYear,2)+"99"
   nKW   := Val(cKW)

   auf->(dbSeek( cKW ))
   DO WHILE auf->DTerm == nKW
      IF Val(Left(Str(auf->Wterm,4),2)) != nYear
         Aadd(aList,{"ab"=>auf->abnr,"pos"=>auf->Itmnr})
         ? auf->Abnr
      ENDIF
      auf->(dbSkip())
   ENDDO
NEXT

auf->(dbSetOrder( 1 ))
FOR nX := 1 TO Len(aList)
   IF auf->(dbSeek( Str(aList[nX]["ab"],6)+Str(aList[nX]["pos"],3) ))
         auf->(Rec_Lock())
         auf->DTerm  :=  Val(Left(Str(auf->Wterm,4),2)+"99")
         auf->(dbUnLock())
   ENDIF
NEXT
Inkey(0,128)