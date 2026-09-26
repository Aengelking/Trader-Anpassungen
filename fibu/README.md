# Vorbereitende Buchhaltung

Trader-Seite des Ausbaus von Finova zur vorbereitenden Buchhaltung. Ziel ist ein
DATEV-Buchungsstapel, der sich in DATEV oder Lexware einlesen lässt — und der
Fremdwährungen richtig bewertet.

**Keines dieser Programme schreibt in Trader.** Gelesen wird ausschließlich.

| | |
|---|---|
| `vat_dump.prg` | zieht die Kontierungsstammdaten ab (`vat`, `lexware.ini`, `skontoa`) |
| `kontierung_angleichen.md` | Arbeitsliste: was in beiden Firmen nachzupflegen ist |
| `belege_push.prg` | sendet die Belege mit ihrem Buchungssatz an Finova |

## Reihenfolge

1. **`RUN_VAT_DUMP()`** in jeder Firma — zeigt, was die Kontierung hergibt.
2. **Die Arbeitsliste abarbeiten.** Solange in Automotive die Alt-Konten leer sind
   und `DATE` auf dem Anlagedatum steht, bekommt jeder ältere Beleg 0% und ein
   leeres Konto.
3. **`RUN_PUSH_BELEGE()`** als Trockenlauf. Das Protokoll listet, was noch nicht
   kontiert ist.
4. **`RUN_PUSH_BELEGE(.T.)`** erst, wenn diese Liste gelesen wurde.

## Warum Trader den Buchungssatz bildet

Die Kontierung steht vollständig in Trader und wird dort seit Jahren gepflegt: die
Erlös-, Wareneingangs- und Skontokonten je Steuersatz in `vat`, die Auffangkonten
in der `lexware.ini`, das Debitorenkonto am Kunden, das Kreditorenkonto an der
Rechnung. Genau daraus baut `LX_BookOutInvoice` / `LX_BookInInvoice` den Satz für
Lexware.

Dieselbe Logik in Finova noch einmal zu bauen hieße, zwei Wahrheiten zu pflegen,
die irgendwann auseinanderlaufen — unbemerkt, weil beide plausibel aussehen.

Die Richtung, wie in `lexware.prg`:

| | Soll | Haben |
|---|---|---|
| Ausgangsrechnung | Debitor (`ku->Nummer`) | Erlöskonto (`vat->VerkNeu` / `VerkAlt`) |
| Eingangsrechnung | Wareneingang (`vat->EkNeu` / `EkAlt`) | Kreditor (`rech->Konto`) |

`rech->Konto` steht an der **Rechnung**, nicht am Lieferanten — ein Lieferant kann
je Währung ein eigenes Konto haben.

## Die Fälligkeit ist nicht nachrechenbar

Sie wird fertig übergeben, und das ist keine Bequemlichkeit. Bei Zahlungsbedingung
`ziel1 = -4` holt `GetSkonto` die Staffel nicht aus `skontoa`, sondern **führt ein
kundeneigenes Programm aus** (`PT_PATH\<Kundennummer>.prg`, über `MBaseRun`). Ein
Nachbau in SQL könnte diese Kunden nur raten.

Die übrigen negativen Ziele sind ebenfalls Sonderfälle: `-2` Lastschrifteinzug,
`-3` Vorkasse, `Type1 == 1` Ziel ab Monatsende.

## Der Kurs kommt nicht von hier

Bewusst kein `fx_rate` im Rumpf. Trader führt zwar in `curhist` eine eigene
Tagesreihe, aber Finova bewertet den Beleg an seinem Belegtag aus der EZB-Reihe
(`fx_rates`). Zwei Kursquellen hießen, dass dieselbe Rechnung je nach Weg einen
anderen Euro-Wert bekommt.

## Was nicht mitkommt, steht im Protokoll

Drei Filter greifen: eine Rechnung außerhalb des Zeitraums, eine ungepackte
(also noch nicht fertige) und eine über **0,00**. Bei Eingangsrechnungen
zusätzlich: nicht gebucht, oder Lieferant beziehungsweise Belegnummer fehlt.

Die Filter sind richtig — eine Rechnung über 0,00 ist keine Buchung, und die
Datenbank weist sie ohnehin ab. Aber wer im Zeitraum liegt und trotzdem nicht
mitkommt, wird **benannt**, mit Belegnummer und Grund. Sonst klafft in der
Rechnungsnummernfolge eine Lücke, die sich nur durch einen Blick in Trader
erklären lässt — im ersten Automotive-Lauf waren das RE001025 und RE001031,
beide über 0,00.

„Nicht gebucht" ist dabei mehr als Buchführung über den Lauf: eine erfasste,
aber nicht gebuchte Eingangsrechnung im abzurechnenden Monat ist
liegengebliebene Arbeit.

## Der Trockenlauf fasst zusammen, bevor er auflistet

Die Vorschau zeigt höchstens 200 Zeilen. Bei Elektronik sind das 7 % von 2686
Belegen — und weil `ENGLSRE` nach Kunde sortiert gelesen wird, die Buchstaben A
bis C.

In dieser Stichprobe fehlten Fremdwährung, Reverse Charge und der Schweizer
Satz. Was daraus folgt, sagt sie nicht: Reverse Charge kam bisher nie vor, die
erste Schweizer Rechnung ist erst geplant, und Fremdwährung gibt es heute nur
bei Eingangsrechnungen — die stehen weiter hinten. Drei verschiedene Gründe, und
eine Stichprobe lässt keinen davon erkennen.

Vor der Liste steht deshalb eine Aufstellung über **alle** Belege, nach Währung,
Steuerart und Erlös- beziehungsweise Aufwandskonto. Das ist die Zahl, die sich
gegen die Umsatzsteuer-Voranmeldung halten lässt.

Summiert wird immer **je Währung**. Beträge verschiedener Währungen zu addieren
ergäbe eine Zahl, die nichts bedeutet — und der Umrechnungskurs gehört nicht
hierher, den setzt Finova am Belegtag.

## Währung

Das ISO-Kürzel kommt aus Traders Währungstabelle (`cur->Symbol`, zugleich der
Feldname in `curhist`), nicht aus einer Liste im Quelltext. Eine feste Liste
wäre genau bis zur ersten weiteren Währung richtig und danach stillschweigend
falsch: das unbekannte Kennzeichen ginge als einzelner Buchstabe hinüber, fände
keinen Kurs, und der Beleg bliebe unbewertet.

Ausgangsrechnungen in Fremdwährung gibt es heute noch nicht, Eingangsrechnungen
schon. Der Weg ist für beide derselbe — Trader liefert Betrag und Währung,
Finova bewertet am Belegtag.

## Was unkontiert ist, geht trotzdem raus

Eine Eingangsrechnung ohne `rech->Konto` wird **nicht** übergangen. Genau das tut
`LexwareSync` — und deshalb fällt eine Rechnung, die in keiner Buchhaltung
ankommt, niemandem auf. Sie geht ohne Habenkonto hinüber und steht in Finova
unter `documents_unkontiert`; der Trockenlauf zeigt sie schon vorher.

## Einstellungen

Im allgemeinen Wertespeicher:

- `FIBU_SINCE` — Belegdatum, ab dem gesammelt wird (Vorgabe: 01.01.2026)
- `LIQUIDITY_USER_ID` — Empfänger in Finova

Der API-Schlüssel steht im Keychain unter `LIQUIDITY` und geht als `$APIKEY$` in
den `x-api-key`-Kopf — derselbe Weg wie beim Liquiditätsabgleich.

## Nicht getestet

Geprüft wurde auf Linux mit `tools/hbcheck.sh` — der Harbour-Frontend-Syntaxlauf,
kein Build und keine Ausführung. Weder ein LetoDBF-Zugriff noch ein einziger
Aufruf ist gelaufen. Der erste Lauf gehört deshalb als Trockenlauf gestartet und
das Protokoll gelesen, bevor jemand `.T.` übergibt.
