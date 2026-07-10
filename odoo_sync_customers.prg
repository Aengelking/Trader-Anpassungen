PROC Odoo_Sync_Customers(nMax)
   LOCAL cProtocol
   LOCAL nDone

   HB_Default(@nMax,200)

   cProtocol := Path("\\export\\odoo_sync_"+DToS(Date())+"_"+StrTran(Time(),":","-")+".txt")

   nDone := OdooSync_ProcessQueue(nMax,cProtocol)

   ? "Odoo sync processed:", nDone
   ? "Protocol:", cProtocol
RETURN
