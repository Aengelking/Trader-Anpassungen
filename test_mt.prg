
hb_threadStart({|| TestThread(  ) })
hb_threadStart({|| TestThread(  ) })
hb_threadStart({|| TestThread(  ) })

//TestThread(  )
Inkey(10,128)

FUNCTION TestThread()
   LOCAL nTime := Seconds()
   LOCAL cTest := Space(20)

   pGT := hb_gtCreate( "GTWVT" )
   HB_GTSELECT( pGT )

   @ 00,00 SAY "Test" GET cTest
   READ

   /*DO WHILE Seconds() < nTime+10 //run for a minute
       ? Seconds()
   ENDDO*/
RETURN