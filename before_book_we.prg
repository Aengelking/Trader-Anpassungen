FUNCTION HOOK_BEFORE_BOOK_WE(hData,oBesPos,oArt)
   LOCAL oExtra 
   LOCAL cCharge
   Default(@oArt,oBesPos:oArtikel)
   oExtra := art->(ExtraData():New(oArt:Artikelnr))
   IF oArt:Gewicht == 0 .AND. hData["gewicht"] == 0 .AND. oExtra:ElektroG
      Tr_MsgBox("Bitte Gewicht angeben")
      RETURN .F.
   ENDIF
   /*cNotes := GetNotesDisplay("BES",oBesPos:Besnr,,";")
   IF ! Empty(cNotes)
      Alert(cNotes)
   ENDIF*/
   IF oExtra:CoC
      IF ! oArt:Charge //Keine Chargenverwaltung, dann mÅssen wir noch die Lieferantennummer voranstellen
         ku->(dbSetOrder(1))
         ku->(dbSeek(oBesPos:Liefma+"L"))
         cCharge := StrZero(ku->Nummer,6)      
      ELSE
         cCharge := Trim(hData:cCharge)
      ENDIF
      cCharge := cCharge+"-"+hData:cBeleg
      IF oArt:Manufactur != 6 .OR. oBesPos:oArtikel:Matchcode == oArt:Matchcode  //Nur bei Fremdwaren         
         IF Len(GetArchiveFiles( {"COC"=>Trim(cCharge)} )) == 0
            Tr_MsgBox("Werksbescheinigung (CoC) fÅr Charge "+Trim(cCharge)+" fehlt. Kein Wareneingang mîglich.")
            RETURN .F.
         ENDIF
      ENDIF
      hData:cCharge := cCharge
   ENDIF
   IF Trim(oBesPos:Liefma) == "OPTRIS" .AND. Left(oArt:Matchcode,9) == "KABEL.SAB"
      Tr_MsgBox("Bitte Lieferschein an Amos (zum einscannen) geben.")
   ENDIF
   IF Trim(oBesPos:Liefma) == "SELT"  .AND. Tr_MsgBox("Kein SELT-Logo auf Karton oder TÅten?",,{"Nein","Ja"}) != 2
      RETURN .F.
   ENDIF
   IF Trim(oBesPos:Liefma) == "TJPOWER" .OR. HB_RegexMatch("^CMI?5[7,8].*",Trim(oBesPos:Matchcode))
      
      Tr_MsgBox("Alle Logos und Hinweise auf ITW auf der Verpackung entfernen!")
      
   ENDIF
RETURN .T.