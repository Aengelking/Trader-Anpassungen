PROC HOOK_AFTER_PRINT_PDF(oObject,cFullFileName)
   LOCAL cFileName
   
   HB_FNameSplit( cFullFileName , ,@cFileName)

   IF Tr_Getini(28) == 9
      //Alert("Here;"+cFileName+";"+cFullFileName)
      //Alert(ValType(oObject))
      //RETURN      
   ENDIF
   IF ValType(oObject) == "O" .AND. oObject:ClassName == "RECHNUNG" .AND. LEFT(Upper(cFileName),2) == "RE" .AND.;
      ! IsInHook("BEFORE_PACK_FROM_LIST")
     MBaseRun(Path("run\create_xrechnung"),{oObject:Rechnr,cFullFileName})
     IF Tr_Getini(28) == 9 .AND. ! GetConfigValue("BATCHMODE")
         //Alert("X-Rechnung wurde erstellt")
         //BREAK
     ENDIF
   ENDIF
RETURN