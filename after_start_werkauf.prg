PROC HOOK_AFTER_START_WERKAUF( nWnr )
   LOCAL lFremdOnly,oExtra
   LOCAL cConfigDir := "\\EK-SERVER4\Data\Technik\Prozessdoku\TesterTemplates\"
   MEMVAR mirpt,mibesnr

wer->(dbSetOrder(1))
wer->(dbSeek( str(nWnr,6) ))
IF ! Empty(wer->Liefma)
  lne->(dbSetOrder(1))
  lne->(dbSeek(wer->LagNum))

  lFremdOnly := .T.

  DO WHILE lne->Nummer == wer->Lagnum .AND. lFremdOnly
     IF lne->Menge != GetEntFremdLagerQty(lne->Nummer,lne->Pos)
        lFremdOnly := .F.
     ENDIF
     lne->(dbSkip())
  ENDDO

  IF lFremdOnly .AND. LockEntity("LNE",wer->Lagnum)
      IF ! GetConfigValue("BATCHMODE")
         Tr_MsgBox("Beistellware bereits beim Lieferanten, bitte Bestellung versenden.")
      ENDIF
      wer->(Rec_Lock())
      wer->Status := 3
      wer->(dbUnLock())
      mirpt := wer->besnr
      mibesnr := wer->besnr
      enbedr(wer->Besnr,,.F.)
      IF ! GetConfigValue("BATCHMODE")
         EINFUG(0,wer->LagNum,.T.,.T.)
      ENDIF
      UnLockEntity("LNE",wer->Lagnum)
  ENDIF
ELSE //interne Fertigung
   NetUse("werks","we")
   NetUse("artikel","art")
   NetUse( "restime", "rst"  )
   NetUse( "jobs",   "job" )

   art->(dbSetOrder(2))
   art->(dbSeek( Str(wer->Artno,6) ))
   oExtra := art->(ExtraData():New(wer->Artno))
   IF art->Gruppe == "SWPM" .AND. ! oExtra:ManualTest
      rst->(dbSetOrder( 1 ))
      rst->(dbSeek( "WA "+Str(wer->Aufno) ))   
      DO WHILE rst->Type == "WA " .AND. rst->No == nWnr
         job->(dbSeek( Str(rst->Job,6) ))
         
         IF AT("PRFEN",Upper(job->Name)) > 0 .AND. Empty(oExtra:CFGTMPLT) //.OR. File(cConfigDir+Trim(oExtra:CFGTMPLT)+".RC"))
            SendMail({{"amos.engelking@engelking.de","Amos"}},"Keine Config-Datei fr SD-Karte fr FA "+LTrim(Str(nWnr)),"Matchcode: "+art->Matchcode)            
            EXIT
         ENDIF
         rst->(dbSkip())
      ENDDO
   ENDIF
ENDIF
