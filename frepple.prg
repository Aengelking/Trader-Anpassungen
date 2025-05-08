

#include 'y:\hb32\include\hbthread.ch'

FUNCTION RUN_FREPPLE
   //SetConfigValue("BATCHMODE",.T.)
   /*hb_threadStart(HB_THREAD_INHERIT_MEMVARS, {||
      //LOCAL oWin := TrWindow():New(,"Frepple Export")
      MBaseRun(Path("run\frepple_export"),{})
      //oWin:destroy()
      RETURN .T.
   })*/
   IF ! MBaseRun(Path("run\frepple_export"))
      SendMessage("FERTIGUNG | Freeple Sync","Fehler beim Export der Daten")
   ENDIF
   IF ! MBaseRun(Path("run\frepple_curl"))
      SendMessage("FERTIGUNG | Freeple Sync","Fehler beim Hochladen der Daten")
   ENDIF

RETURN NIL

//#include 'x:\run\frepple_export.prg'