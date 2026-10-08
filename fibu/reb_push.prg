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
  * ER LIEFERT DEN BELEG, NICHT DIE BUCHUNG
  *
  * Die erste Fassung hat versucht, die Kontierung aus dem Lexware-Journal
  * zurueckzurechnen (LX_GetBookingsForID). Der Trockenlauf vom 26.09. und die
  * Diagnose vom 28.09. haben gezeigt, warum das nicht traegt: im Journal
  * steht nicht die Kontierung einer Rechnung, sondern ihre GESCHICHTE.
  *
  * Nebeneinander liegen dort die Eingangsbuchung, ihr Storno, die
  * Umbuchung, die Zahlung, die Waehrungsdifferenz und die Aufloesung eines
  * Zwischenkontos. Ein Beispiel aus der Diagnose - Conrad, reb-ID 260000002:
  *
  *     1121   76157 / 1200    135.05      die ZAHLUNG
  *    21328    4760 / 70280   113.49+USt  Rechnung, falscher Kreditor
  *    21345    4760 / 70280  -113.49-USt  <Storno>
  *    21346    4760 / 76157   113.49+USt  Rechnung, richtig
  *
  * Die alte Fassung las die Zahlung als Gutschrift, drehte ihr Vorzeichen und
  * kam mit der richtigen Buchung zusammen auf genau 0,00 - der Beleg fiel als
  * "Betrag 0,00" heraus. Er ist echt.
  *
  * Und selbst die saubere Splitbuchung fuehrt nicht immer zum Aufwandskonto:
  * bei Plusnet, Moss und Telekom bucht die Eingangsbuchung gegen ein
  * Zwischenkonto, und der eigentliche Aufwand steht in einer zweiten Buchung,
  * die es wieder aufloest.
  *
  * Das liesse sich alles regeln - ueber Buchungsnummern, Bankkonten,
  * Zwischenkonten, Stornotexte. Nur waere das die Buchungspraxis mehrerer
  * Jahre, nachgebaut in einem Run-Skript, dessen erklaerter Zweck eine
  * Uebergangsloesung ist. Jede dieser Regeln ist eine Stelle, an der man
  * falsch liegen kann, und keine davon faellt laut auf.
  *
  * Deshalb liefert dieser Sammler den Beleg: Nummer, Datum, Lieferant,
  * Betrag, Kostenstelle. Die Kontierung kommt spaeter aus dem Beleg selbst.
  *
  * FUER DIE BANKBUCHUNG REICHT DAS
  *
  * Um "Bank an Kreditor" zu buchen, braucht es den Beleg, den Kreditor und
  * den Betrag - nicht das Aufwandskonto. Das gehoert zur Rechnungsbuchung,
  * nicht zur Zahlung.
  *
  * WAS ENGRECH SCHON HAT, BLEIBT HIER LIEGEN
  *
  * Eine in Trader gebuchte Rechnung hat einen ENGRECH-Satz, und den sammelt
  * belege_push.prg - mit Traders eigener Kontierung aus der vat-Tabelle.
  * Dieselbe Rechnung von hier aus noch einmal zu senden hiesse, den
  * kontierten Beleg mit dem unkontierten zu ueberschreiben: gleiche
  * erp_reference, gleicher Schluessel, der letzte Lauf gewinnt.
  *
  * Deshalb wird ENGRECH einmal komplett in eine Hashtabelle gelesen und jede
  * reb-Zeile dagegen geprueft. Ein Seek je Zeile ginge auch, aber ENGRECH
  * hat keinen Index auf (Liefma, Rechnr).
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
  * Sachkonto und Steuersatz hat reb nicht, und die Faelligkeit auch nicht -
  * die steht am Lexware-Offenposten, den Finova ueber erp_items ohnehin
  * fuehrt. Die Belege gehen ohne hinaus und stehen damit vollzaehlig in
  * documents_unkontiert. Das ist kein Mangel, sondern der Zustand: Beleg da,
  * Buchung folgt.
  *
  * Das DATUM ist das Eingangsdatum aus dem Protokoll (rebprot, Typ RECV),
  * nicht das Rechnungsdatum - reb fuehrt keines. In der Praxis liegen beide
  * wenige Tage auseinander; fuer eine Periodenabgrenzung ist das zu ungenau.
  * Das richtige Datum kommt mit der Kontierung aus dem Beleg.
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
   _Log("Dieser Sammler liefert den Beleg, nicht die Buchung. Sachkonto,")
   _Log("Steuersatz und Faelligkeit fehlen absichtlich - sie kommen aus dem")
   _Log("Beleg selbst. Alle Belege stehen deshalb in documents_unkontiert.")
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
  * Das Protokoll zu einer reb-Zeile: Eingangsdatum und ob storniert.
  *
  * rebprot in Ordnung 2 ist nach ID + Type sortiert. Beide Angaben kommen aus
  * demselben Bereich, deshalb ein Durchlauf statt zweier Seeks.
  *
  * RECV ist der Eingang ins Buch. Er ist NICHT das Rechnungsdatum - reb
  * fuehrt keines -, aber er ist das einzige verlaessliche Datum, das Trader
  * zu diesem Beleg hat.
  **/
STATIC FUNCTION _RebProtokoll(nId, dEingang, lStorno)
   LOCAL nRec

   dEingang := CToD("")
   lStorno  := .F.

   NetUse("rebprot", "rebp")
   nRec := rebp->(RecNo())

   BEGIN SEQUENCE
      rebp->(dbSetOrder(2))
      IF rebp->(dbSeek(Str(nId, 9), .T.))
         DO WHILE ! rebp->(Eof()) .AND. rebp->Id == nId
            DO CASE
            CASE Trim(rebp->Type) == "STORN"
               lStorno := .T.
            CASE Trim(rebp->Type) == "RECV" .AND. Empty(dEingang)
               dEingang := SToD(rebp->DateTime)
            ENDCASE
            rebp->(dbSkip())
         ENDDO
      ENDIF
   RECOVER
      dEingang := CToD("")
      lStorno  := .F.
   END SEQUENCE

   rebp->(dbGoTo(nRec))

RETURN NIL

/**
  * Die Belege aus dem Rechnungseingangsbuch.
  **/
STATIC FUNCTION _CollectReb(dFrom, aUebergangen)
   LOCAL aBelege := {}
   LOCAL hEngrech := _EngrechRefs()
   LOCAL nJahr, nBis := Year(Date())
   LOCAL cJahr, cMatchcode, cRef
   LOCAL dEingang, lStorno
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
         _RebProtokoll(reb->ID, @dEingang, @lStorno)

         DO CASE
         CASE Empty(cRef)
            AAdd(aUebergangen, {"REB" + LTrim(Str(reb->ID)), "keine Belegnummer"})

         CASE lStorno
            AAdd(aUebergangen, {cRef, "storniert"})

         CASE HHasKey(hEngrech, cRef)
            //Gehoert belege_push.prg. Nicht gemeldet - das ist der Normalfall
            //fuer jede in Trader gebuchte Rechnung und waere reines Rauschen.

         CASE Round(reb->Betrag, 2) == 0
            AAdd(aUebergangen, {cRef, "Betrag 0,00"})

         CASE Empty(dEingang)
            //Ohne Datum kein Beleg: doc_date ist in Finova Pflicht, und ein
            //erfundenes Datum waere schlechter als eine gemeldete Luecke.
            AAdd(aUebergangen, {cRef, "kein Eingangsdatum im Protokoll"})

         CASE dEingang < dFrom
            //Vor dem Stichtag. Nicht gemeldet, das ist keine Auslassung.

         OTHERWISE
            AAdd(aBelege, _BelegAusReb(cRef, cMatchcode, dEingang))
         ENDCASE

         reb->(dbSkip())
      ENDDO
   NEXT

   reb->(dbClearFilter())

   _Log("  reb gelesen: " + LTrim(Str(nScanned)))

RETURN aBelege

/**
  * Der Beleg, aus reb allein.
  *
  * Eine Buchungszeile ueber den vollen Betrag, ohne Sachkonto. Die
  * Kostenstelle kommt mit, weil reb sie fuehrt und sie spaeter die
  * Aufteilung traegt.
  **/
STATIC FUNCTION _BelegAusReb(cRef, cMatchcode, dEingang)
   LOCAL hBeleg, hZeile

   hZeile := {=>}
   hZeile["line_no"]     := 1
   hZeile["amount"]      := Round(reb->Betrag, 2)
   hZeile["account"]     := ""
   hZeile["cost_center"] := Trim(reb->KS)

   hBeleg := {=>}
   hBeleg["erp_reference"] := cRef
   hBeleg["doc_type"]      := "purchase_invoice"
   hBeleg["doc_number"]    := Trim(IF(Empty(reb->Beleg_Kurz), reb->Beleg, reb->Beleg_Kurz))
   hBeleg["doc_date"]      := _IsoDate(dEingang)

   hBeleg["counterparty_name"]    := hb_StrToUTF8(Trim(reb->Name))
   hBeleg["counterparty_ref"]     := cMatchcode
   //Steht hier eine 0, kennt reb kein Kreditorenkonto - dann kommt es ueber
   //den Lieferanten, und zwar je Rechnung verschieden (rech->Konto steht an
   //der Rechnung, nicht am Lieferanten). Hier zu raten hiesse, ein falsches
   //Personenkonto plausibel aussehen zu lassen.
   hBeleg["counterparty_account"] := IF(reb->Konto == 0, "", LTrim(Str(reb->Konto)))

   //Das Rechnungseingangsbuch fuehrt den Betrag in Firmenwaehrung.
   hBeleg["currency"]     := "EUR"
   hBeleg["gross_amount"] := Round(reb->Betrag, 2)
   hBeleg["lines"]        := {hZeile}

   hBeleg["source"]     := _Quelle()
   hBeleg["company_id"] := GetConfigValue("FIRMNO")

   //Nur fuer Protokoll und Vorschau, geht nicht mit hinaus.
   hBeleg["_status"] := reb->Status
   hBeleg["_id"]     := reb->ID

RETURN hBeleg

/**
  * Zaehlwerte der Vorschau entfernen, bevor der Beleg hinausgeht.
  **/
STATIC FUNCTION _OhneHilfsfelder(aBelege)
   LOCAL hBeleg, cFeld

   FOR EACH hBeleg IN aBelege
      FOR EACH cFeld IN {"_status", "_id"}
         IF HHasKey(hBeleg, cFeld)
            HDel(hBeleg, cFeld)
         ENDIF
      NEXT
   NEXT

RETURN NIL

STATIC FUNCTION _StatusText(nStatus)
   DO CASE
   CASE nStatus == 9 ; RETURN "verbucht"
   CASE nStatus == 8 ; RETURN "genehmigt"
   CASE nStatus >= 4 ; RETURN "Freigabe"
   ENDCASE
RETURN "offen"

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
      _Log("  " + PadR(cGrund, 34) + PadL(LTrim(Str(Len(hGruppen[cGrund]))), 5) + ;
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
  * Nach Kostenstelle, weil das die einzige Zuordnung ist, die reb mitbringt -
  * und nach Buchungsstand, weil eine erfasste, aber nicht verbuchte Rechnung
  * liegengebliebene Arbeit ist und keine Buchhaltungsfrage.
  *
  * Ohne Personenkonto wird eigens gezaehlt: dort steht in reb eine 0, und die
  * Bankbuchung braucht den Kreditor.
  **/
STATIC FUNCTION _LogZusammenfassung(aBelege)
   LOCAL hKosten := {=>}, hStatus := {=>}
   LOCAL hBeleg
   LOCAL nOhneKonto := 0

   IF Len(aBelege) == 0
      RETURN NIL
   ENDIF

   FOR EACH hBeleg IN aBelege
      _Zaehle(hKosten, PadR(IF(Empty(hBeleg["lines"][1]["cost_center"]), "(ohne)", ;
                              hBeleg["lines"][1]["cost_center"]), 12), hBeleg["gross_amount"])
      _Zaehle(hStatus, PadR(_StatusText(hBeleg["_status"]), 12), hBeleg["gross_amount"])
      IF Empty(hBeleg["counterparty_account"])
         nOhneKonto++
      ENDIF
   NEXT

   _Log("ZUSAMMENFASSUNG ueber alle " + LTrim(Str(Len(aBelege))) + " Belege")
   _LogGruppe("nach Kostenstelle", hKosten)
   _LogGruppe("nach Buchungsstand", hStatus)
   _Log("")

   IF nOhneKonto > 0
      _Log("OHNE PERSONENKONTO: " + LTrim(Str(nOhneKonto)))
      _Log("  reb fuehrt dort kein Kreditorenkonto. Sie gehen trotzdem mit und")
      _Log("  stehen in documents_unkontiert; die Bankbuchung braucht es aber.")
      _Log("")
   ENDIF

RETURN NIL

/**
  * Die Vorschau. Hoechstens 200 Belege - die Aufstellung oben gilt fuer alle.
  **/
STATIC FUNCTION _LogVorschau(aBelege)
   LOCAL hBeleg
   LOCAL nX, nMax := Min(200, Len(aBelege))

   _Log("VORSCHAU (" + LTrim(Str(nMax)) + " von " + LTrim(Str(Len(aBelege))) + ")")

   FOR nX := 1 TO nMax
      hBeleg := aBelege[nX]
      _Log("  " + PadR(hBeleg["erp_reference"], 30) + ;
           PadR(hBeleg["doc_date"], 12) + ;
           PadL(Str(hBeleg["gross_amount"], 12, 2), 13) + "  " + ;
           PadR(Left(hb_UTF8ToStr(hBeleg["counterparty_name"]), 24), 25) + ;
           PadR(IF(Empty(hBeleg["counterparty_account"]), "(kein Konto)", ;
                   "Kreditor " + hBeleg["counterparty_account"]), 16) + ;
           PadR(_StatusText(hBeleg["_status"]), 10) + ;
           IF(Empty(hBeleg["lines"][1]["cost_center"]), "", ;
              "KS " + hBeleg["lines"][1]["cost_center"]))
   NEXT
   _Log("")

RETURN NIL

//Gemeinsame Helfer. Ganz unten, damit hb_hrbRun weiter RUN_PUSH_REB als
//Einstiegspunkt nimmt - die erste oeffentliche Funktion dieser Datei.
#include 'x:\run\fibu\fibu_common.prg'
