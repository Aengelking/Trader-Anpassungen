FUNCTION HOOK_BEFORE_START_WE(oBesPos,oArt,cBeleg)
   LOCAL oExtra
   Default(@oArt,oBesPos:oArtikel)
   oExtra := art->(ExtraData():New(oArt:Artikelnr))
   IF oArt:Gewicht == 0 .AND. (Trim(oBesPos:Liefma) == "WHTECH" .OR. oExtra:ElektroG)
      Tr_MsgBox("Bitte Gewicht erfassen.")      
   ENDIF
   IF oExtra:CoC .AND. ! oArt:Charge .AND. (oArt:Manufactur != 6 .OR. oBesPos:oArtikel:Matchcode == oArt:Matchcode) //Keine Chargenverwaltung, nur in diesem Fall ist die Charge vorab klar
      ku->(dbSetOrder(1))
      ku->(dbSeek(oBesPos:Liefma+"L"))
      cCharge := StrZero(ku->Nummer,6)      
      cCharge := cCharge+"-"+cBeleg
      IF Len(GetArchiveFiles( {"COC"=>Trim(cCharge)} )) == 0
         Tr_MsgBox("Werksbescheinigung (CoC) fÅr Charge "+Trim(cCharge)+" fehlt. Kein Wareneingang mîglich.")
         RETURN .F.
      ENDIF      
   ENDIF
RETURN .T.