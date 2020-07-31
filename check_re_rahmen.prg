NetUse( "rechpos" ,"rpos")
rpos->(dbGoTop())
NetUse( "engbes", "bes" )

DO WHILE ! rpos->(EOF())
   IF rpos->Besnr != 0
      bes->(dbSeek ( Str(rpos->Besnr,6) ))
      IF bes->Rahmen
         ? bes->Besnr
      ENDIF
   ENDIF
   rpos->(dbSkip())
ENDDO

Inkey(0,128)