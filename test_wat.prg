LOCAL nDefQuota,nAvgTime
NetUse("artikel","art")
art->(dbSeek("KS26206"))

Art_GetDefAndAvgTime(@nDefQuota,@nAvgTime)
Alert(Str(nDefQuota)+";"+Str(nAvgTime)+"min")

