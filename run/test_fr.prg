LOCAL oFrPrn

NetUse("engbes","bes")
oFrPrn := frReportManager():new()
oFrPrn:SetIcon( 1 )

oFrPrn:SetWorkArea("bes")
oFrPrn:DesignReport()

oFrPrn:DestroyFR()