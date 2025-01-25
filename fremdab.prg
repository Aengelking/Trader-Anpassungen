FUNCTION FremdAB(oAufPos,cTyp)

LOCAL hFremdRahmen := GetFremdCustomers()
LOCAL nOrd,nDiffQty
LOCAL oContrPos,oContract
LOCAL cText,nEnd,cInfo
LOCAL oFremdKunde
LOCAL oExtra
LOCAL nKunde


IF ! HHasKey(hFremdRahmen,oAufPos:Auftrag:Kunde:Nummer)
   oExtra := ku->(ExtraData():New(oAufPos:Auftrag:Kunde:Nummer))
   IF oExtra:SepAbruf
      hFremdRahmen[oAufPos:Auftrag:Kunde:Nummer] := {oAufPos:Auftrag:Kunde:Nummer}
   ENDIF
ENDIF

//IF HHasKey(hFremdRahmen,Trim(oAufPos:Auftrag:Kundma))
IF HHasKey(hFremdRahmen,oAufPos:Auftrag:Kunde:Nummer)
   //Nach Rahmen suchen
   IF oAufPos:lNew .AND. cTyp != "DEL"
      FOR EACH nKunde IN hFremdRahmen[oAufPos:Auftrag:Kunde:Nummer]
         oContrPos := NIL
         oFremdKunde := Adresse():New()
         oFremdKunde:Load(nKunde)
      
         nOrd := auf->(dbSetOrder( 6 ))
         auf->(dbSetFilter({|| auf->Bestat < 3 .AND. Right( Str( auf->Dterm ), 2 ) == "99" .AND. auf->VkQty >= oAufPos:VkQty},'bestat < 3 .AND. Right( Str( Dterm ), 2 ) == "99" .AND. vkqty >='+LTrim(Str(oAufPos:VkQty))))
         IF auf->(dbSeek( Pad(oFremdKunde:Kunde,8)+oAufPos:Artikel:Matchcode ))
            IF Tr_MsgBox("Aus Rahmen "+Trim(auf->Aufnr)+" (AB "+Ltrim(Str(auf->Abnr))+"/"+Ltrim(Str(auf->Itmnr))+") abrufen?",,{"Ja","Nein"}) == 1
               oContract := Auftrag():New(.F.)
               oContract:Load(auf->Abnr)
               oContrPos := oContract:Positions:GetRecord(auf->Itmnr)
            ENDIF
         ELSE
            //Alert( "Keinen Rahmen gefunden fuer "+Pad(oFremdKunde:Kunde,8)+" "+oAufPos:Artikel:Matchcode )
         ENDIF
         auf->(dbClearFilter())
         auf->(dbSetOrder( nOrd ))
         IF oContract != NIL
            EXIT
         ENDIF
      NEXT
   ELSE
      //we misues the besref field (which does not seem to be used), downside is that the max itmnr for the frame contract can be 99 (this should be enough :-))
      IF ! Empty(oAufPos:BesRef)
         oContract := Auftrag():New(.F.)
         oContract:Load( Val(Left(oAufPos:BesRef,6)) )
         oContrPos := oContract:Positions:GetRecord( Val(Right(oAufPos:BesRef,2)) )
      ENDIF
   ENDIF
   IF oContrPos != NIL
      IF cTyp == "EDIT"
         nDiffQty := oAufPos:VkQty-oAufPos:GetField("VkQty",.T.)
         IF oContrPos:GelQty+nDiffQty > oContrPos:VkQty
            Tr_Msgbox(t("Menge größer als offene Rahmenmenge"))
            RETURN .F.
         ENDIF
         cText := tx->(ReadText( oAufpos:Text ))
         cInfo := "Abgerufen aus Rahmen "+Trim(oContract:Aufnr)+" ("+Trim(oContract:Kunde:cName)+")"
         IF AT(Left(cInfo,20),MemoLine(cText,80,1)) == 1
            nEnd := At(Chr(10),cText)
            IF nEnd == 0
               nEnd := Len(cText)
            ENDIF
            cText := SubStr(cText,nEnd+1)
         ENDIF
   
         cText :=  cInfo+Chr(13)+Chr(10)+cText
         tx->(SaveText(@oAufPos:Text,cText))
         
         oAufPos:BesRef := Str(oContract:AbNr,6)+Str(oContrPos:Itmnr,2)
         oAufPos:VkPr   := oContrPos:VkPr
         oAufPos:Pe     := oContrPos:Pe

      ELSEIF cTyp == "DEL"
         nDiffQty := oAufPos:VkQty*-1
      ELSEIF cTyp == "STATUS"
         nDiffQty := oAufPos:VkQty-oAufPos:GelQty
         IF Tr_Getini(28) == 9
            //Alert(Str(oAufPos:BeStat)+Str(auf->BeStat))
         ENDIF
         IF oAufPos:BeStat > 3 
            nDiffQty *= -1
         ENDIF
      ENDIF

      NetUse("fremdab","frab")
      IF frab->(dbSeek( Str(oContrPos:Auftrag:AbNr,6)+Str(oContrPos:ItmNr,3) ))
         frab->(Rec_Lock())
      ELSEIF cTyp == "DEL" .OR. (cTyp == "STATUS" .AND. oAufPos:beStat < 3)
         RETURN NIL
      ELSE
         frab->(Add_Rec())
         frab->Abnr := oContrPos:Auftrag:AbNr
         frab->Itmnr := oContrPos:ItmNr
      ENDIF
      frab->Qty +=  nDiffQty  //only add the difference
      frab->(dbUnlock())

      oContrPos:VkQty    -= nDiffQty
      oContrPos:ContrQty -= nDiffQty //take it away from the contract quantity
      oContrPos:Save()
      
   ELSE
      oAufPOs:BesBesnr := 0
      oAufPos:BesPosnr := 0
   ENDIF
   
ENDIF

RETURN oContrPos

FUNCTION GetFremdCustomers()
   LOCAL hFremdRahmen := {=>}
   LOCAL nKunde,nKdId,aCustomers,oExtra

   NetUse("engkund","ku")
   ku->(dbSetOrder( 8 ))
   
   /*hFremdRahmen[28267] := 21832 //"BACHMANR"=>"BACHMANG"
   hFremdRahmen[21832] := 28267 //"BACHMANG"=>"BACHMANR"
   hFremdRahmen[21785] := 17981 //"PHOENIXU"=>"ROSEKRIE"

   hFremdRahmen[33720] := 31937 //"STEINHAR"=>"EGYM"
   //hFremdRahmen[21146] := 31937 //"HEFTER"=>"EGYM"
   hFremdRahmen[35245] := 31937 //"MEYMASCH"=>"EGYM"
   hFremdRahmen[14693] := 31937 //"POLYRACK"=>"EGYM"
   hFremdRahmen[37502] := 31937 //"FRTIZMEI"=>"EGYM"

   hFremdRahmen[27434] := 27434 //"TRUMPFSA"=>"TRUMPFSA", dadurch kann TRUMPFSA aus eigenen Rahmen abrufen. Bei denen ist das so eingestellt weil die st„ndig die Lieferadresse „ndern
  
   hFremdRahmen[33991] := 33603 //FREISTRI => STEIERMA
   hFremdRahmen[34270] := 14696 //Technograv => Gessmann

   hFremdRahmen[25429] := 13262 //STORZCH => STORZ
   hFremdRahmen[34353] := 13262 //STORZSCH => STORZ

   //Seidenader
   hFremdRahmen[32795] := 23697 //K™RBERM => Seidenad
   hFremdRahmen[26774] := 23697 //F.EE => Seidenad
   hFremdRahmen[35939] := 23697 //Tripspol => Seidenad
   hFremdRahmen[27538] := 23697 //TRIPS => Seidenad
   hFremdRahmen[36117] := 23697 //KOERBERU => Seidenad
   hFremdRahmen[35780] := 23697 //KOSTWEIN => Seidenad
   hFremdRahmen[32997] := 23697 //BIRCHER => Seidenad
   hFremdRahmen[37363] := 23697 //KOSTWEKR => Seidenad*/

   aCustomers := GetIdsWithExtraField("KU","FREMDABRUF")
   FOR EACH nKdId IN aCustomers
      ku->(dbSeek( Str(nKdId,6) ))
      oExtra := ku->(ExtraData():New(ku->Nummer))
      FOR EACH nKunde IN oExtra:FremdAbruf
         IF ! HHasKey(hFremdRahmen,nKunde)
            hFremdRahmen[nKunde] := {}
         ENDIF
         Aadd(hFremdRahmen[nKunde],nKdId)
      NEXT
   NEXT
   //Alert(ValToPrg(hFremdRahmen))
RETURN hFremdRahmen