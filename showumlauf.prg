
#command @ <top>,<left>,<bottom>,<right> GET <var> LISTBOX <hash> ASSOCIATIVE ;
	[VALID <valid>];
	[WHEN <when>];
	[COLOR <color>];
;
=> GET_AssociativeListBox(getlist,<top>,<left>,<bottom>,<right>,{|v| If(v==NIL,<var>,<var>:=v)},<hash>,<{valid}>, <{when}>,<color>)


PROC RUN_ShowUmlaufVerp()
   LOCAL aArt := {}
   LOCAL cDbId := Pad("ART",5)
   LOCAL cField := Pad("UMLAUF",10)
   LOCAL hVerpack := {=>}
   LOCAL getlist := {}
   LOCAL nArt,cVerp := "",nCount,aMatch
   LOCAL nTotal := 0, nVerpackungen := 0, nOffeneMenge := 0
   LOCAL nInitial := 0, nRemaining
   LOCAL cExludeLager := "000/0[3,4]A.*"
   LOCAL oExtra
   LOCAL hFertigung 
   LOCAL lPrint
   LOCAL hSupplierTotals := {=>}  // Hash to track totals by supplier
   LOCAL hSupplierSent := {=>}    // Hash to track boxes already sent to suppliers
   LOCAL cSupplier, aSuppliers, nSupplierTotal, nSentBoxes
   LOCAL oBesExtra

   LOCAL aInitQty := {"BOXGEH50"=>974,"BOXTAST150"=>100,"BOXROS100"=>136,"BOXBIG50"=>26}

   /** Initial Quantities   
   BOXGEH50: 
      Purchased: 1000 (4x220+120)
      Modified to BOXBIG50: 26
      Remaining: 974
   
   BOXTAST150:
      Purchased: 100

   BOXROS100:
      Purchased: 136         

   BOXBIG50:
      Modified from BOXGEH50: 26
   **/

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
      READ

      IF LastKey() == 27
         RETURN
      ENDIF

      //get all parts with Umlaufverpackungen
      aArt := GetIdsWithExtraField(cDbID,Trim(cField))

      aMatch := HB_Regex("[0-9]+" ,cVerp) // check if cVerp is a number
      IF Len(aMatch) == 0
         Tr_MsgBox("Umlaufverpackung enthÑlt keine Zahl!")
         LOOP
      ENDIF

      nCount := Val(aMatch[1]) // convert to number
      nTotal := 0  // Reset total for each package selection
      hFertigung := {=>} // reset production order tracking
      hSupplierTotals := {=>} // reset supplier totals
      hSupplierSent := {=>} // reset sent boxes tracking

      // Clear screen and prepare for display
      lPrint := Tr_MsgBox("Drucken?",,{"anzeigen","drucken"}) == 2
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
                  ? Str(nArt,6) + " " + ;
                    art->Matchcode + " " + ;
                    PadR("LAGER", 10) + " " + ;
                    PadR("", 6) + " " + ;
                    PadR("", 3) + " " + ;
                    PadR(lag->Lagerort, 12) + " " + ;
                    PadL(Transform(lag->LagerMenge,Me(art->Me)),8) + " " + ;
                    Str(nVerpackungen, 8)
                  nTotal += nVerpackungen
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
                  
                  ? Str(nArt,6) + " " + ;
                    art->Matchcode + " " + ;
                    PadR("BESTELLUNG", 10) + " " + ;
                    Str(bes->Besnr, 6) + " " + ;
                    Pad(Ltrim(Str(bes->Posnr, 3)),3) + " " + ;
                    PadR(AllTrim(bes->Liefma), 12) + " " + ;
                    PadL(Transform(nOffeneMenge, Me(art->Me)),8)  + " " + ;                    
                    Str(nVerpackungen, 8) + " " + ;
                    Str(nSentBoxes,8)  
                    
                  nTotal += nVerpackungen
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

                     ?  Str(nArt,6) + " " + ;
                        art->Matchcode + " " + ;
                        PadR("FERTIGUNG", 10) + " " + ;
                        Str(we->Aufno, 6) + " " + ;
                        Space(3) + " " + ;
                        PadR(AllTrim(wer->Liefma), 12) + " " + ;
                        PadL(Transform(nOffeneMenge, Me(art->Me)),8)  + " " + ;                        
                        Str(nVerpackungen, 8),;
                        Str(nVerpackungen,8)
                     nTotal += nVerpackungen
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
                    
                     ? Str(nArt,6) + " " + ;
                        art->Matchcode + " " + ;
                        PadR("FERT.PROD.", 10) + " " + ;
                        Str(wer->Aufno, 6) + " " + ;
                        Space(3) + " " + ;
                        PadR(AllTrim(wer->Liefma), 12) + " " + ;
                        PadL(Transform(nOffeneMenge, Me(art->Me)),8)  + " " + ;                        
                        Str(nVerpackungen, 8),;
                        Str(nSentBoxes,8)
                     nTotal += nVerpackungen
                  ENDIF
               ENDIF
               wer->(dbSkip())
            ENDDO
         ENDIF
      NEXT

      

      ? ""
      ? Replicate("=", 110)
      ? PadR("GESAMTSUMME VERPACKUNGEN:", 77) + Str(nTotal, 8)
      
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
         nRemaining := nInitial - nTotal
         
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


