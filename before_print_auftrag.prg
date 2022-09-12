FUNCTION Before_Print_auftrag(oAuftrag,hEmailData)
   LOCAL lSend := .T.,aAvail
   LOCAL lCheck := .F.
   LOCAL hArtikel := {=>}

   IF Trim(oAuftrag:Kundma) == "RAFIELTE"  //bei RAFI schicken wir die AB erst wenn wir uns bzgl. des Liefertermins sicher sind.   
      lCheck := .T.
   ENDIF
   
   IF lCheck .OR. Empty(oAuftrag:LastPrint)
      TxtBox("BestÑtigungen werden geprÅft...")
      oAuftrag:Positions:Each({|oPos|
         IF lCheck .OR. HB_RegexMatch("^(48|59-5|49-1|49-9|57M|58M|SA(48|57|50)|JSC4|SDD|[SGCH](48|57M))",oPos:Artikel:Matchcode)
            IF ! HHasKey(hArtikel,oPos:Artikel:Artikelnr)            
               hArtikel[oPos:Artikel:Artikelnr] := aAvail := GetKwQty(oPos:Artikel:Artikelnr,.T.)  //only with confirmed PO's
            ELSE
               aAvail := hArtikel[oPos:Artikel:Artikelnr]
            ENDIF
            /*IF oPos:Artikel:IsManufactured //we currently cannot check the confirmation status of manufacturing orders, but we can check if the PO against the man.order has been confirmed, only the parts required for it might not
               lSend := .F.
               RETURN .F.
            ELSE*/IF Right(Str(oPos:DTERM,4),2) == "97" .OR. GetKwStock(oPos:Artikel:Artikelnr,oPos:DTERM,aAvail) < 0
               lSend := .F.
               RETURN .F.
            ENDIF            
         ENDIF
         RETURN .T.
      })
      TxtClear()
      IF lSend
         RETURN .T.
      ELSE
         IF lCheck
            Tr_MsgBox({"Nicht alle Positionen sind vom Lieferanten bestÑtigt.","AB kann noch nicht verschickt werden."},"FEHLER")
         ELSE
            Tr_MsgBox({"Auftrag enthÑlt Positionen von ITW EBA.","Nicht alle dieser Positionen sind von ITW bestÑtigt.","AB kann noch nicht verschickt werden."},"FEHLER")
         ENDIF
         SendMail({{"amos.engelking@engelking.de","Amos"}},"AB "+Ltrim(str(oAuftrag:AbNr)),Trim(Buy(Tr_Getini(28),.T.))+" mîchte ein AB verschicken. Es sind jedoch nicht alle Positionen bestÑtigt.")
      ENDIF      
      RETURN .F.
   /*ELSEIF oAuftrag:Abnr == 57786
      IF ! GetConfigValue("BATCHMODE")
         Tr_MsgBox("AGB's ungeklÑrt. Auftrag kann nicht bestÑtigt werden.")
      ENDIF
      RETURN .F.*/
   ENDIF
RETURN .T.