PROC Hook_Automotive_After_Pack( nNr,lRech)

   NetUse("engkund","ku",.F.,0)

   re->(dbSetOrder( 4 ))
   re->(dbSeek( Str(nNr,6) ))

   GotoRechAddress()      
   UpdateInvoiceDate(nNr,Date())
      
   MBaseRun(Trim(Tr_Getini(1))+"\run\print_vda",{nNr,lRech})
RETURN