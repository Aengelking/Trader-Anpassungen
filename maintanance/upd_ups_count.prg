NetUse("ups","ups")
ups->(dbSetOrder( 0 ))
ups->(dbGoTop())
NetUse("paknum","pnum")
pnum->(dbSetOrder( 1 ))
DO WHILE ! ups->(Eof()) //.AND. ups->(Recno()) < 50
   ups->(Rec_Lock())
   ups->Pieces := pnum->(Leto_Sum("#",,ups->Nr,ups->Nr ))
   ups->(dbUnLock())
   ? ups->Nr,ups->Pieces
   ups->(dbSkip())
ENDDO

Inkey(0,128)