#define CRLF Chr(13)+Chr(10)

FUNCTION HOOK_ON_AUF_NOT_ORDERED(nAbnr,aOrderList,nReminderCount)
   LOCAL cMsg,nX,aKwStock   
   LOCAL cSupplier,cWaldMatch := Pad("WALDOM",8)
   LOCAL hFreigabe
   LOCAL nStdLZ := GetConfigValue("DEFAULTS_SUPPLIER_DELTIME")
   LOCAL nIncome,nEkPr,nPe,nVKPr,nMargin
   LOCAL lIsRahmen := .F.
   LOCAL nContract := 0
   LOCAL nContrPos := 0
   LOCAL nSupArt   
   LOCAL oExtra,lUnderMoq := .F.
   //LOCAL cPrevMatch := ""
   LOCAL lOrdered := .F.,lManu := .F.,lFrei := .F.,lFreiWait := .F.,lVorzug := .F.,lToBeOrdered := .F.,lToBeChecked := .F.
   LOCAL lMOQ := .F.
   LOCAL cMsgManu,cComment,cMsgLine
   LOCAL cMsgFrei,cNotes   
   LOCAL cCheapestSupplier
   LOCAL nRec,nInd
   LOCAL lSampleFound,nSampleWeek,lSampleShipped,dSampleDate
   LOCAL aTo

   MEMVAR mcNoBesPos
   
   NetUse("artlief","ali")
   NetUse("manufact","man")
   NetUse("engkund","ku")
   NetUse("ppf","ppf")
   NetUse("folgeart","fol")
   NetUse("parts","part")
   NetUse("liefstock","lsto")
   NetUse("notes","nts")

   ali->(dbSetOrder( 6 ))   

   cMsg := Pad("Artikel",25+8)+" "+Pad("StÅckzahl",17)+" "+Pad("Termin",11)+" "+"Kommentare"+Chr(13)+Chr(10)
   cMsgManu := cMsg
   cMsgFrei := cMsg

   FOR nX := 1 TO Len(aOrderList)
      art->(dbSetOrder( 2 ))
      art->(dbSeek(Str(aOrderList[nX]["ARTNR"],6)))
      auf->(dbSetOrder( 1 ))
      IF ! auf->(dbSeek( Str(nAbnr,6)+Str(aOrderList[nX]["POS"],3) ))      
         cMsg += "Auftrag nicht gefunden?!"
      ENDIF
      
      //cMsgLine := IF(art->Matchcode!=cPrevMatch,art->Matchcode,Space(25))+" #"+Pad(LTrim(Str(aOrderList[nX]["ARTNR"],6)),6)+" "+Pad(Transform(aOrderList[nX]["QTY"],Me(art->Me))+" "+art->Me,17)+" "+Pad(NiceWeek(aOrderList[nX]["WEEK"]),11)+" "
      cMsgLine := art->Matchcode+" #"+Pad(LTrim(Str(aOrderList[nX]["ARTNR"],6)),6)+" "+Pad(Transform(aOrderList[nX]["QTY"],Me(art->Me))+" "+art->Me,17)+" "+Pad(NiceWeek(aOrderList[nX]["WEEK"]),11)+" "
      cMsg += cMsgLine
      cPrevMatch := art->Matchcode
      IF art->Sperren
         cMsg += "Artikel gesperrt"
         lToBeChecked := .T.
      ELSEIF art->Inventur
         cMsg += "Wegen Inventur gesperrt"
         lToBeChecked := .T.
      ELSEIF Right(Str(aOrderList[nX]["WEEK"],4),2) == "99" //Rahmen
         cMsg += "Meldebestand"         
         IF art->Bezug >= 5 .AND. ! part->(dbSeek( Str(art->Artikelnr,6)+Str(-1,4) )) //StÅckliste ohne Lohnposition - wird intern gefertigt und Åber Frepple
            cMsg += " - Fertigung muss noch geplant werden"
            cMsgManu += cMsgLine
            cMsgManu += CRLF
            lManu := .T. //Meldung an Fertigungplanung
         ELSE
            lToBeOrdered := .T.
         ENDIF
      ELSEIF HHasKey(aOrderList[nX],"MOVEWEEK") .AND. aOrderList[nX]["MOVEWEEK"] != 0
         cMsg += "Liefervorzug prÅfen - verfÅgbar in KW "+NiceWeek(aOrderList[nX]["MOVEWEEK"])
         lVorzug := .T.
         IF art->Bezug >= 5 .AND. ! part->(dbSeek( Str(art->Artikelnr,6)+Str(-1,4) ))
            cMsgManu += cMsgLine + " Produktionsvorzug prÅfen - verfÅgbar in KW "+NiceWeek(aOrderList[nX]["MOVEWEEK"])
            lManu := .T. //Meldung an Fertigungplanung
         ENDIF         
      ELSEIF art->Mindest > 0 .AND. art->Mindest >= aOrderList[nX]["QTY"]/2  //Artikel hat Meldebestand und dieser ist mindestens 50% der benîtigten Menge
         cMsg += "Lagerartikel - BestÑnde prÅfen"
         lToBeChecked := .T.
      ELSEIF art->Bezug >= 5 .AND. ! part->(dbSeek( Str(art->Artikelnr,6)+Str(-1,4) )) //StÅckliste ohne Lohnposition - wird intern gefertigt und Åber Frepple
         cMsg += "Fertigung muss noch geplant werden"
         cMsgManu += cMsgLine
         cMsgManu += CRLF
         lManu := .T. //Meldung an Fertigungplanung
      ELSE         
         aKwStock := GetKwQty(art->Artikelnr,.F.)
         cSupplier := ""
         IF art->Bezug >= 5
            nSupArt := part->Partart
         ELSE
            nSupArt := aOrderList[nX]["ARTNR"]
         ENDIF

         IF Atail(aKWStock)[6] >= 0 .OR. __GetTotalQtyForPart(art->Artikelnr,aOrderList) > Atail(aKWStock)[6]*-1
            cMsg += "wird nicht bestellt - Termine prÅfen"
            lToBeChecked := .T.
         ELSEIF ali->(dbSeek( Str(nSupArt,6) ))
            ali->(dbSkip())
            IF ali->Artikelnr == nSupArt .AND. ali->Priority != 9 //we have a second supplier     
               ku->(dbSetOrder( 8 ))                         
               IF man->(dbSeek( Str(art->Manufactur,5) )) .AND. man->Principal .AND. ku->(dbSeek( Str(man->Address,6) ))
                  IF art->manufactur $ {1,10}
                     GetLowestBuyPrice(nSupArt,aOrderList[nX]["QTY"],Date(),@cCheapestSupplier)                     
                  ELSE
                     cCheapestSupplier := ""
                  ENDIF
                  //oExtra := ku->(ExtraData():New(ku->Nummer))
                  ali->(dbSetOrder( 1 ))
                  IF (! art->manufactur $ {1,10} .OR. cCheapestSupplier != cWaldMatch) .AND. ali->(dbSeek( ku->Kunde+Str(nSupArt,6) )) .AND. ali->Priority <= 8 .AND. (Right(Str(aOrderList[nX]["WEEK"],4),2)=="97" .OR. AddWeeks(Cweek(Date()),IF(ali->LZ==0,nStdLZ,ali->LZ)) <= aOrderList[nX]["WEEK"]) .AND. ali->Min <= aOrderList[nX]["QTY"] //we can purchase directly                  
                     //should we add oExtra:RecvTime?                                          
                     cSupplier := ku->Kunde
                  ELSEIF art->manufactur $ {1,10} .AND. ali->(dbSeek( cWaldMatch+Str(art->Artikelnr,6) )) .AND. ali->Priority <= 8 .AND. ali->Min <= aOrderList[nX]["QTY"] //in case of Bulgin we can purchase from Waldom too
                     //hier werden wir die Lieferzeit wahrscheinlich nicht prÅfen, sondern der Kundenauftrag mÅsste dann angepasst werden
                     //LAGERBESTAND bei Waldom prÅfen, nicht alle Artikel sind korrekt z.B. #MT
                     cSupplier := cWaldMatch
                  ENDIF
                  ali->(dbSetOrder( 6 ))
               ENDIF
               IF Empty(cSupplier)
                  cMsg += "wird nicht bestellt - Lieferant nicht eindeutig"
                  lToBeChecked := .T.
               ENDIF
            ELSE               
               ali->(dbSkip(-1))
               
               cSupplier := ali->Kunde               
            ENDIF

            /** FREIGABE PRöFEN **/
            IF ! Empty(cSupplier) .AND. ! Empty(art->Zeichnung)
               ku->(dbSetOrder( 1 ))
               ku->(dbSeek( cSupplier+"L" ))
               hFreigabe := art->(GetFreigabeBesState(ku->Nummer))
               IF ! hFreigabe:lBes
                  cComment := "Keine Freigabe fÅr "+Trim(cSupplier)+" vorhanden - Kein Bestellung mîglich!"
                  cMsgFrei += cMsgLine+cComment+CRLF
                  cMsg += cComment
                  cSupplier := ""
                  lFrei := .T.
               ELSEIF hFreigabe:nMaxQty != 0  //eingeschrÑnkte Menge
                  bes->(dbSetOrder(8))
                  nIncome := bes->(LETO_SUM("beqty-gelqty",'released .AND. (bestat <= 2 .OR. (bestat >= 6 .AND. bestat <= 8))',cSupplier+art->Matchcode,cSupplier+art->Matchcode))
      
                  IF hFreigabe:nMaxQty < aOrderList[nX]["QTY"]+nIncome
                     NetUSe("englsre","re")
                     re->(dbSetOrder(10))
   
                     nRec := auf->(Recno())
                     nInd := auf->(IndexOrd())
                     auf->(dbSetOrder( 13 ))
                     auf->(dbSeek( Str(art->Artikelnr,6) ))

                     lSampleFound := .F.
                     lSampleShipped := .F.
                     nSampleWeek := CWeek(Date())
                     DO WHILE ! lSampleFound .AND. auf->Artikelnr == art->Artikelnr .AND. (auf->Bestat <= 3 .OR. (auf->Bestat >= 4 .AND. auf->Bestat <= 6))
                        IF auf->VkQty <= hFreigabe:nMaxQty
                           lSampleFound := (auf->Bestat != 3 .AND. auf->Bestat != 6) .OR. auf->GelQty > 0
                           lSampleShipped := auf->GelQty > 0
                           nSampleWeek := auf->DTerm
                           IF lSampleShipped
                              re->(dbSetFilter( {|| re->AoQty != 0 },"aoqty != 0"))
                              IF re->(dbSeek( Str(auf->Abnr,6)+Str(auf->itmnr,3) ))         
                                 dSampleDate := re->Rechdat
                              ELSE
                                 dSampleDate := Date()
                              ENDIF
                              re->(dbClearFilter())
                           ENDIF
                        ENDIF         
                        auf->(dbSkip())
                     ENDDO
                     auf->(dbGoto(nRec))
                     auf->(dbSetOrder(nInd))

                     cComment := "Maximale Menge von "+LTrim(Transform(hFreigabe:nMaxQty,Me(art->Me)))+" "+art->Me+" bei "+Trim(cSupplier)+" Åberschritten - Nur Materialfreigabe mîglich!"
                     cMsgFrei += cMsgLine
                     IF lSampleFound
                        IF lSampleShipped
                           cMsgFrei += "Muster wurde am "+DToC(dSampleDate)+" geliefert. "
                        ELSE
                           cMsgFrei += "Muster wurde noch nicht geliefert (geplant fÅr KW "+NiceWeek(nSampleWeek)+"). "
                        ENDIF
                     ELSE
                        cMsgFrei += "Kein Muster in diesem Auftrag gefunden. "
                     ENDIF
                     cMsgFrei += cComment+CRLF
                     cMsg += cComment 
                     cSupplier := ""
                     lFrei := .T.
                     IF ! lSampleFound .OR. ;
                        (! lSampleShipped .AND. nSampleWeek < CWeek(Date())) .OR. ;
                        (lSampleShipped .AND. dSampleDate+7 <= Date()) //Muster wurde nicht versendet oder wurde vor mehr als 7 Tagen versendet
                        //this will send a reminder
                     ELSE
                        lFreiWait := .T.
                     ENDIF
                  ELSE
                     cMsg += "Freigabe ok - "
                     lToBeOrdered := .T.
                  ENDIF
               ELSE
                  lToBeOrdered := .T.
                  cMsg += "Freigabe ok - "
               ENDIF
            ENDIF

            /** Preis ermitteln **/
            IF ! Empty(cSupplier)
               lUnderMoq := .F.
               nEKPr := 0

               //check for blanket order
               bes->(dbSetOrder( 8 ))
               IF bes->(dbSeek(cSupplier+art->Matchcode))
                  lIsRahmen := .F.
                  DO While bes->Liefma == cSupplier .AND. bes->Matchcode == art->Matchcode .AND. bes->Bestat < 3 .AND. ! bes->(Eof())
                     If bes->Rahmen .AND. bes->BeQty != 0 .AND. aOrderList[nX]["QTY"] <= bes->BeQty
                        lIsRahmen := .T.
                        EXIT
                     Endif
                     bes->(dbSkip())
                  ENDDO  
                  IF lIsRahmen
                     nContract    := bes->Besnr
                     nContrPos    := bes->Posnr                     
                     nEkPr        := bes->EkPr
                     nPe          := bes->Pe
                  ENDIF                
               ENDIF
               IF ! lIsRahmen
                  GetBuyPrice(cSupplier,nSupArt,aOrderList[nX]["QTY"],@nEkPr,@nPe,.T.)
               ENDIF
               ku->(dbSetOrder( 1 ))
               ku->(dbSeek( cSupplier+"L"))
               oExtra := ku->(ExtraData():New(ku->Nummer))

               IF oExtra:MoqSurchar > 0 //Mindermengenzzuschlag prÅfen                  
                  IF nEkPr == 0 .AND. oExtra:MoqSurchar > 0
                     lMOQ := .T.
                     GetBuyPrice(cSupplier,nSupArt,ali->MIN,@nEkPr,@nPe,.T.) //get the price of the MOQ quantity
                     IF nEkPr != 0 .AND. (ali->Min-aOrderList[nX]["QTY"])*nEkPr/nPE <= oExtra:MoqSurchar //is it cheaper or just as expensive to order the MOQ then we do this
                        aOrderList[nX]["QTY"] := ali->Min
                     ELSE
                        lUnderMoq := .T.
                        GetBuyPrice(cSupplier,nSupArt,-1,@nEkPr,@nPe,.T.) //find the first price break             
                     ENDIF
                  ENDIF
                  IF ! lUnderMoq .AND. oExtra:MOQNOVPE .AND. ali->VPE > 0 .AND. aOrderList[nX]["QTY"] % ali->VPE != 0
                     lMOQ := .T.
                     IF nEKPR != 0 .AND. aOrderList[nX]["QTY"] % ali->VPE * nEkPr/nPE <= oExtra:MoqSurchar //IF it is just as expensive to buy the PU then we increase the quantity
                        aOrderList[nX]["QTY"] += aOrderList[nX]["QTY"] % ali->VPE
                     ELSE
                        lUnderMOQ := .T.
                     ENDIF
                  ENDIF
               ENDIF

               IF nEkPr == 0                  
                  cMsg += "EK fehlt bei "+Trim(cSupplier)
                  cSupplier := ""
                  lToBeChecked := .T.
               ENDIF

               //Margin prÅfen
               nVKPr := (auf->VkPr/auf->Pe)*(1-auf->Rabatt/100)
               IF nVKPr == 0
                  nMargin := -999
               ELSE
                  nMargin := (nVkPr-(nEkPr+IF(lUnderMOQ,oExtra:MoqSurchar/aOrderList[nX]["QTY"],0))*currate(ku->Money,"E"))/nVkPr
               ENDIF
               IF nVKPr > 0 .AND. nMargin < 0.15
                  cMsg += "Margin ("+LTrim(Str(nMargin,12,2))+"%) zu klein bei "+Trim(cSupplier)+" - EK ("+Ltrim(Str(nEkPr+IF(lUnderMOQ,oExtra:MoqSurchar/aOrderList[nX]["QTY"],0)))+" EUR) und VK ("+Ltrim(Str(nVkPr))+") prÅfen"
                  cSupplier := ""
                  lToBeChecked := .T.
               ENDIF
            ENDIF

            IF Trim(cSupplier) $ {"ONPOW","WALDOM","TECHNO","EDAC","SCOLMORE","BULGIN","ITW","SIGNAL"}               
               ku->(dbSetOrder( 1 ))
               ku->(dbSeek( cSupplier+"L "))

               IF ! __AddToWaitList(aOrderList[nX]["QTY"],nEkPr,nPe,nContract,nContrPos,IF(Trim(cSupplier)=="WALDOM",0,ali->LZ))
                  cMsg += "Bestellung bei "+Trim(cSupplier)+" konnte nicht gespeichtert werden. "+mcNoBesPos   
                  lToBeChecked := .T.
               ELSE
                  art->(dbSetOrder( 1 ))
                  IF lUnderMoq .AND. oExtra:MoqSurchar > 0 .AND. art->(dbSeek(Pad("MINDERMENGENZUSCHLAG",25)))  //Mindermengenzuschlag hinzufÅgen
                     IF ! __AddToWaitList(1,oExtra:MoqSurchar,1,0,0,auf->WTerm)
                        cMsg += "Mindermengezuschlag nicht hinzugefÅgt. "
                     ENDIF
                  ENDIF
                  cMsg += "Auf die Warteliste bei "+Trim(cSupplier)+" gesetzt"
                  lOrdered := .T.
               ENDIF
            ELSEIF ! Empty(cSupplier)              
               IF art->Bezug >= 5
                  cMsg += "Fertigung bei "+Trim(cSupplier)+" planen"   
                  lToBeOrdered := .T.
               ELSE
                  cMsg += "bei "+Trim(cSupplier)+" bestellen"
                  lToBeOrdered := .T.
               ENDIF
            ENDIF

         ENDIF
      ENDIF
      cMsg += Chr(10)+Chr(13)
   NEXT

   cNotes := __GetNotes(nAbNr)
   cMsg += cNotes
   cMsgFrei += cNotes
   cMsgManu += cNotes

   IF ! lOrdered
      
   ENDIF

   lRet := .T.

   IF /*lOrdered .OR.*/ (lVorzug .AND. nReminderCount == 0) .OR. lToBeOrdered .OR. lToBeChecked
      SendMail(GetConfigEMail("SO-ORDERPARTS"),"AB "+LTrim(Str(nAbnr,6)),cMsg)      
      //SendMail({{"amos.engelking@engelking.de","Amos"}},"AB "+LTrim(Str(nAbnr,6)),cMsg)      
      IF lMOQ
         //SendMail({{"amos.engelking@engelking.de","Amos"}},"AB "+LTrim(Str(nAbnr,6))+" mit MMZ",cMsg)      
      ENDIF
      //RETURN .F.
      lRet := .F.
   ENDIF
   IF lOrdered //we do not send a message to the buyer if we have ordered the parts
      //RETURN .F.
      lRet := .F.
   ENDIF
   IF lManu
      SendMessage("Fertigung | Auftrag planen","AB "+LTrim(Str(nAbnr,6))+" Fertigung planen",cMsgManu)
      lRet := .F.
   ENDIF
   IF lFrei
      IF ! lFreiWait
         SendMessage("Projektmanagement | Freigabe Kundenauftrag","AB "+LTrim(Str(nAbnr,6))+" Freigabe prÅfen",cMsgFrei)         
      ELSE
         // SendMail({{"amos.engelking@engelking.de","Amos"}},"AB "+LTrim(Str(nAbnr,6))+" Freigabe prÅfen (geht nicht an Chris)",cMsgFrei)
      ENDIF
      //RETURN .F.
      lRet := .F.
   ENDIF

   IF lRet
      SendMail({{"amos.engelking@engelking.de","Amos"}},;
         "AB "+LTrim(Str(nAbnr,6))+IF(nReminderCount!=NIL .AND. nReminderCount != 0," - "+LTrim(Str(nReminderCount))+". Erinnerung","")+" (Standardmitteilung wird verschickt)",;
         IF(lVorzug .AND. nReminderCount != 0,"VORZUG NICHT VERSENDET"+CRLF,"")+cMsg)
   ENDIF

RETURN lRet


STATIC Function __AddToWaitList(nQty,nEkPr,nPe,nContract,nContrPos,nDelWeeks)
   LOCAL oBesPos,nLastPosnr
   LOCAL oExtra := ku->(ExtraData():New(ku->Nummer))
   LOCAL nShipWeeks := Max(1,Ceiling(oExtra:RecvTime/7))

   oBesPos := bes->(BestellungPos():New(.T.))
   oBesPos:Besnr    := -1
   oBesPos:Liefma   := ku->Kunde
   oBesPos:Besda    := Date()
   //oBesPos:Buyer
   oBesPos:Confirmed := "N"
   //oBesPos:Pay    := 0
   oBesPos:ContrNo   := nContract
   oBesPos:ContrPos  := nContrPos
   oBesPos:Mahnen    := .T.

   oBesPos:oBestellung := {;
      "DATE"=>Date(),;
      "LIEFMA"=>ku->Kunde,;
      "PERSON"=>0,;
      "ABNR"=>Space(10),;
      "PAY"=>0,;
      "RAHMEN"=>.F.,;
      "MONEY"=>ku->Money;
   }
   
   oBesPos:WTerm    := Max(CWeek(Date()),AddWeeks(auf->WTerm,nShipWeeks*-1-1))
   oBesPos:LTerm    := Max(oBesPos:Wterm,AddWeeks(CWeek(DATE()),nDelWeeks))
   IF auf->DTerm >= AddWeeks(oBesPos:LTerm,-2) .AND. auf->DTerm <= oBesPos:LTerm 
      oBesPos:LTerm := Max(oBesPos:Wterm,AddWeeks(auf->DTerm,nShipWeeks*-1))
   ENDIF

   oBesPos:Released := .T. //standard is released
   oBesPos:Pe       := nPe
   oBesPos:EkPr     := nEkPr
   oBesPos:BeQty    := nQty
   oBesPos:ShipTime := nShipWeeks
   oBesPos:Artikelnr := art->Artikelnr
   oBesPos:Matchcode := art->Matchcode

   oBesPos:Money    := ku->Money
   oBesPos:rate     := currate(oBesPos:Money,"E")
   oBesPos:LastChange := Left(TtoS(DateTime()),14)

   //oBesPos:Rabatt    := art->rabatt

   
   //find next position no.
   bes->(dbSetOrder( 6 ))
   bes->(dbSeek( ku->Kunde+Str(-1,6) ))
   DO WHILE bes->Liefma == ku->Kunde .AND. bes->Besnr == -1
      oBesPos:Posnr := bes->Posnr+1
      bes->(dbSkip())
   ENDDO


   IF ! Hook("before_save_bespos",{oBespos},.T.)      
      RETURN .F.
   ENDIF

   oBesPos:Save()

   //Folgeartikel
   art->(dbPush())
   If fol->(dbSeek(Str(oBesPos:Artikelnr,6))) .AND. ! art->Lagerart
      nLastPosnr := oBesPos:Posnr
      Do While oBesPos:Artikelnr == fol->Artikelnr .AND. ! fol->( EOF() )
         art->(dbSetOrder(2))
         art->(dbSeek(Str(fol->Folgeart,6)))
         art->(dbSetOrder(1))

         If ! art->(Found())
            fol->(dbSkip())
            LOOP
         Endif

         nLastPosnr++

         bes->(Add_Rec(0))
         bes->besnr     := -1
         bes->posnr     := nLastPosnr
         bes->liefma    := ku->Kunde
         bes->besda     := Date()
         bes->matchcode := art->matchcode
         bes->artikelnr := art->Artikelnr
         bes->buyer     := oBesPos:Buyer
         bes->confirmed := "N"
         bes->pay       := oBesPos:Pay
         bes->person    := oBesPos:Person
         bes->Printed   := .F.
         bes->beqty    := oBesPos:Qty*fol->Faktor
         bes->wterm     := oBesPos:WTerm
         bes->LTerm := oBesPos:LTerm
         bes->Mahnen  := .F.
         bes->Pe := 1
         bes->money     := oBesPos:Money
         bes->rate      := oBesPos:Rate
         bes->FolgeTo    := oBesPos:Posnr
         bes->FolgeFakto  := fol->Faktor
         bes->ShipTime  := oBesPos:Shiptime
         bes->Released  := .T.
         bes->( dbUnlock() )

         fol->(dbSkip())
      Enddo

   Endif
   art->(dbPop())

   If nContract != 0 //is a call off order, redue the open qty on the frame contract
      bes->(dbSetOrder( 1 ))
      If bes->( dbSeek(Str(nContract,6)+Str(nContrPos,3)) )
         bes->(Rec_Lock( 0 ))
         bes->BeQty := bes->BeQty-oBesPos:Qty
         If bes->BeQty == 0
            bes->Bestat := 3
         Endif
         bes->(dbUnLock())
      Endif                  
   ENDIF
RETURN .T.


STATIC FUNCTION __GetTotalQtyForPart(nArtnr,aOrderList)
   LOCAL nX
   LOCA nQty := 0

   FOR nX := 1 TO Len(aOrderList)
      IF aOrderList[nX]["ARTNR"] == nArtnr
         nQty += aOrderList[nX]["QTY"]
      ENDIF
   NEXT
RETURN nQty

STATIC FUNCTION __GetNotes(nAbNr)
   LOCAL cText := "<h3>"+t("Notizen")+"</h3>"
   cText += "<table border='1'><tr><th>Datum</th><th>Art</th><th>Inhalt</th></tr>"

   nts->(dbSetOrder( 3 ))
   nts->(dbSeek("AUF"+Str(nAbNr,6),.T.))
   DO WHILE nts->Betreff == "AUF" .AND. nts->Nummer == nAbNr
      cText += "<tr><td>"+DToC(nts->Date)+"</td><td>"
      cText += NoteType(nts->Type)
      If nts->Buyer != 0
         cText += "<br>"+Trim("von: "+Buy(nts->Buyer,.T.))
      Endif
      If nts->Person != 0
         cText += "<br>"+Trim(If(nts->Type=="VISIT","bei","mit")+": "+PERSAY(nts->Person,.T.))
      Endif
      cText += "</td><td>"+StrTran(nts->Note,Chr(13),"<br>")+"</td></tr>"                       

      nts->(dbSkip())
   ENDDO
   cText += "</table>"
RETURN cText
