FUNCTION GetUpsImportCost(nGewicht)
   LOCAL nRec,nOrd
   LOCAL nPrice

   NetUse("versand","vers")
   NetUse( "zone"   ,"ZO" )
   NetUse( "verspr" ,"VP" )


   IF Select("ku") != 0
      nRec := ku->(Recno())
      nOrd := ku->(IndexOrd())
   ELSE
      NetUse("engkund","ku")
   ENDIF

   nGewicht := Max(1000,nGewicht) //always min. 1kg   
   
   NetUSe("manufact","manu")
   manu->(dbSeek( Str(art->Manufactur,5) ))

   ku->(dbSetOrder( 8 ))
   ku->(dbSeek( Str(manu->Address,6) ))
   
   nPrice := Hook("get_supplier_ship_cost",{ku->Kunde,nGewicht})
   //nPrice := PakPreis(15,nGewicht)

   IF nRec != NIL
      ku->(dbSetOrder(nOrd))      
      ku->(dbGoto(nRec))
   ENDIF
RETURN nPrice