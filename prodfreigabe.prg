
PROC RUN_PRODFREIGABE
   LOCAL dProdDate := AddMonth(Date(),3)
   LOCAL oAuftrag := Auftrag():New()
   LOCAL lUpdate := .F.

   oAuftrag:Load(50155)

   oAuftrag:Positions:Each({|oPos|
      IF ! oPos:IsRahmen .AND. oPos:GelQty == 0 .AND. dProdDate >= oPos:WDatum
         ? oPos:Itmnr,"freigegeben"
         IF oPos:BeStat > 0            
            oPos:BeStat := 0                
            oPos:Save()         
            lUpDate := .T.  
         ENDIF
      ENDIF            
      RETURN NIL
   })

   IF lUpdate
      oAuftrag:LastChange := TtoS(DateTime())
      oAuftrag:Save(.T.)        
      Approve("AUF",oAuftrag:AbNr,StoT(oAuftrag:LastChange),oAuftrag:Buyer,oAuftrag)
   ENDIF

   Sinkey(0)
RETURN