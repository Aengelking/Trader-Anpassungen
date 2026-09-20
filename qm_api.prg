/*
 * qm_api.prg  -  gemeinsamer HTTP-Helfer fuer das QM-Portal (engelking-qm).
 * -----------------------------------------------------------------------
 * Wird von den qm_we_*-Run-Scripts per #include am DATEIENDE eingebunden
 * (Muster brevo.prg). Alles STATIC, damit zwei geladene .hrb sich nicht auf
 * einem oeffentlichen Symbol ueberschneiden und der Entry-Point des
 * einbindenden Scripts nicht gekapert wird.
 *
 * Auth laeuft ueber den verschluesselten Keychain: der Eintrag QM-TRADER
 * liefert den Wert fuer den Platzhalter $APIKEY$ im Header x-api-key.
 * Muster: portalarticle.prg / PA_PushArticle().
 *
 * Die Adresse der Edge Function steht in den Einstellungen unter QM_API_URL
 * (Kategorie QM, Maske Browse_Values). Der Default unten wird beim ersten
 * Aufruf automatisch angelegt - wie bei NEXUSCRM_URL, NOCRM_URL, FREPPLE_URL.
 * Sie liegt damit pro Mandant vor und ist ohne Neuuebersetzung aenderbar.
 */

#define QM_KEYNAME "QM-TRADER"
#define QM_DEFURL  "https://gkwtwjvjzdsbejwqfeig.supabase.co/functions/v1/trader-incoming-receipt"

// POST eines Hashes an die Edge Function. Gibt den dekodierten Antwort-Hash
// zurueck oder NIL, wenn der Aufruf nicht sauber durchging. nStatus und
// cResponse kommen per Referenz zurueck, damit der Aufrufer 400 (Payload) von
// 401/403 (Schluessel) und 0 (kein Netz) unterscheiden kann.
STATIC FUNCTION QmPost(hBody, nStatus, cResponse)
   LOCAL oRest, aHeader, hRet
   LOCAL cUrl := AllTrim(GetValue("QM_API_URL", QM_DEFURL, ;
                                  "URL der QM-Wareneingangsschnittstelle (engelking-qm)"))

   nStatus   := 0
   cResponse := ""

   IF Empty(cUrl)
      RETURN NIL
   ENDIF

   aHeader := {"Content-Type: application/json", "x-api-key: $APIKEY$"}

   oRest := RestApi():New()
   oRest:cBaseUrl    := ""
   oRest:cApiKeyName := QM_KEYNAME

   BEGIN SEQUENCE WITH {|e| Break(e)}
      oRest:Execute(cUrl, "POST", hBody, aHeader, .T., @nStatus, @cResponse)
   RECOVER
      nStatus := 0
   END SEQUENCE

   IF nStatus < 200 .OR. nStatus >= 300
      RETURN NIL
   ENDIF

   BEGIN SEQUENCE WITH {|e| Break(e)}
      hRet := HB_JsonDecode(cResponse)
   RECOVER
      hRet := NIL
   END SEQUENCE

   IF ValType(hRet) != "H"
      RETURN NIL
   ENDIF
RETURN hRet

// Lieferantennummer (ku->Nummer) zum Matchcode. Das Portal findet den
// Lieferanten darueber auch dann, wenn suppliers.supplier_number abweicht.
// Gleiche Suche wie show_qs_parts.prg:513.
STATIC FUNCTION QmSupplierNo(cLiefma)
   LOCAL nRet := 0
   IF Empty(cLiefma)
      RETURN 0
   ENDIF
   NetUse("engkund", "ku")
   ku->(dbSetOrder(1))
   IF ku->(dbSeek(Pad(Trim(cLiefma), 8) + "L"))
      nRet := ku->Nummer
   ENDIF
RETURN nRet

// Felder, die als Text rausgehen, muessen von CP865 nach UTF-8.
STATIC FUNCTION QmStr(cText)
RETURN hb_strtoutf8(Trim(IF(ValType(cText) == "C", cText, "")))
