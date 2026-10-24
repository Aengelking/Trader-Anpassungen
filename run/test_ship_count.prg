NetUse("ups","ups")
ups->(dbSetOrder( 5 ))
CLS
? "UPS"
? "----"
? "This month:",ups->(Leto_sum( "pieces","versandart=2",BoM(Date()),EoM(Date()) ))
? "Today:",ups->(Leto_sum( "pieces","versandart=2",Date(),Date() ))
?
? "DPD"
? "---"
? "This month:",ups->(Leto_sum( "pieces","versandart=3",BoM(Date()),EoM(Date()) ))
? "Today:",ups->(Leto_sum( "pieces","versandart=3",Date(),Date() ))

Sinkey(0)