PARAMETERS nWaNr,nArtNr
   NetUse("engkund","ku")

   wer->(dbSetOrder(1))
   wer->(dbSeek( str(nWaNr,6) ))

   ku->(dbSeek( wer->Liefma+"L" ))
   oExtra := ku->(ExtraData():New(ku->Nummer))

   IF oExtra:WaDay != 0 .AND. WADue() .AND. WAStatus() .AND. (Dow(Date()) != oExtra:WaDay .OR. Time() > "15:00:00")
      IF Tr_MsgBox("Versandtag WHTECH ist "+CDow(Date()+oExtra:WaDay-Dow(Date()))+" bis 15:00",,{"trotzdem richten","abbrechen"}) != 1
         RETURN .F.
      ENDIF
   ENDIF


   art->(dbSetOrder( 2 ))
   art->(dbSeek( Str(nArtnr,6) ))
   IF wer->Liefma $ "WETEC HECK" .AND. Empty(art->Zeichnung)
      TR_MsgBox("Keine Arbeitsanweisung vorhanden. Auftrag kann nicht begonnen werden")
      RETURN .F.
   ENDIF
RETURN .T.