FUNCTION RUN_CLEAN_QS
   LOCAL cFilter

   NetUse("qs","qs")
   cFilter := "status == 0 .AND. datum < Stod('"+DtoS(Date()-365*2)+"')"
   qs->(dbSetFilter( {|| qs->(&(cFilter))},cFilter ))
   qs->(dbGoTop())

   CLS

   DO WHILE ! qs->(EOF())
      ? qs->Status,qs->Liefma,qs->Datum,qs->Nummer
      qs->(Rec_Lock())
      qs->Status := 9
      qs->(dbUnLock())
      qs->(dbSkip())
   ENDDO

   Sinkey(0)
RETURN NIL
