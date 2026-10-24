/*
 * portalanfrage.prg  -  Convert a 0-price quote (Angebot) into a portal enquiry.
 * -----------------------------------------------------------------------
 * Phase 3 of "0-price quote -> portal enquiry". Reads a quote (angebot),
 * takes the positions whose sales price is 0 (= to be sourced) and pushes them
 * as ONE DRAFT enquiry to the edge function `import-enquiry`.
 *
 * The positions are still grouped by their SET of active suppliers, but the
 * groups no longer split the enquiry - they only tell the portal which position
 * goes to which supplier:
 *   - recipients of the enquiry = the UNION of all supplier sets,
 *   - a position its recipient does not supply is de-selected for him there
 *     (enquiry_recipient_excluded_items), so he never gets to see it.
 * One quote is one enquiry: one mail per supplier and one price comparison over
 * the whole quote, instead of one enquiry per supplier set.
 *
 * Runs in the Trader DESKTOP context. Invoked via the trader: protocol
 * (opaque, '&' separator):
 *
 *   trader:-R&portalanfrage&{"<angebotsnr>","<erp_firm_id>"}
 *
 * Run twice for the same quote and the DRAFT of the first run is replaced, not
 * added to - one quote stays one enquiry. The portal only replaces when asked
 * to (replace_existing), so this asks first and names what hangs off that
 * draft: manual additions there are lost with it. Once the enquiry has been
 * SENT the import refuses (HTTP 409) instead of putting a second one in front
 * of the suppliers; changes then belong in the portal.
 *
 * PRECONDITION (Phase 4 will automate this): the articles and their suppliers
 * must already exist in the portal (run portalarticle / portalsuppliers first,
 * or the combined Phase-4 push). import-enquiry resolves saved_articles by
 * erp_article_id and organizations by erp_supplier_id; missing ones are skipped
 * and reported.
 *
 * Config: keychain "PORTALDRW" (shared push secret) -> header x-import-secret.
 *
 * Reuses PS_CollectSuppliers() from portalsuppliers.prg (bottom #include).
 */

PROCEDURE PortalAnfrage(cAngnr, cFirm)
   LOCAL nAngnr := Val(_pfStr(cAngnr))
   LOCAL nFirm  := Val(_pfStr(cFirm))
   LOCAL aParts, aGroups := {}, aNoSup := {}, hPart, aSup, hS, aIds, cKey, nG, nId
   LOCAL nPos := 0, aAllSup := {}
   LOCAL cCustomer := "", hBody, aHeader, nStatus := 0, cResponse := "", oRest, g
   LOCAL nArt, cM := ""
   LOCAL cUrl := "https://jjxieivxbnkjoboiysaj.supabase.co/functions/v1/import-enquiry"

   IF nAngnr <= 0
      Tr_MsgBox("Keine Angebotsnummer uebergeben.")
      RETURN
   ENDIF

   aParts := _pfZeroPriceParts(nAngnr, @cCustomer)
   IF Len(aParts) == 0
      Tr_MsgBox("Angebot " + LTrim(Str(nAngnr)) + ": keine 0-Preis-Positionen gefunden.")
      RETURN
   ENDIF

   // group the 0-price positions by their set of active suppliers - the portal
   // derives the per-recipient position selection from these groups
   FOR EACH hPart IN aParts
      nArt := hPart["artikelnr"]
      // Phase 4: Artikel (inkl. Zeichnung/Beistellteile) sicherstellen
      IF nArt > 0
         PA_PushArticle(nArt, nFirm, @cM)
      ENDIF
      aSup := PS_CollectSuppliers(nArt)                 // read-only (Prio 9 = deaktiviert ausgeschlossen)
      IF Len(aSup) == 0
         AAdd(aNoSup, hPart["article_number"])
         LOOP
      ENDIF
      // Phase 4: Lieferanten dieses Artikels anlegen (import-suppliers)
      PS_PushSuppliers(nFirm, nArt, aSup, @cM)
      aIds := {}
      FOR EACH hS IN aSup
         AAdd(aIds, hS["erp_supplier_id"])
      NEXT
      aIds := ASort(aIds)
      cKey := ""
      FOR EACH nId IN aIds
         cKey += Str(nId, 8)
      NEXT
      nG := AScan(aGroups, {|x| x["key"] == cKey})
      IF nG == 0
         AAdd(aGroups, { "key" => cKey, "supplier_erp_ids" => aIds, "positions" => {} })
         nG := Len(aGroups)
      ENDIF
      AAdd(aGroups[nG]["positions"], { ;
         "erp_article_id" => hPart["artikelnr"], ;
         "article_number" => hPart["article_number"], ;
         "name"           => hPart["name"], ;
         "quantity"       => hPart["quantity"], ;
         "unit"           => hPart["unit"] })
   NEXT

   IF Len(aGroups) == 0
      Tr_MsgBox("Angebot " + LTrim(Str(nAngnr)) + ": keine Position mit aktiven Lieferanten." + Chr(13) + ;
                "Ohne Zeichnung: " + _pfJoin(aNoSup))
      RETURN
   ENDIF

   // Kennzahlen fuer die Meldung: gesendete Positionen und Empfaenger der Anfrage
   // (der Lieferant haengt an mehreren Gruppen, gezaehlt wird er einmal).
   FOR EACH g IN aGroups
      nPos += Len(g["positions"])
      FOR EACH nId IN g["supplier_erp_ids"]
         IF AScan(aAllSup, nId) == 0
            AAdd(aAllSup, nId)
         ENDIF
      NEXT
   NEXT

   FOR EACH g IN aGroups           // internen Gruppierungs-Schluessel nicht mitsenden
      HB_HDel(g, "key")
   NEXT

   hBody := { ;
      "erp_firm_id"  => nFirm, ;
      "quote_number" => nAngnr, ;
      "customer"     => hb_strtoutf8(cCustomer), ;
      "sender_email" => Lower(AllTrim(_pfStr(SystemUser():Email))), ;
      "groups"       => aGroups }

   aHeader := { "Content-Type: application/json", "x-import-secret: $APIKEY$" }

   oRest := RestApi():New()
   oRest:cBaseUrl := ""
   oRest:cApiKeyName := "PORTALDRW"
   oRest:Execute(cUrl, "POST", hBody, aHeader, .T., @nStatus, @cResponse)

   // Steht zu dem Angebot schon ein Entwurf, ersetzt ihn das Portal nur auf
   // ausdrueckliche Anweisung: was jemand dort von Hand ergaenzt hat -
   // Empfaenger, Anhaenge, Texte - geht beim Ersetzen mit. Also erst fragen.
   IF nStatus == 409 .AND. _pfTxt(cResponse, "reason") == "draft_exists"
      IF Tr_MsgBox(_pfReplaceQuestion(nAngnr, cResponse),, {"Nein","Ja"}) != 2
         Tr_MsgBox("Abgebrochen. Der vorhandene Entwurf bleibt unveraendert.")
         RETURN
      ENDIF
      hBody["replace_existing"] := .T.
      oRest:Execute(cUrl, "POST", hBody, aHeader, .T., @nStatus, @cResponse)
   ENDIF

   IF nStatus >= 200 .AND. nStatus < 300
      Tr_MsgBox("Angebot " + LTrim(Str(nAngnr)) + ": Anfrage mit " + ;
                LTrim(Str(nPos)) + " Position(en) an " + LTrim(Str(Len(aAllSup))) + ;
                " Lieferant(en) als Entwurf angelegt." + ;
                IF(Len(aNoSup) > 0, Chr(13) + "Ohne Lieferant (nicht angefragt): " + _pfJoin(aNoSup), "") + ;
                _pfReplaceNote(cResponse) + ;
                Chr(13) + _pfStr(cResponse))
   ELSEIF nStatus == 409
      // Zu diesem Angebot steht im Portal schon eine versendete Anfrage. Sie
      // wird nicht ersetzt - sonst bekaeme jeder Lieferant eine zweite.
      Tr_MsgBox("Angebot " + LTrim(Str(nAngnr)) + ": im Portal liegt bereits eine " + ;
                "VERSENDETE Anfrage zu diesem Angebot." + Chr(13) + ;
                "Es wurde nichts angelegt - Aenderungen bitte im Portal an der " + ;
                "vorhandenen Anfrage vornehmen.")
   ELSE
      Tr_MsgBox("Anfrage-Erstellung fehlgeschlagen (HTTP " + LTrim(Str(nStatus)) + ")." + Chr(13) + _pfStr(cResponse))
   ENDIF
RETURN


// Rueckfrage vor dem Ersetzen. Sie nennt, was an dem vorhandenen Entwurf
// haengt - ohne diese Zahlen ist "Ersetzen?" keine Frage, die jemand
// beantworten kann.
STATIC FUNCTION _pfReplaceQuestion(nAngnr, cResponse)
   LOCAL xItems := _pfVal(cResponse, "existing_items")
   LOCAL xRecip := _pfVal(cResponse, "existing_recipients")
   LOCAL cWhat := ""

   IF ValType(xItems) == "N" .AND. ValType(xRecip) == "N"
      cWhat := " (" + hb_ntos(xItems) + " Position(en), " + ;
               hb_ntos(xRecip) + " Empfaenger)"
   ENDIF
RETURN "Angebot " + LTrim(Str(nAngnr)) + ": im Portal steht bereits ein " + ;
       "Entwurf" + cWhat + "." + Chr(13) + ;
       "Ersetzen? Was dort von Hand ergaenzt wurde - Empfaenger, Anhaenge, " + ;
       "Texte - geht dabei verloren."


// Hinweis auf einen ersetzten Entwurf: die Meldung soll es benennen und nicht
// nur im JSON-Rumpf stehen lassen.
STATIC FUNCTION _pfReplaceNote(cResponse)
   LOCAL xIds := _pfVal(cResponse, "replaced_enquiry_ids")

   IF ValType(xIds) == "A" .AND. Len(xIds) > 0
      RETURN Chr(13) + "Der vorhandene Entwurf zu diesem Angebot wurde ersetzt."
   ENDIF
RETURN ""


// Ein Feld aus der JSON-Antwort. NIL, wenn die Antwort kein Objekt ist oder das
// Feld fehlt - der Aufrufer prueft den Typ und faellt sonst auf den Normalfall
// zurueck.
STATIC FUNCTION _pfVal(cResponse, cKey)
   LOCAL xData := hb_jsonDecode(_pfStr(cResponse))

   IF ValType(xData) == "H" .AND. HHasKey(xData, cKey)
      RETURN xData[cKey]
   ENDIF
RETURN NIL


// Dasselbe als Zeichenkette. Fehlt das Feld, kommt "" statt NIL zurueck: ein
// Vergleich NIL == "..." waere ein Laufzeitfehler, und eine Antwort ohne das
// Feld ist der Normalfall (jede erfolgreiche Antwort hat kein "reason").
STATIC FUNCTION _pfTxt(cResponse, cKey)
   LOCAL xVal := _pfVal(cResponse, cKey)
RETURN IF(ValType(xVal) == "C", xVal, "")


// Read the quote and return its 0-price positions (one per part matchcode):
// { artikelnr, article_number, name, quantity, unit }. A part counts as
// "to source" when NONE of its price tiers has a price > 0. cCustomer (by ref)
// receives the customer matchcode of the quote.
STATIC FUNCTION _pfZeroPriceParts(nAngnr, cCustomer)
   LOCAL hSeen := {=>}, cM, hP, aOut := {}

   NetUse("angebot", "ang")
   NetUse("artikel", "art")
   ang->(dbSetOrder(1))                        // Angnr
   art->(dbSetOrder(1))                        // Matchcode

   ang->(dbSeek(Str(nAngnr, 6)))
   DO WHILE ang->Angnr == nAngnr .AND. ! ang->(EOF())
      cM := Trim(ang->Matchcode)
      IF Empty(cCustomer)
         cCustomer := Trim(ang->Kundma)
      ENDIF
      IF ! Empty(cM) .AND. Upper(Left(cM, 4)) != "TEXT"
         IF ! HHasKey(hSeen, cM)
            hSeen[cM] := { "name" => hb_strtoutf8(Trim(ang->Artikel)), ;
                           "qty" => ang->VkQty, "priced" => (ang->VkPr > 0) }
         ELSE
            hP := hSeen[cM]
            hP["qty"] := Max(hP["qty"], ang->VkQty)
            IF ang->VkPr > 0
               hP["priced"] := .T.
            ENDIF
         ENDIF
      ENDIF
      ang->(dbSkip())
   ENDDO

   FOR EACH hP IN hSeen
      cM := hP:__enumKey()
      IF ! hP["priced"]                        // kein Preis -> anzufragen
         IF art->(dbSeek(cM)) .AND. Upper(Trim(art->Matchcode)) == Upper(cM)
            AAdd(aOut, { "artikelnr" => art->Artikelnr, "article_number" => cM, ;
                         "name" => hP["name"], "quantity" => hP["qty"], ;
                         "unit" => hb_strtoutf8(Trim(art->Me)) })
         ELSE
            AAdd(aOut, { "artikelnr" => 0, "article_number" => cM, ;
                         "name" => hP["name"], "quantity" => hP["qty"], "unit" => "" })
         ENDIF
      ENDIF
   NEXT

   ang->(dbCloseArea())
   art->(dbCloseArea())
RETURN aOut


STATIC FUNCTION _pfStr(x)
   DO CASE
   CASE ValType(x) == "C" ; RETURN x
   CASE ValType(x) == "N" ; RETURN hb_ntos(x)
   ENDCASE
RETURN ""

STATIC FUNCTION _pfJoin(a)
   LOCAL c := "", x
   FOR EACH x IN a
      c += IF(Empty(c), "", ", ") + _pfStr(x)
   NEXT
RETURN c


// Reusable push helpers (bottom #include does not hijack the entry point;
// first public proc PortalAnfrage wins):
//   portalsuppliers.prg -> PS_CollectSuppliers / PS_PushSuppliers
//   portalarticle.prg   -> PA_PushArticle (+ portaldrawing.prg / PD_PushDrawing)
#include 'x:\run\portalsuppliers.prg'
#include 'x:\run\portalarticle.prg'
