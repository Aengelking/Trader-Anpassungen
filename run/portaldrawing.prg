/*
 * portaldrawing.prg  -  Push an article's drawing file to the supplier portal.
 * -----------------------------------------------------------------------
 * Runs in the Trader DESKTOP context (as the logged-in user), so it CAN read
 * the drawing share \\EK-SERVER4\Data\Technik\Prozessdoku - unlike the IIS
 * api-intern app pool, which has no access. This is the workaround for that.
 *
 * Invoked from the portal via a protocol link (opaque trader: URI, '&' as the
 * parameter separator):
 *
 *   trader:-R&portaldrawing&{"<artikelnr>","<erp_firm_id>"}
 *
 * It resolves the drawing exactly like the desktop (get_drawingfile hook),
 * reads the bytes and POSTs them base64-encoded as JSON to the portal edge
 * function import-article-drawing, which stores them in saved_article_attachments.
 *
 * The upload core is the STATIC PD_PushDrawing() so other run-scripts can reuse
 * it via bottom #include (e.g. portalarticle.prg uploads the drawing together
 * with the article master data).
 *
 * Config (once):
 *   - keychain entry "PORTALDRW" (max 10 chars): the shared upload secret as its
 *     password (matched by the edge function's IMPORT_DRAWING_SECRET).
 *
 * NOTE (v1): uses the CURRENTLY open firm. If the article number is not found
 * in it, switch Trader to the matching firm and retry.
 */

PROCEDURE PortalDrawing(cArtNr, cFirm)
   LOCAL cMsg := ""

   IF Val(_pdStr(cArtNr)) <= 0
      Tr_MsgBox("Keine Artikelnummer uebergeben.")
      RETURN
   ENDIF

   PD_PushDrawing(Val(_pdStr(cArtNr)), Val(_pdStr(cFirm)), @cMsg)
   Tr_MsgBox(cMsg)
RETURN


// Resolve the article's drawing (get_drawingfile hook) and upload it to the
// portal (import-article-drawing). Sets cMsg (by ref) to a human message and
// returns the HTTP status of the upload, or a marker when nothing was sent:
//   -1 article not found, 0 no drawing number, 1 no file, 2 file unreadable.
// Shared by portaldrawing (standalone) and portalarticle (bottom #include).
STATIC FUNCTION PD_PushDrawing(nArtNr, nFirm, cMsg)
   LOCAL cFile, cData, cName, cMime
   LOCAL cNo := "", cIdx := "", lCust := .F., lProd := .F.
   LOCAL hBody, aHeader, nStatus := 0, cResponse := "", oRest
   LOCAL cUrl := "https://jjxieivxbnkjoboiysaj.supabase.co/functions/v1/import-article-drawing"

   NetUse("artikel", "art")
   art->(dbSetOrder(2))                       // index 2 = artikelnr
   IF ! art->(dbSeek(Str(nArtNr, 6)))
      cMsg := "Artikel " + LTrim(Str(nArtNr)) + " nicht in der aktuellen Firma gefunden."
      RETURN -1
   ENDIF
   IF ! PD_DrawingRef(@cNo, @cIdx, @lCust, @lProd)
      cMsg := "Artikel " + AllTrim(art->Matchcode) + " hat keine Zeichnungsnummer."
      RETURN 0
   ENDIF

   // Produktionszeichnung explizit aufloesen; sonst normale Zeichnung (NIL ->
   // der Hook normalisiert den Dateinamen + Kunden/.LP).
   IF lProd
      cFile := _pdGuard({|| Hook("get_drawingfile", { .F., cNo, cIdx, .F. }) }, "")
   ELSE
      cFile := _pdGuard({|| Hook("get_drawingfile", {.F.}) }, "")
   ENDIF
   IF ValType(cFile) != "C" .OR. Empty(cFile) .OR. ! File(cFile)
      cMsg := "Keine Zeichnungsdatei gefunden fuer " + cNo + ;
              IF(Empty(cIdx), "", " / Index " + cIdx) + "."
      RETURN 1
   ENDIF

   cData := hb_MemoRead(cFile)                // binary-safe whole-file read
   IF Empty(cData)
      cMsg := "Zeichnungsdatei konnte nicht gelesen werden:" + Chr(13) + cFile
      RETURN 2
   ENDIF

   cName := SubStr(cFile, RAt("\", cFile) + 1)
   cMime := _pdMime(cName)

   hBody := {;
      "erp_firm_id"         => nFirm, ;
      "erp_article_id"      => nArtNr, ;
      "matchcode"           => AllTrim(art->Matchcode), ;
      "drawing_number"      => cNo, ;
      "drawing_index"       => cIdx, ;
      "is_customer_drawing" => lCust, ;
      "file_name"           => cName, ;
      "mime_type"           => cMime, ;
      "data_base64"         => hb_base64Encode(cData) }

   aHeader := { "Content-Type: application/json", "x-import-secret: $APIKEY$" }

   oRest := RestApi():New()
   oRest:cBaseUrl := ""                        // cUrl is already the full URL (else NIL + cUrl -> BASE/1081)
   oRest:cApiKeyName := "PORTALDRW"            // -> $APIKEY$ in the header (keychain, max 10 chars)
   oRest:Execute(cUrl, "POST", hBody, aHeader, .T., @nStatus, @cResponse)

   IF nStatus >= 200 .AND. nStatus < 300
      cMsg := "Zeichnung " + cNo + " wurde ins Lieferantenportal geladen."
   ELSE
      cMsg := "Zeichnungs-Upload fehlgeschlagen (HTTP " + LTrim(Str(nStatus)) + ")." + Chr(13) + _pdStr(cResponse)
   ENDIF
RETURN nStatus


// Preferred drawing for portal sync: Produktionszeichnung (art->Anweisung when
// Bezug != 5) before the normal Zeichnung. By-ref fields; returns .T. if a
// drawing number exists. lProd -> resolve via the explicit Anweisung path
// (base folder, never a customer drawing). Reads the current "art" record.
STATIC FUNCTION PD_DrawingRef(cNo, cIdx, lCust, lProd)
   IF ! Empty(art->Anweisung) .AND. art->Bezug != 5
      lProd := .T. ; cNo := Trim(art->Anweisung)  ; cIdx := Trim(art->AwIndex)   ; lCust := .F.
   ELSE
      lProd := .F. ; cNo := Trim(art->Zeichnung)  ; cIdx := Trim(art->Zeichindex) ; lCust := art->KuZeichnun
   ENDIF
RETURN ! Empty(cNo)


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
