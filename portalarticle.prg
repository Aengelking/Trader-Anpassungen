/*
 * portalarticle.prg  -  Push an article's master data (+ BOM as consigned
 * parts) to the supplier portal so a saved_articles record exists.
 * -----------------------------------------------------------------------
 * Phase 2 of "0-price quote -> portal enquiry": before a quote position can
 * become an enquiry item, the article must exist in the portal. This run-
 * script gathers the article stock data and, for manufactured articles, its
 * bill of materials (as consigned parts, position -1 excluded) and POSTs it to
 * the edge function `import-article`, which upserts saved_articles.
 *
 * Runs in the Trader DESKTOP context. Invoked via the trader: protocol
 * (opaque, '&' separator):
 *
 *   trader:-R&portalarticle&{"<artikelnr>","<erp_firm_id>"}
 *
 * The drawing FILE itself is a separate push (portaldrawing); this only carries
 * the drawing NUMBER/INDEX/customer flag as metadata.
 *
 * Config: keychain "PORTALDRW" (shared push secret) -> header x-import-secret.
 */

PROCEDURE PortalArticle(cArtNr, cFirm)
   LOCAL nArt  := Val(_paStr(cArtNr))
   LOCAL nFirm := Val(_paStr(cFirm))
   LOCAL cMsg := ""

   IF nArt <= 0
      Tr_MsgBox("Keine Artikelnummer uebergeben.")
      RETURN
   ENDIF

   PA_PushArticle(nArt, nFirm, @cMsg)
   Tr_MsgBox(cMsg)
RETURN


// Gather the article master data (+ BOM as consigned parts) and POST it to
// import-article, then upload the drawing file. Sets cMsg (by ref) and returns
// the import-article HTTP status (or -1 when the article was not found).
// Shared so portalanfrage.prg can ensure an article before enquiring.
STATIC FUNCTION PA_PushArticle(nArt, nFirm, cMsg)
   LOCAL hBody, aHeader, nStatus := 0, cResponse := "", oRest
   LOCAL cMatch, cName, cUnit, cDrw, cIdx, lKu, lObs, lManu, aBom, cDrawMsg := ""
   LOCAL cUrl := "https://jjxieivxbnkjoboiysaj.supabase.co/functions/v1/import-article"

   lManu := ArtIsManufactured(nArt)          // eigene NetUse/SaveEnv/RestEnv -> zuerst

   NetUse("artikel", "art")
   art->(dbSetOrder(2))                       // index 2 = artikelnr
   IF ! art->(dbSeek(Str(nArt, 6)))
      art->(dbCloseArea())
      cMsg := "Artikel " + LTrim(Str(nArt)) + " nicht in der aktuellen Firma gefunden."
      RETURN -1
   ENDIF

   cMatch := Trim(art->Matchcode)
   cName  := Trim(_paDesc())
   cUnit  := Trim(art->Me)
   cDrw   := Trim(art->Zeichnung)
   cIdx   := Trim(art->Zeichindex)
   lKu    := art->KuZeichnun
   lObs   := art->Obsolete

   aBom := _paCollectBom(nArt, lManu)         // uses "art" for component lookups

   art->(dbCloseArea())

   hBody := { ;
      "erp_firm_id"         => nFirm, ;
      "erp_article_id"      => nArt, ;
      "article_number"      => hb_strtoutf8(cMatch), ;
      "name"                => hb_strtoutf8(cName), ;
      "unit"                => hb_strtoutf8(cUnit), ;
      "drawing_number"      => hb_strtoutf8(cDrw), ;
      "drawing_index"       => hb_strtoutf8(cIdx), ;
      "is_customer_drawing" => lKu, ;
      "obsolete"            => lObs, ;
      "consigned_parts"     => aBom }

   aHeader := { "Content-Type: application/json", "x-import-secret: $APIKEY$" }

   oRest := RestApi():New()
   oRest:cBaseUrl := ""
   oRest:cApiKeyName := "PORTALDRW"
   oRest:Execute(cUrl, "POST", hBody, aHeader, .T., @nStatus, @cResponse)

   IF nStatus >= 200 .AND. nStatus < 300
      // Artikel ist jetzt im Portal -> Zeichnungsdatei gleich mit hochladen
      // (import-article-drawing findet den Artikel ueber erp_article_id+firm).
      PD_PushDrawing(nArt, nFirm, @cDrawMsg)
      cMsg := "Artikel " + cMatch + " uebergeben (" + LTrim(Str(Len(aBom))) + ;
              " Beistellteile). " + _paStr(cResponse) + " | Zeichnung: " + cDrawMsg
   ELSE
      cMsg := "Artikel-Upload fehlgeschlagen (HTTP " + LTrim(Str(nStatus)) + "). " + _paStr(cResponse)
   ENDIF
RETURN nStatus


// BOM of a manufactured article as consigned parts. Position -1 is skipped.
// Reuses the open "art" alias for component lookups (parent fields must be
// captured by the caller BEFORE this runs).
STATIC FUNCTION _paCollectBom(nArt, lManu)
   LOCAL aBom := {}
   IF ! lManu
      RETURN aBom
   ENDIF
   NetUse("parts", "part")
   part->(dbSetOrder(1))                       // index 1 = Listart + Pos
   part->(dbSeek(Str(nArt, 6)))
   DO WHILE ! part->(EOF()) .AND. part->Listart == nArt
      IF part->Pos != -1
         art->(dbSeek(Str(part->Partart, 6)))  // component
         AAdd(aBom, { ;
            "part_name"        => hb_strtoutf8(Trim(art->Matchcode)), ;
            "part_description" => hb_strtoutf8(Trim(_paDesc())), ;
            "quantity"         => _paFld("part", "Qty", 0), ;
            "unit"             => hb_strtoutf8(Trim(art->Me)), ;
            "sort_order"       => part->Pos })
      ENDIF
      part->(dbSkip())
   ENDDO
   part->(dbCloseArea())
RETURN aBom


// description reader for the current "art" record (may be char or memo)
STATIC FUNCTION _paDesc()
   LOCAL xVal := art->Artikel
RETURN IF(ValType(xVal) $ "CM", xVal, "")

STATIC FUNCTION _paStr(x)
   DO CASE
   CASE ValType(x) == "C" ; RETURN x
   CASE ValType(x) == "N" ; RETURN hb_ntos(x)
   ENDCASE
RETURN ""

STATIC FUNCTION _paFld(cAlias, cField, xDef)
   LOCAL nPos := (cAlias)->(FieldPos(cField))
   IF nPos > 0
      RETURN (cAlias)->(FieldGet(nPos))
   ENDIF
RETURN xDef


// Reuse the drawing upload core (PD_PushDrawing) - a bottom #include with public
// procs does NOT hijack the entry point (first public proc PortalArticle wins).
#include 'x:\run\portaldrawing.prg'
