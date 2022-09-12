FUNC HOOK_get_supplier_ship_cost(cSupplier,nWeight)
LOCAL nCost := 0

   IF Trim(cSupplier) == "SIGNAL"
      nCost := (1200/1000)*(nWeight/1000)  //1200? pro Tonne
   ELSEIF Trim(cSupplier) $ {"SIGNAL","DEGSON","FINECABL"}
      NetUse("versand","vers")
      NetUse("engkund","ku")   
      ku->(dbSeek( cSupplier+"L" ))   
      nCost := PakPreis(15,nWeight/1000)      
      //Alert(Str(nWeight)+"kg"+Str(nCost))
   ELSEIF Trim(cSupplier) == "ASCONNEC"
      nCost := 300/1000*nWeight/1000  //300? pro Tonne
   ENDIF
RETURN nCost

#include 'x:\run\getupsimportcost.prg'