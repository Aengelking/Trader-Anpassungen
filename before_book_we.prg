FUNCTION HOOK_BEFORE_BOOK_WE(hData,oBesPos)
   LOCAL oExtra := art->(ExtraData():New(oBesPos:oArtikel:Artikelnr))
   LOCAL cCharge
   IF oBesPos:oArtikel:Gewicht == 0 .AND. hData["gewicht"] == 0 .AND. oExtra:ElektroG
      Tr_MsgBox("Bitte Gewicht angeben")
      RETURN .F.
   ENDIF
   IF oExtra:CoC
      IF ! oBesPos:oArtikel:Charge //Keine Chargenverwaltung, dann mÅssen wir noch die Lieferantennummer voranstellen
         ku->(dbSetOrder(1))
         ku->(dbSeek(oBesPos:Liefma+"L"))
         cCharge := StrZero(ku->Nummer,6)      
      ELSE
         cCharge := Trim(hData:cCharge)
      ENDIF
      cCharge := cCharge+"-"+hData:cBeleg
      IF Len(GetArchiveFiles( {"COC"=>Trim(cCharge)} )) == 0
         Tr_MsgBox("Werksbescheinigung (CoC) fÅr Charge "+Trim(cCharge)+" fehlt. Kein Wareneingang mîglich.")
         RETURN .F.
      ENDIF
      hData:cCharge := cCharge
   ENDIF
RETURN .T.