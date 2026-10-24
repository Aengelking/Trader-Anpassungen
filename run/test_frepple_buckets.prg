PROC run_test_frepple_buckets
   LOCAL oFrepple,aResult
   LOCAL hCalendars := {=>}
   LOCAL nX

   CLS
   ? "Syncing Timebutler with Frepple buckets"

   //NetUse("buyer","buy")
   //buy->(dbGoto( 55 ))

   //we actually need to still lookup the calendar names for each resource
   //for the time beeing we will assume they are named according to the resource name
   

   NetUSe("resource","res")
   res->(dbGoTop())
   DO WHILE ! res->(EOF())
      IF res->User != 0
         hCalendars[Trim(res->Name)] := {}
      ENDIF      
      res->(dbSkip())
   ENDDO

   LoadModule("frepple")
   oFrepple := GetFreppleApi()

   ? "Downloading buckets"
   aResult := oFrepple:getCalendarBuckets() //this returns all buckets for all resources

   ? "Deleting existing (Timebutler) buckets"
   FOR nX := 1 TO Len(aResult)
      IF aResult[nX]["source"] == "Timebutler"
         ? "FOUND"
      ENDIF
      /*IF ! HHasKey(hCalendars,aResult[nX]["calendar"])
         hCalendars[aResult[nX]["calendar"]] := {}
      ENDIF
      Aadd(hCalendars[aResult[nX]["calendar"]],aResult[nX])*/
   NEXT

   //? ValToPrg(hCalendars["Nora"])
   ? "Sync completed"
   Sinkey(0)
   

RETURN
