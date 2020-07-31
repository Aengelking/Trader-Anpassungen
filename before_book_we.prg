FUNCTION HOOK_BEFORE_BOOK_WE(hData,oBesPos)
   LOCAL oExtra := art->(ExtraData():New(oBesPos:oArtikel:Artikelnr))
   IF oBesPos:oArtikel:Gewicht == 0 .AND. hData["gewicht"] == 0 .AND. oExtra:ElektroG
      Tr_MsgBox("Bitte Gewicht angeben")
      RETURN .F.
   ENDIF
RETURN .T.