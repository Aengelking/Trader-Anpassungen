NetUse("ups","ups")
ups->(dbSetOrder( 5 ))

? ups->(Leto_sum( "pieces","versandart=51",BoM(Date()),EoM(Date()) )) < 55
? ups->(Leto_sum( "pieces","versandart=51",Date(),Date() )) < 5

Inkey(0,128)