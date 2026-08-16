/*
 * portalanfrage.prg  -  Convert a 0-price quote (Angebot) into portal enquiries.
 * -----------------------------------------------------------------------
 * Phase 3 of "0-price quote -> portal enquiry". Reads a quote (angebot),
 * takes the positions whose sales price is 0 (= to be sourced), groups them by
 * their SET of active suppliers, and pushes one DRAFT enquiry per supplier-set
 * to the edge function `import-enquiry`:
 *   - positions with the same set of suppliers are combined into one enquiry,
 *   - recipients of that enquiry = exactly that supplier set.
 *
 * Runs in the Trader DESKTOP context. Invoked via the trader: protocol
 * (opaque, '&' separator):
 *
 *   trader:-R&portalanfrage&{"<angebotsnr>","<erp_firm_id>"}
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
   LOCAL cCustomer := "", hBody, aHeader, nStatus := 0, cResponse := "", oRest, g
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

   // group the 0-price positions by their set of active suppliers
   FOR EACH hPart IN aParts
      aSup := PS_CollectSuppliers(hPart["artikelnr"])   // read-only (Prio 9 = deaktiviert ausgeschlossen)
      IF Len(aSup) == 0
         AAdd(aNoSup, hPart["article_number"])
         LOOP
      ENDIF
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

   IF nStatus >= 200 .AND. nStatus < 300
      Tr_MsgBox("Angebot " + LTrim(Str(nAngnr)) + ": " + LTrim(Str(Len(aGroups))) + ;
                " Anfrage(n) als Entwurf angelegt." + ;
                IF(Len(aNoSup) > 0, Chr(13) + "Ohne Lieferant (nicht angefragt): " + _pfJoin(aNoSup), "") + ;
                Chr(13) + _pfStr(cResponse))
   ELSE
      Tr_MsgBox("Anfrage-Erstellung fehlgeschlagen (HTTP " + LTrim(Str(nStatus)) + ")." + Chr(13) + _pfStr(cResponse))
   ENDIF
RETURN


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


// PS_CollectSuppliers() for the supplier grouping (bottom #include does not
// hijack the entry point; first public proc PortalAnfrage wins).
#include 'x:\run\portalsuppliers.prg'
