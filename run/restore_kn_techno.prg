PROC RESTORE_KN_TECHNO
   IF Tr_Getini(28) != 9
   RETURN
   ENDIF

   NetUse("artikel","art")
   
   Select(0)
   dbUseArea(.T.,"DBFCDX","C:\Users\Amos\Desktop\Artikel","tmpart")
   SET FILTER TO tmpart->Manufactur == 11
   tmpart->(dbGotop())

   art->(dbSetOrder(2))

   DO WHILE ! tmpart->(EOF())
      IF art->(dbSeek( Str(tmpart->Artikelnr,6) ))
         ? art->Matchcode,art->KnCode,tmpart->KnCode
         art->(Rec_Lock())
         art->KnCode := tmpart->KnCode
         art->(dbUnLock())
      ENDIF
      tmpart->(dbSkip())
   ENDDO