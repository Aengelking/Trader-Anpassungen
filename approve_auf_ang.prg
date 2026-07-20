STATIC lDbg

FUNCTION Approve_AUF_ANG(aProducts,cText1,nLevel,cKundma,dDate,cMoney,lAuf)

/** SETTINGS **/
LOCAL aLevels := { {9},{33},{41},{45,37,28,58,73},{66} }
LOCAL aLearning := {73,66}
LOCAL nMinIncrease := 0.049  //Mindest um diesen Wert in den letzten 12 Monaten angehoben, wenn au·erhalb der Staffel
LOCAL nIncreasePerYear := 0.029 //Mindestens um diesen Wert pro Jahr angehoben wenn au·erhalb der Staffel
LOCAL lHoliday := Date() >= GetValue("HOLIDAY-AMOS-START") .AND. Date() <= GetValue("HOLIDAY-AMOS-END")
/** END */

LOCAL hProd
LOCAL cPreText,nPrice,lStaffel,lStaffelVor,aPrices,nX,lStock,nLowPrice,dLowDate,dHighDate,nHighPrice
LOCAL nPr,nBeforePrice,dBeforeDate,aAvail,lRS,lTME,nQty,hPrice,nRec,hPrices,aUsers
LOCAL nWaldPrice,lWaldom
LOCAL nGewinn,hEK,aCalcCost
LOCAL lUnderMOQ,dPreisSeit,nVorschlag,nVorschlagDiff,nTotalDiff := 0,nTotal := 0,lStaffelOnly := Empty(cText1),lStaffelDown
LOCAL nEdacTotal := 0
LOCAL cFilter
LOCAL nVPE,nLastQty

MEMVAR c_five

IF lHoliday .AND. Date() <= StoD("20190510") //Thimo is away too
   Aadd(aLevels[2],37)
ENDIF



lDbg := Tr_Getini(28) == 9

NetUse("manufact","manu")                           
NetUse("engkund","ku")
IF Select("ali") != 0
   ali->(dbCloseArea())
ENDIF
NetUse("artlief","ali")
NetUSe("folgeart","fol")
NetUse("liefstock","lsto")
NetUse( "buyprice", "bpr", .F., 0 )
NetUse("comprice2","cmp2")

IF lDbg
   @ MaxRow()/2+3,00 CLEAR
ENDIF
DbgPrn("Anzahl Artikel: "+Str(Len(aProducts)))

FOR EACH hProd IN aProducts
   cPreText := Transform(hProd:Qty,Me(hProd:Artikel:Me))+" "+Trim(hProd:Artikel:Me)+" "+Trim(hProd:Artikel:Matchcode)
   nPrice := 0
   lStock := .F.
   lStaffel := .T.
   lStaffelFound := .F.
   lStaffelVor := .F.
   lStaffelDown := .T. //Herabstufung bei der MarginprÅfung erlaubt   

   IF hProd:VkPr*hProd:Qty < 0
      nLevel := 1
      cText1 += cPreText+" Gutschrift;"
      lStaffelOnly := .F.
      lStaffelDown := .F.
   ELSEIF hProd:Qty > 0
      

      aPrices := hProd:Artikel:GetSellPrices(dDate,cKundma)
      FOR nX := 1 To Len(aPrices)
         IF hProd:Qty >= aPrices[nX,1]
            nPrice := nX //aPrices[nX,2]         
         ELSEIF (hProd:Artikel:Manufactur != 9 .AND. hProd:Qty*5 >= aPrices[nX,1]) .OR. (Trim(cKundma) == "PENTAIRF" .AND. nX == 2) //wenn nicht Scolmore staffel vorlauf solange die Menge max. das f¸nfache st
            nPrice := nX
         ENDIF
      NEXT
      ali->(dbSetOrder( 5 ))
/*      IF hProd:Artikel:Manufactur == 9 .AND. nPrice == 0 .AND. ali->(dbSeek( Str(hProd:Artikel:Artikelnr,6) + "SCOLMORE " )) .AND. ali->VPE > hProd:Qty
            cText1 += cPreText+" Menge unter erster Staffel;"
            nLevel := 1
      ELSE*/

      nValue := Round(hProd:VkPr / Currate( cMoney, "V" ),2)*hProd:Qty

      nTotal += nValue

      IF hProd:Artikel:Manufactur == 2
         nEdacTotal += nValue
      ENDIF
       
       @ 20,31 SAY " "+hProd:Artikel:Matchcode+" " COLOR C_FIVE

       DbgPrn(Trim(hProd:Artikel:Matchcode)+" Qty: "+Transform(hProd:Qty,ME(art->Me))+" EK: "+Ltrim(Str(hProd:nEk))+" "+hProd:Supplier) //+" "+Str(aPrices[nPrice,1])+Str(aPrices[nPrice,2]))
       IF Len(aPrices) > 0 .AND. nPrice > 0 .AND. Round(hProd:VkPr / Currate( cMoney, "V" ),2) < Round(aPrices[nPrice,2] / hProd:Artikel:VkPe*IF(hProd:Artikel:Manufactur == 9,0.98,0.995),2) //nicht auf Staffelvorlauf mit 0,5% (2% beu Scolmore wg. WÑhrungsdiff.) Abweichung wegen Rundungsdiff. etc.
         lStaffelFound := .T.
          //check to see if there has been a price increase in the last 12 months          
          nLowPrice := 999999.99
          dLowDate := Date()

          nHighPrice := 0
          dHighDate := AddMonth(Date(),-12)

          nBeforePrice := 0
          dBeforeDate := StoD()

          dPreisSeit := Date()

          auf->( dbSetOrder( 6 ) )
          auf->( dbSeek( cKundma + hProd:Artikel:Matchcode ) )
          DO WHILE ! auf->( Eof() ) .AND. auf->matchcode == hProd:Artikel:Matchcode .AND.  auf->kundma == cKundma
               IF Max(auf->ContrQty,auf->VkQty) <= hProd:Qty .AND. Max(auf->ContrQty,auf->VkQty) > 0
                  nPr := Round(auf->VkPr/auf->Pe*(1-auf->Rabatt/100) / Currate(auf->Money,"V",auf->Besda),2)
                  //Alert(str(nPr)+";"+DToC(auf->Besda))
                  IF auf->Besda >= AddMonth(dDate,-12) .AND. auf->Besda <= dDate
                     IF nPr != 0
                        IF nPR <= nLowPrice .AND. auf->Besda <= dLowDate
                           nLowPrice := nPr
                           dLowDate := auf->Besda
                        ENDIF
                        IF nPR >= nHighPrice .AND. auf->Besda >= dHighDate
                           nHighPrice := nPr
                           dHighDate := auf->Besda
                        ENDIF
                     ENDIF
                  ENDIF
                  //Alert(DtoC(auf->Besda)+";"+Str(nPR))
                  IF auf->Besda >= dBeforeDate .AND. auf->Besda < AddMonth(dDate,-12) //.AND. nPr > nBeforePrice
                     nBeforePrice := nPr
                     dBeforeDate := auf->Besda
                  ENDIF
                  IF auf->Besda < dPreisSeit .AND. nPr == Round(hProd:VkPr / Currate( cMoney, "V" ),2)
                     dPreisSeit := auf->Besda
                  ENDIF
               ENDIF
               auf->(dbSkip())
          ENDDO
          nPr := hProd:VkPr / Currate( cMoney, "V" )
          IF .F. //Tr_Getini(28) == 9
             Alert( cPreText+" Tiefpreis (in den letzten 12 Monaten): "+LTrim(Str(nLowPrice))+" "+DtoC(dLowDate)+;
                     ";Hochpreis: "+LTrim(Str(nHighPrice))+" "+DtoC(dHighDate)+;
                     ";Preis zuvor (lettze Preis vor dem Tiefpreis): "+LTrim(Str(nBeforePrice))+" "+DtoC(dBeforeDate)+;
                     ";Erhoehung 12 Monate: "+LTrim(Str(IF(nLowPrice > 0,(nPr-nLowPrice)/nLowPrice,0)*100,5,2))+"%"+;
                     ";Erhoehung Preis zuvor: "+LTrim(Str(IF(nBeforePrice > 0,(nPr-nBeforePrice)/nBeforePrice,0)*100,5,2))+"%";
                  )
            IF dPreisSeit < Date()
               Alert("Preis seit: "+DtoC(dPreisSeit))
            ENDIF
          ENDIF
          IF Len(aPrices) > 0 //Preisstaffel vorhanden
            IF (hProd:Artikel:Manufactur != 9 .OR. Trim(cKundma) == "SCHROFFF") .AND. ;  //Nicht Scolmore oder Pentairf
               ( (nLowPrice > 0 .AND. (nPr+0.01-nLowPrice)/nLowPrice >= nMinIncrease)  .OR. ;  //Erhˆhung zwischen aktuellen und niedrigstem Preis in den letzten 12 Monate grˆﬂer gleich nMinIncrease
               (nBeforePrice > 0 .AND. (nPr+0.01-nBeforePrice)/nBeforePrice >= Max((dDate-dBeforeDate)/365*nIncreasePerYear,nMinIncrease)) ) ; //Preis zuvor um mindestens nIncreasPerYear pro Jahr oder nMinIncrease angehoben
               .AND. hProd:VkPr / Currate( cMoney, "V" ) >= nHighPrice
               //in this case it is ok
            ELSE
               cText1 += cPreText+" Preis unter Staffelpreis ("+LTrim(Str(hProd:VkPr / Currate( cMoney, "V" ),12,2))+"<"+Ltrim(str(aPrices[nPrice,2]/hProd:Artikel:VkPe,12,2))+");"
               IF dPreisSeit < Date()
                  cText1 += Space(10)+"Preis seit: "+DtoC(dPreisSeit)+";"
                  
                  IF nLowPrice > 0 
                     nVorschlag := (1+nMinIncrease)*nLowPrice
                  ENDIF
                  IF nBeforePrice > 0
                     nVorschlag := Min(nVorschlag,nBeforePrice*(1+Max((dDate-dBeforeDate)/365*nIncreasePerYear,nMinIncrease)))
                  ENDIF
                  IF Len(aPrices) > 0 .AND. nPrice > 0
                     nVorschlag := Min(nVorschlag,Round(aPrices[nPrice,2] / hProd:Artikel:VkPe,2))
                  ENDIF
                  nVorschlag := Max(nVorschlag,nHighPrice)
                  nVorschlagDiff := nVorschlag-nPr
                  nTotalDiff += nVorschlagDiff*hProd:Qty

                  cText1 += Space(10)+"Preisvorschlag: "+LTrim(Str(nVorschlag,12,2))+";"
               ENDIF
               
               IF TR_getIni(28) == 9 .AND. ( (nLowPrice > 0 .AND. (nPr-nLowPrice)/nLowPrice >= nMinIncrease)  .OR. (nBeforePrice > 0 .AND. (nPr-nBeforePrice)/nBeforePrice >= Max((dDate-dBeforeDate)/365*nIncreasePerYear,nMinIncrease)) ) .AND. hProd:VkPr / Currate( cMoney, "V" ) >= nHighPrice
                  //Alert(hProd:Artikel:Matchcode+";"+Transform(hProd:Qty,Me(hProd:Artikel:Me))+";"+"Zuletzt: "+DToC(dBeforeDate))
               ENDIF

               IF nPrice > 3 .AND. Round(hProd:VkPr / Currate( cMoney, "V" ),2) >= Round(aPrices[nPrice-1,2] / hProd:Artikel:VkPe,2) 
                  nLevel := 4
               ELSEIF nLevel > 2
                  nLevel := 2
                  IF Len(aPrices) >= nPrice .AND. nPrice > 0
                     cText1 += cPreText+" Preis nur knapp Åber Staffelpreis ("+LTrim(Str(hProd:VkPr / Currate( cMoney, "V" ),12,2))+"<"+Ltrim(str(aPrices[nPrice,2]/hProd:Artikel:VkPe,12,2))+");"
                  
                  ENDIF
                  
               ENDIF
               IF hProd:Artikel:Manufactur == 9
                  nLevel := IF(lHoliday,2,1)
                  lStaffelDown := .T. //verhindert eine Herabstuftung
               ENDIF
            ENDIF          
            lStaffel := .F.
         ENDIF
       ELSEIF Len(aPrices) > 0 .AND. nPrice > 0 .AND. Round(hProd:VkPr / Currate( cMoney, "V" ),2) >= Round(aPrices[nPrice,2] / hProd:Artikel:VkPe,2)  //Staffelvorlauf gew‰hrt, 1cent Abweichung erlaubt
         lStaffelVor := .T.
         lStaffelFound := .T.         
       ENDIF

       IF Len(aPrices) == 0 .OR. (nPrice > 0 .AND. Round(aPrices[nPrice,2] / hProd:Artikel:VkPe,2) == 0) .OR. hProd:VkPr == 0 //Keine Preise gefunden
          lStaffel := .F.
          lStaffelFound := .F.
       ENDIF

       IF /*hProd:Artikel:LagerArt .AND.*/ hProd:Artikel:Mindest == 0
         aAvail := GetKwQty(hProd:Artikel:Artikelnr)
                                 //ATail(aAvail)[6]
         IF /*GetKwStock(hProd:Artikel:Artikelnr,hProd:KW,aAvail)*/ATail(aAvail)[6] >= IF(lAuf .AND. !hProd:Add,0,hProd:Qty)
         IF lAuf .OR. GetKwStock(hProd:Artikel:Artikelnr,hProd:KW+IF(hProd:Artikel:LZ==0,12,hProd:Artikel:LZ),aAvail) >= hProd:Qty
            lStock := .T.
            //Alert("Here"+Str(ATail(aAvail)[6]))
         ENDIF
         ENDIF
      ELSEIF hProd:Artikel:Mindest != 0
         lStock := .T. 
      ENDIF
               
      IF ! lStock //we do not have enough in stock or on order to fullfill this order
         DbgPrn("NO STOCK")
         nVPE := 0
         lUnderMOQ := .T. //if we have no direct manufacturer we are always under MOQ
         ali->(dbSetOrder( 6 ))
         IF (hProd:Artikel:Manufactur == 5 .AND. ali->(dbSeek( Str(hProd:Artikel:Artikelnr,6) + "1" ))); //Engelking China - search for Prio 1 supplier
            .OR. (hProd:Artikel:Manufactur != 5 .AND. manu->(dbSeek( Str(hProd:Artikel:Manufactur,5) )) .AND. manu->Address != 0)
            IF hProd:Artikel:Manufactur != 5
               ku->(dbSetOrder( 8 ))
               ku->(dbSeek( Str(manu->Address,6) ))
               ali->(dbSetOrder( 5 ))
               ali->(dbSeek( Str(hProd:Artikel:Artikelnr,6) + ku->Kunde ))
            ENDIF
            
            lUnderMOQ := hProd:Qty < ali->VPE
            IF lUnderMOQ
               DbgPrn("Under manufacturer MOQ")
            ENDIF
            nVPE := ali->VPE

            bpr->( dbSetOrder( 1 ) ) 
            cFilter := "(Empty(enddate) .OR. enddate >= StoD('"+DtoS(dDate)+"')) .AND. startdate <= StoD('"+DtoS(dDate)+"')"
            bpr->(dbSetFilter( {|| bpr->(&(cFilter)) },cFilter))  
            IF bpr->( dbSeek( ku->Kunde + Str( hProd:Artikel:Artikelnr, 6 ) ) )               
               lUnderMOQ := hProd:Qty < bpr->Qty
               IF lUnderMOQ
                  DbgPrn("Under manufacturer price MOQ "+Str(hProd:Qty)+Str(bpr->Qty))
               ENDIF
               nVPE := bpr->Qty
            ENDIF
            bpr->(dbClearFilter())
         ENDIF
         
         IF hProd:Artikel:Lagerart .AND. hProd:Artikel:Bezug < 5  //LagerfÑhige Artikel und Kaufteil            
            ali->(dbSetOrder( 5 ))
            lWaldom := .F.     
            IF lUnderMOQ                       
               IF ali->(dbSeek( Str(hProd:Artikel:Artikelnr,6) + Pad("WALDOM",8) )) .AND. lsto->(dbSeek( Pad("WALDOM",8)+Str(hProd:Artikel:Artikelnr,6) )) //does waldom have this part and is the qty over waldoms MOQ
                  DbgPrn("Waldom prices found")
                  hPrice := GetBuyPrice( Pad("WALDOM",8), hProd:Artikel:Artikelnr, hProd:Qty )
                  nWaldPrice := hPrice["price"]/hPrice["unit"]
                  lWaldom := .T. //we can buy from waldom
                  IF lsto->Stock >= hProd:Qty .AND. AddWeeks(CWeek(Date()),hProd:Artikel:LZ) > hProd:KW .AND. nWaldPrice > 0 //Waldom hat bestand und die Lieferwoche schreibt eine Zukauf vor oder wir sind unter MOQ                               
                     DbgPrn("Delivery week: "+NiceWeek(AddWeeks(CWeek(Date()),hProd:Artikel:LZ))+" Quoted:"+NiceWeek(hProd:KW)+" LZ: "+LTrim(Str(hProd:Artikel:LZ)))                  
                     hProd:nEK := nWaldPrice
                     hProd:Supplier := Pad("WALDOM",8)
                     hProd:Margin :=  (hProd:VkPr / Currate( cMoney, "V" ) - hProd:nEK) /  (hProd:VkPr / Currate( cMoney, "V" ))
                     DbgPrn("Kauf von Waldom, Margin:"+LTrim(Str(hProd:Margin))+", EK: "+Ltrim(str(hProd:nEK)))
                  ENDIF
               ELSE
                  DbgPrn("No Waldom found")
               ENDIF         
         
               IF (Empty(hProd:Supplier) .OR. hProd:Supplier == ku->Kunde) 
                  ali->(dbSeek( Str(hProd:Artikel:Artikelnr,6) + ku->Kunde ))
                  IF lUnderMOQ .OR. hProd:Qty < ali->VPE //under MOQ of Manufacturer
                     DbgPrn("Under MOQ")
                     lRS := .F.
                     lTME := .F.
                     IF hProd:Artikel:Manufactur==11 //Techno artikel unter VPE                     
                        //Alert("Techno unter MOQ. "+LTrim(str(hProd:nEK)))
                        IF hProd:nEK == 0
                           //margin neu berrechnen, falls bisher kein Preis gefunden wurde
                           hEK := hProd:Artikel:getBuyPrice(ku->Kunde,-1,,,,,,dDate)  
                           hProd:nEk :=  hEK["price"]/hEk["unit"]*Currate(ku->Money,"E",dDate)
                           hProd:Supplier := "Techno under MOQ"
                           IF hProd:nEk == 0
                              nGewinn := 0
                           ELSE
                              nGewinn := ( hProd:VkPr - hProd:nEk )
                           ENDIF

                           IF hProd:VkPr != 0
                              hProd:Margin := ( nGewinn / hProd:VkPr ) //* 100
                           ELSE
                              hProd:Margin := 0
                           ENDIF
                        ENDIF
                        /*IF hProd:VkPr*hProd:Qty < 150 .AND. AScan(aProducts,{|x| Trim(x:Artikel:Matchcode)=="MINDERMENGENZUSCHLAG" }) ==0  //Kein Mindermengenzuschlag berechnet
                        cText1 += cPreText+" VPE ("+Ltrim(Str(ali->VPE))+") und kein Mindermengenzuschlag berechnet;"
                        IF nLevel > 2
                           nLevel := 2
                        ENDIF
                        ENDIF*/
                     ELSEIF lWaldom .AND. nWaldPrice > 0
                        hProd:nEK := nWaldPrice
                        hProd:Supplier := Pad("WALDOM",8)
                        hProd:Margin :=  (hProd:VkPr / Currate( cMoney, "V" ) - hProd:nEK) /  (hProd:VkPr / Currate( cMoney, "V" ))
                        DbgPrn("Waldom (wegen MOQ), Margin:"+LTrim(Str(hProd:Margin))+", EK: "+Ltrim(str(hProd:nEK)))
                     ELSEIF hProd:Artikel:Bezug < 5 //see if we can buy from RS or TME
                        //TME
                        IF Left(hProd:Artikel:Gruppe,2) != "KO"
                           hProd:Artikel:gotoRec()
                           hPrice := GetPricesCompet("TME")
                           IF ValType(hPrice) == "H" .AND. ! Empty(hPrice)
                              DbgPrn("TME: "+ValToPrg(hPrice))
                              lTME := .T. //tme has this product, we set lRS to .T. if they are cheap enough
                              FOR EACH nPrice IN hPrice
                                 IF ValType(nPrice:__eNumKey()) == "N" .AND. nPrice:__eNumKey() <= hProd:Qty  .AND. nPrice*1.2  <= hProd:VkPr / Currate( cMoney, "V" )
                                    hProd:nEK := nPrice
                                    hProd:Margin :=  (hProd:VkPr / Currate( cMoney, "V" ) - nPrice) /  (hProd:VkPr / Currate( cMoney, "V" ))
                                    hProd:Supplier := Pad("TME",8)
                                    lRS := .T.
                                 ENDIF
                              NEXT
                              IF lRS
                                 DbgPrn("TME "+LTrim(Str(hProd:nEK)))
                              ENDIF
                           ELSE
                              DbgPrn("NO TME (no price)")
                           ENDIF

                           IF ! lRs

                              nQty := GetLiefStock("RS",hProd:Artikel:Artikelnr)
                              IF nQty >= hProd:Qty  //RS hat Lagerbestand
                                 DbgPrn("RS has stock")
                                 hPrice := GetBuyPrice( Pad("RS",8), hProd:Artikel:Artikelnr, hProd:Qty )
                                 nPrice := hPrice["price"]/hPrice["unit"]
                                 IF nPrice <= 0  //no quote found
                                    
                                    DbgPrn("No quote from RS")
                                    
                                    //nRec := ali->(Recno())
                                    //ali->(dbSeek( Str(hProd:Artikel:Artikelnr,6) + Pad("RS",8) ))
                                    hProd:Artikel:gotoRec()
                                    hPrices := GetPricesCompet("RS") //MBaseRun(Trim(Tr_Getini(1))+"\run\prices\rs",{hProd:Artikel:Artikelnr,ali->Artlief,hProd:Artikel:Matchcode})
                                    //ali->(dbGoTo(nRec))
                                    IF hPrices != NIL .AND. Len(hPrices) > 1
                                       nPrice := HGetValueAt(hPrices,Len(hPrices)) //last break
                                    ENDIF
                                 ENDIF
                                 IF nPrice > 0 .AND. nPrice*1.3 <= hProd:VkPr / Currate( cMoney, "V" )
                                    DbgPrn("Kaufen wir bei RS")
                                    hProd:nEK := nPrice
                                    hProd:Margin :=  (hProd:VkPr / Currate( cMoney, "V" ) - nPrice) /  (hProd:VkPr / Currate( cMoney, "V" ))
                                    hProd:Supplier := Pad("RS",8)
                                    lRS := .T.
                                 ELSE
                                    cText1 += cPreText+" RS "+IF(lTME," und TME sind","ist")+" zu teuer"+IF(Tr_Getini(28)==9,"("+Str(nPrice,5,2)+")","")+";"
                                    lStaffelOnly := .F.
                                    lStaffelDown := .T.
                                 ENDIF
                              ELSE
                                 cText1 += cPreText+" RS hat keinen Bestand"+IF(lTME," und TME ist zu teuer","")+";"
                                 lStaffelOnly := .F.
                                 lStaffelDown := .T.
                              ENDIF
                           ENDIF
                        ENDIF
                        IF ! lRs  //we cannot buy it from RS
                           IF lUnderMOQ .AND. nVPE != 0
                              cText1 += cPreText+" VPE ("+Ltrim(Str(nVPE))+") unterschritten;"
                           ENDIF
                           lStaffelOnly := .F.
                           lStaffelDown := .T.
                           IF nLevel > 2
                              nLevel := 2
                           ENDIF
                        ENDIF
                     ENDIF
                  ENDIF
               ENDIF
            ENDIF
         ENDIF
      ENDIF
      //IF Tr_Getini(28) == 9
//         Alert(hProd:Matchcode+" "+IF(lStaffelVor,"Staffelvorlauf",IF(lStaffel,"Staffel","Auﬂerhalb Staffel"))+LTrim(Str(Round(hProd:Margin,2))))
         //DbgPrn("EK: "+Str(hProd:nEk)+IF(hProd:Artikel:Bezug >= 5,"manufactured","-"))
         IF hProd:nEk == 0 .AND. hProd:Artikel:Lagerart .AND. hProd:Artikel:Bezug >= 5  //Artikel die eine StÅli haben sollten aber kein EK errechnet werden konnte, da versuchen wir eine Calc-StÅli zu finden
            
            cFile := ""
            aCalcCost := RUN_GetCostFromOO(hProd:Artikel:Artikelnr,,@cFile)    
                
            IF aCalcCost["ERROR"] == 0
               nLastQty := 0               
               DbgPrn("Calc-Cost: "+ValToPrg(aCalcCost["DATA"]))
               FOR nX := 1 TO Len(aCalcCost["DATA"])
                  IF aCalcCost["DATA",nX,"QTY"] <= hProd:Qty .AND. aCalcCost["DATA",nX,"QTY"] >= nLastQty
                     nLastQty := aCalcCost["DATA",nX,"QTY"]
                     hProd:nEK := aCalcCost["DATA",nX,"COST"]
                     hProd:Supplier := Pad("KALKULATION",8)
                     hProd:Margin :=  (hProd:VkPr / Currate( cMoney, "V" ) - hProd:nEK) /  (hProd:VkPr / Currate( cMoney, "V" ))
                  ENDIF
               NEXT
            ELSE
               IF aCalcCost["ERROR"] ==  2
                  Tr_MsgBox("Keine Gesamtkosten in der Kalkulation gefunden")
               ELSEIF aCalcCost["ERROR"] ==  3
                  Tr_MsgBox("Keine Menge in der Kalkulation gefunden")
               ENDIF
               DbgPrn(aCalcCost["ERRORTEXT"])
            ENDIF            
         ENDIF
      //ENDIF
      
      DbgPrn("Margin: "+LTrim(Str(hProd:Margin))+" "+hProd:Supplier)

      IF hProd:nEk == 0 .AND. hProd:Artikel:Lagerart  //this should now be covered by nGewinn == 0
         nLevel := IF(lHoliday,2,1)
         cText1 += cPreText+" "+t(" kein EK errechenbar.;")
      ENDIF

      IF ! lStaffelFound
         //nLevel := IF(lHoliday,2,1)
         //cText1 += cPreText+" "+t("Keine Staffel vorhanden")
      ENDIF

      fol->(dbSetOrder( 1 ))
      lFolge := fol->(dbSeek( Str(hProd:Artikel:Artikelnr,6) ))

      IF (;
            (! lStaffel .AND. Round(hProd:Margin,2) < 0.3) .OR.;  //Au·erhalb der Staffel (auch kein Vorlauf)
            (lStaffelVor .AND. Round(hProd:Margin,2) < _GetMinMargin(hProd:Artikel:Matchcode));
         );
            .AND. (hProd:Artikel:LagerArt .OR. lFolge);
         .AND. Left(hProd:Artikel:Matchcode,4) != "TEXT" //mehr als eine Staffel vorlauf 30% Marge, bei Staffelvorlauf min. 20%
         cText1 += cPreText+" Margin:"+Str(hProd:Margin*100,6,1)+"% zu niedrig ("+Trim(hProd:Supplier)+" - "+IF(HB_HHasKey(hProd,"NEK"),LTrim(Str(hProd:nEk,12,2)),"")+");"
         IF hProd:Margin <= 0.2
            IF Trim(cKundma) $ {"SOFTCOM"} .AND. hProd:Margin >= 0.049 //Beistellware fÅr Produktion
               nLevel := 4
            ELSEIF lHoliday .AND. nLevel > 2 //.AND. hProd:Margin >= 0.12
               nLevel := 2
            ELSEIF ! lHoliday .AND. nLevel > 1  
               IF Trim(cKundma) $ {"SOFTCOM"}  
                  cText1 += "SOFTCOM nicht unter 5% Marge erlaubt;"
               ENDIF
               nLevel := 1
            ENDIF
         ELSE
           IF (nLevel >= 3 .OR. lStaffelDown) .AND. ((Left(hProd:Artikel:Gruppe,2) == "KO" .AND. hProd:Margin >= 0.20) .OR. hProd:Margin >= 25) //niedriger Marge 
              nLevel := 3
           ELSEIF nLevel > 2 .OR. lStaffelDown
              nLevel := 2
           ENDIF
         ENDIF
      ELSE
         /*cText1 += "Margin ok "+LTrim(Str(hProd:Margin*100,5,1))+"%;"
         cText1 += "Mindestmarge: "+LTrim(Str(_GetMinMargin(hProd:Artikel:Matchcode)*100,5,1))+"%;"
         cText1 += IF(!lStaffelVor,"kein","")+"Staffelvorlauf;"
         cText1 += IF(lStaffel,"Staffel","Au·erhalb Staffel")+";"
         cText1 += IF(lFolge,"Folgeartikel vorhanden","kein Folgeartikel")+";"*/
      ENDIF

      IF Trim(hProd:Artikel:Matchcode) $ {"565-290-728","565-290-718"} .AND. ! Trim(cKundma) $ {"WEIDMUEL","SCHNEIDG"}
         cText1 += Trim(hProd:Artikel:Matchcode)+t(" ausschlieﬂlich f¸r Weidm¸ller")
      ENDIF
   ENDIF
NEXT

IF nEdacTotal > 0 .AND. nEdacTotal < 500
   cText1 += "EDAC Gesamtwert unter 500 EUR"
   nLevel := 2
ENDIF

IF lDbg
   DbgPrn("complete")
   Inkey(0,128)   
ENDIF


IF ! Empty(cText1)
   IF lStaffelOnly .AND. nTotal > 0 .AND. (nTotalDiff/nTotal <= 0.01 .OR. (nTotal <= 50 .AND. nTotalDiff/nTotal <= 0.03)) .AND. nLevel >= 2
      nLevel := 4
   ENDIF
   IF lDbg
      //Alert("Level: "+Str(nLevel)+";"+cText1)
   ENDIF
ELSE
   nLevel := 4
ENDIF

aUsers := {}
FOR nX := nLevel TO 1 STEP -1
   AEval(aLevels[nX],{|x| Aadd(aUsers,x) })
NEXT

IF Tr_Getini(28) $ aLearning .AND. Tr_Getini(28) $ aUsers ;
   .AND. Len(aUsers) > 1 .AND. Tr_MsgBox("Anderer Person zu Genehmigung vorlegen?",,{"selber genehmigen","Ja"}) == 2 //Learning mode for these users
   HB_ADel(aUsers,AScan(aUsers,{|x| x==Tr_Getini(28) }),.T.)
ENDIF

RETURN {cText1,aUsers}
//ENDIF
//RETURN {"",{TR_getini(28)}}


#include 'X:\run\margin.prg'
#include 'X:\run\OO_costing.prg'

STATIC Function DbgPrn(cText1)
   IF lDbg
      Scroll(MaxRow()/2+3,00,MaxRow(),MaxCol(),-1)
      @ MaxRow()/2+3,00 SAY cText1
   ENDIF
RETURN NIL

#include 'x:\run\prices\getprices.prg'


