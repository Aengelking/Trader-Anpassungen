FUNC HOOK_after_delete_artikel(nArtnr,cMatch,lChangeObsolete,lIsObsolete)
   IF lChangeObsolete //nur dann kînnen wir noch auf den Artikel zugreifen
      oArt := Artikel():New()
      oArt:Load(nArtnr)
      IF ! oArt:QS //Keine QS, dann auch keine Meldung
         RETURN .T.
      ENDIF
   ENDIF
   SendMail({{"amos.engelking@engelking.de","Amos"}},"Artikel "+Trim(cMatch)+"(#"+LTrim(Str(nArtnr))+") "+IF(lChangeObsolete,IF(lIsObsolete,"abgekÅndigt","reaktiviert"),"gelîscht"))
   
RETURN .T.