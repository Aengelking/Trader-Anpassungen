FUNC HOOK_get_supplier_ship_cost(cSupplier,nGramms)
LOCAL nCost := 0

   /*IF Trim(cSupplier) == "SIGNAL"
      nCost := (1200/1000)*(nGramms/1000)  //1200? pro Tonne, fix = Kostenteilung ber viele Bestellungen, Frachtkosten basieren auf Zug.      
   ELSE*/IF Trim(cSupplier) $ {"SIGNAL","DEGSON","FINECABL","ELCOM"}
      NetUse("versand","vers")
      NetUse("engkund","ku")   
      ku->(dbSeek( cSupplier+"L" ))   
      nCost := PakPreis(15,nGramms/1000)      
      //Alert(Str(nGramms)+"kg"+Str(nCost))
   ELSEIF Trim(cSupplier) == "ASCONNEC"
      nCost := 300/1000*nGramms/1000  //300? pro Tonne
   ENDIF

   //Cost for special products
   IF Trim(cSupplier) $ {"WHTECH","SELT","TTAF"}
      nCost += 60
   ENDIF

RETURN nCost

