/*
 * portaldrawing.prg  -  Push an article's drawing file to the supplier portal.
 * -----------------------------------------------------------------------
 * Runs in the Trader DESKTOP context (as the logged-in user), so it CAN read
 * the drawing share \\EK-SERVER4\Data\Technik\Prozessdoku - unlike the IIS
 * api-intern app pool, which has no access. This is the workaround for that.
 *
 * Invoked from the portal via a protocol link (checkstock.prg uses the same
 * trader:// mechanism, '&' as the parameter separator):
 *
 *   trader://-R&portaldrawing&{"<artikelnr>","<erp_firm_id>"}
 *
 * -R runs  MBaseRun(Path('run\portaldrawing'), {"<artikelnr>","<firm>"}),
 * so the two array elements arrive here as parameters.
 *
 * It resolves the drawing exactly like the desktop (get_drawingfile hook),
 * reads the bytes and POSTs them base64-encoded as JSON to the portal edge
 * function, which stores them in saved_article_attachments.
 *
 * Config (once):
 *   - keychain entry "PORTALDRW" (max 10 chars): the shared upload secret as its
 *     password (matched by the edge function's IMPORT_DRAWING_SECRET).
 *
 * NOTE (v1): uses the CURRENTLY open firm. If the article number is not found
 * in it, switch Trader to the matching firm and retry.
 */

PROCEDURE PortalDrawing(cArtNr, cFirm)
   LOCAL nArtNr := Val(_pdStr(cArtNr))
   LOCAL cFile, cData, cName, cMime
   LOCAL hBody, aHeader, nStatus := 0, cResponse := "", oRest
   LOCAL cUrl := "https://jjxieivxbnkjoboiysaj.supabase.co/functions/v1/import-article-drawing"

   IF nArtNr <= 0
      Tr_MsgBox("Keine Artikelnummer uebergeben.")
      RETURN
   ENDIF

   NetUse("artikel", "art")
   art->(dbSetOrder(2))                       // index 2 = artikelnr
   IF ! art->(dbSeek(Str(nArtNr, 6)))
      Tr_MsgBox("Artikel " + LTrim(Str(nArtNr)) + " nicht in der aktuellen Firma gefunden." + Chr(13) + ;
                "Bitte Trader in die passende Firma umschalten und erneut aufrufen.")
      RETURN
   ENDIF
   IF Empty(art->Zeichnung)
      Tr_MsgBox("Artikel " + AllTrim(art->Matchcode) + " hat keine Zeichnungsnummer.")
      RETURN
   ENDIF

   // resolve like the desktop path (shared get_drawingfile hook)
   cFile := _pdGuard({|| Hook("get_drawingfile", {.F.}) }, "")
   IF ValType(cFile) != "C" .OR. Empty(cFile) .OR. ! File(cFile)
      Tr_MsgBox("Keine Zeichnungsdatei gefunden fuer " + AllTrim(art->Zeichnung) + ;
                IF(Empty(art->ZeichIndex), "", " / Index " + AllTrim(art->ZeichIndex)) + ".")
      RETURN
   ENDIF

   cData := hb_MemoRead(cFile)                // binary-safe whole-file read
   IF Empty(cData)
      Tr_MsgBox("Zeichnungsdatei konnte nicht gelesen werden:" + Chr(13) + cFile)
      RETURN
   ENDIF

   cName := SubStr(cFile, RAt("\", cFile) + 1)
   cMime := _pdMime(cName)

   hBody := {;
      "erp_firm_id"         => Val(_pdStr(cFirm)), ;
      "erp_article_id"      => nArtNr, ;
      "matchcode"           => AllTrim(art->Matchcode), ;
      "drawing_number"      => AllTrim(art->Zeichnung), ;
      "drawing_index"       => AllTrim(art->ZeichIndex), ;
      "is_customer_drawing" => art->KuZeichnun, ;
      "file_name"           => cName, ;
      "mime_type"           => cMime, ;
      "data_base64"         => hb_base64Encode(cData) }

   aHeader := { "Content-Type: application/json", "x-import-secret: $APIKEY$" }

   oRest := RestApi():New()
   oRest:cBaseUrl := ""                        // cUrl is already the full URL (else NIL + cUrl -> BASE/1081)
   oRest:cApiKeyName := "PORTALDRW"            // -> $APIKEY$ in the header (keychain, max 10 chars)
   oRest:Execute(cUrl, "POST", hBody, aHeader, .T., @nStatus, @cResponse)

   IF nStatus >= 200 .AND. nStatus < 300
      Tr_MsgBox("Zeichnung " + AllTrim(art->Zeichnung) + " wurde ins Lieferantenportal geladen.")
   ELSE
      Tr_MsgBox("Upload fehlgeschlagen (HTTP " + LTrim(Str(nStatus)) + ")." + Chr(13) + _pdStr(cResponse))
   ENDIF
RETURN


// "" for non-character / empty
STATIC FUNCTION _pdStr(x)
   DO CASE
   CASE ValType(x) == "C" ; RETURN x
   CASE ValType(x) == "N" ; RETURN hb_ntos(x)
   ENDCASE
RETURN ""

// guarded eval - fallback on error
STATIC FUNCTION _pdGuard(bBlock, xDef)
   LOCAL xRet
   BEGIN SEQUENCE WITH {|e| Break(e)}
      xRet := Eval(bBlock)
   RECOVER
      xRet := xDef
   END SEQUENCE
RETURN xRet

// map file name -> MIME type
STATIC FUNCTION _pdMime(cName)
   LOCAL cExt := Lower(SubStr(cName, RAt(".", cName)))
   DO CASE
   CASE cExt == ".pdf"                      ; RETURN "application/pdf"
   CASE cExt == ".zip"                      ; RETURN "application/zip"
   CASE cExt == ".png"                      ; RETURN "image/png"
   CASE cExt == ".jpg" .OR. cExt == ".jpeg" ; RETURN "image/jpeg"
   CASE cExt == ".tif" .OR. cExt == ".tiff" ; RETURN "image/tiff"
   CASE cExt == ".dxf"                      ; RETURN "image/vnd.dxf"
   ENDCASE
RETURN "application/octet-stream"
