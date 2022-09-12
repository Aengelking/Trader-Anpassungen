FUNCTION HOOK_BEFORE_SAVE_AUFTRAG(oAuftrag)
   LOCAL oExtra
   LOCAL aDels := {}

   oExtra := ku->(ExtraData():New(oAuftrag:Kunde:Nummer))

   IF oExtra:ReqDelad .AND. (oAuftrag:nLiefAd == 2 .OR. oAuftrag:nLiefAd == 0) //nLiefAd verwenden damit die Auftragsbezogenen Lieferadressen mit einbezogen werden, 2=Rechnungsadresse
      Tr_MsgBox( t("Lieferadresse fehlt und ist bei diesem Kunden Pflicht") )
      RETURN .F.
   ENDIF

   IF oExtra:ReqPerson .AND. Empty(oAuftrag:Person)
      Tr_MsgBox("Bitte Kontaktperson hinterlegen")
      RETURN .F.
   ENDIF

   IF oExtra:FixDelad != 0  .AND. oAuftrag:DelAd != oExtra:FixDelad
      Tr_MsgBox(t("Nur Lieferadresse Nr. % erlaubt",LTrim(Str(oExtra:FixDelad))))
      RETURN .F.
   ENDIF

   IF oAuftrag:lNew .AND. Tr_Getini(28) == 41 .AND. oAuftrag:Kunde:Team != 2
      SendMail({{"amos.engelking@engelking.de","Amos"}},"Auftrag "+LTrim(Str(auf->Abnr))+" angelegt")
   ENDIF
   
RETURN .T.