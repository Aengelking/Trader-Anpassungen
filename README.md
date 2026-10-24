# Trader-Anpassungen

Was am ERP Trader ohne Neubau des Programms angepasst wird: Harbour-Skripte und Masken, die Trader zur Laufzeit lädt. Bis Oktober 2026 lagen sie in drei Repositories; die Historie ist erhalten.

| Ordner | Was | Früher | In Trader |
|---|---|---|---|
| `hooks/` | Hooks: `<name>.prg` wird beim Ereignis `<name>` aufgerufen (`Hook()` in `hooks.prg` des Kerns). Unterordner = Firma (`FIRMPATH`), z. B. `automotive/`. | `Aengelking/Trader-Hooks` | `DATA\hooks\` |
| `run/` | Run-Skripte: per Menü, Zeitplan oder `#include` aus Hooks gestartet (`MBaseRun`). | `Aengelking/Trader-Run` | Run-Verzeichnis (`x:\run\`) |
| `mask/` | Masken (`.prg`, `.arr`, Texte je Sprache `.d`/`.e`/`.f`). | `Aengelking/trader-MASK` | Maskenverzeichnis (`Path(,"MASK")`) |

Nicht hier: der Trader-Kern (`Aengelking/Trader`, wird mit Windows gebaut), der MCP-Server (gehört zum Kern) und die Weboberfläche (`Aengelking/Trader-www`).

## Regeln

- **Kodierung CP865** für alle Quellen (`.prg`, `.ch`, `.arr`, `.d`/`.e`/`.f`). Nur diese Markdown-Dateien sind UTF-8.
- **Includes:** nur Harbour-Header und Dateien aus diesem Repository, keine Header des Trader-Kerns (`trader.ch` …). Bestehende Includes mit Windows-Pfad (`x:\run\agorum.prg`, `x:\hooks\archive.ch`) bleiben, wie sie sind – Trader findet sie auf dem Server, die Prüfung der AppSchneiderei löst sie über den Dateinamen hier im Repository auf.
- Trader kompiliert die Skripte erst beim Aufruf (`HB_COMPILEBUF`, wie `harbour -n2`): Code darf außerhalb von Funktionen stehen.

## Arbeiten mit der AppSchneiderei

Projektart „Trader-Anpassungen“: `master`/`main` ist das Produkt, `kunde/<firma>` die Version einer Firma. Änderungen per Chat, Vorschau = Prüfergebnis des Harbour-Compilers, „Freigeben“ prüft die geänderten Skripte; Trader holt den freigegebenen Stand mit seinem Token ab und spielt jeden Ordner in sein Verzeichnis (siehe Tabelle).
