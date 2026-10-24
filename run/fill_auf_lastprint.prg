NetUse("auftrag","ab")
DO WHILE ! ab->(EOF())
   oAuftrag := Auftrag():New()
   oAuftrag:Load(ab->AbNr)
  /* ab->(Rec_Lock())
   ab->LastChange := ab->LastPrint
   ab->(dbUnLock())
   IF Empty(oAuftrag:LastPrint)
      dLastPrint := StoD("")
      oAuftrag:Positions:Each({|oPos|
         dLastPrint := Max(dLastPrint,oPos:Lastprint)
         RETURN NIL
      })
      IF ! Empty(dLastPrint)
         ab->(Rec_Lock())
         ab->LastPrint := DtoS(dLastPrint)+"235959"
         ab->(dbUnLock())
      ENDIF
   ENDIF*/
   ab->(dbSkip())
ENDDO