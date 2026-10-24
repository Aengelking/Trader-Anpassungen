PROC RUN_SYNC_Supabase
   LOCAL oSupa := Supabase():New()
      IF ! oSupa:Login() 
         IF ! GetConfigValue("BATCHMODE")
            Tr_MsgBox("Login failed")
         
         ENDIF
         RETURN
      ENDIF

   LoadPrg(Path("run\timebutlerapi.prg")) //load timbutler api
   LoadPrg(Path("run\supabase\supabase_kpi.prg")) //load the functions

   hb_ExecFromArray("Sync_Supabase_KPI",{oSupa})   

RETURN

#include "x:\run\supabase_api.prg"
