# Kontierungsstammdaten angleichen

Arbeitsliste für die `vat`-Tabelle (Maske „Editiere MWST-Sätze", `mwst_browse.prg`).
Grundlage sind die Abzüge beider Firmen vom 25.09.2026 mit `RUN_VAT_DUMP()`.

Zwei Dinge sind zu tun: **Automotive** auf denselben Stand bringen wie Elektronik,
und in **Elektronik** drei Lücken schließen, die heute schon zu einer Fehlbuchung
führen können.

> Der Schlüssel ist die **Satznummer**. `taxit()` macht ein schlichtes `GO mitax` —
> `re->TaxCode` und `rech->Steuer` sind Satznummern in dieser Tabelle. Sätze also
> nicht umsortieren und keine löschen, an denen Belege hängen.

---

## Warum `DATE` und die „alt"-Konten überhaupt gefüllt gehören

`taxit()` entscheidet über das Belegdatum:

```harbour
miwst := if(midate >= v->date, v->vat, v->vatold)
```

und `lexware.prg` wählt nach derselben Bedingung `EkNeu` oder `EkAlt`. Das Feld ist
für einen **echten Steuersatzwechsel** da — Elektronik nutzt es genau dafür: 19% ab
01.01.2021, davor 16% auf Konto 8340, das in DATEV datumsunabhängig immer 16%
rechnet.

In Automotive steht dort aber offenbar der Tag, an dem der Satz **angelegt** wurde:
`VATOLD` ist 0 und die Alt-Konten sind leer. Damit bekommt jeder Beleg vor diesem
Datum **0% und ein leeres Konto**. Bei Satz 2 wäre das alles vor dem 16.02.2026 —
eine Rechnung aus dem Januar fiele schon darunter.

Deshalb: `DATE` weit zurücksetzen, `VATOLD` gleich `VAT`, Alt-Konten gleich den
Neu-Konten. Dann greift immer der „neu"-Zweig und es gibt keine Kante. Automotive
hat nie mit 16% abgerechnet, es geht also nichts verloren.

## Warum die Skonto-Konten nicht leer bleiben dürfen

`LX_BookRestAsSkonto` (`lexware.prg:436`):

```harbour
If re->taxcode > 0
   vat->(dbGoTo(re->taxcode))
   cKonto := AllTrim(vat->SkontoNeu)      // bzw. SkontoAlt
Else
   cKonto := AllTrim(shIniData["KONTEN"]["SkontiOhneUSt"])
Endif
hData:nSoll := Val(cKonto)
```

Das Auffangkonto `SkontiOhneUSt` greift **nur bei TaxCode 0**. Ist ein Steuersatz
gesetzt und `SkontoNeu` leer, wird `Val("")` — also **Sollkonto 0**.

---

## Automotive

Ist-Stand: vier Sätze, nur die „neu"-Konten gefüllt, keine Skonto-Konten.

### Satz 1 — INLAND 19%

| Feld | ist | soll |
|---|---|---|
| `DATE` | 27.09.24 | **01.01.20** |
| `VATOLD` | 0,00 | **19,00** |
| `VERKALT` | leer | **8410** |
| `EKALT` | leer | **3400** |
| `SKONTONEU` | leer | **8736** |
| `SKONTOALT` | leer | **8736** |

### Satz 2 — 7%

| Feld | ist | soll |
|---|---|---|
| `TEXT` | reduzier | **INLAND** |
| `DATE` | 16.02.26 | **01.01.20** |
| `VATOLD` | 0,00 | **7,00** |
| `VERKALT` | leer | **08300** |
| `EKALT` | leer | **03300** |
| `SKONTONEU` | leer | **8731** |
| `SKONTOALT` | leer | **8731** |

`TEXT` ist funktional gleichgültig — `taxit()` prüft nur auf `"EG"`. Elektronik
nennt beide Inlandssätze `INLAND`; einheitlich ist leichter zu lesen.

### Satz 3 — EG

| Feld | ist | soll |
|---|---|---|
| `DATE` | 16.02.26 | **01.01.20** |
| `VERKALT` | leer | **8125** |
| `EKALT` | leer | **3425** |
| `SKONTONEU` | leer | **8730** |
| `SKONTOALT` | leer | **8730** |

`VATOLD` bleibt 0 — der Satz ist in beiden Zeiträumen 0%.

Elektronik führt hier `EKALT = 3431` statt 3425. Das ist keine Alt/Neu-Frage,
sondern ein anderer Steuersatz beim innergemeinschaftlichen Erwerb. Für Automotive
ist 3425 in beiden Feldern richtig; für Elektronik siehe die offene Frage unten.

### Satz 4 — Reverse Charge

| Feld | ist | soll |
|---|---|---|
| `DATE` | 16.02.26 | **01.01.20** |
| `VERKALT` | leer | **8337** |
| `EKALT` | leer | **3125** |
| `SKONTONEU` | leer | **8730** |
| `SKONTOALT` | leer | **8730** |

### Nicht anzulegen, solange nicht gebraucht

Elektronik hat einen fünften Satz **Schweiz, 8,10% ab 01.01.2024 auf Konto 8338**.
Das ist Schweizer Umsatzsteuer und setzt eine dortige Registrierung voraus. Für
Automotive nur anlegen, wenn dort tatsächlich in die Schweiz fakturiert wird.

Nicht zu füllen sind `KONTOVNEU`, `KONTOVALT`, `KONTOUNEU`, `KONTOUALT`,
`VATVORST`, `VATUMST` und `PORTONEU`/`PORTOALT`: `lexware.prg` liest keines davon.
Sie stehen nur noch in `obsolete/tr_078.prg` und sind in der Maske nicht ohne Grund
auskommentiert. Die Erlös- und Wareneingangskonten sind **Automatikkonten** — der
Steuersatz hängt am Konto, ein Steuerschlüssel wird dort weder gebraucht noch
angenommen.

---

## Elektronik

Nur die Skonto-Lücken. Alles andere ist in Ordnung.

| Satz | | `SKONTONEU` / `SKONTOALT` ist | soll |
|---|---|---|---|
| 2 | INLAND 7% | leer | **8731** |
| 4 | Reverse | leer | **8730** |
| 5 | Schweiz | leer | *offen, siehe unten* |

Satz 1 (8736/8735) und Satz 3 (8730) sind gefüllt.

**Satz 6 ist vollständig leer** — kein Satz, kein Datum, kein Konto. `TaxCode 6`
ergäbe 0% und Konto 0. Entweder füllen oder prüfen, ob Belege darauf verweisen,
bevor er verschwindet.

---

## Offene Fragen an die Buchhaltung

1. **Skontokonto für die Schweiz** (Elektronik Satz 5). 8338 ist das Erlöskonto für
   den Schweizer Satz; ein passendes Skontokonto dazu gibt der SKR03 nicht von
   selbst her. Das gehört einmal festgelegt, nicht geraten.

2. **`EKALT = 3431` bei Elektronik Satz 3 (EG).** 3425 ist der innergemeinschaftliche
   Erwerb zu 19%. Was 3431 abbilden soll und ob die Umschaltung am 01.01.2021 dafür
   die richtige Bedingung ist, weiß ich nicht — es sieht nach einem anderen
   Steuersatz aus, nicht nach einem Zeitraum.

3. **Satz 6 in Elektronik** — füllen oder entfernen.

---

## Danach

Ein erneuter `RUN_VAT_DUMP()` in beiden Firmen. Die beiden Abzüge sollten sich dann
nur noch in den Zeilen unterscheiden, die es wirklich gibt (Schweiz), nicht mehr in
der Vollständigkeit der Felder.
