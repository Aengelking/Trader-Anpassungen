/*
 * conrad_orders.prg  -  Bestellungen vom Conrad-Marktplatz (Mirakl) abholen.
 * -----------------------------------------------------------------------
 * Conrad nimmt die Bestellungen selbst an. Angenommene und bezahlte
 * Bestellungen (Status SHIPPING, "Wartet auf Versand") liefert Mirakl mit der
 * Lieferadresse des Endkunden. Daraus wird ein Auftrag fuer
 * CONRAD_ORDERS_KUNDE angelegt: Conrad-Bestellnr. als "Ihre Bestellnr.",
 * Preis je Stueck = price_unit von Conrad (kommt netto), Versandart und Porto aus dem Kunden, Lieferadresse
 * "Auftragsbezogen (A)" mit der Adresse des Endkunden. Die SKU ist die aus
 * dem frueheren Angebots-Upload (product_data.prg): Artikelnr + S/W/I/P,
 * ggf. mit "-06"/"-24". Geht das nicht (z. B. SKU ohne Artikel), kommt
 * einmalig eine Mail mit allem, was zum Anlegen von Hand gebraucht wird.
 *
 * Versand melden: Conrad_Ship() aus dem Hook after_pack, wenn die Rechnung
 * fuer CONRAD_ORDERS_KUNDE gebucht wird. Die Conrad-Bestellnr. kommt aus
 * "Ihre Bestellnr." der Rechnungspositionen; gemeldet werden Spediteur und
 * Tracking-Nr. (OR23) und der Versand (OR24). Fehler kommen per Mail, der
 * Packplatz wird nie aufgehalten.
 *
 * Welche Bestellungen schon erledigt sind, steht in
 * Path("export\conrad\")conrad_orders_erledigt.txt (eine Zeile je Bestellung).
 * Zusaetzlich wird keine Bestellung angelegt, fuer die es beim Kunden schon
 * einen Auftrag mit dieser "Ihre Bestellnr." gibt (auch von Hand angelegt).
 *
 * Aufruf (Run-Script, z. B. alle 15 Minuten aus der Aufgabenplanung):
 *   trader:-R&conrad_orders                 abholen, Auftraege anlegen, melden
 *   trader:-R&conrad_orders&{"J"}           Testlauf: nur protokollieren
 *
 * Keychain-Eintrag CONRADMKL: Mirakl-API-Schluessel (Shop-Key), eingesetzt fuer $APIKEY$ im Header
 *
 * Config (GetValue, siehe Conrad_Orders_Setup):
 *   CONRAD_MIRAKL_URL   Adresse der Mirakl-API
 *   CONRAD_MIRAKL_SHOP  Shop-ID bei Conrad (der Schluessel gilt fuer mehrere
 *                       Shops; leer = Standard-Shop des Schluessels)
 *   CONRAD_ORDERS_MAIL  Empfaenger der Meldungen
 *   CONRAD_ORDERS_KUNDE Matchcode des Kunden fuer die Auftraege (CONRADSE)
 *
 * Protokoll: Path("run\logs\")conrad_orders_<Datum>.log, eine Datei je Tag,
 * nach 30 Tagen geloescht (CO_LOGTAGE)
 */

#define CO_LOGDIR    "run\logs\"
#define CO_LOGTAGE   30
#define CO_DATADIR   "export\conrad\"
#define CO_KEYNAME   "CONRADMKL"            // Keychain, max. 10 Zeichen


PROCEDURE RUN_CONRAD_ORDERS(cTestlauf)
   LOCAL lTest    := CO_IsYes(cTestlauf)
   LOCAL lBatch   := GetConfigValue("BATCHMODE")
   LOCAL cLogFile := CO_LogFile()
   LOCAL cBase, cFehler, cMail, cErledigt, cKunde
   LOCAL aOrders, hOrder, cOrderId, aOhne, nAbnr
   LOCAL nAngelegt := 0, nGemeldet := 0, nX
   LOCAL aFehler := {}

   Conrad_Orders_Setup()

   cBase := AllTrim(CO_Str(GetValue("CONRAD_MIRAKL_URL")))
   cMail := AllTrim(CO_Str(GetValue("CONRAD_ORDERS_MAIL")))
   cKunde := Upper(AllTrim(CO_Str(GetValue("CONRAD_ORDERS_KUNDE"))))
   IF Empty(cBase) .OR. Empty(cMail) .OR. Empty(cKunde)
      CO_Ende(cLogFile, lBatch, "CONRAD_MIRAKL_URL, CONRAD_ORDERS_MAIL oder CONRAD_ORDERS_KUNDE ist nicht gesetzt.")
      RETURN
   ENDIF
   IF Right(cBase, 1) != "/"
      cBase += "/"
   ENDIF
   NetUse("keychain", "chain")
   IF ! chain->(dbSeek( Pad(CO_KEYNAME, 10) ))
      CO_Ende(cLogFile, lBatch, "Im Schluesselbund fehlt der Eintrag " + CO_KEYNAME + " mit dem Mirakl-API-Schluessel.")
      RETURN
   ENDIF
   cErledigt := CO_ErledigtDatei()

   IF ! lBatch
      Head("Conrad-Marktplatz - Bestellungen abholen")
      ? "Bestellungen werden abgefragt..."
   ENDIF

   NetUse("artikel", "art")
   art->(dbSetOrder( 2 ))
   NetUse("engauf", "auf")
   auf->(dbSetOrder( 2 ))                        // Kundma
   NetUse("engkund", "ku")
   ku->(dbSetOrder( 1 ))
   IF ! ku->(dbSeek( Pad(cKunde, 8) + "K" ))
      CO_Ende(cLogFile, lBatch, "Kunde " + cKunde + " (CONRAD_ORDERS_KUNDE) nicht gefunden.")
      RETURN
   ENDIF

   // bezahlte Bestellungen mit Lieferadresse als Auftrag anlegen
   aOrders := CO_Orders(cBase, "SHIPPING", @cFehler)
   IF aOrders == NIL
      CO_Ende(cLogFile, lBatch, "Versandbereite Bestellungen nicht abrufbar: " + cFehler)
      RETURN
   ENDIF
   CO_Log(cLogFile, "INFO", "Conrad meldet " + LTrim(Str(Len(aOrders))) + " Bestellung(en) im Status SHIPPING")
   FOR nX := 1 TO Len(aOrders)
      hOrder   := aOrders[nX]
      cOrderId := CO_Str(CO_HDef(hOrder, "order_id", ""))
      IF CO_Erledigt(cErledigt, cOrderId)
         CO_Log(cLogFile, "INFO", cOrderId + ": schon erledigt (" + cErledigt + ")")
         LOOP
      ENDIF
      nAbnr := CO_Vorhanden(cOrderId, cKunde)
      IF nAbnr > 0                               // schon in Trader, z. B. von Hand angelegt
         CO_Log(cLogFile, "INFO", cOrderId + ": Auftrag " + LTrim(Str(nAbnr)) + " gibt es schon")
         IF ! lTest
            CO_Merken(cErledigt, cOrderId)
         ENDIF
         LOOP
      ENDIF
      IF lTest
         CO_Log(cLogFile, "INFO", cOrderId + ": wuerde Auftrag anlegen")
         nAngelegt++
         LOOP
      ENDIF
      aOhne := CO_OhneArtikel(hOrder)
      IF Len(aOhne) > 0
         nAbnr   := 0
         cFehler := "SKU ohne Artikel: " + CO_Join(aOhne, ", ")
      ELSE
         nAbnr := CO_Auftrag(hOrder, cKunde, @cFehler)
      ENDIF
      CO_Merken(cErledigt, cOrderId)
      IF nAbnr > 0
         CO_Log(cLogFile, "INFO", cOrderId + ": Auftrag " + LTrim(Str(nAbnr)) + " angelegt")
         nAngelegt++
      ENDIF
      IF ! Empty(cFehler)
         CO_Log(cLogFile, "ERROR", cOrderId + ": " + cFehler)
         CO_Mail(cMail, "Conrad-Bestellung " + cOrderId + " - " + ;
                 IF(nAbnr > 0, "Auftrag " + LTrim(Str(nAbnr)) + " pruefen und freigeben", "Auftrag fuer " + cKunde + " von Hand anlegen"), ;
                 cFehler + Chr(13) + Chr(10) + Chr(13) + Chr(10) + CO_Text(hOrder, cKunde), nAbnr)
         nGemeldet++
      ELSEIF nAbnr > 0                           // Auftrag muss noch freigegeben werden
         CO_Mail(cMail, "Conrad-Bestellung " + cOrderId + " - Auftrag " + LTrim(Str(nAbnr)) + " bitte freigeben", ;
                 "Der Auftrag wurde automatisch angelegt und muss noch freigegeben werden." + ;
                 Chr(13) + Chr(10) + Chr(13) + Chr(10) + CO_Text(hOrder, cKunde), nAbnr)
      ENDIF
   NEXT

   FOR nX := 1 TO Len(aFehler)
      CO_Log(cLogFile, "ERROR", aFehler[nX])
   NEXT
   CO_Log(cLogFile, "INFO", IF(lTest, "Testlauf: ", "") + "Auftraege angelegt " + LTrim(Str(nAngelegt)) + ", per Mail gemeldet " + LTrim(Str(nGemeldet)) + ;
          ", Fehler " + LTrim(Str(Len(aFehler))))
   IF Len(aFehler) > 0 .AND. lBatch
      CO_Mail(cMail, "Conrad-Bestellungen: Fehler beim Abholen", CO_Join(aFehler, Chr(13) + Chr(10)), 0)
   ENDIF

   CO_Ende(cLogFile, lBatch, IF(Len(aFehler) == 0, "", LTrim(Str(Len(aFehler))) + " Fehler - siehe Protokoll."))
RETURN


FUNCTION Conrad_Orders_Setup()
   GetValue("CONRAD_MIRAKL_URL", "https://conradb2b-prod.mirakl.net/api/", "Adresse der Mirakl-API von Conrad")
   GetValue("CONRAD_MIRAKL_SHOP", "", "Shop-ID bei Conrad (leer = Standard-Shop des API-Schluessels)")
   GetValue("CONRAD_ORDERS_MAIL", "", "Empfaenger der Meldungen zu Conrad-Bestellungen")
   GetValue("CONRAD_ORDERS_KUNDE", "CONRADSE", "Kunde (Matchcode) fuer Auftraege aus Conrad-Bestellungen")
RETURN NIL


// Versand einer Rechnung an Conrad melden (aus after_pack). Liefert .T., wenn
// alles gemeldet wurde; Fehler gehen ins Protokoll und per Mail.
FUNCTION Conrad_Ship(nRechnr, nVersandart, aPakete)
   LOCAL cLogFile := CO_LogFile()
   LOCAL aFehler  := {}
   LOCAL cBase, cMail, cFehler, cCarrier, cTracking, cNr
   LOCAL aNummern, hOrder, hTrack, cOrderId, cState, nX

   Conrad_Orders_Setup()
   cBase := AllTrim(CO_Str(GetValue("CONRAD_MIRAKL_URL")))
   cMail := AllTrim(CO_Str(GetValue("CONRAD_ORDERS_MAIL")))
   IF Right(cBase, 1) != "/"
      cBase += "/"
   ENDIF
   CO_Log(cLogFile, "INFO", "Versand melden fuer Rechnung " + LTrim(Str(nRechnr)))

   NetUse("keychain", "chain")
   IF ! chain->(dbSeek( Pad(CO_KEYNAME, 10) ))
      AAdd(aFehler, "Im Schluesselbund fehlt der Eintrag " + CO_KEYNAME + ".")
   ENDIF

   aNummern := IF(Len(aFehler) == 0, CO_RechnungNummern(nRechnr), {})
   IF Len(aFehler) == 0 .AND. Len(aNummern) == 0
      AAdd(aFehler, "Rechnung " + LTrim(Str(nRechnr)) + " hat keine Conrad-Bestellnr. (Ihre Bestellnr.)")
   ENDIF

   cCarrier  := AllTrim(CO_Str(VerShow(nVersandart)))
   cTracking := ""
   FOR nX := 1 TO Len(aPakete)
      IF ValType(aPakete[nX]) == "C" .AND. ! Empty(aPakete[nX])
         IF Empty(cTracking)
            cTracking := AllTrim(aPakete[nX])
         ELSE
            CO_Log(cLogFile, "INFO", "weitere Tracking-Nr. " + AllTrim(aPakete[nX]) + " (Conrad nimmt nur eine)")
         ENDIF
      ENDIF
   NEXT
   IF Len(aNummern) > 0 .AND. ! Empty(cTracking)
      hTrack := CO_Carrier(cBase, cCarrier, cLogFile)
      hTrack["tracking_number"] := cTracking
   ENDIF

   FOR EACH cNr IN aNummern
      hOrder := CO_Bestellung(cBase, cNr, @cFehler)
      IF hOrder == NIL
         AAdd(aFehler, cNr + ": " + IF(Empty(cFehler), "bei Conrad nicht gefunden", cFehler))
         LOOP
      ENDIF
      cOrderId := CO_Str(CO_HDef(hOrder, "order_id", ""))
      cState   := CO_Str(CO_HDef(hOrder, "order_state", ""))
      IF cState != "SHIPPING"
         CO_Log(cLogFile, "INFO", cOrderId + ": Status " + cState + " - nichts zu melden")
         LOOP
      ENDIF
      IF hTrack != NIL .AND. CO_Request(cBase + "orders/" + cOrderId + "/tracking", "PUT", hTrack, @cFehler) == NIL
         AAdd(aFehler, cOrderId + ": Tracking nicht gemeldet: " + cFehler)
         LOOP
      ENDIF
      IF CO_Request(cBase + "orders/" + cOrderId + "/ship", "PUT", NIL, @cFehler) == NIL
         AAdd(aFehler, cOrderId + ": Versand nicht gemeldet: " + cFehler)
         LOOP
      ENDIF
      CO_Log(cLogFile, "INFO", cOrderId + ": Versand gemeldet (" + cCarrier + ;
             IF(Empty(cTracking), ", ohne Tracking-Nr.", " " + cTracking) + ")")
   NEXT

   FOR nX := 1 TO Len(aFehler)
      CO_Log(cLogFile, "ERROR", aFehler[nX])
   NEXT
   IF Len(aFehler) > 0 .AND. ! Empty(cMail)
      CO_Mail(cMail, "Conrad: Versand zu Rechnung " + LTrim(Str(nRechnr)) + " nicht gemeldet", ;
              "Bitte den Versand im Conrad-Portal von Hand melden." + Chr(13) + Chr(10) + Chr(13) + Chr(10) + ;
              CO_Join(aFehler, Chr(13) + Chr(10)) + Chr(13) + Chr(10) + Chr(13) + Chr(10) + ;
              "Versandart: " + cCarrier + Chr(13) + Chr(10) + ;
              "Tracking-Nr.: " + CO_Join(aPakete, ", "), 0)
   ENDIF
RETURN Len(aFehler) == 0


// Conrad-Bestellnummern ("Ihre Bestellnr.") der Positionen einer Rechnung
STATIC FUNCTION CO_RechnungNummern(nRechnr)
   LOCAL aNummern := {}
   LOCAL cNr

   NetUse("engslre", "re")
   re->(dbSetOrder( 12 ))
   re->(dbSeek( Str(nRechnr,6) + Str(0,3) ))
   re->(dbSkip())
   DO WHILE ! re->(Eof()) .AND. re->Rechnr == nRechnr
      cNr := AllTrim(re->Aufnr)
      IF re->AoQty > 0 .AND. ! Empty(cNr) .AND. AScan(aNummern, {|x| x == cNr }) == 0
         AAdd(aNummern, cNr)
      ENDIF
      re->(dbSkip())
   ENDDO
RETURN aNummern


// Bestellung bei Conrad zur Nummer; von Hand wird oft nur der Teil vor dem
// ersten "-" erfasst (4519864688 statt 4519864688-00-A). NIL, wenn nicht da.
STATIC FUNCTION CO_Bestellung(cBase, cNr, cFehler)
   LOCAL xAntwort, aOrders, nX

   xAntwort := CO_Json(CO_Request(cBase + "orders?order_ids=" + cNr, "GET", NIL, @cFehler))
   IF ValType(xAntwort) != "H"
      RETURN NIL
   ENDIF
   aOrders := CO_HDef(xAntwort, "orders", {})
   IF Len(aOrders) > 0
      RETURN aOrders[1]
   ENDIF
   aOrders := CO_Orders(cBase, "SHIPPING", @cFehler)
   IF aOrders == NIL
      RETURN NIL
   ENDIF
   FOR nX := 1 TO Len(aOrders)
      IF Left(CO_Str(CO_HDef(aOrders[nX], "order_id", "")), Len(cNr) + 1) == cNr + "-"
         RETURN aOrders[nX]
      ENDIF
   NEXT
RETURN NIL


// Spediteur fuer OR23: Code aus der Conrad-Liste (SH21), wenn Code oder
// Bezeichnung in der Trader-Versandart vorkommt (z. B. "DHL Paket" -> DHL);
// sonst nur der Name.
STATIC FUNCTION CO_Carrier(cBase, cCarrier, cLogFile)
   LOCAL cFehler := ""
   LOCAL cUpper  := Upper(cCarrier)
   LOCAL xAntwort, aListe, cCode, cLabel, nX

   xAntwort := CO_Json(CO_Request(cBase + "shipping/carriers", "GET", NIL, @cFehler))
   aListe   := CO_HDef(IF(ValType(xAntwort) == "H", xAntwort, {=>}), "carriers", {})
   FOR nX := 1 TO Len(aListe)
      cCode  := Upper(AllTrim(CO_Str(CO_HDef(aListe[nX], "code", ""))))
      cLabel := Upper(AllTrim(CO_Str(CO_HDef(aListe[nX], "label", ""))))
      IF (! Empty(cCode) .AND. cCode $ cUpper) .OR. (! Empty(cLabel) .AND. cLabel $ cUpper)
         RETURN {"carrier_code" => CO_Str(CO_HDef(aListe[nX], "code", ""))}
      ENDIF
   NEXT
   CO_Log(cLogFile, "INFO", "Spediteur '" + cCarrier + "' nicht in der Conrad-Liste - nur Name gemeldet")
RETURN {"carrier_name" => cCarrier}


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


// AbNr des Auftrags fuer cKunde mit der Conrad-Bestellnr. als "Ihre Bestellnr.";
// 0, wenn es noch keinen gibt. Verglichen wird nur die Nummer vor dem ersten
// "-" (4519864688-00-A -> 4519864688), von Hand wird oft nur die erfasst.
STATIC FUNCTION CO_Vorhanden(cOrderId, cKunde)
   LOCAL cNr := AllTrim(cOrderId)

   IF "-" $ cNr
      cNr := Left(cNr, At("-", cNr) - 1)
   ENDIF
   IF Empty(cNr)
      RETURN 0
   ENDIF
   auf->(dbSeek( Pad(cKunde, 8) ))
   DO WHILE ! auf->(Eof()) .AND. Upper(Trim(auf->Kundma)) == cKunde
      IF Left(AllTrim(auf->Aufnr), Len(cNr)) == cNr
         RETURN auf->Abnr
      ENDIF
      auf->(dbSkip())
   ENDDO
RETURN 0


// SKUs der Bestellung, zu denen es keinen Artikel gibt
STATIC FUNCTION CO_OhneArtikel(hOrder)
   LOCAL aLines := CO_HDef(hOrder, "order_lines", {})
   LOCAL aOhne  := {}
   LOCAL cSku, nX

   FOR nX := 1 TO Len(aLines)
      IF CO_Storniert(aLines[nX])
         LOOP
      ENDIF
      cSku := CO_Str(CO_HDef(aLines[nX], "offer_sku", ""))
      IF CO_Artikelnr(cSku) == 0
         AAdd(aOhne, cSku)
      ENDIF
   NEXT
RETURN aOhne


// abgelehnte oder stornierte Position
STATIC FUNCTION CO_Storniert(hLine)
RETURN AScan({"REFUSED", "CANCELED"}, CO_Str(CO_HDef(hLine, "order_line_state", ""))) > 0


// Auftrag mit allen Positionen anlegen, danach die Lieferadresse des
// Endkunden als auftragsbezogene Adresse ("A"+AbNr, Gruppe 0).
// Liefert die AbNr (0, wenn kein Auftrag entstanden ist); cFehler ist leer,
// wenn alles geklappt hat.
STATIC FUNCTION CO_Auftrag(hOrder, cKunde, cFehler)
   LOCAL cOrderId := CO_Str(CO_HDef(hOrder, "order_id", ""))
   LOCAL aLines   := CO_HDef(hOrder, "order_lines", {})
   LOCAL hAdr     := CO_HDef(CO_HDef(hOrder, "customer", {=>}), "shipping_address", {=>})
   LOCAL nAbnr    := 0
   LOCAL lSaved   := .T.
   LOCAL oAuf, oPos, oErr, hLine, nX, nPreis

   cFehler := ""
   BEGIN SEQUENCE WITH {|e| Break(e)}
      oAuf := Auftrag():New(.T.)
      oAuf:Besda   := Date()
      oAuf:Kundma  := cKunde                     // Porto/Versandart/Incoterm aus dem Kunden
      oAuf:Money   := IF(Empty(oAuf:Kunde:Money), "EUR", AllTrim(oAuf:Kunde:Money))
      oAuf:nLiefAd := 1                          // Lieferadresse "Auftragsbezogen (A)"
      FOR nX := 1 TO Len(aLines)
         hLine := aLines[nX]
         IF CO_Storniert(hLine)
            LOOP
         ENDIF
         nPreis := Round(CO_HDef(hLine, "price_unit", 0), 2)    // Conrad liefert netto
         IF nPreis <= 0
            cFehler := "Position " + LTrim(Str(nX)) + " ohne Conrad-Preis"
            BREAK
         ENDIF
         lSaved := .F.
         oPos := oAuf:Positions:NewRecord()
         oPos:InitializeDefaultDates()
         oPos:Artikelnr := CO_Artikelnr(CO_Str(CO_HDef(hLine, "offer_sku", "")))
         oPos:VKQty     := CO_HDef(hLine, "quantity", 0)
         oPos:VkPr   := nPreis                   // nach der Menge, die setzt sonst den Kundenpreis
         oPos:Pe     := 1
         oPos:Rabatt := 0
         oPos:SetField("AUFNR", cOrderId)
         IF oPos:HasValidationErrors()
            cFehler := "Position " + LTrim(Str(nX)) + " ungueltig: " + CO_ValErr(oPos)
            BREAK
         ENDIF
         oPos:Save()                             // die erste Position vergibt die AbNr
         lSaved := .T.
         IF nAbnr == 0
            nAbnr := oAuf:AbNr
         ENDIF
      NEXT
      IF nAbnr == 0
         cFehler := "Bestellung ohne Positionen"
         BREAK
      ENDIF
      oAuf:HeadText := "Conrad-Bestellung " + cOrderId + " - Versand direkt an den Endkunden"
      oAuf:Save()
   RECOVER USING oErr
      IF Empty(cFehler)
         cFehler := "Fehler beim Anlegen des Auftrags" + ;
                    IF(ValType(oErr) == "O", ": " + CO_Str(oErr:Description) + " " + CO_Str(oErr:Operation), "")
      ENDIF
   END SEQUENCE
   IF ! lSaved .AND. oPos != NIL
      BEGIN SEQUENCE WITH {|e| Break(e)}
         oPos:Discard()
      END SEQUENCE
   ENDIF

   IF nAbnr > 0
      IF ! Empty(cFehler)
         cFehler := "Auftrag " + LTrim(Str(nAbnr)) + " nur teilweise angelegt - bitte pruefen. " + cFehler
      ELSEIF ! CO_Lieferadresse(nAbnr, hAdr, @cFehler)
         cFehler := "Auftrag " + LTrim(Str(nAbnr)) + " angelegt, aber die Lieferadresse fehlt - " + ;
                    "bitte von Hand eintragen, sonst geht die Ware an " + cKunde + ". " + cFehler
      ENDIF
   ENDIF
RETURN nAbnr


// Lieferadresse des Endkunden als auftragsbezogene Adresse speichern
STATIC FUNCTION CO_Lieferadresse(nAbnr, hAdr, cFehler)
   LOCAL cFirma  := CO_Teile(hAdr, "company")
   LOCAL cName   := CO_Teile(hAdr, "firstname", "lastname")
   LOCAL cStr    := CO_Teile(hAdr, "street_1")
   LOCAL cZusatz := CO_Teile(hAdr, "street_2")
   LOCAL cMatch  := "A" + LTrim(Str(nAbnr, 6))
   LOCAL lOk     := .F.
   LOCAL oAdr, oErr

   IF Empty(cName + cFirma) .OR. Empty(cStr) .OR. Empty(CO_Teile(hAdr, "city"))
      cFehler := "Conrad hat keine vollstaendige Lieferadresse geliefert."
      RETURN .F.
   ENDIF
   IF Empty(cFirma)
      cFirma := cName
      cName  := ""
   ENDIF
   IF Empty(cName)
      cName := cZusatz
   ELSEIF ! Empty(cZusatz)
      cStr += ", " + cZusatz
   ENDIF

   ku->(dbSetOrder( 1 ))
   IF ku->(dbSeek( Pad(cMatch, 8) + "0" ))
      cFehler := "Adresse " + cMatch + " gibt es schon."
      RETURN .F.
   ENDIF
   BEGIN SEQUENCE WITH {|e| Break(e)}
      oAdr := Adresse():New(.T.)
      oAdr:SetField("kunde", cMatch)
      oAdr:SetField("group", "0")
      oAdr:SetField("name1", cFirma)
      oAdr:SetField("name2", cName)
      oAdr:SetField("street", cStr)
      oAdr:SetField("plz", CO_Teile(hAdr, "zip_code"))
      oAdr:SetField("town", CO_Teile(hAdr, "city"))
      oAdr:SetField("telefon", CO_Teile(hAdr, "phone"))
      oAdr:CountryIso := CO_Iso2(CO_Teile(hAdr, "country_iso_code"))
      oAdr:SetField("k_seit", Date())
      oAdr:Save()
      lOk := .T.
   RECOVER USING oErr
      cFehler := "Fehler beim Speichern der Lieferadresse" + ;
                 IF(ValType(oErr) == "O", ": " + CO_Str(oErr:Description) + " " + CO_Str(oErr:Operation), "")
   END SEQUENCE
RETURN lOk


// Mirakl liefert das Land als ISO-3166 alpha-3 ("DEU"), Trader nutzt alpha-2
STATIC FUNCTION CO_Iso2(cIso)
   LOCAL aEnv := SaveEnv()
   LOCAL cIso2 := ""

   cIso := Upper(AllTrim(cIso))
   IF Len(cIso) == 2
      RETURN cIso
   ENDIF
   NetUse("countri2", "ct2", .F., 0)
   ct2->(dbGoTop())
   DO WHILE ! ct2->(Eof())
      IF Upper(AllTrim(ct2->Iso3)) == cIso
         cIso2 := AllTrim(ct2->Iso2)
         EXIT
      ENDIF
      ct2->(dbSkip())
   ENDDO
   RestEnv(aEnv, .F.)
RETURN IF(Empty(cIso2), "DE", cIso2)


// erste Fehlermeldung aus der Pruefung der Position
STATIC FUNCTION CO_ValErr(oPos)
   LOCAL hR := oPos:GetValidationResult()
   LOCAL aErr

   IF ValType(hR) == "H" .AND. HHasKey(hR, "errors")
      aErr := hR["errors"]
      IF ValType(aErr) == "A" .AND. Len(aErr) > 0
         RETURN CO_Str(CO_HDef(aErr[1], "message", ""))
      ENDIF
   ENDIF
RETURN ""


// Trader-Artikel zur SKU; 0, wenn es keinen gibt. art steht danach auf dem Artikel.
// - "12345S-06" -> Artikel 12345
// - CM-Teile hat product_data.prg mit dem Matchcode hochgeladen, "/" durch "-"
//   ersetzt, ggf. mit Zusatz wie "(S)" am Ende. Gesucht wird der Matchcode
//   erst wie geliefert, dann ohne Zusatz, dann mit "/" statt "-":
//   CMI35-V2-F-R-RD-24-M-S-28(S) -> CMI35/V2/F/R/RD/24/M/S/28
STATIC FUNCTION CO_Artikelnr(cSku)
   LOCAL nX := 1
   LOCAL nArtnr := 0
   LOCAL cOhne, aVersuche

   DO WHILE nX <= Len(cSku) .AND. IsDigit(SubStr(cSku, nX, 1))
      nX++
   ENDDO
   nArtnr := Val(Left(cSku, nX - 1))
   IF nArtnr != 0
      RETURN IF(art->(dbSeek( Str(nArtnr,6) )), nArtnr, 0)
   ENDIF

   cOhne := AllTrim(cSku)
   IF Right(cOhne, 1) == ")" .AND. "(" $ cOhne    // Zusatz "(S)" weg
      cOhne := AllTrim(Left(cOhne, RAt("(", cOhne) - 1))
   ENDIF
   aVersuche := {AllTrim(cSku), cOhne, StrTran(cOhne, "-", "/")}

   art->(dbSetOrder( 1 ))                        // Matchcode
   FOR nX := 1 TO Len(aVersuche)
      IF ! Empty(aVersuche[nX]) .AND. art->(dbSeek( Pad(aVersuche[nX], 25) ))
         nArtnr := art->Artikelnr
         EXIT
      ENDIF
   NEXT
   art->(dbSetOrder( 2 ))
   IF nArtnr != 0
      art->(dbSeek( Str(nArtnr,6) ))
   ENDIF
RETURN nArtnr


// Mailtext mit allem, was fuer den Auftrag gebraucht wird
STATIC FUNCTION CO_Text(hOrder, cKunde)
   LOCAL cNl    := Chr(13) + Chr(10)
   LOCAL hAdr   := CO_HDef(CO_HDef(hOrder, "customer", {=>}), "shipping_address", {=>})
   LOCAL aLines := CO_HDef(hOrder, "order_lines", {})
   LOCAL cText, cSku, hLine, nX

   cText := "Kunde: " + cKunde + cNl
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

   cText += "Positionen (Preise netto, wie von Conrad):" + cNl
   FOR nX := 1 TO Len(aLines)
      hLine := aLines[nX]
      cSku  := CO_Str(CO_HDef(hLine, "offer_sku", ""))
      cText += CO_Str(CO_HDef(hLine, "quantity", 0)) + " x "
      IF CO_Artikelnr(cSku) != 0
         cText += Trim(art->Matchcode) + " (Artikel " + LTrim(Str(art->Artikelnr)) + ")"
      ELSE
         cText += "SKU " + cSku + " - KEIN ARTIKEL GEFUNDEN"
      ENDIF
      cText += " je " + Transform(CO_HDef(hLine, "price_unit", 0), "999999.99") + " EUR" + cNl
   NEXT
   cText += "Versand: " + Transform(CO_HDef(hOrder, "shipping_price", 0), "999999.99") + " EUR" + cNl
   cText += "Gesamt:  " + Transform(CO_HDef(hOrder, "total_price", 0), "999999.99") + " EUR" + cNl
RETURN cText


// Mail als HTML: SendMail entfernt im Text Chr(10), Zeilenumbrueche gingen
// sonst verloren. Mit nAbnr > 0 steht oben ein Link auf den Auftrag.
STATIC FUNCTION CO_Mail(cMail, cSubject, cText, nAbnr)
   LOCAL cHtml := ""

   IF nAbnr > 0
      cHtml := 'Auftrag <a href="' + TraderUrl('EngAuft(' + LTrim(Str(nAbnr)) + ')') + '">' + ;
               LTrim(Str(nAbnr)) + '</a><br><br>'
   ENDIF
   cText := StrTran(StrTran(StrTran(cText, "&", "&amp;"), "<", "&lt;"), ">", "&gt;")
   cHtml += StrTran(cText, Chr(13) + Chr(10), "<br>")
   SendMail({{cMail, cMail}}, cSubject, cHtml, , , , .T.)
RETURN NIL


// eine Adresszeile aus mehreren Feldern; leer, wenn alle Felder leer sind
STATIC FUNCTION CO_Zeile(hAdr, ...)
   LOCAL cZeile := CO_Teile(hAdr, ...)
RETURN IF(Empty(cZeile), "", "  " + cZeile + Chr(13) + Chr(10))


// Werte mehrerer Adressfelder, mit Leerzeichen verbunden
STATIC FUNCTION CO_Teile(hAdr, ...)
   LOCAL aKeys := hb_AParams()
   LOCAL cZeile := "", cWert, nX

   FOR nX := 2 TO Len(aKeys)
      cWert := AllTrim(hb_Utf8ToStr(CO_Str(CO_HDef(hAdr, aKeys[nX], ""))))
      IF ! Empty(cWert)
         cZeile += IF(Empty(cZeile), "", " ") + cWert
      ENDIF
   NEXT
RETURN cZeile


// Aufruf der Mirakl-API mit dem Schluessel aus dem Keychain; NIL bei Fehler
STATIC FUNCTION CO_Request(cUrl, cMethod, hBody, cFehler)
   LOCAL oRest   := RestApi():New()
   LOCAL aHeader := {"Authorization: $APIKEY$", "Accept: application/json"}
   LOCAL nStatus := 0
   LOCAL cGrund  := ""
   LOCAL cShop   := AllTrim(CO_Str(GetValue("CONRAD_MIRAKL_SHOP")))
   LOCAL cAntwort, oErr

   IF hBody != NIL
      AAdd(aHeader, "Content-Type: application/json")
   ENDIF
   IF ! Empty(cShop)                             // Schluessel gilt fuer mehrere Shops
      cUrl += IF("?" $ cUrl, "&", "?") + "shop_id=" + cShop
   ENDIF
   oRest:cBaseUrl    := ""
   oRest:cApiKeyName := CO_KEYNAME
   cFehler := ""
   BEGIN SEQUENCE WITH {|e| Break(e)}
      cAntwort := oRest:Execute(cUrl, cMethod, hBody, aHeader, hBody != NIL, @nStatus, @cGrund)
   RECOVER USING oErr                            // z. B. Zieladresse im Schluesselbund nicht freigegeben
      cAntwort := NIL
      nStatus  := -1
      cGrund   := IF(ValType(oErr) == "O", CO_Str(oErr:Description), "")
   END SEQUENCE
   IF nStatus < 200 .OR. nStatus >= 300
      cFehler := "HTTP " + LTrim(Str(nStatus)) + " " + CO_Str(cGrund) + " " + Left(CO_Str(cAntwort), 300)
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
      cOut += IF(nX > 1, cTrenner, "") + CO_Str(aZeilen[nX])
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


// eine Datei je Tag, alle Laeufe des Tages haengen an; aeltere als
// CO_LOGTAGE Tage werden geloescht
STATIC FUNCTION CO_LogFile()
   LOCAL cDir := Path(CO_LOGDIR)
   LOCAL cFile, aAlt, nX

   IF ! hb_DirExists(Left(cDir, Len(cDir) - 1))
      MakeDir(Left(cDir, Len(cDir) - 1))
   ENDIF
   aAlt := Directory(cDir + "conrad_orders_*.log")
   FOR nX := 1 TO Len(aAlt)
      IF aAlt[nX, 3] < Date() - CO_LOGTAGE       // F_DATE
         FErase(cDir + aAlt[nX, 1])
      ENDIF
   NEXT
   cFile := cDir + "conrad_orders_" + DToS(Date()) + ".log"
   CO_Log(cFile, "INFO", "----- Lauf gestartet")
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
