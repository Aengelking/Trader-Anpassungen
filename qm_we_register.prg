/*
 * qm_we_register.prg  -  meldet einen Wareneingang an das QM-Portal.
 * ------------------------------------------------------------------
 * Aufruf aus den Hooks:
 *   GET_WE_QM_NUMBER  mit "reserve"  (vor dem Druck des Warenetiketts)
 *   AFTER_BOOK_WE     mit "confirm"  (nach dem Buchen)
 *
 * Der Payload wird bewusst HIER gebaut und nicht in den Hooks: der trader_ref
 * ist der Idempotenz-Schluessel, derselbe Wareneingang muss in beiden Phasen
 * exakt denselben Schluessel liefern. Jede Hook-Datei wird einzeln kompiliert
 * und sieht die Funktionen der anderen nicht - eine zweite Kopie der
 * Schluesselbildung wuerde frueher oder spaeter auseinanderlaufen.
 *
 * qs_required ist das Artikelstamm-Flag art->QS ("WE-QS Pruefung",
 * artikel_edit.prg:380). Ist es nicht gesetzt, legt das Portal fuer diesen
 * Artikel keine neue Pruefung an. Fehlt das Feld im Payload, wird geprueft -
 * die sichere Richtung.
 *
 * Rueckgabe: der Antwort-Hash des Portals
 *   { decision, status, inspection_number, inspection_id, plan_id, reason }
 * oder NIL, wenn das Portal nicht erreichbar war. In dem Fall liegt der
 * Payload in der Queue und RUN_QM_WE_RETRY traegt ihn nach - der
 * Wareneingang selbst laeuft normal weiter.
 */

FUNCTION RUN_QM_WE_REGISTER(cPhase, oBesPos, oArt, hData, cBeleg)
   LOCAL hPayload, hRet
   LOCAL nStatus := 0, cResponse := ""

   IF oBesPos == NIL .OR. ValType(hData) != "H"
      RETURN NIL
   ENDIF
   Default(@cPhase, "confirm")
   Default(@oArt, oBesPos:oArtikel)
   Default(@cBeleg, "")

   hPayload := QmWePayload(cPhase, oBesPos, oArt, hData, cBeleg)

   hRet := QmPost(hPayload, @nStatus, @cResponse)

   IF hRet == NIL
      IF nStatus >= 400 .AND. nStatus < 500
         // Der Payload passt nicht. Ein Nachlauf mit demselben Inhalt wuerde
         // genauso scheitern, also gleich als endgueltig markieren - aber
         // protokollieren, damit es in der Queue auffaellt.
         QmQueueAdd(hPayload, "HTTP " + LTrim(Str(nStatus)) + ": " + Left(cResponse, 200), "F")
      ELSE
         QmQueueAdd(hPayload, IF(nStatus == 0, "Keine Verbindung zum QM-Portal", "HTTP " + LTrim(Str(nStatus))), "O")
      ENDIF
   ENDIF
RETURN hRet

// Der gemeinsame Payload beider Phasen.
STATIC FUNCTION QmWePayload(cPhase, oBesPos, oArt, hData, cBeleg)
   LOCAL hRet

   hRet := { ;
      "phase"                   => cPhase, ;
      "firm_id"                 => GetConfigValue("FIRMNO"), ;
      "trader_ref"              => LTrim(Str(oBesPos:Besnr)) + "/" + ;
                                   LTrim(Str(oBesPos:Posnr)) + "/" + ;
                                   Trim(cBeleg) + "/" + ;
                                   LTrim(Str(oArt:Artikelnr)), ;
      "part_number"             => QmStr(oArt:Matchcode), ;
      "qs_required"             => IF(ValType(oArt:QS) == "L", oArt:QS, .T.), ;
      "supplier_number"         => QmStr(oBesPos:Liefma), ;
      "trader_supplier_id"      => LTrim(Str(QmSupplierNo(oBesPos:Liefma))), ;
      "delivery_note_number"    => QmStr(cBeleg), ;
      "quantity"                => hData:nMenge, ;
      "purchase_order_number"   => LTrim(Str(oBesPos:Besnr)), ;
      "purchase_order_position" => oBesPos:Posnr, ;
      "drawing_no"              => QmStr(oArt:Zeichnung), ;
      "drawing_index"           => QmStr(oArt:ZeichIndex), ;
      "receipt_date"            => DToS(Date()) }

   // Charge und Lagerort stehen erst beim Buchen fest.
   IF HHasKey(hData, "CCHARGE") .AND. ! Empty(hData:cCharge)
      hRet["batch_number"] := QmStr(hData:cCharge)
   ENDIF
   IF HHasKey(hData, "CLAGERORT") .AND. ! Empty(hData:cLagerort)
      hRet["storage_location"] := QmStr(hData:cLagerort)
   ENDIF
RETURN hRet

#include 'x:\run\qm_api.prg'
#include 'x:\run\qm_we_queue.prg'
