FUNCTION HOOK_BEFORE_SAVE_ARTIKEL(lNew,oArt)
   LOCAL oExtra := art->(ExtraData():New(oArt:Artikelnr))

   IF lNew .AND. Left(oArt:Matchcode,2) == "KS" .AND. Empty(oArt:Zeichnung) .AND. Left(oArt:Matchcode,10) != "KS14696/59"
      Tr_MsgBox('Zeichnungsnummer ist bei KS Artikeln Pflicht. "t.b.d." wurde hinterlegt.')
      oArt:Zeichnung := "t.b.d."
   ENDIF
   
   IF AT("p",oArt:Matchcode) == 1 .AND. AT(".KONF",oArt:Matchcode) != 0 .AND. ! Empty(oArt:Zeichnung) .AND. oArt:Type == "LOHN"
      IF ! GetConfigValue("BATCHMODE")
         Tr_MsgBox("Konfektionsartikel dÅrfen keine Zeichnung haben!",{"OK"})
      ENDIF
      RETURN .F.
   ENDIF
   IF oArt:Updated("Zeichnung") .AND. Empty(oArt:GetField("Zeichnung",.T.)) .AND. ! Empty(oArt:Zeichnung)
      oArt:QS := .T.
   ELSEIF lNew .AND. ".LP.BS" $ oArt:Matchcode .AND. Tr_MsgBox("WE-QS PrÅfung durchfÅhren?",,{"Ja","Nein"}) == 1
      oArt:QS := .T.
   ENDIF
   IF oExtra:Critical .AND. ! oart:Charge
      oArt:Charge := .T.
      Tr_MsgBox("Chargenverwaltung fÅr kritische Komponente aktiviert")
   ENDIF
   IF oExtra:Expires .AND. ! oArt:Charge      
      oArt:Charge := .T.      
      Tr_MsgBox("Chargenverwaltung fÅr Artikel mit Verfallsdatum aktiviert")
   ENDIF
RETURN .T.