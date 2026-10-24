FUNC HOOK_AFTER_TAKE_STOCK(nArtnr,cORT,nMenge,cCharge,cBuArt)   
   //Alert("Lagerort "+cOrt)
   IF Substr(cOrt,3) == "096"
      //Alert("Sperrlager")
   ENDIF
   RETURN NIL