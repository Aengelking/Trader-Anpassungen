
FUNCTION HOOK_ON_AUF_READY( nAbNr,lWish,lNextDue )
   LOCAL cText
   LOCAL oExtra := ku->(ExtraData():New(ku->Nummer))
   LOCAL oUsr,oAuftrag
   LOCAL nReturn
   LOCAL hMsg := {5=>"RechnungsempfÑnger fehlt",6=>"Kunde gesperrt",7=>"Kreditlimit Åberschritten",8=>"Abbruch durch einen Hook",9=>"Problem mit der UST-ID des Kunden",10=>"Nicht ausreichend Kredit vorhanden (Vorkasse)"}
   LOCAL cMsg,aTo
   LOCAL aVorkasseOrders := {67443, 67358, 67357},nOldSkonto

   MEMVAR mirenr

   IF lWish .AND. oExtra:NoWish //diese Kunden mîchten keine direkte Lieferung zum Wunschterm sondern es muss zunÑchst einer TerminÑnderung erfolgen
      
      cText := "Bei diesem Auftrag kînnten Positionen ausgeliefert werden (Wunschtermin),<br>"
      cText += "jedoch mîchte dieser Kunde informiert werden wenn wir die Lieferung vorziehen (bestÑtigter Termin).<br>"
      cText += "Bitte genau prÅfen wie dies zu erfolgen hat (Lieferantenportal/TerminÑnderung) oder ob es evtl. vom<br>"
      cText += "Kunden bestÑtigt werden muss."
      
      oAuftrag := Auftrag():New()
      oAuftrag:Load(nAbnr)

      oUsr := User():New()
      oUsr:Load(oAuftrag:Buyer)

      SendMail({{oUsr:Email,oUsr:Buyer}},"Termin bei AB "+LTrim(Str(nAbNr))+" kann vorgezogen werden.",cText)   
      RETURN .F.
   ENDIF

   /**
      Automatischer Versand
   **/
   IF ! lWish .OR. lNextDue //nur wenn die wirklich fÑllig sind (oder bald)
      NetUse("engnr","nr")
      IF ! nr->Inventur
         IF nAbnr $ aVorkasseOrders
            oAuftrag := Auftrag():New()
            oAuftrag:Load(nAbnr)
            nOldSkonto := oAuftrag:Kunde:Skonto
            oAuftrag:Kunde:Skonto := 9  //Auf Vorkasse setzen
            oAuftrag:Kunde:Save()

            SendMail({{"amos.engelking@engelking.de","Amos"}},"Vorkassenrechnung wird erstellt fÅr AB "+LTrim(Str(nAbNr)))
         ENDIF
         
         nReturn := engreab(nAbNr,.F.,,@cMsg)

         IF nAbnr $ aVorkasseOrders
            oAuftrag:Kunde:Skonto := nOldSkonto //zurÅcksetzen
            oAuftrag:Kunde:Save()
         ENDIF

         IF nReturn > 0
            IF nReturn == 12 //Auftrag wird gerade bearbeitet
               RETURN .F.  //dann warten wir bis spÑter
            ENDIF

            aTo := GetConfigEmail("SO-READY")

            cText := "Hallo,<br><br>"
            cText += 'ich wollte Auftrag <a href="trader: -F EngAuft('+Ltrim(Str(nAbNr))+')">'+LTrim(Str(nAbNr))+'</a> verschicken, aber es gab das folgende Problem:<br><br>'
            IF ! Empty(cMsg)
               cText += StrTran(cMsg,";","<br>")
            ELSEIF HHasKey(hMsg,nReturn)
               cText += hMsg[nReturn]
            ELSEIF nReturn == 13
               aTo := {{"amos.engelking@engelking.de","Amos"}}
               cText += "Die Rechnung hÑtte keine Positionen."
            ENDIF

            SendMail(aTo,"Rechnung konnte nicht erstellt werden fÅr AB "+LTrim(Str(nAbNr)),cText)
         ELSE
            //SendMail({{"amos.engelking@engelking.de","Amos"}},"Rechnung erstellt fÅr AB "+LTrim(Str(nAbNr)))  //+LTrim(Str(mirenr,6)), mirenr is not available for some reason
         ENDIF
         RETURN .F.  //keine Miteilung versenden
      ELSE
         nr->(dbCloseArea())
         RETURN .F. //keine Miteilung versenden
      ENDIF
   ENDIF

RETURN .T.