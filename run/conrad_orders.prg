/*
 * conrad_orders.prg  -  Bestellungen vom Conrad-Marktplatz (Mirakl) abholen.
 * -----------------------------------------------------------------------
 * 1. Neue Bestellungen (Status WAITING_ACCEPTANCE) werden automatisch
 *    angenommen, wenn jede Position einem Trader-Artikel zugeordnet werden
 *    kann. Die SKU ist die aus dem frueheren Angebots-Upload
 *    (product_data.prg): Artikelnr + S/W/I/P, ggf. mit "-06"/"-24".
 *    Laesst sich eine Position nicht zuordnen, wird nichts angenommen und
 *    einmalig eine Mail geschickt.
 * 2. Angenommene und bezahlte Bestellungen (Status SHIPPING) liefert Mirakl
 *    mit der Lieferadresse des Endkunden. Sie werden einmalig per Mail
 *    gemeldet (Artikel, Mengen, Preise, Lieferadresse), damit der Auftrag
 *    fuer CONRADSE angelegt werden kann.
 *
 * Welche Bestellungen schon gemeldet sind, steht in
 * Path("export\conrad\")conrad_orders_erledigt.txt (eine Zeile je Meldung).
 *
 * Aufruf (Run-Script, z. B. alle 15 Minuten aus der Aufgabenplanung):
 *   trader:-R&conrad_orders                 abholen, annehmen, melden
 *   trader:-R&conrad_orders&{"J"}           Testlauf: nur protokollieren
 *
 * Config (GetValue, siehe Conrad_Orders_Setup):
 *   CONRAD_MIRAKL       Keychain-Eintrag mit dem Mirakl-API-Schluessel
 *                       (Shop-Key), eingesetzt fuer $APIKEY$ im Header
 *   CONRAD_MIRAKL_URL   Adresse der Mirakl-API
 *   CONRAD_ORDERS_MAIL  Empfaenger der Meldungen
 *
 * Protokoll: Path("run\logs\")conrad_orders_<Datum>_<Zeit>.log
 */

#define CO_LOGDIR    "run\logs\"
#define CO_DATADIR   "export\conrad\"


PROCEDURE RUN_CONRAD_ORDERS(cTestlauf)
   LOCAL lTest    := CO_IsYes(cTestlauf)
   LOCAL lBatch   := GetConfigValue("BATCHMODE")
   LOCAL cLogFile := CO_LogFile()
   LOCAL cBase, cFehler, cMail, cErledigt
   LOCAL aOrders, hOrder, cOrderId, aOhne
   LOCAL nAngenommen := 0, nGemeldet := 0, nX
   LOCAL aFehler := {}

   Conrad_Orders_Setup()

   cBase := AllTrim(CO_Str(GetValue("CONRAD_MIRAKL_URL")))
   cMail := AllTrim(CO_Str(GetValue("CONRAD_ORDERS_MAIL")))
   IF Empty(cBase) .OR. Empty(cMail)
      CO_Ende(cLogFile, lBatch, "CONRAD_MIRAKL_URL oder CONRAD_ORDERS_MAIL ist nicht gesetzt.")
      RETURN
   ENDIF
   IF Right(cBase, 1) != "/"
      cBase += "/"
   ENDIF
   cErledigt := CO_ErledigtDatei()

   IF ! lBatch
      Head("Conrad-Marktplatz - Bestellungen abholen")
      ? "Bestellungen werden abgefragt..."
   ENDIF

   NetUse("artikel", "art")
   art->(dbSetOrder( 2 ))

   // 1. neue Bestellungen annehmen
   aOrders := CO_Orders(cBase, "WAITING_ACCEPTANCE", @cFehler)
   IF aOrders == NIL
      CO_Ende(cLogFile, lBatch, "Neue Bestellungen nicht abrufbar: " + cFehler)
      RETURN
   ENDIF
   FOR nX := 1 TO Len(aOrders)
      hOrder   := aOrders[nX]
      cOrderId := CO_Str(CO_HDef(hOrder, "order_id", ""))
      aOhne    := CO_OhneArtikel(hOrder)
      IF Len(aOhne) > 0
         CO_Log(cLogFile, "WARNING", cOrderId + ": SKU ohne Artikel: " + CO_Join(aOhne, ", "))
         IF ! lTest .AND. ! CO_Erledigt(cErledigt, cOrderId + " OHNE_ARTIKEL")
            SendMail({{cMail}}, "Conrad-Bestellung " + cOrderId + " nicht angenommen", ;
                     "Diese SKUs passen zu keinem Artikel in Trader:" + Chr(13) + Chr(10) + ;
                     CO_Join(aOhne, Chr(13) + Chr(10)) + Chr(13) + Chr(10) + Chr(13) + Chr(10) + ;
                     "Bitte im Conrad-Portal von Hand annehmen oder ablehnen.")
            CO_Merken(cErledigt, cOrderId + " OHNE_ARTIKEL")
         ENDIF
         LOOP
      ENDIF
      CO_Log(cLogFile, "INFO", cOrderId + ": " + IF(lTest, "wuerde annehmen", "annehmen"))
      IF lTest
         nAngenommen++
      ELSEIF CO_Annehmen(cBase, hOrder, @cFehler)
         nAngenommen++
      ELSE
         AAdd(aFehler, cOrderId + ": Annehmen fehlgeschlagen: " + cFehler)
      ENDIF
   NEXT

   // 2. bezahlte Bestellungen mit Lieferadresse melden
   aOrders := CO_Orders(cBase, "SHIPPING", @cFehler)
   IF aOrders == NIL
      AAdd(aFehler, "Versandbereite Bestellungen nicht abrufbar: " + cFehler)
      aOrders := {}
   ENDIF
   FOR nX := 1 TO Len(aOrders)
      hOrder   := aOrders[nX]
      cOrderId := CO_Str(CO_HDef(hOrder, "order_id", ""))
      IF CO_Erledigt(cErledigt, cOrderId)
         LOOP
      ENDIF
      CO_Log(cLogFile, "INFO", cOrderId + ": " + IF(lTest, "wuerde melden", "melden"))
      IF ! lTest
         SendMail({{cMail}}, "Neue Conrad-Bestellung " + cOrderId + " - Auftrag fuer CONRADSE anlegen", ;
                  CO_Text(hOrder))
         CO_Merken(cErledigt, cOrderId)
      ENDIF
      nGemeldet++
   NEXT

   FOR nX := 1 TO Len(aFehler)
      CO_Log(cLogFile, "ERROR", aFehler[nX])
   NEXT
   CO_Log(cLogFile, "INFO", IF(lTest, "Testlauf: ", "") + "angenommen " + LTrim(Str(nAngenommen)) + ;
          ", gemeldet " + LTrim(Str(nGemeldet)) + ", Fehler " + LTrim(Str(Len(aFehler))))
   IF Len(aFehler) > 0 .AND. lBatch
      SendMail({{cMail}}, "Conrad-Bestellungen: Fehler beim Abholen", CO_Join(aFehler, Chr(13) + Chr(10)))
   ENDIF

   CO_Ende(cLogFile, lBatch, IF(Len(aFehler) == 0, "", LTrim(Str(Len(aFehler))) + " Fehler - siehe Protokoll."))
RETURN


FUNCTION Conrad_Orders_Setup()
   GetValue("CONRAD_MIRAKL", "", "Keychain-Eintrag mit dem Mirakl-API-Schluessel von Conrad")
   GetValue("CONRAD_MIRAKL_URL", "https://conradb2b-prod.mirakl.net/api/", "Adresse der Mirakl-API von Conrad")
   GetValue("CONRAD_ORDERS_MAIL", "", "Empfaenger der Meldungen zu Conrad-Bestellungen")
RETURN NIL


// Alle Bestellungen in einem Status (OR11), seitenweise; NIL bei Fehler
STATIC FUNCTION CO_Orders(cBase, cState, cFehler)
   LOCAL aAlle   := {}
   LOCAL nOffset := 0
   LOCAL xAntwort, aSeite, nX

   DO WHILE .T.
      xAntwort := CO_Json(CO_Request(cBase + "orders?order_state_codes=" + cState + ;
                                     "&max=100&offset=" + LTrim(Str(nOffset)), "GET", NIL, @cFehler))
      IF ValType(xAntwort) != "H"
         IF Empty(cFehler)
            cFehler := "Unerwartete Antwort"
         ENDIF
         RETURN NIL
      ENDIF
      aSeite := CO_HDef(xAntwort, "orders", {})
      FOR nX := 1 TO Len(aSeite)
         AAdd(aAlle, aSeite[nX])
      NEXT
      nOffset += Len(aSeite)
      IF Len(aSeite) < 100 .OR. nOffset >= CO_HDef(xAntwort, "total_count", 0)
         EXIT
      ENDIF
   ENDDO
RETURN aAlle


// Alle Positionen annehmen (OR21)
STATIC FUNCTION CO_Annehmen(cBase, hOrder, cFehler)
   LOCAL aLines := CO_HDef(hOrder, "order_lines", {})
   LOCAL aBody  := {}
   LOCAL nX

   FOR nX := 1 TO Len(aLines)
      AAdd(aBody, {"accepted" => .T., "id" => CO_Str(CO_HDef(aLines[nX], "order_line_id", ""))})
   NEXT
RETURN CO_Request(cBase + "orders/" + CO_Str(CO_HDef(hOrder, "order_id", "")) + "/accept", ;
                  "PUT", {"order_lines" => aBody}, @cFehler) != NIL


// SKUs der Bestellung, zu denen es keinen Artikel gibt
STATIC FUNCTION CO_OhneArtikel(hOrder)
   LOCAL aLines := CO_HDef(hOrder, "order_lines", {})
   LOCAL aOhne  := {}
   LOCAL cSku, nX

   FOR nX := 1 TO Len(aLines)
      cSku := CO_Str(CO_HDef(aLines[nX], "offer_sku", ""))
      IF CO_Artikelnr(cSku) == 0 .OR. ! art->(dbSeek( Str(CO_Artikelnr(cSku),6) ))
         AAdd(aOhne, cSku)
      ENDIF
   NEXT
RETURN aOhne


// "12345S-06" -> 12345
STATIC FUNCTION CO_Artikelnr(cSku)
   LOCAL nX := 1

   DO WHILE nX <= Len(cSku) .AND. IsDigit(SubStr(cSku, nX, 1))
      nX++
   ENDDO
RETURN Val(Left(cSku, nX - 1))


// Mailtext mit allem, was fuer den Auftrag gebraucht wird
STATIC FUNCTION CO_Text(hOrder)
   LOCAL cNl    := Chr(13) + Chr(10)
   LOCAL hAdr   := CO_HDef(CO_HDef(hOrder, "customer", {=>}), "shipping_address", {=>})
   LOCAL aLines := CO_HDef(hOrder, "order_lines", {})
   LOCAL cText, cSku, hLine, nX

   cText := "Kunde: CONRADSE" + cNl
   cText += "Ihre Bestellnr.: " + CO_Str(CO_HDef(hOrder, "order_id", "")) + cNl
   cText += "Bestellt am: " + Left(CO_Str(CO_HDef(hOrder, "created_date", "")), 10) + cNl + cNl

   cText += "Lieferadresse (Endkunde):" + cNl
   cText += CO_Zeile(hAdr, "company")
   cText += CO_Zeile(hAdr, "civility", "firstname", "lastname")
   cText += CO_Zeile(hAdr, "street_1")
   cText += CO_Zeile(hAdr, "street_2")
   cText += CO_Zeile(hAdr, "zip_code", "city")
   cText += CO_Zeile(hAdr, "country_iso_code", "country")
   cText += CO_Zeile(hAdr, "phone")
   cText += cNl

   cText += "Positionen (Preise brutto, wie bei Conrad):" + cNl
   FOR nX := 1 TO Len(aLines)
      hLine := aLines[nX]
      cSku  := CO_Str(CO_HDef(hLine, "offer_sku", ""))
      cText += CO_Str(CO_HDef(hLine, "quantity", 0)) + " x "
      IF CO_Artikelnr(cSku) != 0 .AND. art->(dbSeek( Str(CO_Artikelnr(cSku),6) ))
         cText += Trim(art->Matchcode) + " (Artikel " + LTrim(Str(art->Artikelnr)) + ")"
      ELSE
         cText += "SKU " + cSku + " - KEIN ARTIKEL GEFUNDEN"
      ENDIF
      cText += " je " + Transform(CO_HDef(hLine, "price_unit", 0), "999999.99") + " EUR" + cNl
   NEXT
   cText += "Versand: " + Transform(CO_HDef(hOrder, "shipping_price", 0), "999999.99") + " EUR" + cNl
   cText += "Gesamt:  " + Transform(CO_HDef(hOrder, "total_price", 0), "999999.99") + " EUR" + cNl
RETURN cText


// eine Adresszeile aus mehreren Feldern; leer, wenn alle Felder leer sind
STATIC FUNCTION CO_Zeile(hAdr, ...)
   LOCAL aKeys := hb_AParams()
   LOCAL cZeile := "", cWert, nX

   FOR nX := 2 TO Len(aKeys)
      cWert := AllTrim(hb_Utf8ToStr(CO_Str(CO_HDef(hAdr, aKeys[nX], ""))))
      IF ! Empty(cWert)
         cZeile += IF(Empty(cZeile), "", " ") + cWert
      ENDIF
   NEXT
RETURN IF(Empty(cZeile), "", "  " + cZeile + Chr(13) + Chr(10))


// Aufruf der Mirakl-API mit dem Schluessel aus dem Keychain; NIL bei Fehler
STATIC FUNCTION CO_Request(cUrl, cMethod, hBody, cFehler)
   LOCAL oRest   := RestApi():New()
   LOCAL aHeader := {"Authorization: $APIKEY$", "Accept: application/json"}
   LOCAL nStatus := 0
   LOCAL cAntwort

   IF hBody != NIL
      AAdd(aHeader, "Content-Type: application/json")
   ENDIF
   oRest:cBaseUrl    := ""
   oRest:cApiKeyName := "CONRAD_MIRAKL"
   cFehler := ""
   BEGIN SEQUENCE WITH {|e| Break(e)}
      cAntwort := oRest:Execute(cUrl, cMethod, hBody, aHeader, hBody != NIL, @nStatus)
   RECOVER
      cAntwort := NIL
      nStatus  := -1
   END SEQUENCE
   IF nStatus < 200 .OR. nStatus >= 300
      cFehler := "HTTP " + LTrim(Str(nStatus)) + " " + Left(CO_Str(cAntwort), 300)
      RETURN NIL
   ENDIF
RETURN IF(cAntwort == NIL, "", cAntwort)


STATIC FUNCTION CO_ErledigtDatei()
   LOCAL cDir := Path(CO_DATADIR)

   IF ! hb_DirExists(Left(cDir, Len(cDir) - 1))
      MakeDir(Left(cDir, Len(cDir) - 1))
   ENDIF
RETURN cDir + "conrad_orders_erledigt.txt"


STATIC FUNCTION CO_Erledigt(cFile, cKey)
RETURN File(cFile) .AND. (Chr(10) + cKey + Chr(13)) $ (Chr(10) + hb_MemoRead(cFile))


STATIC FUNCTION CO_Merken(cFile, cKey)
   LOCAL nHandle := FOpen(cFile, 2)              // FO_READWRITE

   IF nHandle == -1
      nHandle := FCreate(cFile)
   ENDIF
   IF nHandle != -1
      FSeek(nHandle, 0, 2)                       // FS_END
      FWrite(nHandle, cKey + Chr(13) + Chr(10))
      FClose(nHandle)
   ENDIF
RETURN NIL


STATIC FUNCTION CO_Json(cText)
   IF cText == NIL
      RETURN NIL
   ENDIF
RETURN hb_jsonDecode(cText)


STATIC FUNCTION CO_HDef(hHash, cKey, xDef)
   IF ValType(hHash) == "H" .AND. HHasKey(hHash, cKey) .AND. hHash[cKey] != NIL
      RETURN hHash[cKey]
   ENDIF
RETURN xDef


STATIC FUNCTION CO_Str(xVal)
   DO CASE
   CASE ValType(xVal) == "C"
      RETURN xVal
   CASE ValType(xVal) == "N"
      RETURN LTrim(Str(xVal))
   CASE ValType(xVal) == "L"
      RETURN IF(xVal, ".T.", ".F.")
   ENDCASE
RETURN ""


STATIC FUNCTION CO_Join(aZeilen, cTrenner)
   LOCAL cOut := "", nX
   FOR nX := 1 TO Len(aZeilen)
      cOut += IF(nX > 1, cTrenner, "") + aZeilen[nX]
   NEXT
RETURN cOut


STATIC FUNCTION CO_IsYes(xVal)
RETURN ValType(xVal) == "C" .AND. Upper(Left(AllTrim(xVal), 1)) $ "JY1T"


// Abschluss: Fehler protokollieren und - im Dialog - anzeigen
STATIC FUNCTION CO_Ende(cLogFile, lBatch, cFehler)
   IF ! Empty(cFehler)
      CO_Log(cLogFile, "ERROR", cFehler)
   ENDIF
   IF ! lBatch
      Tr_MsgBox(IF(Empty(cFehler), "Fertig - Protokoll: " + cLogFile, cFehler))
   ENDIF
RETURN NIL


STATIC FUNCTION CO_LogFile()
   LOCAL cDir := Path(CO_LOGDIR)
   LOCAL cFile

   IF ! hb_DirExists(Left(cDir, Len(cDir) - 1))
      MakeDir(Left(cDir, Len(cDir) - 1))
   ENDIF
   cFile := cDir + "conrad_orders_" + DToS(Date()) + "_" + StrTran(Time(), ":", "") + ".log"
   CO_Log(cFile, "INFO", "Protokoll gestartet: " + DToC(Date()) + " " + Time())
RETURN cFile


STATIC FUNCTION CO_Log(cLogFile, cLevel, cMessage)
   LOCAL nHandle
   LOCAL cLine := "[" + DToC(Date()) + " " + Time() + "] [" + cLevel + "] " + cMessage + Chr(13) + Chr(10)

   IF Empty(cLogFile)
      RETURN NIL
   ENDIF
   nHandle := FOpen(cLogFile, 2)                 // FO_READWRITE
   IF nHandle == -1
      nHandle := FCreate(cLogFile)
   ENDIF
   IF nHandle != -1
      FSeek(nHandle, 0, 2)                       // FS_END
      FWrite(nHandle, cLine)
      FClose(nHandle)
   ENDIF
RETURN NIL
