

#include 'y:\hb32\include\hbthread.ch'

FUNCTION RUN_FREPPLE

   /*hb_threadStart(HB_THREAD_INHERIT_MEMVARS, {||
      //LOCAL oWin := TrWindow():New(,"Frepple Export")
      MBaseRun(Path("run\frepple_export"),{})
      //oWin:destroy()
      RETURN .T.
   })*/
   MBaseRun(Path("run\frepple_export"))

RETURN NIL

//#include 'x:\run\frepple_export.prg'