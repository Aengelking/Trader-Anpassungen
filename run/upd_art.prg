NetUse("artikel","art")
art->(dbGoTop())
Head("Artikel aktualisieren")
DO WHILE ! art->(EOF())
   @ 01,00 SAY art->Matchcode
   IF art->Manufactur == 1 .AND. Empty(art->Ursprung) //BULGIN
      art->(Rec_Lock())
      IF Left(art->Matchcode,2) $ "FX KT PF"  //manche PX werden in China hergestellt
         art->Ursprung := "TN"
      ENDIF
      art->(dbUnLock())
   ENDIF
   art->(dbSkip())
ENDDO
