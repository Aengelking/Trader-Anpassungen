PROC MASK_BEWEGUNG_TRD07

LOCAL cMemo,nLines,nMax,nBottom,nX

MEMVAR c_five

//Memo: Soft-Returns (Chr(141)+Chr(10)) entfernen, Zeilen auf Boxbreite umbrechen
cMemo  := StrTran(Trim(bew->Memo),Chr(141)+Chr(10)," ")
nLines := IF(Empty(cMemo),0,MlCount(cMemo,57))
nMax   := MaxRow()-1-16                    //verfuegbare Memo-Zeilen
nBottom := Max(20,16+Min(nLines,nMax))

SetColor(c_five)
@ 10,10 CLEAR TO nBottom,70
@ 10,10 TO nBottom,70
@ 11,11 SAY "Mitarbeiter"
@ 11,23 SAY Buy(bew->Buyer,.T.,0)
@ 12,11 SAY "Bestellnr. "
@ 12,23 SAY bew->Besnr
@ 13,11 SAY "Transaktion"
@ 13,23 SAY DToC(bew->TransDate)+"  "+bew->TransTime
@ 14,10 SAY Chr(195)+Replicate(Chr(196),59)+Chr(180)
@ 15,11 SAY "Memo"
IF nLines == 0
   @ 16,12 SAY "(kein Memo)"
ELSE
   FOR nX := 1 TO Min(nLines,nMax)
      @ 15+nX,12 SAY MemoLine(cMemo,57,nX)
   NEXT
   IF nLines > nMax
      @ nBottom,64 SAY "[...]"
   ENDIF
ENDIF
SInkey(0)

RETURN
