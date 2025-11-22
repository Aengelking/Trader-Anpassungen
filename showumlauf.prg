
#command @ <top>,<left>,<bottom>,<right> GET <var> LISTBOX <hash> ASSOCIATIVE ;
	[VALID <valid>];
	[WHEN <when>];
	[COLOR <color>];
;
=> GET_AssociativeListBox(getlist,<top>,<left>,<bottom>,<right>,{|v| If(v==NIL,<var>,<var>:=v)},<hash>,<{valid}>, <{when}>,<color>)


PROC RUN_ShowUmlaufVerp()
   LOCAL cDbId := Pad("ART",5)
   LOCAL cField := Pad("UMLAUF",10)
   LOCAL hVerpack := {=>}
   LOCAL getlist := {}
   LOCAL nTotal, nTotalSent,nTotalLager
   LOCAL nInitial, nRemaining   
   LOCAL lPrint
   LOCAL hSupplierTotals // Hash to track totals by supplier
   LOCAL hSupplierSent     // Hash to track boxes already sent to suppliers
   LOCAL cSupplier, aSuppliers, nSupplierTotal, nSentBoxes
   LOCAL aList,nSort := 1,aEntry
   LOCAL aData
   LOCAL cVerp

   LOCAL aInitQty := GetBoxInitialQuantities()
   

   NetUse("extraval","exv")
   NetUse("artikel","art")
   NetUse("lager","lag")
   NetUse("engbes","bes")
   NetUse("werks","we")
   NetUse("werkauf","wer")

   exv->(dbsetOrder( 1 ))
   exv->(dbSeek( cDbID+cField ))
   
   DO WHILE exv->DBId == cDbID .AND. exv->Name == cField .AND. ! exv->(EOF())
      
      IF Empty(cVerp)
         cVerp := Trim(exv->Value)
      ENDIF
      hVerpack[Trim(exv->Value)] := Trim(exv->Text)
      exv->(dbSkip())
   ENDDO

   DO WHILE .T.
      Head("Umlaufverpackungen")
      @ 01,00 SAY "Verpackung"
      @ 01,11,15,50 GET cVerp LISTBOX hVerpack ASSOCIATIVE
      @ 02,00 SAY "Sortierung"
      @ 02,11,15,50  GET nSort LISTBOX {"Artikelnummer","Lagerort"} DROPDOWN
      READ

      IF LastKey() == 27
         RETURN
      ENDIF
      

      // Clear screen and prepare for display
      lPrint := Tr_MsgBox("Drucken?",,{"anzeigen","drucken"}) == 2


      aData := GetUmlaufStatus(cVerp)
      IF Empty(aData)
         LOOP
      ENDIF
      aList := aData["LIST"]
      nTotal := aData["TOTAL"]
      nTotalSent := aData["SENT"]
      nTotalLager := aData["LAGER"]
      //hFertigung := aData["FERTIGUNG"]
      hSupplierTotals := aData["SUPPLIERS"]
      hSupplierSent := aData["SUPPLIERS_SENT"]      

      IF lPrint
         StartPrint()
         SET PRINTER ON
         ? pr(5)
      ELSE
         CLS
      ENDIF
      ? ""
      ? Replicate("=", 110)
      ? PadC("UMLAUFVERPACKUNGEN - öBERSICHT", 110)
      ? PadC("Verpackung: " + AllTrim(cVerp), 110)
      
      // Display initial quantity if available
      IF HHasKey(aInitQty, AllTrim(cVerp))
         ? PadC("Anfangsbestand: " + Transform(aInitQty[AllTrim(cVerp)], "999,999") + " StÅck", 110)
      ENDIF
      
      ? Replicate("=", 110)
      ? ""
      
      // Table header
      ? "Art.Nr Matchcode                 Typ         Nummer    Lagerort/Info   Menge  Verpack  Gelief"
      ? Replicate("-", 110)

      

      // Sort and display the collected list
      IF nSort == 1
         ASort(aList,,, {|a,b| a[1] < b[1] } )
      ELSE
         ASort(aList,,, {|a,b| a[6] < b[6] } )
      ENDIF
      
      FOR EACH aEntry IN aList   
         ? Str(aEntry[1],6),;
            aEntry[2],;
            PadR( aEntry[3], 10),;
            PadR( aEntry[4], 6),;
            PadR( aEntry[5], 3),;
            PadR( aEntry[6], 12),;
            PadL( Transform(aEntry[7], Me(art->Me)),8),;
            Str( aEntry[8], 8),;
            Str( aEntry[9], 8)
      NEXT
      

      ? ""
      ? Replicate("=", 110)
      ? PadR("GESAMTSUMME VERPACKUNGEN:", 77) + Str(nTotal, 8)      
      ? PadR("VERWENDETE  VERPACKUNGEN:", 77) + Str(nTotalSent, 8)      
      ? PadR("          DAVON IM LAGER:", 77) + Str(nTotalLager, 8)   
      
      // Display supplier totals
      IF Len(hSupplierTotals) > 0
         ? ""
         ? "VERPACKUNGEN NACH LIEFERANT:"
         ? Replicate("-", 80)
         ? "Lieferant                      Benîtigt   Gesendet   Noch zu senden"
         ? Replicate("-", 80)
         aSuppliers := HGetKeys(hSupplierTotals)
         ASort(aSuppliers)
         FOR EACH cSupplier IN aSuppliers
            nSupplierTotal := hSupplierTotals[cSupplier]
            nSentBoxes := IF(HHasKey(hSupplierSent, cSupplier), hSupplierSent[cSupplier], 0)
            ? PadR(cSupplier, 30) + " " + ;
              Str(nSupplierTotal, 8) + " " + ;
              Str(nSentBoxes, 8) + " " + ;
              Str(Max(0, nSupplierTotal - nSentBoxes), 12)
         NEXT
         ? Replicate("-", 80)
      ENDIF
      
      // Show calculation with initial quantity
      IF HHasKey(aInitQty, AllTrim(cVerp))
         nInitial := aInitQty[AllTrim(cVerp)]
         nRemaining := nInitial - nTotalSent
         
         ? PadR("ANFANGSBESTAND:", 77) + Str(nInitial, 8)
         ? Replicate("-", 110)
         
         IF nRemaining >= 0
            ? PadR("VERFöGBAR:", 77) + Str(nRemaining, 8) + " StÅck"
         ELSE
            ? PadR("FEHLEND:", 77) + Str(Abs(nRemaining), 8) + " StÅck"
         ENDIF
         
         ? PadR("AUSLASTUNG:", 77) + Str((nTotal * 100.0) / nInitial, 8, 1) + " %"
      ELSE
         ? PadR("(Kein Anfangsbestand definiert)", 77)
      ENDIF
      
      ? Replicate("=", 110)
      ? ""
      IF lPrint
         CopyPrint()
         SET PRINTER OFF
      ELSE
         ? "DrÅcke eine beliebige Taste..."
         Sinkey(0)
      ENDIF

      
   ENDDO


   FUNCTION GetUmlaufStatus(cVerp)
      LOCAL cDbID := Pad("ART",5)
      LOCAL cField := Pad("UMLAUF",10)
      LOCAL nVerpackungen,nOffeneMenge
      LOCAL nTotal := 0 
      LOCAL nTotalSent := 0 
      LOCAL nTotalLager := 0
      LOCAL oExtra
      LOCAL cSupplier
      LOCAL oBesExtra
      LOCAL nSentBoxes
      LOCAL aArt,nArt
      LOCAL cExludeLager := "000/0[3,4]A.*"
      LOCAL hFertigung := {=>} // reset production order tracking
      LOCAL hSupplierTotals := {=>} // reset supplier totals
      LOCAL hSupplierSent := {=>} // reset sent boxes tracking
      LOCAL aList := {}
      LOCAL nCount
      LOCAL aMatch

         NetUse("artikel","art")
   NetUse("lager","lag")
   NetUse("engbes","bes")
   NetUse("werks","we")
   NetUse("werkauf","wer")


      aMatch := HB_Regex("[0-9]+" ,cVerp) // check if cVerp is a number
      IF Len(aMatch) == 0
         Tr_MsgBox("Umlaufverpackung enthÑlt keine Zahl!")
         RETURN NIL      
      ENDIF

      nCount := Val(aMatch[1]) // convert to number      
      

      //get all parts with Umlaufverpackungen
      aArt := GetIdsWithExtraField(cDbID,Trim(cField))

      art->(dbSetOrder( 2 ))
      FOR EACH nArt IN aArt      
         oExtra := art->(ExtraData():New(nArt))
         
         IF Trim(oExtra:Umlauf) == cVerp
            art->(dbSeek( Str(nArt,6) ))
            
            // Display stock entries
            lag->(dbSeek( nArt ))
            DO WHILE lag->Artikelnr == nArt
               IF Left(lag->Lagerort,3) != "096" .AND. ! HB_RegexMatch(cExludeLager,Trim(lag->Lagerort))
                  nVerpackungen := Ceiling(lag->LagerMenge/nCount)
                  AAdd(aList, {nArt, art->Matchcode, "LAGER", "","", lag->Lagerort, lag->LagerMenge, nVerpackungen,0})                  
                  nTotal += nVerpackungen
                  nTotalSent += nVerpackungen
                  nTotalLager += nVerpackungen
               ENDIF
               lag->(dbSkip())
            ENDDO

            // Display order entries
            bes->(dbSetOrder( 3 ))
            bes->(dbSeek( art->Matchcode ))
            DO WHILE bes->Matchcode == art->Matchcode                              
               IF bes->BeStat < 3 .AND. bes->BeQty-bes->GelQty > 0                  
                  nOffeneMenge := bes->BeQty-bes->GelQty
                  nVerpackungen := Ceiling(nOffeneMenge/nCount)
                  
                  // Check how many boxes were already sent to this supplier for this order
                  
                  oBesExtra := bes->(ExtraData():New(bes->Besnr))                     
                  nSentBoxes := oBesExtra:&(cVerp)  // Get sent boxes from extradata
                  nSentBoxes -= Ceiling(bes->GelQty/nCount) // subtract already returned boxes
                  IF nSentBoxes < 0
                     nSentBoxes := 0
                  ENDIF
                  
                  // Track supplier total and sent boxes
                  cSupplier := AllTrim(bes->Liefma)
                  IF Empty(cSupplier)
                     cSupplier := "INTERN"
                  ENDIF
                  IF ! HHasKey(hSupplierTotals, cSupplier)
                     hSupplierTotals[cSupplier] := 0
                     hSupplierSent[cSupplier] := 0
                  ENDIF
                  hSupplierTotals[cSupplier] += nVerpackungen
                  hSupplierSent[cSupplier] += nSentBoxes

                  AAdd(aList, {nArt, art->Matchcode, "BESTELLUNG", Str(bes->Besnr,6),Str(bes->Posnr,3), AllTrim(bes->Liefma), nOffeneMenge, nVerpackungen, nSentBoxes})
                    
                  nTotal += nVerpackungen
                  nTotalSent += nSentBoxes
               ENDIF
               bes->(dbSkip())
            ENDDO

            // Display production order entries (FertigungsauftrÑge)
            we->(dbSetOrder( 5 ))  // partart index
            we->(dbSeek( Str(nArt,6) ))
            DO WHILE we->PartArt == nArt
               wer->(dbSetOrder( 1 ))

               IF wer->(dbSeek( Str(we->Aufno,6) )) 
                  IF wer->Status >= 1 .AND. wer->Status < 4                  
                     nOffeneMenge := we->BookQty * we->Factor
                     nVerpackungen := Ceiling(nOffeneMenge/nCount)

                     // Track supplier total for external production
                     cSupplier := AllTrim(wer->Liefma)
                     IF Empty(cSupplier)
                        cSupplier := "INTERN"
                     ENDIF
                     IF ! HHasKey(hSupplierTotals, cSupplier)
                        hSupplierTotals[cSupplier] := 0
                        hSupplierSent[cSupplier] := 0
                     ENDIF
                     hSupplierTotals[cSupplier] += nVerpackungen
                     
                     // Parts delivery (internal or external) includes packages - mark as sent
                     hSupplierSent[cSupplier] += nVerpackungen

                     AAdd(aList, {nArt, art->Matchcode, "FERTIGUNG", Str(we->Aufno,6),"", AllTrim(wer->Liefma), nOffeneMenge, nVerpackungen, 0})

                     nTotal += nVerpackungen
                     nTotalSent += nVerpackungen
                  ELSE
                     nOffeneMenge := we->Qty * we->Factor
                     nVerpackungen := Ceiling(nOffeneMenge/nCount)
                  ENDIF
                  hFertigung[we->Aufno] := nVerpackungen //remember how many packages will/are provided to this order
               ENDIF
               we->(dbSkip())
            ENDDO

            // Check for production orders where the final product itself needs this packaging
            wer->(dbSetOrder( 2 ))  // artno index
            wer->(dbSeek( Str(nArt,6) ))
            DO WHILE wer->Artno == nArt
               IF wer->Status >= 1 .AND. wer->Status < 4 .AND. wer->Qty > wer->GelQty           
                  nOffeneMenge := wer->Qty - wer->GelQty
                  nVerpackungen := Ceiling(nOffeneMenge/nCount)

                  // Track supplier total for final product
                  cSupplier := AllTrim(wer->Liefma)
                  IF Empty(cSupplier)
                     cSupplier := "INTERN"
                  ENDIF

                  IF ! HHasKey(hSupplierTotals, cSupplier)
                     hSupplierTotals[cSupplier] := 0
                     hSupplierSent[cSupplier] := 0
                  ENDIF
                  IF HHasKey(hFertigung, wer->Aufno) // if this order is already counted above, skip it
                     nSentBoxes := hFertigung[wer->Aufno]
                  else
                     nSentBoxes := 0
                  ENDIF
                  nVerpackungen := Max(0, nVerpackungen - nSentBoxes)
                  
                  IF nVerpackungen > 0
                     hSupplierTotals[cSupplier] += nVerpackungen
                     AAdd(aList, {nArt, art->Matchcode, "FERT.PROD.", Str(wer->Aufno,6), "", AllTrim(wer->Liefma), nOffeneMenge, nVerpackungen, nSentBoxes})                     
                     nTotal += nVerpackungen
                     nTotalSent += nSentBoxes
                  ENDIF
               ENDIF
               wer->(dbSkip())
            ENDDO
         ENDIF
      NEXT

   RETURN {"TOTAL"=>nTotal,"SENT"=>nTotalSent,"LAGER"=>nTotalLager,"LIST"=>aList,"FERTIGUNG"=>hFertigung,"SUPPLIERS"=>hSupplierTotals,"SUPPLIERS_SENT"=>hSupplierSent}
   

   FUNCTION GetBoxInitialQuantities()
      LOCAL aInitQty := {"BOXGEH50"=>815,"BOXTAST150"=>100,"BOXROS100"=>136,"BOXBIG50"=>26}   

   /** Initial Quantities   
   BOXGEH50: 
      Purchased: 1000 (4x220+120) (BE27447,BE29691,BE49655,BE56282,BE60488)
      Modified to BOXBIG50: 26
      Remaining: 974
      Missing: 159 (22.10.25)
   
   BOXTAST150:
      Purchased: 100 (BE60488)

   BOXROS100:
      Purchased: 136 (BE25490)  

   BOXBIG50:
      Modified from BOXGEH50: 26
   **/   
   
   RETURN aInitQty



