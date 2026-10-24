NetUse("buyer","buy",.T.)
buy->(dbCreateIndex("ntx/buyer.cdx","EMAIL",{|| buy->Email },,"BUYER04"))
