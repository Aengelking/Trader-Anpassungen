
FUNCTION HOOK_APPROVE_AUF(oAuftrag)

LOCAL nAngValidDays := 12*7
LOCAL aProducts := {},hProd
LOCAL cSupplier,lPorto := .F.
LOCAL nLastPrice := 0,dLastDate := StoD("20990101"),oLastPos
LOCAL lHoliday :=  Date() >= GetValue("HOLIDAY-AMOS-START") .AND. Date() <= GetValue("HOLIDAY-AMOS-END")
LOCAL nStdLaufzeit := 18  //Maximale Rahmenlaufzeit
LOCAL nPreStart := 5 //Monate bis Rahmenbegin
LOCAL nLaufzeit
LOCAL oContract
LOCAL cText1,nLevel,nTotal,oContr,nVk,nArtikelnr,nP,nMargin,nQty,nEK,nX,nGewinn
LOCAL aDels := {},nCoc := 0,oExtra 
LOCAL oABExtra

LOCAL hLaufZeit := { ; //Sonderlaufzeiten
   46872=>24,;
   46874=>24,;
   46875=>24,;
   42989=>99,;
   50155=>99;
}

/*IF Tr_MsgBox("Zur Sichtung einer Kollegin/einem Kollegen vorlegen?",,{"Ja","Nein"}) == 2
   RETURN NIL
ENDIF*/

oExtra := ku->(ExtraData():New(oAuftrag:Kunde:Nummer))

//temp
IF ValType(oAuftrag) != "O"   
   oAuftrag := Auftrag():New()
   oAuftrag:Load(auf->AbNr)
ENDIF

oABExtra := auf->(ExtraData():New(auf->Abnr))

IF oABExtra:CUST_APR  //Kudenfreigabe erforderlich
   RETURN {"Kundenfreigabe erforderlich",{33,9}}  //Genehmigsungsanforderung ohne Genehmiger
ENDIF

IF Tr_getIni(28) == 9
//   Alert("HERE")
ENDIF

NetUse("manufact","manu")
NetUse("engkund","ku")
IF Select("ali") != 0
   ali->(dbCloseArea())
ENDIF
NetUse("artlief","ali")
NetUse("angebot","ang")
NetUse("skontoa","sk")
netUse("fremdab","frab")

cText1 := ""

nLevel := 3
nTotal := oAuftrag:Total
IF nTotal > 100000 .AND. ! auf->Abnr $ {50155}
   IF ! lHoliday
      cText1 += t("Gesamtwert ¸ber 100.000 EUR;")
      nLevel := 1
   ENDIF
/*ELSEIF nTotal > 10000
   cText1 += t("Gesamtwert ¸ber 10.000 EUR;")
   nLevel := 2*/
ENDIF

/*IF oAuftrag:Kunde:Nummer == .AND. ! lHoliday .AND. nTotal > 500
   cText1 += t("Gesamtwert ¸ber 500 EUR - Amazon kann alles bis zur Auslieferung kostenfrei stornieren!;")
   nLevel := 1
ENDIF*/


SetPos(0,0)

oAuftrag:Positions:Each({|oPos|
   IF oAuftrag:AbNr == 42989 .AND. oPos:IsRahmen  //Continental Automotive, Platziert nur ein Rahmen und erhˆht den st‰ndig
      nLastPrice := oPos:VkPr/oPos:Pe
      dLastDate :=  AddMonth(CalWd(oPos:WTerm),-12)
   
      auf->(dbPush())
      auf->(dbSetOrder( 1 ))
      auf->(dbSeek( Str(oAuftrag:Abnr,6) ))
      DO WHILE auf->Abnr == oAuftrag:Abnr
         IF Right(Str(auf->Dterm,4),2) != "99"
            IF auf->ContrPos == oPos:Itmnr
               dLastDate := Min(dLastDate,CalWd(auf->WTerm))
            ENDIF
         ENDIF
         auf->(dbSkip())
      ENDDO
      auf->(dbPop())

      oLastPos := oPos
   ENDIF
   
   IF oPos:ContractPosition != NIL
      oContract := oPos:ContractPosition
   ELSEIF ! Empty(oPos:BesRef)
      oContr := Auftrag():New(.F.)
      oContr:Load( Val(Left(oPos:BesRef,6)) )
      oContract := oContr:Positions:GetRecord( Val(Right(oPos:BesRef,2)) )
   ELSE
      oContract := NIL
   ENDIF

   IF oContract != NIL .AND. oPos:WTerm > oContract:WTerm  //does not work as this does not count as a change of order!
      nLevel := 1
      cText1 += t(Str(oPos:Itmnr,3)+". "+" Abruf nach Rahmenende ("+Str(oPos:Wterm)+" > "+Str(oContract:Wterm)+");")
   ENDIF
   IF Trim(oPos:Artikel:Matchcode) $ {"PORTO","FREIGHT"}
      lPorto := .T.
   ENDIF

   IF Left(oPos:Artikel:Matchcode,5) $ {"48-5-","48-6-"} .AND. oPos:VkQty-oPos:GelQty > 0 .AND. oPos:Bestat < 7
      cText1 += Trim(oPos:Artikel:Matchcode)+" schwachsinniges Produkt - LP-AnschlÅsse mit Litzen!;"
      nLevel := 1
   ENDIF
   
   IF ! Trim(oPos:Artikel:Matchcode) $ {"CoC","PORTO"} .AND. ! Left(oPos:Artikel:Matchcode,6) $ "13693/ 13694/"  .AND. oContract == NIL .AND. auf->VkQty != auf->GelQty .AND. oPos:Bestat < 7 .AND. oPos:Bestat >= 4 //ignore glands, call off positions, delivered positions, closed positions and already approved positions
      //old: cannot ignore approved positions like that, then the user can change anything he likes afterwards
      nVk := oPos:VkPr/oPos:Pe
      nArtikelnr := oPos:Artikel:Artikelnr
      
      IF  oPos:FolgeTo == 0
         
         IF Right(Str(oPos:DTerm,4),2) $ {"98","97"}
            nWeek := AddWeeks(CWeek(Date()),If(oPos:Artikel:lz=0,GetConfigValue("DEFAULTS_SUPPLIER_DELTIME"),oPos:Artikel:LZ))
         ELSE 
            nWeek := oPos:DTerm
         ENDIF
         IF (nP := AScan(aProducts,{|x| x:Artikel:Artikelnr == nArtikelnr .AND. x:VkPr == nVk })) == 0    
            //Altd()      
            nMargin := oPos:GetMargin(@cSupplier)
            Aadd(aProducts,{"ARTIKEL"=>oPos:Artikel,"QTY"=>0,"VKPR"=>oPos:VkPr/oPos:Pe*(1-oPos:Rabatt/100),"MARGIN"=>0,"KW"=>nWeek,"SUPPLIER"=>cSupplier,"ADD"=>.F.})
            nP := Len(aProducts)
         ENDIF
         IF oPos:IsRahmen
            nQty := oPos:ContrQty-IF(oPos:Bestat==3,oPos:VkQty,0)

            IF HHasKey(hLaufZeit,oAuftrag:AbNr)
               nLaufZeit := hLaufZeit[oAuftrag:Abnr]
            ELSE
               nLaufZeit := nStdLaufzeit
            ENDIF
            IF CalWd(oPos:WTerm) > AddMonth(oPos:SDatum,nLaufZeit)  //Laufzeit auﬂer bei Sonderfall Conti pr¸fen
               cText1 += Str(oPos:Itmnr,3)+". "+Trim(oPos:Artikel:Matchcode)+t(" Laufzeit ¸ber 18 Monate;")
               IF CalWd(oPos:WTerm) > AddMonth(oPos:SDatum,nLaufZeit+6) //Level 2 can approve upto 24 months
                  nLevel := 2
               ENDIF
            ENDIF
            IF oPos:SDatum > AddMonth(oAuftrag:Besda,nPreStart)  //Laufzeit auﬂer bei Sonderfall Conti pr¸fen
               cText1 += Str(oPos:Itmnr,3)+". "+Trim(oPos:Artikel:Matchcode)+t(" Rahmenbeginn ¸ber 5 Monate in der Zukunft;")
               nLevel := 1
            ENDIF


            IF oPos:MeldStock < oPos:VkQty-oPos:GelQty .AND. oPos:MeldStock/(oPos:VkQty-oPos:GelQty) > 1/3 //Lagerbestand f¸r 3 Monate //Min(oPos:VkQty-oPos:GelQty,oPos:MinStock)*oPos:VkPr/oPos:Pe*(1-oPos:Rabatt/100) > 2500
               IF ! lHoliday
                  //cText1 += Str(oPos:Itmnr,3)+". "+Trim(oPos:Artikel:Matchcode)+" Hoher Mindestbestand ("+LTrim(str(oPos:MinStock/(oPos:VkQty-oPos:GelQty)*100,12,2))+"%);" //t(" Wert Mindestbestand ¸ber EUR 2500;")
                  //nLevel := 1
               ENDIF
            ENDIF
         ELSE
            nQty := IF(oPos:Bestat==3,oPos:GelQty,oPos:VkQty)
         ENDIF
         aProducts[nP]:Qty += nQty
         aProducts[nP]:KW  := Min(aProducts[nP]:KW,nWeek)
         IF oPos:Bestat > 3
            aProducts[nP]:Add := .T.
         ENDIF
      ENDIF
   ENDIF

   /*IF oExtra:WerksBesch      
      IF Trim(oPos:Artikel:Matchcode) == "CoC"
         nCoc++
      ELSEIF oPos:Artikel:Bezug < 5  //wir zÑhlen nur Kaufprodukte
         IF oAuftrag:Kunde:JustInTime            
            IF AScan(aDels,oPos:BDatum) == 0
               Aadd(aDels,oPos:BDatum)
            ENDIF
         ELSE
            IF AScan(aDels,oPos:DTerm) == 0
               Aadd(aDels,oPos:DTerm)
            ENDIF
         ENDIF         
      ENDIF
   ENDIF*/

   RETURN NIL
})

/*IF oExtra:WerksBesch        
   IF Len(aDels) > nCoc
      cText1 += "Bitte "+LTrim(Str(Len(aDels)-nCoc))+"x CoC hinzufÅgen;"
      nLevel := 1
   ENDIF
ENDIF*/

IF oAuftrag:AbNr == 42989 .AND. ValType(oLastPos) == "O"
   IF dLastDate < AddMonth(Date(),-12)
      nEK := oLastPos:Artikel:GetLowestBuyPrice(2000,Date())
      IF (nLastPrice-nEK)/nLastPrice < 0.46
         nLevel := 2
         cText1 += Str(oLastPos:Itmnr,3)+". "+"Preis bitte anheben (mind. 46% Marge);"+Dtoc(dLastDate)+";"
      ENDIF
   ENDIF
   //nLevel := 1
   //cText1 += "Verpackungsvorschrift muss noch umgesetzt werden - siehe Vertragsordner;"

ENDIF

FOR nX := 1 TO Len(aProducts)
   hProd := aProducts[nX]

   nVk := hProd:VkPr * Currate( oAuftrag:Money, "V" )
   
   nEk := hProd:Artikel:getBuyPriceForMargin(hProd:Qty,hProd:Add,oAuftrag:Besda,hProd:KW,@cSupplier)

   IF hProd:Artikel:Manufactur $ {12} //Elcom Mindermenge
      nVK -= 60/hProd:Qty
   ENDIF

   IF hProd:Artikel:Manufactur $ {12,16} //Elcom oder Signal 
      IF hProd:Artikel:Gewicht == 0 //no weight, no prices
         cText1 += t(Trim(hProd:Artikel:Matchcode)+" hat kein Gewicht")+";"
         nVK := 0
         hProd:Margin := 0
      ELSE         
         IF hProd:Qty != 0
            nVK -= Hook("get_supplier_ship_cost",{Pad(IF(hProd:Artikel:Manufactur == 16,"SIGNAL","ELCOM"),8),hProd:Artikel:Gewicht/1000*hProd:Qty})/hProd:Qty
         ENDIF
      ENDIF   
   ENDIF   
   
   hProd:nEk := nEk

   IF nEK == 0
      nGewinn := 0
   ELSE
      nGewinn := ( nVk - nEk )
   ENDIF

   IF nVk != 0
      hProd:Margin := ( nGewinn / nVk ) //* 100
   ENDIF

   IF nEk == 0 .AND. hProd:Artikel:Lagerart  //this should now be covered by nGewinn == 0
      //nLevel := IF(lHoliday,2,1)
      //cText1 += Trim(hProd:Artikel:Matchcode)+" "+t(" kein EK errechenbar.;")
   ENDIF
   IF Tr_getini(28) == 9      
      //? hProd:Artikel:Matchcode,"EK",nEK,"VK",nVk
      //? hProd:Qty,hProd:Add,oAuftrag:Besda,hProd:KW
   ENDIF
   
   IF Tr_Getini(28) == 9
      //Alert(hProd:Artikel:Matchcode+";Margin: "+Str(hProd:Margin*100,6,2)+";EK: "+LTrim(Str(nEk,12,2)))
   ENDIF


   ang->(dbSetOrder( 6 ))
   ang->(dbSeek( oAuftrag:Kundma+hProd:Artikel:Matchcode ))
   IF  hProd:Margin > 0.10 // only accept quotes if the margin is greater than 10%
      DO WHILE ang->Kundma == oAuftrag:Kundma .AND. ang->Matchcode == hProd:Artikel:Matchcode .AND. ! ang->(EOF())
         IF ang->Bestat > 0 .AND. ang->Bestat < 3 .AND. ang->VkQty <= hProd:Qty .AND. ang->Besda <= oAuftrag:Besda .AND. ang->Besda+nAngValidDays >= oAuftrag:Besda  .AND.  Round(ang->VkPr/ang->Pe,2) == Round(hProd:VkPr,2) //g¸ltiges Angebot vorhanden
            HB_ADel(aProducts,nX,.T.)
            nX--
            EXIT
         ENDIF
         ang->(dbSkip())
      ENDDO
   ENDIF
NEXT

IF  sk->(IsPrePay(oAuftrag:Kunde:Skonto)) .AND. ! lPorto .AND. ! oAuftrag:Versandart $ {10,44,46,49,56}
   cText1 += t("Kein Porto berechnet ")+";"
   IF nLevel > 2
      nLevel := 2
   ENDIF
ENDIF

IF Len(aProducts) == 0 .AND. Empty(cText1)
   RETURN {"",{Tr_Getini(28)}}
ENDIF

RETURN  Hook("approve_auf_ang",{aProducts,cText1,nLevel,oAuftrag:Kundma,oAuftrag:Besda,oAuftrag:Money,.T.})

#include 'x:\run\getupsimportcost.prg'