FUNCTION HOOK_BEFORE_START_WE(oBesPos,oArt,cBeleg,hData)
   LOCAL oExtra,dDate
   Default(@oArt,oBesPos:oArtikel)
   oExtra := art->(ExtraData():New(oArt:Artikelnr))
   IF oArt:Gewicht == 0 .AND. (Trim(oBesPos:Liefma) == "WHTECH" .OR. oExtra:ElektroG)
      Tr_MsgBox("Bitte Gewicht erfassen.")      
   ENDIF
   IF oExtra:CoC .AND. ! oArt:Charge .AND. (oArt:Manufactur != 6 .OR. oBesPos:oArtikel:Matchcode == oArt:Matchcode) //Keine Chargenverwaltung, nur in diesem Fall ist die Charge vorab klar
      ku->(dbSetOrder(1))
      ku->(dbSeek(oBesPos:Liefma+"L"))
      hData:cCharge := StrZero(ku->Nummer,6)      
      hData:cCharge := Pad(hData:cCharge+"-"+cBeleg,35)
      IF Len(GetArchiveFiles( {"COC"=>Trim(hData:cCharge)} )) == 0
         Tr_MsgBox("Werksbescheinigung (CoC) fr Charge "+Trim(hData:cCharge)+" fehlt. Kein Wareneingang m”glich.")
         RETURN .F.
      ENDIF  
   ELSEIF oExtra:Expires      
      dDate := GetBox(Date()+30,"Verfallsdatum",,,,,{|dDate| dDate >= Date()+30})
      IF LastKey() == 27
         RETURN .F.  //stop WE
      ENDIF
      hData:cCharge := "[EXP:"+DToS(dDate)+"]"
   ENDIF
RETURN .T.