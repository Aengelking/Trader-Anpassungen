#define LAG_STOCK_TEMPBLOCK        6

FUNCTION RUN_FREEPLE_OPTIMISE
   LOCAL oFrepple := GetFreppleApi()  
   LOCAL hStock := {=>}
   LOCAL aData,nX
   LOCAL cMatch,nKw  ,nStock

   /*? ValToPrg(oFrepple:patchManufacturingOrder("49738",{ ;       
               "status"=>"confirmed",;
               "quantity"=>1000;
            })) //["status"]
            Sinkey(0)

RETURN NIL*/

   aData := oFrepple:getManufacturingOrders()
   NetUse("artikel","art")

   FOR nX := 1 TO Len(aData)
      IF "|QS" $ aData[nX]["operation"] .AND. ! ":" $ aData[nX]["operation"] //aData[nX,hMap:Operation_Id]
         cMatch := SubStr(aData[nX]["operation"],1,AT("|",aData[nX]["operation"])-1)
         nKw := CWeek(Frep_StoT(aData[nX]["startdate"]))
         ? aData[nX]["reference"],cMatch,nKw,aData[nX]["quantity"]
         art->(dbSeek( cMatch ))
         IF ! HHasKey(hStock,cMatch)
            hStock[cMatch] :={"STOCK"=>LagGetStock(art->Artikelnr,LAG_STOCK_TEMPBLOCK)-HLAGER(art->Artikelnr,Pad("090/",12)),"WEEKS"=>GetKwQty(art->Artikelnr),"USED"=>0}
         ENDIF
         nStock := GetWeekStock(hStock[cMatch],nKW)
         ?? "",nStock
         IF nStock >= Val(aData[nX]["quantity"]) 
            oFrepple:patchManufacturingOrder(aData[nX]["reference"],{ ;       
               "status"=>"approved",;
               "quantity"=>Str(GetWeekStock(hStock[cMatch],nKW));
            })
            hStock[cMatch]["STOCK"] -= nStock
            ?? " updated"
         ELSE
            oFrepple:patchManufacturingOrder(aData[nX]["reference"],{ ;       
               "status"=>"proposed";
            })     
            hStock[cMatch]["STOCK"] -= Val(aData[nX]["quantity"])       
         ENDIF
      ENDIF
   NEXT

   Sinkey(0)   
RETURN NIL

STATIC FUNCTION GetWeekStock(hStock,nKW)
   LOCAL nX := 1,nStock
   nStock := hStock["STOCK"]   
   DO WHILE nX <= Len(hStock["WEEKS"]) .AND. hStock["WEEKS"][nX,1] <= nKw
      nStock += hStock["WEEKS"][nX][3]+hStock["WEEKS"][nX][5]
      nX++
   ENDDO            
RETURN nStock

#include 'x:\run\frepple_curl.prg'