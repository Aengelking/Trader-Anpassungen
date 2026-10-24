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

   //Hinweis, kein Blocker: ohne USt-Id-Nr. kann fuer einen deutschen Kunden spaeter
   //keine Rechnung erstellt und der Auftrag damit nicht versendet werden (siehe Hook
   //before_create_invoice). Nur bei der Neuanlage, sonst kaeme es bei jeder Bearbeitung.
   IF oAuftrag:lNew .AND. oAuftrag:Kunde:CountryIso == "DE" .AND. Empty(oAuftrag:Kunde:Vatnr)
      Tr_MsgBox({"Bei diesem deutschen Kunden ist keine USt-Id-Nr. hinterlegt.",;
                 "Der Auftrag wird angelegt, aber es kann keine Rechnung erstellt",;
                 "werden, bis die USt-Id-Nr. in der Adresse erfasst ist."},"USt-Id-Nr. fehlt")
   ENDIF

   IF oAuftrag:lNew .AND. Tr_Getini(28) == 41 .AND. oAuftrag:Kunde:Team != 2
      SendMail({{"amos.engelking@engelking.de","Amos"}},"Auftrag "+LTrim(Str(auf->Abnr))+" angelegt")
   ENDIF
   
RETURN .T.