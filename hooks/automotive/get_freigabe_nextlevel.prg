FUNCTION HOOK_GET_FREIGABE_NEXT_LEVEL(cState,nArtnr,nSupplier,lNextFrei)
   
   LOCAL oArt := Artikel():New()
   LOCAL cNextState
   oArt:Load(nArtnr)

   Default(@lNextFrei,.T.) //backwards compatibility

//cState := "BAGK"
   
   SWITCH cState
      CASE ""
         cNextState := "BAGK" //default state for new products
         IF Left(oArt:Matchcode,2) == "KS"
            EXIT //Kundenartikel, this is the first state
         ENDIF
      CASE "BAGK" //Bemusterung mit Kunde
         cNextState := "BAGL" //next level is Bemusterung mit Lieferant
         IF nSupplier != 0
            EXIT //we have a supplier, this is the current state
         ENDIF
      CASE "BAGL" //Bemusterung mit Lieferant
         cNextState := "PRUE"
         IF nSupplier != 0
            EXIT //we have a supplier, this is the current state
         ENDIF
      CASE "PRUE" //PrÅfplan
         cNextState := "MUS" //next level is Musterfreigabe
         IF nSupplier != 0
            EXIT //we have a supplier, this is the current state
         ENDIF
      CASE "MUS" //Musterfreigabe
         cNextState := "KU" //next level is Vom Kunden
         IF nSupplier != 0 .AND. Left(oArt:Matchcode,2) == "KS"
            EXIT //we have a supplier and this is a Kundenartikel, this is the current state
         ENDIF
      CASE "KU" //Vom Kunden
         cNextState := "EMPB" //next level is FAI supplier         
         IF nSupplier != 0
            EXIT //we have a supplier, this is the current state
         ENDIF
      OTHERWISE
         cNextState := "DONE" //next level is Unterschrift Kunde
   ENDSWITCH


Return cNextstate //default