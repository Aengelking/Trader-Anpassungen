FUNCTION HOOK_AFTER_CERATE_VARIANT(oArtikel)
   LOCAL cArtLief
   LOCAL cText
   LOCAL oUsr := SystemUser()

   NetUse("buyer","buy")
   
   cText := "Hallo,<br><br>folgender Varianten Artikel wurde von "+Trim(oUsr:Buyer)+" angelegt:<br><br>"
   cText += 'Matchcode:  <a href="trader: -F BrowseArtikel('+"'"+oArtikel:Matchcode+"'"+")"+oArtikel:Matchcode+"</a><br>"
   cText += "Artikelnr.: "+LTrim(Str(oArtikel:Artikelnr))
   
   IF Left(oArtikel:Matchcode,2) $ "CM CI"
      NetUse("artlief","ali")
      cArtLief := OnpowPartno()
      ali->(Add_Rec(0))
      ali->Kunde := "ONPOW"
      ali->Matchcode := oArtikel:Matchcode
      ali->Artikelnr := oArtikel:Artikelnr
      ali->Artlief   := cArtlief
      ali->(dbUnLock())

      MBaseRun(Trim(Tr_getini(1))+"\run\onpow_prices",{.T.}) //first parameter needs to be .T. to only set prices on this part

      cText += "<br>Hersteller-Artikel: "+cArtlief

   ENDIF
   
   Sendmail({{"samuel.engelking@engelking.de","Samuel"},{"amos.engelking@engelking.de","Amos","CC"}},"Variant wurde angelegt "+Trim(oArtikel:Matchcode),,,,,.T.)
RETURN NIL

#include 'X:\run\onpow_part_no.prg'