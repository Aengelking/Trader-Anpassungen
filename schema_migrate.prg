FUNCTION Run_SchemaMigrate()
   LOCAL oMgr := MigrationManager():New()

   //THIS CURRENTLY DOES NOT WORK CORRECTLY!
   //RISK OF DATA LOSS
   //LOCAL lOk := oMgr:RunSchemaMigrations(.T.)

   IF lOk
      Tr_MsgBox("Schema migration completed")
   ELSE
      Tr_MsgBox("Schema migration failed. See migrations.log")
   ENDIF

RETURN NIL
