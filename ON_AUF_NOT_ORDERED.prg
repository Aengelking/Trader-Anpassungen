#define CRLF Chr(13)+Chr(10)

FUNCTION HOOK_ON_AUF_NOT_ORDERED(nAbnr,aOrderList,nReminderCount)
   LOCAL cMsg,nX,aKwStock   
   LOCAL cSupplier,cWaldMatch := Pad("WALDOM",8)
   LOCAL hFreigabe
   LOCAL nStdLZ := GetConfigValue("DEFAULTS_SUPPLIER_DELTIME")
   LOCAL nIncome,nEkPr,nPe,nVKPr
   LOCAL lIsRahmen := .F.
   LOCAL nContract := 0
   LOCAL nContrPos := 0
   LOCAL nSupArt   
   LOCAL oExtra,lUnderMoq := .F.
   LOCAL cPrevMatch := ""
   LOCAL lOrdered := .F.,lManu := .F.,lFrei := .F.,lVorzug := .F.,lToBeOrdered := .F.,lToBeChecked := .F.
   LOCAL cMsgManu,cComment,cMsgLine
   LOCAL cMsgFrei,cNotes   
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

   cMsg := Pad("Artikel",25+8)+" "+Pad("Stckzahl",17)+" "+Pad("Termin",11)+" "+"Kommentare"+Chr(13)+Chr(10)
   cMsgManu := cMsg
   cMsgFrei := cMsg

   FOR nX := 1 TO Len(aOrderList)
      art->(dbSetOrder( 2 ))
      art->(dbSeek(Str(aOrderList[nX]["ARTNR"],6)))
      auf->(dbSetOrder( 1 ))
      IF ! auf->(dbSeek( Str(nAbnr,6)+Str(aOrderList[nX]["POS"],3) ))      
         cMsg += "Auftrag nicht gefunden?!"
      ENDIF
      cMsgLine := IF(art->Matchcode!=cPrevMatch,art->Matchcode,Space(25))+" #"+Pad(LTrim(Str(aOrderList[nX]["ARTNR"],6)),6)+" "+Pad(Transform(aOrderList[nX]["QTY"],Me(art->Me))+" "+art->Me,17)+" "+Pad(NiceWeek(aOrderList[nX]["WEEK"]),11)+" "
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
         lToBeOrdered := .T.
      ELSEIF HHasKey(aOrderList[nX],"MOVEWEEK") .AND. aOrderList[nX]["MOVEWEEK"] != 0
         cMsg += "Liefervorzug prfen - verfgbar in KW "+NiceWeek(aOrderList[nX]["MOVEWEEK"])
         lVorzug := .T.
      ELSEIF art->Mindest > 0 .AND. art->Mindest >= aOrderList[nX]["QTY"]/2  //Artikel hat Meldebestand und dieser ist mindestens 50% der ben”tigten Menge
         cMsg += "Lagerartikel - Best„nde prfen"
         lToBeChecked := .T.
      ELSEIF art->Bezug >= 5 .AND. ! part->(dbSeek( Str(art->Artikelnr,6)+Str(-1,4) )) //Stckliste ohne Lohnposition - wird intern gefertigt und ber Frepple
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
            cMsg += "wird nicht bestellt - Termine prfen"
            lToBeChecked := .T.
         ELSEIF ali->(dbSeek( Str(nSupArt,6) ))
            ali->(dbSkip())
            IF ali->Artikelnr == nSupArt .AND. ali->Priority != 9 //we have a second supplier     
               ku->(dbSetOrder( 8 ))                         
               IF man->(dbSeek( Str(art->Manufactur,5) )) .AND. man->Principal .AND. ku->(dbSeek( Str(man->Address,6) ))
                  //oExtra := ku->(ExtraData():New(ku->Nummer))
                  ali->(dbSetOrder( 1 ))
                  IF ali->(dbSeek( ku->Kunde+Str(nSupArt,6) )) .AND. ali->Priority <= 8 .AND. (Right(Str(aOrderList[nX]["WEEK"],4),2)=="97" .OR. AddWeeks(Cweek(Date()),IF(ali->LZ==0,nStdLZ,ali->LZ)) <= aOrderList[nX]["WEEK"]) .AND. ali->Min <= aOrderList[nX]["QTY"] //we can purchase directly                  
                     //should we add oExtra:RecvTime?                                          
                     cSupplier := ku->Kunde
                  ELSEIF art->manufactur $ {1,10} .AND. ali->(dbSeek( cWaldMatch+Str(art->Artikelnr,6) )) .AND. ali->Priority <= 8 .AND. ali->Min <= aOrderList[nX]["QTY"] //in case of Bulgin we can purchase from Waldom too
                     //hier werden wir die Lieferzeit wahrscheinlich nicht prfen, sondern der Kundenauftrag msste dann angepasst werden
                     //LAGERBESTAND bei Waldom prfen, nicht alle Artikel sind korrekt z.B. #MT
                     cSupplier := cWaldMatch
                  ENDIF
                  ali->(dbSetOrder( 6 ))
               ENDIF
               IF Empty(cSupplier)
                  cMsg += "wird nicht bestellt - Lieferant nicht eindeutig"
               ENDIF
            ELSE               
               ali->(dbSkip(-1))
               
               cSupplier := ali->Kunde               
            ENDIF

            /** FREIGABE PRšFEN **/
            IF ! Empty(cSupplier) .AND. ! Empty(art->Zeichnung)
               ku->(dbSetOrder( 1 ))
               ku->(dbSeek( cSupplier+"L" ))
               hFreigabe := art->(GetFreigabeBesState(ku->Nummer))
               IF ! hFreigabe:lBes
                  cComment := "Keine Freigabe fr "+Trim(cSupplier)+" vorhanden - Kein Bestellung m”glich!"
                  cMsgFrei += cMsgLine+cComment+CRLF
                  cMsg += cComment
                  cSupplier := ""
                  lFrei := .T.
               ELSEIF hFreigabe:nMaxQty != 0  //eingeschr„nkte Menge
                  bes->(dbSetOrder(8))
                  nIncome := bes->(LETO_SUM("beqty-gelqty",'released .AND. (bestat <= 2 .OR. (bestat >= 6 .AND. bestat <= 8))',cSupplier+art->Matchcode,cSupplier+art->Matchcode))
      
                  IF hFreigabe:nMaxQty < aOrderList[nX]["QTY"]+nIncome
                     cComment := "Maximale Menge von "+LTrim(Transform(hFreigabe:nMaxQty,Me(art->Me)))+" "+art->Me+" bei "+Trim(cSupplier)+" berschritten - Nur Materialfreigabe m”glich!"
                     cMsgFrei += cMsgLine+cComment+CRLF
                     cMsg += cComment 
                     cSupplier := ""
                     lFrei := .T.
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

               IF nEkPr == 0 .AND. oExtra:MoqSurchar > 0
                  lUnderMoq := .T.
                  GetBuyPrice(cSupplier,nSupArt,-1,@nEkPr,@nPe,.T.) //find the first price break             
               ENDIF
               IF nEkPr == 0                  
                  cMsg += "EK fehlt bei "+Trim(cSupplier)
                  cSupplier := ""
               ENDIF

               //Margin prfen
               nVKPr := (auf->VkPr/auf->Pe)*(1-auf->Rabatt/100)
               IF nVKPr > 0 .AND. (nVkPr-(nEkPr+IF(lUnderMOQ,oExtra:MoqSurchar/aOrderList[nX]["QTY"],0))*currate(ku->Money,"E"))/nVkPr < 0.15
                  cMsg += "Margin zu klein bei "+Trim(cSupplier)+" - EK ("+Ltrim(Str(nEkPr+IF(lUnderMOQ,oExtra:MoqSurchar,0)))+" EUR) und VK ("+Ltrim(Str(nVkPr))+") prfen"
                  cSupplier := ""
               ENDIF
            ENDIF

            IF Trim(cSupplier) $ {"ONPOW","WALDOM","TECHNO","EDAC","SCOLMORE"}               
               ku->(dbSetOrder( 1 ))
               ku->(dbSeek( cSupplier+"L "))

               IF ! __AddToWaitList(aOrderList[nX]["QTY"],nEkPr,nPe,nContract,nContrPos,IF(Trim(cSupplier)=="WALDOM",0,ali->LZ))
                  cMsg += "Bestellung bei "+Trim(cSupplier)+" konnte nicht gespeichtert werden. "+mcNoBesPos   
               ELSE
                  art->(dbSetOrder( 1 ))
                  IF lUnderMoq .AND. oExtra:MoqSurchar .AND. art->(dbSeek(Pad("MINDERMENGENZUSCHLAG",25)))  //Mindermengenzuschlag hinzufgen
                     IF ! __AddToWaitList(1,oExtra:MoqSurchar,1,0,0,auf->WTerm)
                        cMsg += "Mindermengezuschlag nicht hinzugefgt. "
                     ENDIF
                  ENDIF
                  cMsg += "Auf die Warteliste bei "+Trim(cSupplier)+" gesetzt"
                  lOrdered := .T.
               ENDIF
            ELSEIF ! Empty(cSupplier)              
               IF art->Bezug >= 5
                  cMsg += "Fertigung bei "+Trim(cSupplier)+" planen"   
               ELSE
                  cMsg += "bei "+Trim(cSupplier)+" bestellen"
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
      SendMail({{"amos.engelking@engelking.de","Amos"}},"AB "+LTrim(Str(nAbnr,6))+IF(nReminderCount!=NIL .AND. nReminderCount != 0," - "+Str(nReminderCount)+". Erinnerung ",""),IF(lVorzug .AND. nReminderCount != 0,"VORZUG NICHT VERSENDET"+CRLF,"")+cMsg)
   ENDIF

   IF lOrdered .OR. (lVorzug .AND. nReminderCount == 0) .OR. lToBeOrdered .OR. lToBeChecked
      SendMail(GetConfigEMail("SO-ORDERPARTS"),"AB "+LTrim(Str(nAbnr,6)),cMsg)      
   ENDIF
   IF lManu
      SendMail({{"samuel.engelking@engelking.de","Samuel"}},"AB "+LTrim(Str(nAbnr,6))+" Fertigung planen",cMsgManu)
   ENDIF
   IF lFrei
      SendMail({{"chris.chertes@engelking.de","Chris"}},"AB "+LTrim(Str(nAbnr,6))+" Freigabe prfen",cMsgFrei)
   ENDIF
   IF lOrdered .OR. lManu .OR. lFrei .OR. lVorzug .OR. lToBeOrdered .OR. lToBeChecked
      RETURN .F. //do not send standard message
   ENDIF

RETURN .T. //send standard message


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
   
   oBesPos:WTerm    := Max(CWeek(Date()),AddWeeks(auf->WTerm,nShipWeeks*-1))
   oBesPos:LTerm    := AddWeeks(CWeek(DATE()),nDelWeeks+nShipWeeks)

   oBesPos:Released := .T. //standard is released
   oBesPos:Pe       := nPe
   oBesPos:EkPr     := nEkPr
   oBesPos:BeQty    := nQty
   oBesPos:ShipTime := 1
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
