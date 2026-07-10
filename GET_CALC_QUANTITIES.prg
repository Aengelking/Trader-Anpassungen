FUNCTION HOOK_GET_CALC_QUANTITIES(oArtikel)
   LOCAL oExtra := art->(ExtraData():New(oArtikel:Artikelnr))
   LOCAL aCalcQuantities := {}
   LOCAL nVPE
   
   IF oArtikel:Table == 60
      IF Len(oExtra:CalcQty) > 0
         aCalcQuantities := oExtra:CalcQty
      ELSE
         IF oArtikel:VPE != 0 //if there is a packaging unit we use multiple of this
            nVPE := oArtikel:VPE
         ELSE //otherwise we use 100 as default quantity
            nVPE := 100
         ENDIF
         aCalcQuantities := {nVPE,nVPE*5,nVPE*10,nVPE*20}
         IF Left(oArtikel:Matchcode,2) == "KS"
            NetUse("Angebot","ang")
            ang->(dbSetOrder( 3 ))
            ang->(dbSetFilter({|| ang->Bestat < 3 }, "BESTAT < 3") ) //only open items
            IF ang->(dbSeek( oArtikel:Matchcode ))
               DO WHILE ang->Matchcode == oArtikel:Matchcode .AND. ! ang->(EOF())
                  IF ang->VKQty > 0 .AND. AScan(aCalcQuantities,ang->VkQty) == 0
                     Aadd(aCalcQuantities,ang->VKQty)
                  ENDIF
                  ang->(dbSkip())
               ENDDO
            ENDIF
            ang->(dbClearFilter())
         ENDIF
      ENDIF
   ENDIF
     
RETURN aCalcQuantities