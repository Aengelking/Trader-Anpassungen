NetUse("artikel","art")

CLS

art->(dbGoTop())
DO WHILE ! art->(Eof())
   IF AScan({1,3},art->Manufactur) != 0 .AND. art->Table > 9
      @ 24,00 SAY art->Matchcode
      art->(Rec_Lock())
      art->Table := 1
      art->(dbUnLock())
   ENDIF
   art->(dbSkip())
ENDDO