LOCAL nBesnr := 0,nFH,cFile

NetUse("engbes","bes")
Netuse("artikel","art")
NetUse("artlief","ali")

DO WHILE .T.
   Head("Bestellung als BOM exportieren")
   @ 01,00 SAY "Bestellung" GET nBesnr PICTURE "@K 999999" VALID nBesnr > 0
   READ

   IF ! bes->(dbSeek( Str(nBesnr,6) ))
      @ 01,18 SAY "Nicht gefunden"
      LOOP
   ENDIF

   IF ! LockEntity("BES",nBesnr)
      LOOP
   ENDIF

   cFile := Trim(Tr_Getini(1))+"\export\BES"+StrZero(nBesnr,6)+".txt"
   nFH := FCreate(cFile)
   IF nFH <= 0
      Tr_MsgBox("Datei konnte nicht erzeugt werden. (Dos Error "+Ltrim(Str(FError()))+")")
      LOOP
   ENDIF

   bes->(dbSetFilter({|| bes->BeStat < 3 .AND. bes->FolgeTo == 0},"bestat < 3 .AND. FolgeTo == 0"))
   DO WHILE bes->Besnr == nBesnr .AND. ! bes->(EOF())
      art->(dbSeek( Str(bes->Artikelnr,6) ))
      IF ali->(dbSeek( Pad("BULGIN",8)+Str(bes->Artikelnr,6) ))
         FWrite(nFH,Trim(ali->Artlief))
      ELSE
         FWrite(nFH,Trim(bes->Matchcode))
      ENDIF
      FWrite(nFH,","+LTrim(Transform(bes->BeQty,Me(art->me)))+Chr(13)+Chr(10))
      bes->(dbSkip())
   ENDDO

   UnLockEntity("BES",nBesnr)
   FClose(nFH)

   //WAPI_ShellExecute(,"open",cFile)
   GTSETCLIPBOARD(cFile)
   
   Alert("Dateiname wurde in die Zwischenablage kopiert")

   EXIT
ENDDO