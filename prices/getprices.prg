
FUNCTION GetPricesCompet(cLief,lDbg)
   LOCAL hPrices

   Default(@lDbg,.F.)
   
   ku->(dbSetOrder( 1 ))
   ku->(dbSeek( Pad(Upper(cLief),8)+"L" ))
   ali->(dbSeek(Pad(Upper(cLief),8)+Str(art->Artikelnr,6)))

   IF lDbg .OR. ! cmp2->(dbSeek( Str(art->Artikelnr,6)+Str(ku->Nummer,6) )) .OR. cmp2->Datum < Date()
      hPrices := MBaseRun(Trim(Tr_Getini(1))+"\run\prices\"+cLief,{art->Artikelnr,ali->Artlief,art->Matchcode})
      IF ValType(hPrices) == "H" .AND. Len(hPrices) != 0
         IF ! cmp2->(dbSeek( Str(art->Artikelnr,6)+Str(ku->Nummer,6) ))
            cmp2->(Add_Rec(0))
            cmp2->Artikelnr := art->Artikelnr
            cmp2->Lieferant := ku->Nummer
         ELSE
            cmp2->(Rec_Lock())
         ENDIF
         cmp2->Datum := Date()
         cmp2->Daten := HB_Serialize(hPrices)
         cmp2->(dbUnLock())
      ENDIF
   ELSE
      hPrices := HB_DeSerialize(cmp2->Daten)
   ENDIF
   
RETURN hPrices