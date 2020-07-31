LOCAL oRec
CLS

NetUse("watime","wat")
DO WHILE ! wat->(Eof())

   IF Empty(wat->End) .AND. StoD(wat->Start) < Date()
      ? wat->WaNr,TtoC(StoT(wat->Start)) ,"no end"
   ELSEIF oRec != NIL .AND. oRec:Wanr == wat->Wanr .AND. oRec:Person == wat->Person .AND. oRec:Job == wat->Job .AND. BetWeen(StoT(wat->Start),StoT(oRec:End),StoT(oRec:End)+5/24/60) //is the start of this one within 5 minutes of the previous and the same taks
      ? wat->WaNr,Left(TtoC(StoT(oRec:Start)),14),Left(TtoC(StoT(wat->Start)),14),Left(TtoC(StoT(wat->End)),14),"|",Left(TtoC(StoT(oRec:End)),14),"|",left(TtoC(StoT(oRec:End)+5/24/60),14)
      oRec:End := wat->End //move end
      oRec:Save()

      //delete the duplicate
      wat->(Rec_Lock())
      wat->(dbDelete())
      wat->(dbUnLock())
   ENDIF
   oRec := wat->(Record():New())
   wat->(dbSkip())
ENDDO

? 'done...'
Inkey(0,128)