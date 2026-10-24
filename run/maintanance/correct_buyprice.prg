NetUse("buyprice","bpr")
bpr->(dbSetOrder( 0 ))
bpr->(dbGoTop())

DO WHILE ! bpr->(EOF())
   IF ! Empty(bpr->EndDate) .AND. bpr->EndDate < bpr->Startdate
      bpr->(Rec_Lock())
      bpr->EndDate := bpr->Startdate
      bpr->(dbUnLock())
   ENDIF
   bpr->(dbSkip())
ENDDO
