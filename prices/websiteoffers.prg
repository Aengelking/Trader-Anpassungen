// Im Browser erfasste Konkurrenzpreise aus der Website-Datenbank (competitor_offers) lesen.
//
// Die Preise erfasst ein Mitarbeiter mit der Browser-Erweiterung "Engelking Konkurrenzpreise"
// (Repo engelking-website, browser-extension/) auf der Produktseite des Shops. Gespeichert
// werden Netto-Stueckpreise in EUR. Abruf ueber die Edge Function erp-competitor-offers,
// Schluessel "WEBSITE" (wie der Website-Sync).
//
// Wird per #include eingebunden (prices/updcompet.prg, prices/capture.prg).

// Antwort der Website als Hash {"offers"=>{...}, "not_found"=>{...}}, NIL wenn nicht erreichbar.
//   offers:    erfasste Angebote (Felder wie in competitor_offers: distributor, part_number,
//              url, price_breaks, captured_at, captured_by, distributor_key ...)
//   not_found: Shops, deren Suche nichts fand (distributor, distributor_key, checked_at)
// distributor_key ist der Shopname nur mit A-Z/0-9 (Buerklin -> BUERKLIN) = Trader-Kuerzel.
STATIC FUNCTION WebCompetResponse(nArtnr, cMpn)
   LOCAL oRest := RestApi():New()
   LOCAL cResp, hResp

   oRest:cBaseUrl := "https://kooxwelqbqplbryoxbya.supabase.co/"
   oRest:cApiKeyName := "WEBSITE"
   cResp := oRest:Execute("functions/v1/erp-competitor-offers", "POST", ;
      {"mpns"=>{hb_StrToUTF8(cMpn)}, "trader_artikelnr"=>{nArtnr}}, ;
      {"Authorization: Bearer $APIKEY$"}, .T.)

   hResp := IF(Empty(cResp), NIL, HB_JsonDecode(cResp))
   IF ValType(hResp) != "H" .OR. ! HHasKey(hResp,"offers") .OR. ValType(hResp["offers"]) != "A"
      RETURN NIL
   ENDIF
   IF ! HHasKey(hResp,"not_found") .OR. ValType(hResp["not_found"]) != "A"
      hResp["not_found"] := {}
   ENDIF
RETURN hResp

// Angebote zum Artikel als Array von Hashes, NIL wenn die Website nicht erreichbar war.
STATIC FUNCTION WebCompetOffers(nArtnr, cMpn)
   LOCAL hResp := WebCompetResponse(nArtnr, cMpn)
RETURN IF(hResp == NIL, NIL, hResp["offers"])

// Trader-Kuerzel der Shops, deren Suche nach cMpn in den letzten nMaxAge Tagen nichts fand
STATIC FUNCTION WebCompetNotFound(hResp, nMaxAge)
   LOCAL aCodes := {}, nX, hRow
   IF hResp == NIL
      RETURN aCodes
   ENDIF
   FOR nX := 1 TO Len(hResp["not_found"])
      hRow := hResp["not_found"][nX]
      IF ValType(hRow) == "H" .AND. HHasKey(hRow,"distributor_key") .AND. HHasKey(hRow,"checked_at") ;
         .AND. ValType(hRow["distributor_key"]) == "C" .AND. ValType(hRow["checked_at"]) == "C" ;
         .AND. StoD(StrTran(Left(hRow["checked_at"],10),"-","")) >= Date()-nMaxAge
         Aadd(aCodes, hRow["distributor_key"])
      ENDIF
   NEXT
RETURN aCodes

// Staffel eines Angebots als Hash {Menge=>Stueckpreis}
STATIC FUNCTION WebCompetPrices(hOffer)
   LOCAL hPrices := {=>}
   LOCAL aBreaks := IF(HHasKey(hOffer,"price_breaks"), hOffer["price_breaks"], NIL)
   LOCAL nX

   IF ValType(aBreaks) == "A"
      FOR nX := 1 TO Len(aBreaks)
         IF ValType(aBreaks[nX]) == "H" .AND. ValType(aBreaks[nX]["qty"]) == "N" .AND. ValType(aBreaks[nX]["price"]) == "N" ;
            .AND. aBreaks[nX]["qty"] > 0 .AND. aBreaks[nX]["price"] > 0
            hPrices[aBreaks[nX]["qty"]] := aBreaks[nX]["price"]
         ENDIF
      NEXT
   ENDIF
RETURN hPrices

// Erfassungsdatum aus "2026-09-26T10:28:35.031+00:00"
STATIC FUNCTION WebCompetDate(hOffer)
   IF ! HHasKey(hOffer,"captured_at") .OR. ValType(hOffer["captured_at"]) != "C"
      RETURN StoD("")
   ENDIF
RETURN StoD(StrTran(Left(hOffer["captured_at"],10),"-",""))

// Staffeln aller Angebote, die hoechstens nMaxAge Tage alt sind: {{cShop,hPrices,dErfasst},...}
// NIL wenn die Website nicht erreichbar war.
STATIC FUNCTION WebCompetPriceLists(nArtnr, cMpn, nMaxAge)
   LOCAL aOffers := WebCompetOffers(nArtnr, cMpn)
   LOCAL aLists := {}
   LOCAL hPrices, nX

   IF aOffers == NIL
      RETURN NIL
   ENDIF
   FOR nX := 1 TO Len(aOffers)
      IF ValType(aOffers[nX]) == "H" .AND. WebCompetDate(aOffers[nX]) >= Date()-nMaxAge
         hPrices := WebCompetPrices(aOffers[nX])
         IF Len(hPrices) > 0
            Aadd(aLists, {hb_UTF8ToStr(aOffers[nX]["distributor"]), hPrices, WebCompetDate(aOffers[nX])})
         ENDIF
      ENDIF
   NEXT
RETURN aLists
