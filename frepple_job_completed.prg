PROC Frepple_Job_Completed
   LOCAL oFrepple
   LoadPrg(Path("run\frepple_curl.prg"))

   oFrepple := GetFreppleApi()
   
   NetUse("frepjobs","fjob")
   fjob->(dbSeek( rst->JobId ))

   //Alert(Trim(fjob->FreppleId))
   //gtSetClipboard(Trim(fjob->FreppleId))

   oFrepple:patchManufacturingOrder(Trim(fjob->FreppleId),{"status"=>"proposed"})

   #include 'x:\run\frepple_curl.prg'

