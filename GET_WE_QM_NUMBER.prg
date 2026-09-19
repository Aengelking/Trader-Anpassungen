/*
 * GET_WE_QM_NUMBER  -  reserviert beim Wareneingang die QM-Pruefnummer.
 * ---------------------------------------------------------------------
 * Aufruf aus wareneingang.prg unmittelbar vor StickPrint("WARE"), also
 * waehrend der Mengeneingabe und VOR dem Buchen. Artikel, Lieferant,
 * Lieferschein, Bestellung und Menge stehen da bereits fest; Charge und
 * Lagerort kommen erst spaeter und werden von AFTER_BOOK_WE nachgereicht.
 *
 * Rueckgabe ist der hFieldMap fuer das Warenetikett (WARE.lbex). Der Hook
 * darf niemals werfen: ein Problem mit dem Portal darf weder den
 * Etikettendruck noch den Wareneingang aufhalten - dann wird das Etikett eben
 * ohne Nummer gedruckt und die Meldung laeuft ueber die Nachlauf-Queue.
 */

FUNCTION HOOK_GET_WE_QM_NUMBER(oBesPos, oArt, hData, cBeleg)
   LOCAL hQm
   LOCAL hRet := {=>}

   BEGIN SEQUENCE WITH {|e| Break(e)}
      hQm := MBaseRun(Path("run\qm_we_register"), {"reserve", oBesPos, oArt, hData, cBeleg})

      IF ValType(hQm) == "H" .AND. "inspection_number" $ hQm
         hRet["qm_number"]         := Trim(hQm["inspection_number"])
         hRet["qm_number_barcode"] := Trim(hQm["inspection_number"])
      ENDIF
   RECOVER
   END SEQUENCE
RETURN hRet
