LOCAL oRech := Rechnung():New()

oRech:Load(47222)
oRech:Positions:Each({|oRec|
   //IF oRec:AoQty != 0
      ? oRec:Rechnung:Rechnr,oRec:RePosnr,oRec:AoQty,oRec:Matchcode
   //ENDIF
})
Sinkey(0)
