# CLAUDE.md

Anpassungen am ERP Trader (Harbour/xHarbour), die Trader zur Laufzeit lädt – siehe README.md für Aufbau und Zielverzeichnisse.

- `hooks/`, `run/`, `mask/`: je ein Teil von Trader; Querverweise per `#include "x:\run\…"` bzw. `"x:\hooks\…"` sind gewollt und bleiben so.
- Quellen sind **CP865** – nie als UTF-8 speichern. Umlaute nur aus CP865, kein €-Zeichen (EUR), keine typografischen Anführungszeichen.
- Keine Includes aus dem Trader-Kern (`trader.ch`, `david.ch` …); Funktionen des Kerns sind zur Laufzeit vorhanden.
- Kompiliert wird beim Aufruf wie `harbour -n2`: Code außerhalb von Funktionen ist erlaubt.
- Prüfen (Linux): `harbour <datei.prg> -s -n2 -w1 -q0 -i<repo> -i<harbour>/include`; in der AppSchneiderei: `trader-pruefen <datei.prg>`.
