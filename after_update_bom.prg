PROC HOOK_AFTER_UPDATE_BOM(oBom,lIndexIncreased,oRec)
   LOCAL cText
   IF lIndexIncreased .AND. oBom:oArtikel:QS .AND. oBom:oArtikel:Manufactur != 6      
      cText := "Position: "+LTrim(Str(oRec:Pos,3))+Chr(13)+Chr(10)
      cText += "Felder: "+ValToPrg(oRec:FieldsUpdatedLastSave())
      SendMail({{"amos.engelking@engelking.de","Amos"}},"StÅckliste geÑndert "+Trim(oBom:oArtikel:Matchcode),cText)
   ENDIF
RETURN