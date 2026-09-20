#define CRLF Chr(13)+Chr(10)
FUNCTION HOOK_AFTER_BOOK_WE(hData,oBesPos,oArt)
   LOCAL cGrund,aTo
   LOCAL cText
   LOCAL cNotes
   LOCAL hQm

   Default(@oArt,oBesPos:oArtikel)

   //HB_SYMBOL_UNUSED(oBesPos)

   //QM-Portal: den jetzt gebuchten Wareneingang bestaetigen. Beim
   //Etikettendruck wurde die Nummer nur reserviert - erst hier stehen Menge,
   //Charge und Lagerort endgueltig fest, und erst hier entsteht die Pruefung.
   //Wurde kein Etikett gedruckt, gab es auch keine Reservierung; derselbe
   //Aufruf legt den Datensatz dann direkt an. Ein Fehler darf hier nichts
   //mehr aufhalten - gebucht ist gebucht.
   BEGIN SEQUENCE WITH {|e| Break(e)}
      hQm := MBaseRun(Path("run\qm_we_register"),{"confirm",oBesPos,oArt,hData,hData:cBeleg})
      IF ValType(hQm) == "H" .AND. "decision" $ hQm .AND. hQm["decision"] == "new"
         SendMessage("Qualitaet | Pruefung angelegt", ;
                     "Wareneingangspruefung "+Trim(hQm["inspection_number"])+" angelegt", ;
                     "Artikel: "+Trim(oBesPos:oArtikel:Matchcode)+CRLF+ ;
                     "Lieferant: "+Trim(oBesPos:Liefma)+CRLF+ ;
                     "Lieferschein: "+Trim(hData:cBeleg)+CRLF+ ;
                     "Menge: "+LTrim(Str(hData:nMenge))+CRLF+ ;
                     "Grund: "+Trim(hQm["reason"]))
      ENDIF
   RECOVER
   END SEQUENCE

   MbaseRun(Path("run\print_batch_labels"),{hData:cCharge})   
   
   IF HHasKey(hData,"CLAGERORT")
      NetUse("lagerort","lago")
      lago->(dbSeek(hData:cLagerort))
      IF lago->SperrLager .AND. (! lago->TempSperr .OR. Left(hData:cLagerort,3) == "093")
         cGrund := MBaseRun(Path("run\print_sperrvermerk"),{.T.,oBesPos:Liefma,hData:cBeleg})
         
         /*IF Date() >= GetValue("HOLIDAY-AMOS-START") .AND. Date() <= GetValue("HOLIDAY-AMOS-END")
            aTo := {{"joel.engelking@engelking.de","Joel"}}
         ELSE
            aTo := {{"amos.engelking@engelking.de","Amos"}}
         ENDIF 
         SendMail(aTo,Trim(art->Matchcode)+" wurde im WE gesperrt","Lagerort:"+hData:cLagerort+CRLF+"Menge: "+Transform(hData:nMenge,Me(art->Me))+CRLF+cGrund)*/
         SendMessage("Qualitaet | Artikel gesperrt","Artikel "+Trim(art->Matchcode)+" wurde im WE gesperrt","Lagerort:"+hData:cLagerort+CRLF+"Menge: "+Transform(hData:nMenge,Me(art->Me))+CRLF+cGrund)

         MBAseRun(Path("run\inform_sales_stock_block"),{art->Artikelnr,hData:nMenge})
      ENDIF
   ENDIF
   IF AddWeeks(bes->wterm,bes->ShipTime*-1) > CWeek(Date())      
      cText := "Bestellung: "
      cText += LTrim(Str(oBesPos:Besnr))+CRLF
      cText += "Pos: " 
      cText += LTrim(Str(oBesPos:Posnr))+CRLF
      cText += "Artikel: "
      cText += oBesPos:oArtikel:Matchcode+CRLF
      cText += "Menge: "
      cText += LTrim(Str(hData:nMenge))+CRLF
      cText += "Lieferschein: "
      cText += hData:cBeleg+CRLF
      cText += "Wunschtermin: "
      cText += NiceWeek(bes->wterm)           

      SendMail({{"amos.engelking@engelking.de","Amos"}},"Wareneingang zu frÅh "+LTrim(Str(oBesPos:Besnr))+" Bestellung ",cText)
   ENDIF
RETURN NIL