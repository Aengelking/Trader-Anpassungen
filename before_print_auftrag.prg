FUNCTION Before_Print_auftrag(oAuftrag,hEmailData)
   LOCAL lSend := .T.,aAvail
   LOCAL hArtikel := {=>}

   IF Trim(oAuftrag:Kundma) == "RAFIELTE"   //bei RAFI schicken wir die AB erst wenn wir uns bzgl. des Liefertermins sicher sind.   
      TxtBox("BestÑtigungen werden geprÅft...")
      oAuftrag:Positions:Each({|oPos|
         IF ! HHasKey(hArtikel,oPos:Artikel:Artikelnr)
            hArtikel[oPos:Artikel:Artikelnr] := aAvail := GetKwQty(oPos:Artikel:Artikelnr,.T.)
         ELSE
            aAvail := hArtikel[oPos:Artikel:Artikelnr]
         ENDIF
         /*IF oPos:Artikel:IsManufactured //we currently cannot check the confirmation status of manufacturing orders, but we can check if the PO against the man.order has been confirmed, only the parts required for it might not
            lSend := .F.
            RETURN .F.
         ELSE*/IF GetKwStock(oPos:Artikel:Artikelnr,oPos:DTERM,aAvail) < 0
            lSend := .F.
         ENDIF
         RETURN .T.
      })
      TxtClear()
      IF lSend
         RETURN .T.
      ELSE
         Tr_MsgBox({"Nicht alle Positionen sind vom Lieferanten bestÑtigt.","AB kann noch nicht verschickt werden."},"FEHLER")
         SendMail({{"amos.engelking@engelking.de","Amos"}},"AB "+Ltrim(str(oAuftrag:AbNr))+" fÅr RAFI",Trim(Buy(Tr_Getini(28),.T.))+" mîchte ein AB an RAFI schicken")
      ENDIF      
      RETURN .F.
   ENDIF
RETURN .T.