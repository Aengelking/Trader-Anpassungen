/**
  * RUN_PUSH_REB - Eingangsrechnungen aus dem Rechnungseingangsbuch
  *
  * Zweiter Sammler der vorbereitenden Buchhaltung. belege_push.prg holt, was
  * in Trader gebucht ist (ENGRECH). Dieser hier holt den Rest: alles, was
  * durch das Rechnungseingangsbuch gelaufen und direkt in Lexware gebucht
  * worden ist - Spedition, Telekom, Paketdienst, Miete, Gebuehren.
  *
  *   DIESES PROGRAMM SCHREIBT NICHTS IN TRADER.
  *
  * Gelesen werden reb, rebprot, engkund und engrech. Kein Rec_Lock, kein
  * Kennzeichen, kein Status.
  *
  * WARUM DIE KONTIERUNG AUS LEXWARE KOMMT UND NICHT AUS reb
  *
  * reb kennt Beleg, Betrag, Kreditor und Kostenstelle - aber kein
  * Rechnungsdatum, keinen Steuersatz und kein Sachkonto. Als Beleg fuer eine
  * Buchhaltung ist das zu wenig.
  *
  * Gebucht sind diese Rechnungen aber laengst, naemlich in Lexware, und dort
  * stehen sie vollstaendig. LX_GetBookingsForID("ER" + <reb-ID>) findet sie
  * ueber den Belegtext und liefert je Buchungszeile Soll, Haben, Netto, USt
  * und das Belegdatum. Genau die Form, die document_lines erwartet - und
  * damit kommt auch eine aufgeteilte Rechnung mit allen ihren Zeilen hinueber
  * statt als eine Summe.
  *
  * Nur das Journal, nicht der Stapel: eine Stapelbuchung ist ein Entwurf.
  * Sie hier mitzunehmen hiesse, einen Beleg zu fuehren, den die Buchhaltung
  * noch gar nicht gebucht hat.
  *
  * WAS ENGRECH SCHON HAT, BLEIBT HIER LIEGEN
  *
  * Eine gebuchte reb-Zeile hat einen ENGRECH-Satz, und den sammelt
  * belege_push.prg - mit Traders eigener Kontierung aus der vat-Tabelle.
  * Dieselbe Rechnung von hier aus noch einmal zu senden hiesse, den besser
  * kontierten Beleg mit dem schlechter kontierten zu ueberschreiben: gleiche
  * erp_reference, gleicher Schluessel, der letzte Lauf gewinnt.
  *
  * Deshalb wird ENGRECH einmal komplett in eine Hashtabelle gelesen und jede
  * reb-Zeile dagegen geprueft. Ein Seek je Zeile ginge auch, aber ENGRECH
  * hat keinen Index auf (Liefma, Rechnr) - beide bestehenden Sammler lesen
  * es in Satznummernfolge.
  *
  * DIE REFERENZ IST DIESELBE WIE IM LIQUIDITAETSABGLEICH
  *
  * liquidity.prg baut aus den Lexware-Offenposten "ER-<Matchcode>-<Beleg>",
  * und ohne Matchcode "ER-KONTO-<Kontonummer>-<Beleg>". Hier entsteht
  * dieselbe Zeichenkette, damit Beleg und offener Posten in Finova
  * zusammenfinden - die Sicht belege_abgleich verbindet beide darueber.
  *
  * WAS FEHLT UND WARUM ES TROTZDEM RAUSGEHT
  *
  * Eine Faelligkeit hat reb nicht. Sie steht am Lexware-Offenposten, den
  * Finova ueber erp_items ohnehin fuehrt. Der Beleg geht ohne hinaus und
  * steht damit in documents_unkontiert - sichtbar statt stillschweigend
  * falsch. Der Trockenlauf zeigt, wie viele das sind; danach laesst sich
  * entscheiden, ob die Faelligkeit aus dem Offenposten nachgezogen wird.
  *
  * Aufruf: RUN_PUSH_REB()     Trockenlauf, sendet nichts
  *         RUN_PUSH_REB(.T.)  Echtlauf
  *
  * Stichtag ueber den Wertespeicher FIBU_SINCE, Vorgabe 01.01.2026.
  * Protokoll unter \export\reb_<Firma>_<Datum>_<Zeit>.txt
  **/

//snProtokoll und shWaehrungen muessen HIER stehen, nicht in fibu_common.prg:
//ein STATIC nach ausfuehrbarem Code gibt E0004, und snProtokoll braucht auch
//RUN_PUSH_REB selbst.
STATIC snProtokoll := 0
STATIC shWaehrungen := {=>}

STATIC shMatchcodes := {=>}

FUNCTION RUN_PUSH_REB(lLive)
   LOCAL oRest := RestApi():New()
   LOCAL dFrom
   LOCAL aBelege
   LOCAL aUebergangen := {}
   LOCAL cProtokoll
   LOCAL nGesendet := 0, nFehler := 0

   Default(@lLive, .F.)

   IF ! LockEntity("FIBU", 0, "%% wird bereits von % durchgefuehrt")
      RETURN .F.
   ENDIF

   dFrom := _BelegSince()
   cProtokoll := Path("\export\reb_" + _Firma() + "_" + DToS(Date()) + "_" + ;
                      StrTran(Time(), ":", "-") + ".txt")
   snProtokoll := FCreate(cProtokoll)

   Head("Rechnungseingangsbuch an Finova senden")
   _Log("Trader -> Finova, " + DToC(Date()) + " " + Time())
   _Log("Firma: " + _Firma() + "   Quelle: " + _Quelle())
   _Log(IF(lLive, "ECHTLAUF - Belege werden gesendet", "TROCKENLAUF - es wird nichts gesendet"))
   _Log("Belege ab " + DToC(dFrom))
   _Log("Trader wird ausschliesslich gelesen")
   _Log("")

   IF Empty(_Quelle())
      _Log("*** ABBRUCH: FIRMNO ist leer - das Mandantenkennzeichen fehlt.")
      _Log("*** Es gehoert in den Schluessel, unter dem Finova eintraegt.")
      _Finish(cProtokoll)
      UnLockEntity("FIBU", 0)
      RETURN .F.
   ENDIF

   aBelege := _CollectReb(dFrom, @aUebergangen)
   _Log("Belege gesamt:      " + LTrim(Str(Len(aBelege))))
   _Log("")

   _LogUebergangen(aUebergangen)
   _LogZusammenfassung(aBelege)
   _LogOhneKonto(aBelege)

   IF Len(aBelege) == 0
      _Log("Nichts zu senden.")
   ELSEIF ! lLive
      _LogVorschau(aBelege)
   ELSE
      _OhneHilfsfelder(aBelege)
      _Send(oRest, aBelege, @nGesendet, @nFehler)
      _Log("")
      _Log("Gesendet: " + LTrim(Str(nGesendet)) + "   Fehler: " + LTrim(Str(nFehler)))
   ENDIF

   _Finish(cProtokoll)
   UnLockEntity("FIBU", 0)

RETURN .T.

/**
  * Alle Referenzen, die ENGRECH schon fuehrt.
  *
  * Einmal lesen statt je reb-Zeile suchen: ENGRECH hat keinen Index auf
  * (Liefma, Rechnr), ein Seek je Zeile waere ein voller Durchlauf je Zeile.
  *
  * Aufgenommen wird alles, unabhaengig von Belegdatum und Buchungsstand -
  * die Frage ist nicht "sammelt belege_push.prg diesen Beleg heute", sondern
  * "kann er ihn ueberhaupt sammeln". Ein Beleg, der dort nur am Stichtag
  * scheitert, gehoert trotzdem ihm.
  **/
STATIC FUNCTION _EngrechRefs()
   LOCAL hRefs := {=>}
   LOCAL cRef

   NetUse("engrech", "rech")
   rech->(dbSetOrder(0))
   rech->(dbGoTop())

   DO WHILE ! rech->(Eof())
      IF ! Empty(rech->Liefma) .AND. ! Empty(rech->Rechnr)
         cRef := "ER-" + Trim(rech->Liefma) + "-" + Trim(rech->Rechnr)
         hRefs[cRef] := .T.
      ENDIF
      rech->(dbSkip())
   ENDDO

RETURN hRefs

/**
  * Der Matchcode zu einer Lieferantennummer.
  *
  * engkund in Ordnung 8 ist nach Lieferantennummer sortiert - derselbe Weg,
  * den reb_web.prg fuer den Zahlungstermin geht. Gemerkt wird das Ergebnis,
  * weil ein Lieferant viele Rechnungen hat.
  **/
STATIC FUNCTION _Matchcode(nLiefnr)
   LOCAL nRec, cCode := ""

   IF nLiefnr == 0
      RETURN ""
   ENDIF
   IF HHasKey(shMatchcodes, nLiefnr)
      RETURN shMatchcodes[nLiefnr]
   ENDIF

   NetUse("engkund", "ku")
   nRec := ku->(RecNo())
   BEGIN SEQUENCE
      ku->(dbSetOrder(8))
      IF ku->(dbSeek(Str(nLiefnr, 6)))
         cCode := Trim(ku->Kunde)
      ENDIF
   RECOVER
      cCode := ""
   END SEQUENCE
   ku->(dbGoTo(nRec))

   shMatchcodes[nLiefnr] := cCode

RETURN cCode

/**
  * Die Referenz einer reb-Zeile.
  *
  * Gebucht wird ueber engre(ku->Kunde, Pad(Beleg_Kurz oder Beleg, 14)) - die
  * Kurzform gewinnt, wenn sie gefuellt ist. Genau so entsteht rech->Rechnr,
  * und genau so muss die Referenz hier lauten, damit sie sich mit der aus
  * ENGRECH und der aus dem Offenposten deckt.
  **/
STATIC FUNCTION _RebRef(cMatchcode)
   LOCAL cBeleg := Trim(IF(Empty(reb->Beleg_Kurz), reb->Beleg, reb->Beleg_Kurz))

   IF Empty(cBeleg)
      RETURN ""
   ENDIF
   IF Empty(cMatchcode)
      RETURN "ER-KONTO-" + LTrim(Str(reb->Konto)) + "-" + cBeleg
   ENDIF

RETURN "ER-" + Trim(cMatchcode) + "-" + cBeleg

/**
  * Hat die Zeile eine Stornierung im Protokoll?
  *
  * rebprot in Ordnung 2 ist nach ID + Type sortiert; check_reb_betrag.prg
  * prueft genauso.
  **/
STATIC FUNCTION _IstStorniert(nId)
   LOCAL nRec, lStorno

   NetUse("rebprot", "rebp")
   nRec := rebp->(RecNo())
   BEGIN SEQUENCE
      rebp->(dbSetOrder(2))
      lStorno := rebp->(dbSeek(Str(nId, 9) + "STORN"))
   RECOVER
      lStorno := .F.
   END SEQUENCE
   rebp->(dbGoTo(nRec))

RETURN lStorno

/**
  * Die Belege aus dem Rechnungseingangsbuch.
  **/
STATIC FUNCTION _CollectReb(dFrom, aUebergangen)
   LOCAL aBelege := {}
   LOCAL hEngrech := _EngrechRefs()
   LOCAL nJahr, nBis := Year(Date())
   LOCAL cJahr, cMatchcode, cRef
   LOCAL aBookings, hBeleg
   LOCAL nScanned := 0

   _Log("ENGRECH kennt bereits " + LTrim(Str(Len(hEngrech))) + " Belegreferenzen.")

   NetUse("reb", "reb")
   reb->(dbClearFilter())
   reb->(dbSetOrder(1))

   //Die ID traegt das Jahr in den ersten beiden Stellen - so sucht auch
   //check_reb_betrag.prg. Jahrweise, weil ein Seek ueber die gesamte Tabelle
   //sonst am Stichtag vorbeilaufen wuerde.
   FOR nJahr := Year(dFrom) TO nBis
      cJahr := Right(Str(nJahr, 4), 2)
      reb->(dbSeek(cJahr + Replicate("0", 7), .T.))

      DO WHILE ! reb->(Eof()) .AND. Left(Str(reb->ID, 9), 2) == cJahr
         nScanned++
         cMatchcode := _Matchcode(reb->Liefnr)
         cRef       := _RebRef(cMatchcode)

         DO CASE
         CASE Empty(cRef)
            AAdd(aUebergangen, {"REB" + LTrim(Str(reb->ID)), "keine Belegnummer"})

         CASE _IstStorniert(reb->ID)
            AAdd(aUebergangen, {cRef, "storniert"})

         CASE HHasKey(hEngrech, cRef)
            //Gehoert belege_push.prg. Nicht gemeldet - das ist der Normalfall
            //fuer jede in Trader gebuchte Rechnung und waere reines Rauschen.

         OTHERWISE
            aBookings := _Buchungen(reb->ID)

            DO CASE
            CASE Len(aBookings) == 0 .AND. reb->Status == 9
               //Als verbucht gekennzeichnet, aber in Lexware nichts zu
               //finden. Das ist keine Auslassung, sondern ein Widerspruch.
               AAdd(aUebergangen, {cRef, "als verbucht markiert, in Lexware nicht gefunden"})

            CASE Len(aBookings) == 0
               AAdd(aUebergangen, {cRef, "noch nicht gebucht"})

            OTHERWISE
               hBeleg := _BelegAusBuchungen(cRef, cMatchcode, aBookings)
               IF hBeleg == NIL
                  AAdd(aUebergangen, {cRef, "keine Zeile beruehrt den Kreditor " + LTrim(Str(reb->Konto))})
               ELSEIF hBeleg["gross_amount"] == 0
                  AAdd(aUebergangen, {cRef, "Betrag 0,00"})
               ELSE
                  AAdd(aBelege, hBeleg)
               ENDIF
            ENDCASE
         ENDCASE

         reb->(dbSkip())
      ENDDO
   NEXT

   reb->(dbClearFilter())

   _Log("  reb gelesen: " + LTrim(Str(nScanned)))

RETURN aBelege

/**
  * Die Lexware-Buchungszeilen zu einer reb-ID.
  *
  * .F. = nur das Journal, kein Stapel. Eine Stapelbuchung ist ein Entwurf;
  * sie als Beleg zu fuehren hiesse, etwas zu buchen, was die Buchhaltung
  * noch nicht gebucht hat.
  **/
STATIC FUNCTION _Buchungen(nId)
   LOCAL aBookings

   BEGIN SEQUENCE
      aBookings := LX_GetBookingsForID("ER" + Str(nId, 9), .F.)
   RECOVER
      aBookings := {}
   END SEQUENCE

   IF ValType(aBookings) != "A"
      aBookings := {}
   ENDIF

RETURN aBookings

/**
  * Aus den Buchungszeilen einen Beleg mit seinen Zeilen bauen.
  *
  * Eine Seite jeder Zeile ist der Kreditor, die andere das Sachkonto. Welche,
  * haengt an der Richtung: bei der Rechnung steht der Kreditor im Haben, bei
  * der Gutschrift im Soll. check_reb_betrag.prg rechnet denselben Saldo als
  * Haben minus Soll.
  *
  * Zeilen, die den Kreditor gar nicht beruehren, gehoeren nicht zu dieser
  * Rechnung - eine Umbuchung etwa. Sie werden gezaehlt, nicht uebernommen.
  **/
STATIC FUNCTION _BelegAusBuchungen(cRef, cMatchcode, aBookings)
   LOCAL hBeleg, aZeilen := {}
   LOCAL hBuchung, hZeile
   LOCAL nKreditor := reb->Konto
   LOCAL nBrutto, nSumme := 0
   LOCAL dBeleg := CToD("")
   LOCAL nFremd := 0
   LOCAL cKonto

   FOR EACH hBuchung IN aBookings
      nBrutto := Round(hBuchung["NETTO"] + hBuchung["UST"], 2)

      DO CASE
      CASE hBuchung["HABEN"] == nKreditor
         cKonto := LTrim(Str(hBuchung["SOLL"]))
      CASE hBuchung["SOLL"] == nKreditor
         //Gutschrift: der Kreditor wird entlastet, der Betrag dreht sich.
         cKonto  := LTrim(Str(hBuchung["HABEN"]))
         nBrutto := -nBrutto
      OTHERWISE
         nFremd++
         LOOP
      ENDCASE

      IF nBrutto == 0
         //Eine Zeile ueber 0,00 weist die Datenbank ab. Sie traegt auch
         //nichts bei, also faellt sie still weg - der Belegbetrag bleibt.
         LOOP
      ENDIF

      hZeile := {=>}
      hZeile["line_no"]     := Len(aZeilen) + 1
      hZeile["amount"]      := nBrutto
      hZeile["account"]     := cKonto
      hZeile["vat_amount"]  := Round(IF(nBrutto < 0, -hBuchung["UST"], hBuchung["UST"]), 2)
      hZeile["vat_rate"]    := _SteuerSatz(hBuchung["NETTO"], hBuchung["UST"])
      hZeile["cost_center"] := Trim(reb->KS)
      hZeile["description"] := hb_StrToUTF8(Trim(hBuchung["TEXT"]))
      AAdd(aZeilen, hZeile)

      nSumme += nBrutto
      IF Empty(dBeleg) .AND. ValType(hBuchung["DATUM"]) == "D"
         dBeleg := hBuchung["DATUM"]
      ENDIF
   NEXT

   IF Len(aZeilen) == 0
      RETURN NIL
   ENDIF
   IF Empty(dBeleg)
      dBeleg := Date()
   ENDIF

   hBeleg := {=>}
   hBeleg["erp_reference"] := cRef
   hBeleg["doc_type"]      := "purchase_invoice"
   hBeleg["doc_number"]    := Trim(IF(Empty(reb->Beleg_Kurz), reb->Beleg, reb->Beleg_Kurz))
   hBeleg["doc_date"]      := _IsoDate(dBeleg)

   hBeleg["counterparty_name"]    := hb_StrToUTF8(Trim(reb->Name))
   hBeleg["counterparty_ref"]     := cMatchcode
   hBeleg["counterparty_account"] := LTrim(Str(nKreditor))

   //Das Lexware-Journal fuehrt die Firmenwaehrung. Eine Rechnung in
   //Fremdwaehrung steht dort bereits umgerechnet - der Belegbetrag ist also
   //Euro, und ein Kurs gehoert nicht daran.
   hBeleg["currency"]     := "EUR"
   hBeleg["gross_amount"] := Round(nSumme, 2)
   hBeleg["lines"]        := aZeilen

   hBeleg["source"]     := _Quelle()
   hBeleg["company_id"] := GetConfigValue("FIRMNO")

   //Zaehlwert fuer die Vorschau, geht nicht mit hinaus.
   hBeleg["_fremd"] := nFremd

RETURN hBeleg

/**
  * Der Steuersatz einer Buchungszeile, aus Netto und USt zurueckgerechnet.
  *
  * Lexware fuehrt den Schluessel, nicht den Satz. Gerundet wird auf zwei
  * Stellen, damit 7,00 und 19,00 herauskommen und nicht 6,9998.
  **/
STATIC FUNCTION _SteuerSatz(nNetto, nUst)
   IF nNetto == 0
      RETURN 0
   ENDIF
RETURN Round(nUst / nNetto * 100, 2)

/**
  * Was im Zeitraum liegt und trotzdem nicht mitkommt.
  **/
STATIC FUNCTION _LogUebergangen(aUebergangen)
   LOCAL hGruppen := {=>}
   LOCAL aEintrag, cGrund, aGruende

   IF Len(aUebergangen) == 0
      RETURN NIL
   ENDIF

   _Log("IM ZEITRAUM, ABER NICHT UEBERNOMMEN: " + LTrim(Str(Len(aUebergangen))))

   FOR EACH aEintrag IN aUebergangen
      cGrund := aEintrag[2]
      IF ! HHasKey(hGruppen, cGrund)
         hGruppen[cGrund] := {}
      ENDIF
      AAdd(hGruppen[cGrund], aEintrag[1])
   NEXT

   aGruende := HGetKeys(hGruppen)
   ASort(aGruende)

   FOR EACH cGrund IN aGruende
      _Log("  " + PadR(cGrund, 46) + PadL(LTrim(Str(Len(hGruppen[cGrund]))), 5) + ;
           "  " + _Kuerze(hGruppen[cGrund]))
   NEXT
   _Log("")

RETURN NIL

STATIC FUNCTION _Kuerze(aRefs)
   LOCAL cText := ""
   LOCAL nX

   FOR nX := 1 TO Min(6, Len(aRefs))
      cText += IF(nX > 1, ", ", "") + aRefs[nX]
   NEXT
   IF Len(aRefs) > 6
      cText += ", ... (" + LTrim(Str(Len(aRefs) - 6)) + " weitere)"
   ENDIF

RETURN cText

/**
  * Die Aufstellung ueber alle Belege, vor der Liste.
  *
  * Nach Sachkonto, weil das die Zahl ist, die sich gegen die Buchhaltung
  * halten laesst - und nach Kostenstelle, weil genau dafuer die Aufteilung
  * gemacht wird.
  **/
STATIC FUNCTION _LogZusammenfassung(aBelege)
   LOCAL hKonten := {=>}, hKosten := {=>}
   LOCAL hBeleg, hZeile
   LOCAL nZeilen := 0, nGesplittet := 0

   IF Len(aBelege) == 0
      RETURN NIL
   ENDIF

   FOR EACH hBeleg IN aBelege
      nZeilen += Len(hBeleg["lines"])
      IF Len(hBeleg["lines"]) > 1
         nGesplittet++
      ENDIF
      FOR EACH hZeile IN hBeleg["lines"]
         _Zaehle(hKonten, PadR(hZeile["account"], 12), hZeile["amount"])
         _Zaehle(hKosten, PadR(IF(Empty(hZeile["cost_center"]), "(ohne)", ;
                                  hZeile["cost_center"]), 12), hZeile["amount"])
      NEXT
   NEXT

   _Log("ZUSAMMENFASSUNG ueber alle " + LTrim(Str(Len(aBelege))) + " Belege")
   _Log("  " + LTrim(Str(nZeilen)) + " Buchungszeilen, davon " + ;
        LTrim(Str(nGesplittet)) + " Belege mit mehr als einer Zeile")
   _LogGruppe("nach Sachkonto", hKonten)
   _LogGruppe("nach Kostenstelle", hKosten)
   _Log("")

RETURN NIL

/**
  * Belege, deren Zeilen kein Sachkonto tragen.
  *
  * Sollte es nicht geben - die Kontierung kommt aus Lexware. Wenn doch, ist
  * eine Buchung dort unvollstaendig, und das gehoert benannt statt gezaehlt.
  **/
STATIC FUNCTION _LogOhneKonto(aBelege)
   LOCAL hBeleg, hZeile
   LOCAL aFehlend := {}

   FOR EACH hBeleg IN aBelege
      FOR EACH hZeile IN hBeleg["lines"]
         IF Empty(hZeile["account"]) .OR. hZeile["account"] == "0"
            AAdd(aFehlend, hBeleg["erp_reference"])
            EXIT
         ENDIF
      NEXT
   NEXT

   IF Len(aFehlend) == 0
      _Log("Alle Belege sind kontiert.")
      _Log("")
      RETURN NIL
   ENDIF

   _Log("OHNE SACHKONTO: " + LTrim(Str(Len(aFehlend))))
   _Log("  " + _Kuerze(aFehlend))
   _Log("  Sie gehen trotzdem hinueber und stehen in Finova unter")
   _Log("  documents_unkontiert.")
   _Log("")

RETURN NIL

/**
  * Die Vorschau. Hoechstens 200 Belege - die Aufstellung oben gilt fuer alle.
  **/
STATIC FUNCTION _LogVorschau(aBelege)
   LOCAL hBeleg, hZeile
   LOCAL nX, nMax := Min(200, Len(aBelege))

   _Log("VORSCHAU (" + LTrim(Str(nMax)) + " von " + LTrim(Str(Len(aBelege))) + ")")

   FOR nX := 1 TO nMax
      hBeleg := aBelege[nX]
      _Log("  " + PadR(hBeleg["erp_reference"], 30) + ;
           PadR(hBeleg["doc_date"], 12) + ;
           PadL(Str(hBeleg["gross_amount"], 12, 2), 13) + "  " + ;
           PadR(Left(hb_UTF8ToStr(hBeleg["counterparty_name"]), 24), 25) + ;
           "Kreditor " + hBeleg["counterparty_account"])

      IF Len(hBeleg["lines"]) > 1 .OR. hBeleg["_fremd"] > 0
         FOR EACH hZeile IN hBeleg["lines"]
            _Log("      Zeile " + LTrim(Str(hZeile["line_no"])) + ": " + ;
                 PadR(hZeile["account"], 10) + ;
                 PadL(Str(hZeile["amount"], 12, 2), 13) + ;
                 "  " + Str(hZeile["vat_rate"], 5, 2) + "%" + ;
                 IF(Empty(hZeile["cost_center"]), "", "  KS " + hZeile["cost_center"]))
         NEXT
         IF hBeleg["_fremd"] > 0
            _Log("      (" + LTrim(Str(hBeleg["_fremd"])) + " Buchungszeilen beruehren den Kreditor nicht)")
         ENDIF
      ENDIF
   NEXT
   _Log("")

RETURN NIL

/**
  * Zaehlwerte der Vorschau entfernen, bevor der Beleg hinausgeht.
  *
  * `_fremd` sagt, wie viele Buchungszeilen den Kreditor nicht beruehren -
  * das gehoert ins Protokoll, nicht in die Belegtabelle. erp-push wuerde es
  * zwar ohnehin nicht lesen, aber ein Feld mitzuschicken, das niemand
  * erwartet, laedt zum Missverstaendnis ein.
  **/
STATIC FUNCTION _OhneHilfsfelder(aBelege)
   LOCAL hBeleg

   FOR EACH hBeleg IN aBelege
      IF HHasKey(hBeleg, "_fremd")
         HDel(hBeleg, "_fremd")
      ENDIF
   NEXT

RETURN NIL

//Gemeinsame Helfer. Ganz unten, damit hb_hrbRun weiter RUN_PUSH_REB als
//Einstiegspunkt nimmt - die erste oeffentliche Funktion dieser Datei.
#include 'x:\run\fibu\fibu_common.prg'
