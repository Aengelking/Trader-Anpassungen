FUNCTION PrintVDE(cProdMatch)
   LOCAL oKuExtra := ku->(ExtraData():New(ku->Nummer))
   LOCAL cRet := ""
   LOCAL oArt
   MEMVAR trVer
   IF oKuExtra:VpeOnPO .AND. bes->BeQty > 0
      oArt := Artikel():New()
      If ValType(cProdMatch)=="C" .AND. !Empty(cProdMatch) .AND. trVer > "7.486"
         oArt:LoadMatchcode(cProdMatch)
      ENDIF              
      cRet := "Package quantity: "
      IF oArt:VPE != 0
         cRet += LTrim(Transform(oArt:Vpe,oArt:cPicture))
      ELSE
         cRet += "\2\Too be agreed - please contact us.\4\"
      ENDIF
   ENDIF
RETURN cRet