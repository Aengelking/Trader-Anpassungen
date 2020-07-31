PARAMETERS nNr,lFehl
//Hook("after_create_werkauf",{nNr,lFehl,.T.})

If wer->Termin <= Val(CalWeek(DATE())) .AND. ! lFehl .AND. Tr_MsgBox("Auftrag zum Richten freigeben?",,{"Ja","Nein"})==1
   IF Hook("before_start_werkauf",{wer->Aufno,wer->artno},.T.)
      WAStart(wer->Aufno,.F.)
   ENDIF
Endif
