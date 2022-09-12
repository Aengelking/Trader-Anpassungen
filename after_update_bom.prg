PROC HOOK_AFTER_UPDATE_BOM(oBom,lIndexIncreased)
   IF lIndexIncreased .AND. oBom:oArtikel:QS .AND. oBom:oArtikel:Manufactur != 6
      SendMail({{"amos.engelking@engelking.de","Amos"}},"StÅckliste geÑndert "+Trim(oBom:oArtikel:Matchcode))
   ENDIF
RETURN