FUNCTION HOOK_BEFORE_SAVE_ANGPOS(oPos)
   LOCAL oExtra

   IF oPos == NIL //old version
      RETURN .T.
   ENDIF

   IF oPos:lNew .AND. Left(art->Matchcode,3) == "57M"
      Tr_MsgBox("Artikel aktuell nicht erh„ltlich - auf CM(I)57 ausweichen.")
      RETURN .F.
   ENDIF
   
   ku->(dbSetOrder( 1 ))  //on a new quote we are not siting on the correct record
   ku->(dbSeek( oPos:Kundma+"K" ))
   oExtra := ku->(ExtraData():New( ku->Nummer ))

   IF art->Manufactur $ oExtra:SperrManu
      Tr_MsgBox("Dieser Kunde darf keine Produkte von diesem Hersteller kaufen!")
      RETURN .F.
   ENDIF
RETURN .T.