# BuchhaltungsButler-Abgleich

`bbbsync.prg` gleicht die Belege aus Trader gegen BuchhaltungsButler ab und legt
dort an, was fehlt. Gegenstück zu `LexwareSync`, mit einem Unterschied, der alles
andere bestimmt: **es schreibt nichts in Trader zurück.**

Kein `re->transfer`, kein `Code`, kein `Status`, kein `Paydate`, kein `AoQty`,
nirgends ein `Rec_Lock`. Damit läuft der Abgleich neben der bestehenden
Lexware-Übertragung her, ohne sie zu stören, und ein Lauf darf beliebig oft
wiederholt werden.

## Woher kommt dann der Stand?

Von der Gegenseite. Jeder Lauf liest über `receipts/get` den Belegbestand von
BuchhaltungsButler ab dem Stichtag und baut daraus einen frischen Index über
Belegnummer und Betrag. Gesendet wird nur, was dort fehlt.

Drei Ausgänge je Beleg:

| Fall | Was passiert |
|---|---|
| Belegnummer und Betrag stimmen überein | vorhanden, nichts zu tun |
| Belegnummer unbekannt | fehlt, wird gesendet |
| Belegnummer vorhanden, Betrag weicht ab | **zur Klärung**, wird *nicht* gesendet |

Der dritte Fall trifft zwei echte Situationen: zwei Lieferanten mit derselben
Rechnungsnummer, und eine Rechnung, die sich nach der Übertragung geändert hat.
Beides darf weder ein zweiter Beleg werden noch stillschweigend als erledigt
gelten — es steht im Protokoll, damit jemand hinsieht.

## Einrichtung

**Zwei** Keychain-Einträge, weil zwei verschiedene Geheimnisse gebraucht werden —
und beide ins **Password**-Feld gehören:

| Eintrag | Password | wofür |
|---|---|---|
| `BBB` | `APICLIENT:APISECRET` | HTTP-Basic. `RestApi:Execute` reicht das Kennwortfeld bei gesetztem `cKeyName` unverändert als `CURLOPT_USERPWD` an curl weiter — genau die Form, die Basic braucht. |
| `BBBKEY` | der `api_key` des Mandanten | wählt die Firma. Über `cApiKeyName` geladen und im Rumpf als `$APIKEY$` ersetzt. |

Der `api_key` passt **nicht** ins Username-Feld von `BBB` — das ist ein kurzes
Klartextfeld. Lang genug (247 Zeichen) und verschlüsselt ist nur das
Kennwortfeld, deshalb der zweite Eintrag.

**Der Keychain ist in Trader firmenbezogen.** Beide Einträge gelten also nur für
die Firma, in der sie angelegt wurden — für eine weitere Firma müssen sie dort
erneut hinterlegt werden, mit deren eigenem `api_key`. Das ist zugleich der
Schutz davor, die Belege der einen Firma in die Buchhaltung der anderen zu
schicken: fehlt `BBBKEY` in der gerade laufenden Firma, bleibt `cApiKey` NIL,
der Platzhalter geht unersetzt raus und BuchhaltungsButler antwortet mit
Fehlercode 3. Der Lauf bricht dann schon beim ersten `receipts/get` ab — bevor
irgendetwas gesendet wird.

Den Schlüssel im Sync-Modul selbst aus dem Keychain zu lesen geht nicht:
`Keychain_GetPassword` prüft `ProcName(1)` gegen eine feste Liste und lässt nur
`RestApi:Execute` und wenige andere durch. Der Weg über `RestApi` ist also nicht
der bequemere, sondern der einzige.

> Dafür war eine Ergänzung in `lib/restapi.prg` nötig (Trader-Repo): `$APIKEY$`
> wurde bisher nur in Headern ersetzt, nicht in Rumpfwerten. Siehe dort.

So steht kein Zugangsdatum im Quelltext.

Optional im allgemeinen Wertespeicher:

- `BBB_SINCE` — Belegdatum, ab dem abgeglichen wird (Vorgabe: 01.01.2026)
- `BBB_ERRORMAIL` — Adresse für die Fehlermeldung nach einem Lauf mit Ablehnungen

## Aufruf

```harbour
RUN_SYNC_BBB()               // Trockenlauf: liest beide Seiten, zeigt und protokolliert,
                             // was zu senden wäre, sendet nichts
RUN_SYNC_BBB(.T.)            // Echtlauf: legt die fehlenden Belege an
RUN_SYNC_BBB(.F., .T.)       // zusätzlich die Summen- und Saldenliste ziehen
RUN_SYNC_BBB(.F., .F., .T.)  // zusätzlich zählen, zu wie vielen Belegen ein PDF
                             // im Archiv liegt - lädt nichts hoch
```

Der Trockenlauf ist die Voreinstellung. Ein Beleg in einer Buchhaltung lässt sich
nicht so leicht zurückholen wie eine Zeile in einer Liste.

Das Protokoll landet unter `\export\bbb_protocol_<Datum>_<Zeit>.txt` und wird am
Ende geöffnet, sofern der Lauf nicht im Batchmodus läuft.

## Kontrollwert

Jeder Lauf rechnet die **Beträge** beider Seiten gegeneinander, nicht die
Stückzahlen. Eine Stückzahl verdeckt den einen fehlenden Beleg über 40.000 Euro
zwischen dreihundert kleinen.

Aus dem ersten Trockenlauf gegen einen leeren BuchhaltungsButler-Mandanten
(Engelking Automotive, 22.09.2026):

```
KONTROLLRECHNUNG (Betraege, nicht Stueck)
                          Ausgangsbelege   Eingangsbelege
  Trader gesamt                154925.51             0.00
  BuchhaltungsButler                0.00             0.00
  Luecke                       154925.51             0.00
  davon wird gesendet          154925.51             0.00
  davon zur Klaerung                0.00             0.00
  bleibt danach offen               0.00             0.00
```

Das kostet keinen einzigen zusätzlichen API-Aufruf — beide Seiten liegen nach dem
Abgleich ohnehin im Speicher.

Bleibt nach dem Senden ein Rest, hat das genau drei mögliche Gründe, und alle
drei gehören angesehen: ein Klärungsfall, ein Beleg in BuchhaltungsButler ohne
Gegenstück in Trader (von Hand erfasst, aus anderer Quelle, doppelt), oder ein
Betrag, der auf einer Seite anders steht.

### Summen- und Saldenliste

Mit dem zweiten Parameter zieht der Lauf zusätzlich die Summen- und Saldenliste
(`reports/create/sums` → `reports/get/sums`) und hält die Salden der
Personenkonten gegen die offenen Posten aus Trader.

**Sie trägt erst, wenn drüben auch gebucht wird.** Ein Beleg ist noch keine
Buchung. Solange dieser Abgleich nur Belege liefert und in BuchhaltungsButler
niemand bucht, stehen die Personenkonten auf null und die Differenz ist so groß
wie die offenen Posten — das ist dann kein Fehler, sondern der Normalzustand. Bis
dahin ist die Kontrollrechnung über die Belegbeträge der belastbare Wert.

Deshalb nur auf ausdrückliche Anforderung, und aus zwei weiteren Gründen: der
Bericht wird asynchron erzeugt (der Lauf wartet bis zu 60 Sekunden), und ein
neuer Bericht **ersetzt** den zuletzt erzeugten — wer in BuchhaltungsButler
gerade selbst einen gezogen hat, verlöre ihn.

Die Trader-Seite: offene Posten aus Belegen **ab dem Stichtag**, Bedingung und
Betrag wie in `lexware_import.prg`, wo dieselbe Summe seit Jahren gegen den
Lexware-Debitorensaldo läuft. Eine kumulierte Summe gegen einen Teilbestand zu
halten wäre eine Differenz, die nichts bedeutet.

## Personenkonten

Ohne Personenkonto bucht BuchhaltungsButler jeden Beleg auf das Sammelkonto —
dann gibt es keine offenen Posten je Kunde oder Lieferant, und genau die sind der
Grund, warum die Belege überhaupt hinübergehen. Der Lauf legt deshalb vor dem
Senden an, was fehlt.

Die Kontonummer kommt aus Trader und wird ausdrücklich mitgegeben. Sonst
nummeriert BuchhaltungsButler selbst durch, und dieselbe Firma trüge dort eine
andere Nummer als in Lexware — beim Vergleich der beiden Systeme wäre das die
erste Fehlerquelle.

Zwei verschiedene Quellen, weil Trader es so führt:

| | Konto | woher |
|---|---|---|
| Debitor | `ku->Nummer` | am Kunden; dieselbe Nummer schreibt `LX_CreateDebtor` nach Lexware |
| Kreditor | `rech->Konto` | **an der Rechnung**, nicht am Lieferanten — ein Lieferant kann je Währung ein eigenes Konto haben (siehe `fibu` in `address_edit.prg`). `LexwareSync` bucht über dasselbe Feld. |

Eine Eingangsrechnung ohne `rech->Konto` wird übergangen und im Protokoll gezählt
— dieselbe Bedingung wie in `LexwareSync`, nur hier sichtbar gemacht.

Gesendet werden nur Name und Kontonummer. Anschrift, IBAN und
Umsatzsteuer-Identifikation lässt die API prüfen und weist den ganzen Stammsatz
mit eigenen Fehlercodes zurück, wenn ihr eine Angabe nicht gefällt. Für die
Kontierung reicht ein Konto mit Namen; die Anschrift kann nachziehen, sobald die
Felder einmal gegen die echte API getestet sind.

Fehlt ein Konto trotzdem, geht der Beleg **trotzdem raus** und landet auf dem
Sammelkonto. Nicht schön, aber sichtbar: die Buchhaltung findet ihn und kann
umkontieren. Ihn zurückzuhalten hieße, ihn verschwinden zu lassen.

Im Trockenlauf werden die fehlenden Konten aufgelistet und für die Vorschau als
vorhanden geführt — sonst zeigte die Liste lauter Belege ohne Personenkonto, die
im Echtlauf sehr wohl eines bekämen.

## Beleg-PDF: erst einmal nur gezählt

Der dritte Parameter zählt, zu wie vielen der gesammelten Belege ein PDF im
Trader-Archiv liegt. Er zählt nur — **hochgeladen wird nichts.**

So sieht der Block aus (erfundene Zahlen — der Lauf stand bei Drucklegung noch
aus):

```
BELEG-PDF IM ARCHIV (nur gezaehlt - es wird nichts hochgeladen)
                          Ausgangsbelege   Eingangsbelege
  Belege gesamt                       12                0
  davon mit PDF                       11                0
  ohne PDF im Archiv                   1                0
  Pfad da, Datei fehlt                 0                0
  kein Vorgang gefunden                0                0

  Davon fehlt in BuchhaltungsButler:
  Belege                              12                0
  davon mit PDF                       11                0
```

Die zweite Hälfte ist die, auf die es ankommt. Einem Beleg, der in
BuchhaltungsButler schon liegt, lässt sich nachträglich kein PDF mehr
anhängen: `receipts/upload` ist der einzige Endpunkt der ganzen Schnittstelle,
der eine Datei annimmt, und er legt dabei einen neuen Beleg an. Es gibt also
`receipts/addBatch` (50 Belege je Aufruf, ohne Datei) **oder**
`receipts/upload` (ein Beleg je Aufruf, mit Datei, höchstens 10 Aufrufe je
Minute) — nicht beides nacheinander.

Daran hängt die Entscheidung: eine Erstbefüllung von rund 1750
Ausgangsrechnungen dauert mit PDF gut drei Stunden statt zwei Minuten. Im
Tagesbetrieb mit zehn bis zwanzig Belegen sind es ein bis zwei Minuten — dort
kostet es praktisch nichts.

**Warum nur auf Anforderung:** jeder Archivzugriff geht über
`Hook("get_archive_files")`, und `Hook()` übersetzt die Hook-Datei bei *jedem*
Aufruf neu (`MBaseRun` → `HB_COMPILEBUF`). Ein Beleg kostet damit einen
vollständigen Harbour-Übersetzungslauf. Bei zwölf Belegen fällt das nicht auf,
bei siebzehnhundert sehr wohl, und der nächtliche Abgleich soll das nicht
jedes Mal bezahlen.

Wo das PDF liegt, ist je Richtung verschieden:

| | Archivschlüssel | woher |
|---|---|---|
| Ausgangsrechnung | `{"RE" => re->Rechnr}` | wie in `rechnung_print.prg` |
| Eingangsrechnung | `{"ER" => reb->ID}` | am **Belegerfassungssatz**, nicht an `ENGRECH`; gefunden über Adressnummer des Lieferanten + Rechnungsnummer, wie in `lexware_import.prg` |

Ein Archiveintrag, dessen Datei nicht lesbar ist, zählt als eigene Zeile und
nicht als „hat ein PDF" — für einen Upload wäre er wertlos.

## Was übertragen wird

**Ausgangsrechnungen** aus `ENGLSRE` — gepackt, Betrag ungleich null, Belegdatum
ab dem Stichtag. Anders als bei `LexwareSync` zählt `re->transfer` nicht: gesucht
ist der vollständige Belegbestand ab dem Stichtag, nicht das, was Lexware noch
nicht kennt.

**Eingangsrechnungen** aus `ENGRECH` — nur gebuchte (`Booked`). Eine nur teilweise
erfasste Rechnung hat im Kopf noch keinen belastbaren Betrag; im Liquiditätsplan
darf sie hochgerechnet werden, in der Buchhaltung nicht.

Je Beleg gehen Gegenpartei, Belegnummer, Belegdatum, Bruttobetrag, Währung,
Steuersatz und Fälligkeit. Der Steuersatz bleibt bei Import und
innergemeinschaftlichem Erwerb (`TaxCode 0`) bewusst leer — BuchhaltungsButler
lässt das ausdrücklich zu, und die Buchhaltung sieht eine Lücke, einen falschen
Satz sieht sie nicht.

## Grenzen der API (Stand 1.9.1)

- Basis `https://webapp.buchhaltungsbutler.de/api/v1`, alles `POST`, auch das Lesen
- höchstens 100 Anfragen je Mandant und Minute
- `receipts/get` liefert höchstens 500 Zeilen je Aufruf (wird geblättert)
- `receipts/addBatch` nimmt höchstens 50 Belege je Aufruf
- `receipts/upload` ist der einzige Endpunkt, der eine Datei annimmt: ein
  Beleg je Aufruf, höchstens 10 Aufrufe je Minute. Eine Datei an einen schon
  angelegten Beleg zu hängen sieht die Schnittstelle nicht vor.

## Noch nicht enthalten

- Anschrift, IBAN und USt-Id an den Personenkonten (siehe oben)
- Zahlungen und der Ausgleich offener Posten (`transactions/*`,
  `postings/add/transaction`)
- der Upload der Beleg-PDF selbst (`receipts/upload` statt `receipts/addBatch`;
  gezählt wird schon, siehe oben)

## Nicht getestet

Die Zählung der Beleg-PDF ebenfalls nicht: der Archivzugriff läuft über einen
Hook, der nur auf dem Windows-Rechner und nur gegen die echten Daten existiert.

Gebaut und geprüft wurde auf Linux mit `tools/hbcheck.sh` — das ist der
Harbour-Frontend-Syntaxlauf, kein Build und keine Ausführung. Weder der
LetoDBF-Zugriff noch ein einziger API-Aufruf ist gelaufen; beides geht nur auf
dem Windows-Rechner und mit echten Zugangsdaten. Der erste Lauf gehört deshalb
als Trockenlauf gestartet, und die Vorschauliste im Protokoll gehört gelesen,
bevor irgendjemand `.T.` übergibt.
