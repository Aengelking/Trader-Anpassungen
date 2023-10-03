/**
   Dynamische Sicherheitsbest„nde Gessmann

   Mit diesem Programm berechnen wir die Sicherbest„nde fr Gessmann
   
**/
#define CRLF Chr(13)+Chr(10)

PROC RUN_GESSMANN_DYN(nKunde,lDisplay,lUpdateMelde)
   /*** SETTINGS ***/
   LOCAL nForcastMonths := 12/52*12 //How many months does the custmomer plan ahead
   LOCAL nStockFor      := 3 //For how many months do we hold stock
   //LOCAL nEAUDays       := 311  //Number of days to use for caculating the EAU
   /*** END OF SETTINGS ***/

   LOCAL hBedarf := {=>}   
   LOCAL cText := ""
   LOCAL cKuList := ""
   LOCAL aTo := {{"gf","Amos"}}
   LOCAl nLen,nIncome,nHistPerYear
   LOCAL cFilter,nOpen
   LOCAL nThisYear := Year(Date()) 
   LOCAL dEoY := Stod(Str(nThisYear,4)+"1231")
   LOCAL dBoY := Stod(Str(nThisYear,4)+"0101")
   LOCAL dBoNY := Stod(Str(nThisYear+1,4)+"0101")
   LOCAL dEnd
   LOCAL nMelde

   LOCAL cMatchcode,hArtikel,nThreeMax,nThreeMonths,nX
   LOCAL nBestand,nArtikelnr,nPerDay,nYear,cMe,nMonth,nQty
   LOCAL hTotals := {Str(Year(Date())-3,4)=>0,Str(Year(Date())-2,4)=>0,Str(Year(Date())-1,4)=>0,Str(Year(Date()),4)=>0,"HOCH"=>0,"RAHM"=>0,"BES"=>0}
   LOCAL hSubTotals
   LOCAL nRahmQty,dBis
   LOCAL hAvail := {=>}
   LOCAL cScreen := SaveScreen(),cCol

   MEMVAR c_one
   
   Default(@lDisplay,.T.)
   Default(@lUpdateMelde,.F.)
   
   IF lDisplay
      cCol := SetColor(c_one)
      @ 10,00 CLEAR
      @ 11,00 SAY "Daten werden eingelesen..."
   ENDIF

   NetUse("engauf","auf")
   NetUse("artikel","art")
   NetUse("folgeart","fol")
   NetUse("engbes","bes")
   
   IF nKunde == NIL .AND. Select("ku") != 0
   ELSE
      NetUse("engkund","ku")
      ku->(dbSetOrder( 8 ))
      ku->(dbSeek( Str(nKunde,6) ))
   ENDIF

   auf->(dbSetOrder( 6 )) //kundma+matchcode
   cFilter := 'WDATUM >= Stod(Str(Year(Date())-3,4)+"0101") .AND. folgeto == 0  .AND. Left(Matchcode,'+IF(ku->Nummer==14696,'11)=="KS14696/59-"','8)=="KS17535/"') //.AND.  Right(Str(dterm,4),2)!="99"
   auf->(dbSetFilter( {|| auf->(&(cFilter)) } ,cFilter))

   auf->(dbSeek( ku->Kunde ))

   DO WHILE auf->Kundma == ku->Kunde .AND. ! auf->(EOF())      
      
      art->(dbSetOrder( 1 ))
      art->(dbSeek(auf->matchcode))
      IF AT(".",auf->Matchcode) != 0
         cMatchcode := Pad(SubStr(auf->Matchcode,1,RAT(".",auf->Matchcode)-1),25)
      ELSE
         cMatchcode := auf->Matchcode
      ENDIF
      IF ! HHasKey(hBedarf,cMatchcode)
         hBedarf[cMatchcode] := {;
            Str(Year(Date())-3,4)=>0,;
            Str(Year(Date())-2,4)=>0,;
            Str(Year(Date())-1,4)=>0,;
            Str(Year(Date()),4)=>0,;
            "LAST_DATE_THIS"=>StoD(""),;
            "FIRST_DATE_THIS"=>dEoY,;
            "SHIPPED"=>0,"PLANNED"=>0,"UNPLANNED"=>0,"LAST_DATE"=>StoD(""),"BESTAND"=>0,"LZ"=>0,"12M"=>0,"MONTHS"=>{=>},"COUNT"=>0}            
         FOR nYear := Year(Date())-3 TO Year(Date())-1
            FOR nMonth := 1 TO 12
               hBedarf[cMatchcode]["MONTHS"][Str(nYear,4)+StrZero(nMonth,2)] := 0
            NEXT
         NEXT
      ENDIF
      IF ! art->LagerArt .AND. fol->(dbSeek(STR(art->Artikelnr,6)))
         nBestand := NIL
         nArtikelnr := art->Artikelnr
         art->(dbSetOrder(2))

         While fol->artikelnr == nArtikelnr
            art->(dbSeek(Str(fol->folgeart,6)))
            If nBestand == NIL
               nBestand := art->bestand/fol->faktor
            Else
               nBestand := Min(art->bestand/fol->faktor,nBestand)
            Endif
            fol->(dbSkip())
         Enddo
         art->(dbSetOrder( 1 ))
         art->(dbSeek(auf->matchcode))
   
         If nBestand != NIL
            hBedarf[cMatchcode]["BESTAND"] += nBestand
         Endif
      ELSE       
         hBedarf[cMatchcode]["BESTAND"] += art->BESTAND
      ENDIF
      IF ! HHasKey(hAvail,art->Artikelnr)
         hAvail[art->Artikelnr] := GetKwQty(art->Artikelnr,.F.,.F.,.T.,.F.) //GetKwQty(nArtnr,lConfirmOnly,lUseMelde,lTBAasLT,lRahmenEnde)
      ENDIF
      hBedarf[cMatchcode]["LZ"] += GetKwStock(art->Artikelnr,AddWeeks(CWeek(Date()),art->LZ+2),hAvail[art->Artikelnr])
      //hBedarf[cMatchcode]["6M"] += GetKwStock(art->Artikelnr,AddWeeks(CWeek(Date()),4.34524*6))

      DO WHILE auf->Matchcode == art->Matchcode
         IF Right(Str(auf->dterm,4),2) == "99"  ///Rahmenposition
            hBedarf[cMatchcode]["UNPLANNED"] += auf->VkQty-auf->GelQty
         ELSE
            nOpen := IF(auf->bestat>=3,0,auf->vkqty-auf->gelqty)
            nQty  := IF(auf->Bestat>=3,auf->GelQty,auf->VkQty)
            nYear := Year(auf->WDatum)
            IF nYear <= nThisYear
               hBedarf[cMatchcode][Str(nYear,4)] += nQty
            ENDIF
            IF nYear < nThisYear
               hBedarf[cMatchcode]["MONTHS"][Str(nYear,4)+StrZero(Month(auf->WDatum),2)] += nQty
            ENDIF
            IF nYear == nThisYear
               hBedarf[cMatchcode]["SHIPPED"] += auf->gelqty
               hBedarf[cMatchcode]["COUNT"] ++
               hBedarf[cMatchcode]["LAST_DATE_THIS"] := Max(hBedarf[cMatchcode]["LAST_DATE_THIS"],auf->WDatum)
               hBedarf[cMatchcode]["FIRST_DATE_THIS"] := Min(hBedarf[cMatchcode]["FIRST_DATE_THIS"],auf->WDatum)

            ENDIF
            IF nOpen != 0
               hBedarf[cMatchcode]["PLANNED"] += nOpen
            ENDIF
            hBedarf[cMatchcode]["LAST_DATE"] := Max(hBedarf[cMatchcode]["LAST_DATE"],auf->WDatum)
         ENDIF
         
         auf->(dbSkip())
      ENDDO
   ENDDO
   
   auf->(dbClearFilter())
  
   nLen := 6

   
   IF lDisplay
      SetPos(10,00)
      ? Pad("Artikel",25),PadL(Str(Year(Date())-3,4),nLen),PadL(Str(Year(Date())-2,4),nLen),PadL(Str(Year(Date())-1,4),nLen),PadL(Str(Year(Date()),4),nLen),PadL("Hoch-",nLen),PadL("Be-",nLen),;
            PadL("LZ",nLen),PadL("offene",nLen),Pad("gedeckt",8),Pad("Liefer-",8),PadL("Max-3M",nLen),PadL("Melde-",nLen),PadL("Bestellung",nLen),PadL("Rahmen",nLen),Pad("letzter",8),Pad("erwarteter",8)
      ? Space(25),Space((nLen+1)*4-1),PadL("rechnung",nLen),PadL("stand",nLen),Space(nLen),PadL("Menge",nLen),Pad("bis",8),Pad("datum",8),Space(nLen),PadL("bestand",nLen),Space(nLen),Space(nLen),Pad("Abruf",8),Pad("Abruf",8)
   ENDIF
   bPrintTotal := {|lBig|
      LOCAL cDiv := IF(lBig,Chr(205),Chr(196))
      LOCAL hTot := iF(lBig,hTotals,hSubTotals)
      ? Space(25),Replicate(cDiv,nLen),Replicate(cDiv,nLen),Replicate(cDiv,nLen),Replicate(cDiv,nLen),Replicate(cDiv,nLen)
      ?? Space((nLen+1)*5+(8+1)*2),Replicate(cDiv,nLen),Replicate(cDiv,nLen)

      ? Space(25),PadL(TransForm(hTot[Str(Year(Date())-3,4)],cMe),nLen),PadL(TransForm(hTot[Str(Year(Date())-2,4)],cMe),nLen),PadL(TransForm(hTot[Str(Year(Date())-1,4)],cMe),nLen),PadL(TransForm(hTot[Str(Year(Date()),4)],cMe),nLen)   ,PadL(TransForm(hTot["HOCH"],cMe),nLen)
      ?? Space((nLen+1)*5+(8+1)*2),PadL(TransForm(hTot["BES"],cMe),nLen),PadL(TransForm(hTot["RAHM"],cMe),nLen)

      ?
   }

   cLast := Left(HGetKeyAt(hBedarf,1),12)
   hSubTotals := {Str(Year(Date())-3,4)=>0,Str(Year(Date())-2,4)=>0,Str(Year(Date())-1,4)=>0,Str(Year(Date()),4)=>0,"HOCH"=>0,"RAHM"=>0,"BES"=>0}
   
   FOR EACH hArtikel IN hBedarf          
      art->(dbSeek(hArtikel:__eNumKey()))
      IF Left(art->Matchcode,12) != cLast
         Eval(bPrintTotal,.F.)
         cLast := Left(art->Matchcode,12)
         hSubTotals := {Str(Year(Date())-3,4)=>0,Str(Year(Date())-2,4)=>0,Str(Year(Date())-1,4)=>0,Str(Year(Date()),4)=>0,"HOCH"=>0,"RAHM"=>0,"BES"=>0}
      ENDIF

      cMe := Me(art->Me)

      IF hArtikel["LAST_DATE"] < StoD(Str(Year(Date()),4),"0701") //in the first half oof the year we take the last year into account
         nPerDay := (hArtikel[Str(Year(Date())-1,4)]/365+hArtikel[Str(Year(Date()),4)]/(Max(Date()+(365/12*nForcastMonths),hArtikel["LAST_DATE"])-dBoY/3))            
      ELSE
         IF Date()+(365/12*nForcastMonths) >= dEoY   //customer should not be placing any further orders
            dEnd := dEoY
         ELSEIF Year(hArtikel["LAST_DATE"]) == nThisYear .AND. hArtikel["LAST_DATE_THIS"]+(hArtikel["LAST_DATE_THIS"]-dBoY)/hArtikel["COUNT"] > dEoY-15  //we do not expect another call off this year
            dEnd := dEoY
         ELSE
            dEnd := hArtikel["LAST_DATE"]
         ENDIF
         dEnd := Max(Date()+(365/12*nForcastMonths),dEnd)
         nPerDay := hArtikel[Str(Year(Date()),4)]/(dEnd-dBoY+1)

      ENDIF

      IF nPerDay == 0
         nPerDay := 0.0001 //avoid division by zero
      ENDIF
      //nPerDay := hArtikel["12M"]/(Max(Date()+(365/12*nForcastMonths),hArtikel["LAST_DATE"])-Stod(Str(Year(Date()-365),4)+"0101"))

      //Gewichteter Durchschnitt der Vorjahre
      //nHistPerYear := (hArtikel[Str(Year(Date())-3,4)]+hArtikel[Str(Year(Date())-2,4)]*2+hArtikel[Str(Year(Date())-1,4)]*4)/7

      //Suche 3 Monats Maximum
      nThreeMonths := 0
      nThreeMax := 0
      FOR nX := 1 TO Len(hArtikel["MONTHS"])
         //? HGetKeyAt(hArtikel["MONTHS"],nX),HGetValueAt(hArtikel["MONTHS"],nX)
         IF nX > 3
            nThreeMonths -= HGetValueAt(hArtikel["MONTHS"],nX-3)
         ENDIF
         nThreeMonths += HGetValueAt(hArtikel["MONTHS"],nX)
         nThreeMax := Max(nThreeMax,nThreeMonths)
         //?? "",nThreeMonths,nThreeMax            
      NEXT

      nIncome := GetOpenPO()

      nMelde := Round(nPerDay*365/12*nStockFor,GetMeDecimals(art->Me))

    

      hTotals[Str(Year(Date())-3,4)] += hArtikel[Str(Year(Date())-3,4)]
      hTotals[Str(Year(Date())-2,4)] += hArtikel[Str(Year(Date())-2,4)]
      hTotals[Str(Year(Date())-1,4)] += hArtikel[Str(Year(Date())-1,4)]
      hTotals[Str(Year(Date()),4)] += hArtikel[Str(Year(Date()),4)]
      hTotals["HOCH"] += nPerDay*365 //nEAUDays

      hSubTotals[Str(Year(Date())-3,4)] += hArtikel[Str(Year(Date())-3,4)]
      hSubTotals[Str(Year(Date())-2,4)] += hArtikel[Str(Year(Date())-2,4)]
      hSubTotals[Str(Year(Date())-1,4)] += hArtikel[Str(Year(Date())-1,4)]
      hSubTotals[Str(Year(Date()),4)] += hArtikel[Str(Year(Date()),4)]
      hSubTotals["HOCH"] += nPerDay*365 
      

      dBis := hArtikel["LAST_DATE"]+IF(nPerDay==0,9999,((hArtikel["BESTAND"]+nIncome-hArtikel["PLANNED"])/nPerDay))
      
      
      nBesQty := Max(0,Round((nPerDay*365-IF(dBis>dBoNY,(dBis-dBoNy)*nPerDay,0))/500,0)*500) //gerundet auf 500 Stk.
      nRahmQty := Round((nPerDay*365-IF(dBis>dBoNY,(dBis-dBoNy)*nPerDay,0)-hArtikel["UNPLANNED"]+hArtikel["BESTAND"]+nIncome-hArtikel["PLANNED"])/500,0)*500

      hTotals["BES"] += nBesQty
      hSubTotals["BES"] += nBesQty
      hTotals["RAHM"] += nRahmQty
      hSubTotals["RAHM"] += nRahmQty

      

      IF hArtikel["COUNT"] > 0 .AND. lDisplay
         IF hArtikel["LZ"] < nMelde
            SetColor("R+/W*")
         ELSE
            SetColor("N/W*")
         ENDIF
         ? hArtikel:__eNumKey(),PadL(TransForm(hArtikel[Str(Year(Date())-3,4)],cMe),nLen),PadL(TransForm(hArtikel[Str(Year(Date())-2,4)],cMe),nLen),PadL(TransForm(hArtikel[Str(Year(Date())-1,4)],cMe),nLen),;
            PadL(TransForm(hArtikel[Str(Year(Date()),4)],cMe),nLen),;            
            PadL(TransForm(nPerDay*(dEoY-dBoy+1),cMe),nLen),;
            PadL(TransForm(hArtikel["BESTAND"],cMe),nLen),;
            PadL(TransForm(hArtikel["LZ"],cMe),nLen),;
            PadL(TransForm(hArtikel["BESTAND"]+nIncome-hArtikel["PLANNED"],cMe),nLen),DtoC(dBis),;            
            hArtikel["LAST_DATE"]+(hArtikel["BESTAND"]+nIncome-hArtikel["PLANNED"]-nMelde)/nPerDay,;            
            PadL(Transform(nThreeMax,cMe),nLen),;
            PadL(TransForm(nMelde,cMe),nLen),;            
            PadL(TransForm(nBesQty,cMe),nLen),;
            PadL(TransForm(nRahmQty,cMe),nLen),;
            hArtikel["LAST_DATE"],;
            hArtikel["LAST_DATE"]+(hArtikel["LAST_DATE_THIS"]-dBoY)/hArtikel["COUNT"]
         IF Left(art->Matchcode,12) == "KS14696/59-1"
            IF ! Empty(cKuList); cKuList += CRLF; ENDIF
            cKuList += hArtikel:__eNumKey()+" "+Pad(DtoC(dBis),11)+"  "+PadL(TransForm(nRahmQty,cMe),nLen)        
         ENDIF
         SetColor("N/W*")
      ENDIF

      IF lUpdateMelde .AND. ku->Nummer==14696 .AND. Left(art->Matchcode,12)=="KS14696/59-1" //Gessmann and 59-1 only 
         IF art->(dbSeek( Trim(art->Matchcode)+"/ODM" )) .AND. (art->Mindest != nMelde .OR. hArtikel["LZ"] < nMelde) //Meldebestand muss auf den ODM Artikel
            cText += art->Matchcode+" alt: "+Transform(art->Mindest,Me(art->Me))+" neu: "+Transform(nMelde,Me(art->Me))
            IF hArtikel["LZ"] < nMelde
               cText += " UNTERSCHRITTEN!"
            ENDIF
            cText += CRLF
            IF art->Mindest != nMelde
               art->(Rec_Lock())
               art->Mindest := nMelde
               art->(dbUnLock())
            ENDIF
         ENDIF
      ENDIF
                  
            
   NEXT

   IF lDisplay
      Eval(bPrintTotal,.F.)
      Eval(bPrintTotal,.T.)
   ENDIF

   
   
   IF ! Empty(cText)
      SendMail(aTo,"GESSMANN Meldebest„nde","<pre>"+cText+"</pre>",,,,.T.)
   ENDIF
   IF lDisplay
      
      ? "Anmerkungen:"
      ? "- Die Hochrechung kann niedriger sein als die tats„chlichen Abrufe in einem Jahr, wenn bereits Abrufe fr das folgende Jahre erteilt wurden."
      ? "- Die offene Menge beinhaltet auch Best„nde die ber die aktuellen Rahmen hinausgehen"
      ?   
      IF ku->Nummer == 14696 
         ? ">E< erzeugt Email fr Kunde"
      ENDIF
      ? "Weiter mit beliebiger Taste..."
      DO WHILE .T.      
         IF ku->Nummer == 14696 .AND. Upper(Chr(Sinkey(0))) == "E"
            cText := "<pre>"+Pad("Artikel",25)+" "+Pad("Gedeckt bis",11)+"  "+"Neue Rahmenmenge"+CRLF
//            cText += Space(25)+" "+Pad("Zulauf bis",10)+CRLF
            cText += cKuList+"</pre>"
            OpenMailClient({},"Aktueller Stand 59-1 Serie",cText,{})
         ELSE
            EXIT
         ENDIF  
      ENDDO 
      RestScreen(,,,,cScreen)
      SetColor(cCol)
   ENDIF

STATIC FUNC GetOpenPO()
   LOCAL nIncome := 0
   LOCAL cFilter := 'beqty > gelqty .AND. bestat < 3'
   bes->(dbSetOrder(4))
   bes->(dbSetFilter({|| bes->(&(cFilter))},cFilter))
   bes->(dbSeek(art->Matchcode ,.T.))
   Do While bes->Matchcode == art->Matchcode
      nIncome += Max(0,bes->beqty-bes->gelqty)
      bes->(dbSkip())
   Enddo
   bes->(dbClearFilter())
RETURN nIncome
