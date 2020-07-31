FUNCTION RUN_CORR_ABG
LOCAL nX
LOCAL aList := {}
NetUse("engabg","abg")
abg->(dbSetFilter({|| abg->Buart == "RAŽ" .OR. abg->BuArt == "ENŽ" },'BuArt == "RAŽ" .OR. BuArt == "ENŽ"'))
abg->(dbGotop())
CLS
nX := 0
DO WHILE ! abg->(Eof()) //.AND. nX < 1000
   //? abg->Matchcode,abg->(Recno())
   Aadd(aList,abg->(Recno()))
   nX++

   abg->(dbSkip())
ENDDO

abg->(dbClearFilter())

abg->(dbSetOrder( 3 ))
FOR nX := 1 TO Len(aList)
   abg->(dbGoto( aList[nX] ))
   nQty := abg->Bestand
   abg->(dbSkip( -1 ))
   nQty := abg->Bestand-nQty
   abg->(dbGoto( aList[nX] ))
   IF abg->Menge != nQty 
      ? abg->Matchcode,abg->BuArt,Pad(Trim(abg->Beleg)+" "+Trim(Str(abg->Besnr)),10),nQty
      IF Len(LTrim(Str(nQty))) > 11
         Alert("Qty too big "+LTrim(Str(nQty)))
      ELSE
         abg->(Rec_Lock(0))
         abg->Menge := nQty
         abg->(dbUnLock())
      ENDIF
   ENDIF
NEXT

Sinkey(0)

RETURN
