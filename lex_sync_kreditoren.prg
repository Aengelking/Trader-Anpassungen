#define LX_CAT_KREDITOR         256

PROC RUN_LEX_SYNC_JREDITOREN
   LOCAL hAccounts
   LOCAL nAccount,cName
   LOCAL nCount := 0

   NetUse("fibu","fibu")

/*? HB_OEmToAnsi("W„hrung")
SInkey(0)
RETURN*/

   LX_Start()
   hAccounts := LX_GetAccountsInCat(LX_CAT_KREDITOR,.T.)

   FOR EACH cName IN hAccounts
      nAccount := cName:__eNumKey()
      fibu->(dbSetOrder( 2 ))
      IF ! fibu->(dbSeek( Str(nAccount,6) ))
         fibu->(dbSetOrder( 3 ))
         IF ! fibu->(dbSeek( Str(nAccount,6) ))
            IF 'W"hrung' $ HB_AnsiToOem(cName)
               ? nAccount,"WD"
            ELSE
               ? nAccount,HB_AnsiToOem(cName)
               nCount++
            ENDIF            
         ENDIF
      ENDIF
   NEXT

   ? "Anzahl:",nCount

   SInkey(0)


