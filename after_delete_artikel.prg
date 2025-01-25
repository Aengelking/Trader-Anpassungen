#define CRLF Chr(13)+Chr(10)

FUNC HOOK_after_delete_artikel(nArtnr,cMatch,lChangeObsolete,lIsObsolete)
   LOCAL cText 

   IF lChangeObsolete //nur dann kînnen wir noch auf den Artikel zugreifen
      oArt := Artikel():New()
      oArt:Load(nArtnr)
      IF ! oArt:QS //Keine QS, dann auch keine Meldung
         RETURN .T.
      ENDIF
      cText := "Hallo, "+CRLF+CRLF
      cText += "der Artikel "+Trim(cMatch)+" wurde "
      IF lIsObsolete
         cText += "abgekÅndigt und das Erstmuster kann aussortiert werden."
      ELSE
         cText += "reaktiviert und das Erstmuster muss wieder einsortiert werden"
      ENDIF
      SendMail({{"amos.engelking@engelking.de","Amos"}},"Artikel "+Trim(cMatch)+"(#"+LTrim(Str(nArtnr))+") "+IF(lIsObsolete,"abgekÅndigt","reaktiviert"),cText)
   ELSE
      SendMail({{"amos.engelking@engelking.de","Amos"}},"Artikel "+Trim(cMatch)+"(#"+LTrim(Str(nArtnr))+") gelîscht")
   ENDIF
   
RETURN .T.