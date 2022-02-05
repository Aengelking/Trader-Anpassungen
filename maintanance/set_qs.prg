FUNCTION RUN_SET_QS
   NetUse("artikel","art")
   
   SET FILTER TO ! Empty(art->Zeichnung) .AND. ! art->QS .AND. ! art->Obsolete
   art->(dbGoTop())
   DO WHILE ! art->(EOF())
      ? art->Matchcode
      art->(Rec_Lock(0))
      art->QS := .T.
      art->(dbUnLock())
      art->(dbSkip())
   ENDDO
   art->(dbClearFilter())
RETURN NIL