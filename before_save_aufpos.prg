FUNCTION HOOK_BEFORE_SAVE_AUFPOS(oAufPos)

LOCAL nNewQty,nValue,lFremdAB
LOCAL nMinStock
LOCAL hFields := {=>},hField
LOCAL aEnv
LOCAL getlist := {}
LOCAL oExtra
LOCAL oArtExtra
LOCAL cBez,cText,nX

NetUse("engkund","ku")
oExtra := ku->(ExtraData():New( oAufPos:Auftrag:Kunde:Nummer ))
oArtExtra := art->(ExtraData():New(oAufpos:Artikelnr))

IF ValType(oAufPos) != "O"  //old version of trader
   RETURN .T.
ENDIF

IF oExtra:SepAbruf .AND. oAufPos:ContractPosition != NIL
   Tr_MsgBox("Keine Abrufe mîglich. Bitte separaten Auftrag anlegen")
   RETURN .F.
ENDIF

//Check for Folgeartikel on Engelking's Switch products
IF oAufPos:Artikel:Manufactur == 6 .AND. Left(oAufPos:Artikel:Gruppe,2) == "SW" .AND. ! oArtExtra:NoFolge  

   NetUse("folgeart","fol")
   IF ! fol->(dbSeek(STR(oAufPos:Artikel:Artikelnr,6)))
      IF Tr_MsgBox("Dieser Schalter hat keine Folgeartikel. Bitte ergÑnzen lassen.",,{"Ok","Artikel trotzdem einfÅgen"}) != 2
         RETURN .F.
      ENDIF
   ENDIF
ENDIF

//Check for stock on /BULK parts
IF Trim(oAufPos:Matchcode) $ "SA3148,SA3149,SA3179,SA3180,SA3347,SA3348,SA3349,SA3350"  .AND. oAufPos:Wterm < oAufPos:Dterm
   art->(dbSetOrder( 1 ))
   IF art->(dbSeek( Trim(oAufPos:Matchcode)+"/BULK" )) .AND. art->Bestand >= oAufPos:VkQty*10 .AND. GetAvailKw(art->Artikelnr,oAufPos:VkQty*10) <= oAufPos:WTerm
      IF Tr_MsgBox({t("Dieser Artikel ist in der Groﬂpackung verf¸gbar"),"Soll die Position umgewandelt werden?"},,{"Ja","Nein"}) == 1
         oAufPos:Matchcode := Pad(Trim(oAufPos:Matchcode)+"/BULK",25)
         oAufPos:VkQty *= 10
         oAufPos:VkPr *= 10
         RETURN .F.
      ENDIF
   ENDIF
ENDIF

//Kundenbezeichnung Pflicht
IF oExtra:ReqKuArt .AND. ! Trim(oAufPos:Artikel:Matchcode) $ {"@","TEXT"}  //Trim(oAufPos:Auftrag:Kundma)+"|" $ "GESSMANN|BACHMANG|BACHMANN|BACHMANR|RSCOMPON|KWAUTOMO|RUAGTHUN|BIZERBA|"
   aku->( dbSetOrder( 1 ) )
   IF ! aku->( dbSeek( oAufPos:Auftrag:KundMa + Str( oAufPos:Artikelnr, 6 ) ) ) .OR. Empty(aku->Artlief)
      cBez := GetBox(Space(35),"Bitte Kundenbezeichnung hinterlegen")
      IF ! Empty(cBez) .AND. LastKey() != 27
         IF ! aku->( dbSeek( oAufPos:Auftrag:KundMa + Str( oAufPos:Artikelnr, 6 ) ) )
            aku->(Add_Rec())
         ELSE
            aku->(Rec_Lock())
         ENDIF
         aku->Kunde     := oAufPos:Auftrag:KundMa
         aku->Artikelnr := oAufPos:Artikelnr
         aku->Matchcode := oAufPos:Artikel:Matchcode
         aku->Artlief   := cBez
         aku->(dbUnLock())
      ELSE
         RETURN .F.
      ENDIF
   ENDIF
ENDIF

//Bestellnummern pr¸fen
/*IF (Trim(oAufPos:Auftrag:Kundma)+"|" $ HB_AnsiToOem("L÷FFELHA|RSCOMPON|RUAGTHUN|") .AND. ! HB_RegexMatch("^4[0-9]{9}$",Trim(oAufPos:Aufnr))) .OR.; //Bestellnummer im SAP Format Pflicht
   (Trim(oAufPos:Auftrag:Kundma)+"|" $ HB_AnsiToOem("LEONI|BIZERBA|") .AND. ! HB_RegexMatch("^[0-9]{3}\/4[0-9]{7}$",Trim(oAufPos:Aufnr))) .OR.;//SAP mit Eink‰uferkennung
   (Trim(oAufPos:Auftrag:Kundma)+"|" $ HB_AnsiToOem("KWAUTOMO|") .AND. ! HB_RegexMatch("^[0-9]{6}$",Trim(oAufPos:Aufnr))) //6-Ziffern
  */
IF ( Trim(oExtra:AufnrForm) == "SAPEK" .AND. ! HB_RegexMatch("^[0-9]{3}\/4[0-9]{7}$",Trim(oAufPos:Aufnr)) ) .OR.;
   ( Trim(oExtra:AufnrForm) == "SAP" .AND.  ! HB_RegexMatch("^4[0-9]{9}$",Trim(oAufPos:Aufnr)))  .OR.;
   ( Trim(oExtra:AufnrForm) == "6ZIFF" .AND. ! HB_RegexMatch("^[0-9]{6}$",Trim(oAufPos:Aufnr))) .OR.;
   ( Trim(oExtra:AufnrForm) == "2-6-3" .AND. ! HB_RegexMatch("^([A-Z]{2}-)?[0-9]{6}-[A-Z0-9]{3}$",Trim(oAufPos:Aufnr))) .OR.;
   ( Trim(oExtra:AufnrForm) == "B8ZEK" .AND. ! HB_RegexMatch("^(W[0-9]{7})|(K[0-9]{8})\/[A-Z]{4}$",Trim(oAufPos:Aufnr)))
   
      Tr_MsgBox("Auftragsnummer nicht im richtigen Format")
      RETURN .F.
ELSEIF Trim(oExtra:AufnrForm) == "EMAIL"  .AND. ! HB_RegexMatch("^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$",Upper(Trim(oAufPos:Aufnr))) // Trim(oAufPos:Auftrag:Kundma)+"|" $ HB_AnsiToOem("RPS|")
      Tr_MsgBox("Bitte Email-Adresse des Anforderers als Auftragsnummer hinterlegen")
      RETURN .F.
ENDIF

//Zus‰tzliche Felder
IF At("TEXT",oAufPos:Artikel:Matchcode) != 1


   IF oExtra:AufPos .AND. ! oAufPos:IsRahmen // Trim(oAufPos:Auftrag:Kundma)+"|" $ "KWAUTOMO|RUAGTHUN|"
      hFields["POS"] := {"TEXT"=>"Position","TYPE"=>"N","VALUE"=>0,"PICTURE"=>"999","LINE"=>0}
   ENDIF
   IF oExtra:AufBestimm .AND. ! oAufPos:IsRahmen //Trim(oAufPos:Auftrag:Kundma) == "GESSMANN"
      //hFields["POS"] := {"TEXT"=>"Position","TYPE"=>"N","VALUE"=>0,"PICTURE"=>"999","LINE"=>0}
      hFields["FOR"] := {"TEXT"=>t("Bestimmt f¸r"),"TYPE"=>"C","VALUE"=>Space(80-15),"PICTURE"=>"@S20","LINE"=>0}
   ENDIF
   IF  oExtra:AufLos .AND. oAufPos:IsRahmen // Trim(oAufPos:Auftrag:Kundma) == "BACHMANG"
      hFields["LOS"] := {"TEXT"=>t("Losgrˆﬂe"),"TYPE"=>"N","VALUE"=>0,"PICTURE"=>Me(art->me),"LINE"=>0}
   ENDIF

   IF Len(hFields) > 0
      cText := tx->(ReadText( oAufpos:Text ))
   
      FOR nX := 1 TO MlCount(cText)
         cLine := MemoLine(cText,80,nX)
         FOR EACH hField IN hFields
            IF (nY := AT(hField:Text+":",cLine)) != 0
               hField:Line := nX
               IF hField:Type == "N"
                  hField:Value := Val(AllTrim(SubStr(cLine,nY+Len(hField:Text)+1)))
               ELSEIF hField:Type == "C"
                  hField:Value := Pad(Ltrim(SubStr(cLine,14)),Len(hField:Value))
               ENDIF
               EXIT
            ENDIF
         NEXT
      NEXT

      aEnv := SaveEnv()
      SetColor(c_five)
      @ 10,10 CLEAR TO 10+Len(hFields)+1,MaxCol()-10
      @ 10,10 TO 10+Len(hFields)+1,MaxCol()-10
      @ 10,11 SAY "[ Weitere Details ]"
      FOR EACH hField IN hFields
         @ 10+hField:__eNumIndex(),11 SAY hField:Text GET hField:Value PICTURE hField:Picture
      NEXT
      READ

      RestEnv(aEnv,.T.)

      nStart := 1
      FOR EACH hField IN hFields
         IF hField:Line == 0
            nStart--
            hField:Line := nStart
         ENDIF
      NEXT
      
      nLen := MlCount(cText)
      cOldText := cText
      cText := ""

      FOR nX := nStart TO nLen
         IF nX > nStart
            cText += Chr(13)+Chr(10)
         ENDIF
         nF := HB_HScan(hFields,{|x,y| y:Line == nX })
         IF nF != 0
            hField := HGetValueAt(hFields,nF)
            cText += hField:Text+": "
            IF hField:Type == "N"
               cText += LTrim(Transform(hField:Value,hField:Picture))
            ELSEIF hField:Type == "C"
               cText += hField:Value
            ENDIF
         ELSE
            cText += MemoLine(cOldText,80,nX)
         ENDIF
      NEXT
      
      tx->(SaveText(@oAufPos:Text,cText))
   ENDIF

   /*IF Trim(oAufPos:Auftrag:Kundma) == "GESSMANN" .AND. ! oAufPos:IsRahmen

   nPosLine := 0
   nForLine := 0

   nPos := 0
   cFor := Space(80-15)

   FOR nX := 1 TO MlCount(cText)
      cLine := MemoLine(cText,80,nX)
      IF (nY := AT("Position:",cLine)) != 0
         nPosLine := nX
         nPos := Val(AllTrim(SubStr(cLine,nY+10)))
      ELSEIF AT(t("Bestimmt f¸r:"),cLine) != 0
         nForLine := nX
         cFor := Pad(Ltrim(SubStr(cLine,14)),80-15)
      ENDIF
   NEXT


   DO WHILE Empty(nPos)
      nPos := GetBox(nPos,"Bestellposition","999")
   ENDDO
   DO WHILE Empty(cFor)
      cFor := GetBox(cFor,t("Bestimmt f¸r"),"@S20")
   ENDDO

   nStart := 1
   IF nForLine == 0
      nStart--
      nForLine := nStart
   ENDIF
   IF nPosLine == 0
      nStart--
      nPosLine := nStart
   ENDIF

   nLen := MlCount(cText)
   cOldText := cText
   cText := ""

   FOR nX := nStart TO nLen

      IF nX > nStart
         cText += Chr(13)+Chr(10)
      ENDIF
      IF nX == nPosLine
         cText += "Position: "+LTrim(Str(nPos))
      ELSEIF nX == nForLine
         cText += t("Bestimmt f¸r:")+" "+cFor
      ELSE
         cText += MemoLine(cOldText,80,nX)
      ENDIF

   NEXT    */



ENDIF

//Abruf aus fremden Rahmen
IF oAufPos:ContrPos == 0 //we can only call off from another order if this is not a call off itself
   oContrPos := MBaseRun(Trim(Tr_Getini(1))+"\run\fremdab",{oAufPos,"EDIT"})
   lFremdAB := oContrPos != NIL
   IF ! lFremdAB
      oContrPos := oAufPos:ContractPosition
   ENDIF
ELSE
   oContrPos := NIL
ENDIF

//Losgrˆﬂe bei bestimmten Kunden pr¸fen
IF oContrPos != NIL .AND. oExtra:AufLos //"|"+Trim(oAufPos:Auftrag:Kundma)+"|" $ "|BACHMANG|BACHMANR|"
   cText := tx->(ReadText(oContrPos:Text))
   IF (nPos := AT(t("Losgrˆﬂe:"),cText)) != 0
      nMinStock := Val(Alltrim(SubStr(cText,nPos+9,IF(At(Chr(13),cText)==0,Len(cText),At(Chr(13),cText)))))
   ELSE
      nMinStock := oContrPos:MeldStock
   ENDIF
   nMinStock := Min(nMinStock,oContrPos:VkQty)

   IF nMinStock != 0 .AND. oAufPos:VkQty % nMinStock != 0

      nNewQty := Max(Round(oAufPos:VkQty/nMinStock,0),1)*nMinStock
      IF ! oAufPos:lNew
         nOldValue := (oAufPos:GetField("VkQty",.T.)-oAufPos:GetField("GelQty",.T.)) * oAufPos:GetField("vkpr",.T.) / oAufPos:GetField("pe",.T.) * ( 100 -oAufPos:GetField("Rabatt",.T.) ) / 100 * Currate(oAufPos:Money,"V")
      ELSE
         nOldValue := 0
      ENDIF
      nValue := (nNewqty-oAufPos:GelQty) * oAufPos:VkPr / oAufPos:Pe * ( 100 -oAufPos:Rabatt ) / 100 - nOldValue * Currate(oAufPos:Auftrag:Money,"V")
      Alert(t("Menge ("+LTrim(Transform(oAufPos:VkQty,Me(oAufPos:Artikel:Me)))+") stimmt nicht mit Losgrˆﬂe ("+LTrim(Transform(nMinStock,Me(oAufPos:Artikel:Me)))+") ¸berein und wurde entsprechend angepasst ("+LTrim(Transform(nNewQty,Me(oAufPos:Artikel:Me)))+")"))
      IF ! AufCheckCreditLimit(oAufPos,(nNewQty-oAufPos:GelQty),If(oAufPos:Auftrag:Kunde:JustinTime,oAufPos:BDatum,CalWd(oAufPos:Dterm)),nValue)
         IF lFremdAB
            IF oAufPos:lNew
               MBaseRun(Trim(Tr_Getini(1))+"\run\fremdab",{oAufPos,"DEL"})
            ELSE
               //reset call off
               nNewQty := oAufPos:VkQty
               oAufPos:VkQty := oAufPos:GetField("VkQty",.T.)
               MBaseRun(Trim(Tr_Getini(1))+"\run\fremdab",{oAufPos,"EDIT"})
            ENDIF
         ENDIF
         RETURN .F.
      ELSE
         IF  lFremdAB
            IF oAufPos:lNew
               MBaseRun(Trim(Tr_Getini(1))+"\run\fremdab",{oAufPos,"DEL"}) //delete old entry if there is one
            ELSE
               oAufPos:Save() //we have to save to the db to make fremdab work a second time
            ENDIF
            oAufPos:VkQty := nNewQty
            MBaseRun(Trim(Tr_Getini(1))+"\run\fremdab",{oAufPos,"EDIT"})
         ELSE
            oAufPos:VkQty := nNewQty
         ENDIF
      ENDIF
      //,GetMeDecimals( oAufPos:Artikel:Me ))
   ENDIF
ENDIF