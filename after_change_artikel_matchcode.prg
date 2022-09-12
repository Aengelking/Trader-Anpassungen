FUNC HOOK_AFTER_CHANGE_ARTIKEL_MATCHCODE(cNewMatch,cOldMatch)
   LOCAL cText
   IF art->Bestand > 0 .AND. Tr_Getini(28) != 46
      cText := "Artikelnummer:"+LTrim(Str(art->Artikelnr))+Chr(13)+Chr(10)+"Alter Matchcode: "+cOldMatch+Chr(13)+Chr(10)+"Neuer Matchcode: "+cNewMatch+Chr(13)+Chr(10)+"Lagerorte:"

      NetUse("LAGER","LAG",.F.,0)
      lag->(dbSetOrder( 3 ))
      lag->(dbSEEK(Str(art->Artikelnr,6)))
      DO WHILE lag->Artikelnr == art->Artikelnr
         cText += Chr(13)+Chr(10)+lag->Lagerort+" "+Transform(lag->Lagermenge,Me(art->Me))
         lag->(dbSkip())
      ENDDO
      cText += Chr(13)+Chr(10)+Chr(13)+Chr(10)+"Artikel bitte neu etikettieren."            
      SendMail({{"bertram.merz@engelking.de","Bertram Merz"}},"Artikel Matchcode "+Trim(cOldMatch)+" ge„ndert",cText)
   ENDIF
RETURN .T.