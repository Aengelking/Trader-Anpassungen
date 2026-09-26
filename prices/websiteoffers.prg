// Im Browser erfasste Konkurrenzpreise aus der Website-Datenbank (competitor_offers) lesen.
//
// Die Preise erfasst ein Mitarbeiter mit der Browser-Erweiterung "Engelking Konkurrenzpreise"
// (Repo engelking-website, browser-extension/) auf der Produktseite des Shops. Gespeichert
// werden Netto-Stueckpreise in EUR. Abruf ueber die Edge Function erp-competitor-offers,
// Schluessel "WEBSITE" (wie der Website-Sync).
//
// Wird per #include eingebunden (prices/updcompet.prg, prices/capture.prg).

// Angebote zum Artikel als Array von Hashes (Felder wie in competitor_offers:
// distributor, part_number, url, price_breaks, captured_at, captured_by ...),
// NIL wenn die Website nicht erreichbar war.
STATIC FUNCTION WebCompetOffers(nArtnr, cMpn)
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
RETURN hResp["offers"]

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
