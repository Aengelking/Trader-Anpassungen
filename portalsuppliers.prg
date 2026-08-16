/*
 * portalsuppliers.prg  -  Push all suppliers of an article to the supplier
 * portal so the organizations exist before an enquiry is created.
 * -----------------------------------------------------------------------
 * Phase 1 of the "0-price quote -> portal enquiry" system: before an article
 * can be enquired in the portal, ALL its Trader suppliers must exist there as
 * organizations. This run-script gathers them from artlief + engkund and POSTs
 * them to the edge function `import-suppliers`, which creates the missing ones.
 *
 * Runs in the Trader DESKTOP context. Invoked via the trader: protocol
 * (opaque, no // -> browser adds no trailing slash), '&' as separator:
 *
 *   trader:-R&portalsuppliers&{"<artikelnr>","<erp_firm_id>"}
 *
 * Config: keychain "PORTALDRW" (shared push secret) -> header x-import-secret.
 *
 * The supplier-collecting helper (PS_CollectSuppliers) is STATIC so a later
 * quote-conversion script can #include this file and reuse it per article.
 */

PROCEDURE PortalSuppliers(cArtNr, cFirm)
   LOCAL nArt  := Val(_psStr(cArtNr))
   LOCAL nFirm := Val(_psStr(cFirm))
   LOCAL aSup, hBody, aHeader, nStatus := 0, cResponse := "", oRest
   LOCAL cUrl := "https://jjxieivxbnkjoboiysaj.supabase.co/functions/v1/import-suppliers"

   IF nArt <= 0
      Tr_MsgBox("Keine Artikelnummer uebergeben.")
      RETURN
   ENDIF

   aSup := PS_CollectSuppliers(nArt)
   IF Len(aSup) == 0
      Tr_MsgBox("Keine Lieferanten (artlief) fuer Artikel " + LTrim(Str(nArt)) + " gefunden.")
      RETURN
   ENDIF

   hBody := { "erp_firm_id" => nFirm, "article" => nArt, "suppliers" => aSup }
   aHeader := { "Content-Type: application/json", "x-import-secret: $APIKEY$" }

   oRest := RestApi():New()
   oRest:cBaseUrl := ""
   oRest:cApiKeyName := "PORTALDRW"            // shared push secret (keychain, max 10 chars)
   oRest:Execute(cUrl, "POST", hBody, aHeader, .T., @nStatus, @cResponse)

   IF nStatus >= 200 .AND. nStatus < 300
      Tr_MsgBox(LTrim(Str(Len(aSup))) + " Lieferant(en) an das Portal uebergeben." + Chr(13) + _psStr(cResponse))
   ELSE
      Tr_MsgBox("Lieferanten-Upload fehlgeschlagen (HTTP " + LTrim(Str(nStatus)) + ")." + Chr(13) + _psStr(cResponse))
   ENDIF
RETURN


// Collect the distinct suppliers of an article from artlief (order 5 =
// Artikelnr + Kunde) resolved against engkund (group "L"). One entry per
// supplier matchcode.
STATIC FUNCTION PS_CollectSuppliers(nArt)
   LOCAL aSup := {}, aSeen := {}, cMatch

   NetUse("artlief", "ali")
   NetUse("engkund", "ku")
   ali->(dbSetOrder(5))                        // Artikelnr + Kunde
   ku->(dbSetOrder(2))                         // Group + Matchcode

   ali->(dbSeek(Str(nArt, 6), .T.))            // soft seek to first row of the article
   DO WHILE ! ali->(EOF()) .AND. ali->Artikelnr == nArt
      // Priority 9 = deaktivierter Lieferant (Stufe 9) -> nicht uebergeben.
      // (Zeile ueberspringen, ohne den Matchcode zu "sehen", damit eine evtl.
      //  aktive Zeile desselben Lieferanten weiter beruecksichtigt wird.)
      IF _psFld("ali", "Priority", 0) >= 9
         ali->(dbSkip())
         LOOP
      ENDIF
      cMatch := Upper(Trim(ali->Kunde))
      IF ! Empty(cMatch) .AND. AScan(aSeen, {|c| c == cMatch}) == 0
         AAdd(aSeen, cMatch)
         IF ku->(dbSeek("L" + Upper(Pad(cMatch, 8)))) .AND. ku->Group == "L" ;
            .AND. Upper(Trim(ku->Kunde)) == cMatch
            AAdd(aSup, { ;
               "erp_supplier_id" => ku->Nummer, ;
               "matchcode"       => hb_strtoutf8(Trim(ku->Kunde)), ;
               "company_name"    => hb_strtoutf8(IF(Empty(Trim(ku->Name1)), Trim(ku->Kunde), Trim(ku->Name1))), ;
               "name2"           => hb_strtoutf8(Trim(ku->Name2)), ;
               "email"           => hb_strtoutf8(Trim(ku->Email)), ;
               "country_iso"     => hb_strtoutf8(Trim(ku->CountryIso)) })
         ENDIF
      ENDIF
      ali->(dbSkip())
   ENDDO

   ali->(dbCloseArea())
   ku->(dbCloseArea())
RETURN aSup


STATIC FUNCTION _psStr(x)
   DO CASE
   CASE ValType(x) == "C" ; RETURN x
   CASE ValType(x) == "N" ; RETURN hb_ntos(x)
   ENDCASE
RETURN ""

// defensive field read (field may be absent in some firm's artlief schema)
STATIC FUNCTION _psFld(cAlias, cField, xDef)
   LOCAL nPos := (cAlias)->(FieldPos(cField))
   IF nPos > 0
      RETURN (cAlias)->(FieldGet(nPos))
   ENDIF
RETURN xDef
