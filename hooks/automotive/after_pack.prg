PROC Hook_Automotive_After_Pack( nNr,lRech)
   LOCAL oErr

   NetUse("engkund","ku",.F.,0)

   re->(dbSetOrder( 4 ))
   IF ! re->(dbSeek( Str(nNr,6) ))
      oErr := Error("TRADER",101,0,"PACK_INVOICE","Rechnung nicht gefunden")
      Throw( oErr )
   ENDIF

   GotoRechAddress()      
   UpdateInvoiceDate(nNr,Date())
      
   MBaseRun(Trim(Tr_Getini(1))+"\run\print_vda",{nNr,lRech})
   IF lRech
      MBaseRun(Trim(Tr_Getini(1))+"\run\ship_notification",{nNr,1})
   ENDIF
RETURN