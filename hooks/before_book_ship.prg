FUNCTION Hook_before_book_ship(nNr,lRech,nVersandart,nPerson,hArten,hSizes)
   HB_SYMBOL_UNUSED(nNr)
   HB_SYMBOL_UNUSED(lRech)
   HB_SYMBOL_UNUSED(nVersandart)
   HB_SYMBOL_UNUSED(nPerson)
   HB_SYMBOL_UNUSED(hArten)
   IF nVersandart == 10 //Abholung
      hSizes["CT"] := {"W"=>0,"H"=>0,"L"=>0}  //box size required
   ENDIF
RETURN .T.
