FUNCTION RUN_ONWORKDAYS(cFunc,aParams,lRun)
   #include "noworking.ch"

   Default(@lRun,.F.)

   IF ! lRun
      //cFunc := &cFunc
      HB_ExecFromArray( cFunc, aParams )
   ELSE
      MBaseRun(Path("run\"+cFunc),aParams)
   ENDIF
RETURN NIL
