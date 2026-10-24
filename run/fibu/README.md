# Vorbereitende Buchhaltung

Trader-Seite des Ausbaus von Finova zur vorbereitenden Buchhaltung. Ziel ist ein
DATEV-Buchungsstapel, der sich in DATEV oder Lexware einlesen lässt — und der
Fremdwährungen richtig bewertet.

**Keines dieser Programme schreibt in Trader.** Gelesen wird ausschließlich.

| | |
|---|---|
| `vat_dump.prg` | zieht die Kontierungsstammdaten ab (`vat`, `lexware.ini`, `skontoa`) |
| `kontierung_angleichen.md` | Arbeitsliste: was in beiden Firmen nachzupflegen ist |
| `belege_push.prg` | sendet die in Trader gebuchten Belege mit ihrem Buchungssatz |
| `reb_push.prg` | sendet die Belege aus dem Rechnungseingangsbuch |
| `reb_dump.prg` | Diagnose: die rohen Lexware-Buchungen zu einem reb-Beleg |
| `fibu_common.prg` | gemeinsame Helfer beider Sammler (kein Einstiegspunkt) |

## Reihenfolge

1. **`RUN_VAT_DUMP()`** in jeder Firma — zeigt, was die Kontierung hergibt.
2. **Die Arbeitsliste abarbeiten.** Solange in Automotive die Alt-Konten leer sind
   und `DATE` auf dem Anlagedatum steht, bekommt jeder ältere Beleg 0% und ein
   leeres Konto.
3. **`RUN_PUSH_BELEGE()`** als Trockenlauf. Das Protokoll listet, was noch nicht
   kontiert ist.
4. **`RUN_PUSH_BELEGE(.T.)`** erst, wenn diese Liste gelesen wurde.

## Zwei Sammler, eine Tabelle

Die Eingangsrechnungen laufen auf zwei Wegen durchs Haus, und beide enden in
`documents`:

| | Quelle | Kontierung aus |
|---|---|---|
| `belege_push.prg` | `ENGRECH` — in Trader gebucht | Traders `vat`-Tabelle |
| `reb_push.prg` | `reb` — nicht in Trader gebucht | noch niemandem |

Die Trennung ist scharf: `reb_push.prg` liest einmal alle Referenzen aus
`ENGRECH` ein und **überspringt jede reb-Zeile, die dort schon steht**. Ohne
das würde derselbe Beleg zweimal gesendet — unter derselben `erp_reference`,
also auf denselben Schlüssel, und der letzte Lauf gewänne. Traders Kontierung
ist die genauere; sie darf nicht von der aus Lexware überschrieben werden.

### reb_push liefert den Beleg, nicht die Buchung

Die erste Fassung hat versucht, die Kontierung aus dem Lexware-Journal
zurückzurechnen. Der Trockenlauf vom 26.09. und die Diagnose vom 28.09.
(`reb_dump.prg`) haben gezeigt, warum das nicht trägt: **im Journal steht
nicht die Kontierung einer Rechnung, sondern ihre Geschichte.**

Nebeneinander liegen dort Eingangsbuchung, Storno, Umbuchung, Zahlung,
Währungsdifferenz und die Auflösung eines Zwischenkontos. Conrad,
reb-ID 260000002:

```
  1121   76157 / 1200    135.05      die ZAHLUNG
 21328    4760 / 70280   113.49+USt  Rechnung, falscher Kreditor
 21345    4760 / 70280  -113.49-USt  <Storno>
 21346    4760 / 76157   113.49+USt  Rechnung, richtig
```

Die alte Fassung las die Zahlung als Gutschrift, drehte ihr Vorzeichen und kam
mit der richtigen Buchung zusammen auf genau 0,00 — der Beleg fiel als
„Betrag 0,00" heraus. Er ist echt.

Und selbst die saubere Splitbuchung führt nicht immer zum Aufwandskonto: bei
Plusnet, Moss und Telekom bucht die Eingangsbuchung gegen ein Zwischenkonto,
und der eigentliche Aufwand steht in einer zweiten Buchung, die es auflöst.

Das ließe sich regeln — über Buchungsnummern, Bankkonten, Zwischenkonten,
Stornotexte. Nur wäre das die Buchungspraxis mehrerer Jahre, nachgebaut in
einem Run-Skript, dessen erklärter Zweck eine Übergangslösung ist.

Deshalb liest `reb_push.prg` **gar nicht mehr in Lexware**. Es ist ein reiner
Trader-Leser: `reb`, `rebprot`, `engkund`, `engrech`.

### Was reb-Belegen fehlt — mit Absicht

Sachkonto, Steuersatz und Fälligkeit. Alle reb-Belege stehen deshalb in
`documents_unkontiert`. Das ist kein Mangel, sondern der Zustand: Beleg da,
Buchung folgt — aus dem Beleg selbst.

Für die Bankbuchung reicht es: um „Bank an Kreditor" zu buchen, braucht es den
Beleg, den Kreditor und den Betrag, nicht das Aufwandskonto. Das gehört zur
Rechnungsbuchung, nicht zur Zahlung.

Das **Datum** ist das Eingangsdatum aus `rebprot` (Typ `RECV`), nicht das
Rechnungsdatum — `reb` führt keines. In der Praxis liegen beide wenige Tage
auseinander; für eine Periodenabgrenzung ist das zu ungenau. Das richtige
Datum kommt mit der Kontierung aus dem Beleg.

Steht in `reb->Konto` eine `0`, kennt das Buch kein Kreditorenkonto. Es wird
dann **nicht geraten** — `rech->Konto` steht an der Rechnung, nicht am
Lieferanten, ein Lieferant kann je Währung ein eigenes haben. Der Beleg geht
ohne Personenkonto hinaus, und das Protokoll zählt diese Fälle eigens.

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

## Beide Mandanten, eine Tabelle

Finova trägt über `(user_id, source, erp_reference)` ein. Beide Firmen laufen
unter derselben `user_id`, und die Referenz einer Eingangsrechnung lautet
`ER-<Matchcode>-<Rechnungsnummer>`. `rech->Liefma` ist kein Zahlenfeld, sondern
ein sprechendes Kürzel (`WHTECH`, `UPS`, `BULGIN`) — und gerade weil es
sprechend ist, vergeben beide Firmen für denselben Lieferanten unabhängig
voneinander dasselbe. `ER-WHTECH-14602539` kann es also zweimal geben, mit
verschiedenen Beträgen.

Stünde in `source` für beide dasselbe, würde der zweite Lauf den Beleg des
ersten überschreiben — kein Fehler, keine Meldung, die Zeile ist einfach weg.
Deshalb geht die Firmennummer als `trader-<FIRMNO>` mit; sie steht damit im
Schlüssel. Ist `FIRMNO` leer, bricht der Lauf ab, statt unter einem
mehrdeutigen Schlüssel zu schreiben.

`FIRMNO` und nicht `FIRMPATH`, weil dieselbe Nummer in Finova an der Firma
steht (`companies.erp_company_id`). Beide Firmen sind dort
gepflegt: Elektronik als `1`, Automotive als `2`.

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
