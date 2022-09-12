FUNCTION HOOK_BEFORE_EDIT_ART(lNew,oArt)   
   /*IF lNew .AND. HB_RegexMatch("^TH(H\.625|B\.381)\..3.*",oArt:Matchcode)
      //nach unserer Erkenntnis k”nnen alle 3 poligen Techno 381 verdreht werden, sodass PE mit L verbunden sein kann
      Tr_MsgBox("Dieses Produkt kann nicht angelegt werden (HOOK_BEFORE_EDIT_ART)")
      RETURN .F.
   ENDIF*/
RETURN .T.