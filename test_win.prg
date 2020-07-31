#include 'y:\hb32\include\hbthread.ch'
MEMVAR hmtx_busy
PUBLIC hmtx_busy := HB_mutexCreate()

hb_threadStart(HB_THREAD_INHERIT_MEMVARS, {||
   LOCAL oWin := TrWindow():New()
   NetUse("engkund","ku")
   DO WHILE Inkey(0.1,128) != 27
      HB_mutexLock(hmtx_busy)
      ? ku->Kunde
      ku->(dbSkip())
      HB_mutexUnLock(hmtx_busy)
   ENDDO
   oWin:destroy()
})

NetUse("engkund","ku")
DO WHILE Inkey(0,128) != 27
   HB_mutexLock(hmtx_busy)
   ? ku->Kunde
   ku->(dbSkip())
   HB_mutexUnLock(hmtx_busy)
ENDDO

