PROC CREATE_ENGKUND_INDEX
   
NetUse("engkund","ku",.T.)
ku->(OrdCreate("ntx\engkund.cdx","engkund09","str(team,2)",{|| Str(ku->Team,2)}))
