PROC Odoo_Backfill_Customers(cGroups,nLimit)
   LOCAL nAdded

   HB_Default(@cGroups,"KL")
   HB_Default(@nLimit,0)

   nAdded := OdooSync_Backfill(cGroups,nLimit)

   ? "Odoo backfill queued:", nAdded
   ? "Groups:", cGroups
RETURN
