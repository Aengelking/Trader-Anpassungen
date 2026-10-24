# Befunde für `BestellungConfirm.prg` (trader-pain-points)

Zwei Fehler, die beim Bau des MCP-Servers aufgefallen sind. **Nicht von uns
gefixt** – der MCP-Code umgeht beide bewusst, die Originalmaske
`BestellungConfirm.prg` ist aber betroffen. Als Referenz für die jeweils
korrekte Vorgehensweise sind die entsprechenden Stellen aus `mcp_stdio.prg`
angegeben.

---

## 1. Duplikat-Wochen-Prüfung der Liefereinteilung sucht mit einem Schlüssel, der nicht im Index steht

**Datei:** `BestellungConfirm.prg` (Liefereinteilung / `besdel`)

**Kern:** Der `besdel`-Index (Order 1) ist `Str(Besnr,6) + Str(Posnr,3)` – die
**Woche (`Lterm`) ist nicht Teil des Index-Ausdrucks.**

Beim Prüfen, ob für eine bestimmte Woche bereits ein Liefereinteilungs-Satz
existiert, wird jedoch mit einem Schlüssel gesucht, der die Woche **enthält**
(also in etwa `Str(Besnr,6)+Str(Posnr,3)+Str(Lterm,…)`). Da der Index nur
`Besnr+Posnr` abdeckt, kann dieser längere Schlüssel nie treffen: der `DbSeek`
schlägt immer fehl.

**Folge:** Die Duplikatprüfung greift nie. Für dieselbe Woche kann ein zweiter
`besdel`-Satz angelegt werden (doppelte Liefereinteilung derselben KW).

**Korrekt (Referenz `mcp_stdio.prg`, Z. 3859–3870):** nur mit `Besnr+Posnr`
seeken, dann über die Treffer iterieren und `bdel->Lterm == nWeek` vergleichen
(RecNo des Treffers merken). Kommentar dort:

```
// The besdel index covers Besnr+Posnr only (not the week), so the entry
// for a week is located by iterating, remembering its RecNo.
bdel->(DbSetOrder(1))  // Str(Besnr,6) + Str(Posnr,3)
IF bdel->(DbSeek(Str(nPo, 6) + Str(nPos, 3)))
   DO WHILE ! bdel->(Eof()) .AND. bdel->Besnr == nPo .AND. bdel->Posnr == nPos
      ...
      IF nWeek > 0 .AND. bdel->Lterm == nWeek .AND. nWeekRec == 0
         nWeekRec := bdel->(RecNo())
      ENDIF
      bdel->(DbSkip())
   ENDDO
ENDIF
```

**Fix-Richtung:** In `BestellungConfirm.prg` die wochengenaue Suche durch dieses
Muster ersetzen (Prefix-Seek `Besnr+Posnr`, Schleife mit `Lterm`-Vergleich).
Alternativ einen Index mit `…+Str(Lterm,…)` schaffen und konsistent verwenden –
dann können aber Altdatenbestände ohne diesen Index nachziehen müssen; der
Schleifen-Ansatz ist robuster.

---

## 2. `bes->ShipTime` wird nach der Folge-Positions-Schleife vom falschen Satz gelesen

**Datei:** `BestellungConfirm.prg` (Setzen des FA-Endtermins in `werkauf`)

**Kern:** Nach der Bestätigung der Hauptposition läuft eine Schleife über die
Folgepositionen (`bes->Posnr == nPos .OR. bes->FolgeTo == nPos`, mit
`bes->(DbSkip())`). **Nach der Schleife steht `bes` auf dem ersten Satz, der
nicht mehr passt** – also einer anderen Position oder EOF.

Wird anschließend der FA-Endtermin gesetzt
(`werkauf->End = AddWeeks(bestätigte KW, bes->ShipTime)`), stammt
`bes->ShipTime` aus **diesem falschen Satz**, nicht aus der Hauptposition, zu
der die Transitzeit gehört.

**Folge:** FA-Endtermin mit falscher Transitzeit (die der Nachbarposition –
oder undefiniert bei EOF). Der Endtermin der Fertigung wird dadurch falsch
berechnet.

**Korrekt (Referenz `mcp_stdio.prg`, Z. 4038–4053):** `bes` vor dem Lesen von
`ShipTime` wieder auf die Hauptposition zurücksetzen. Kommentar dort:

```
// … Same logic as
// BestellungConfirm.prg, but with bes repositioned on the main position
// first so ShipTime is read from the correct record.
...
bes->(DbSeek(Str(nPo, 6) + Str(nPos, 3)))   // Re-read the main position
...
wer->End := IIF(Val(Right(Str(nWeek, 4), 2)) <= 52, AddWeeks(nWeek, bes->ShipTime), nWeek)
```

**Fix-Richtung:** In `BestellungConfirm.prg` vor dem `werkauf`-Update ein
`bes->(DbSeek(Str(Besnr,6)+Str(Posnr,3)))` (bzw. gemerkte RecNo der
Hauptposition wiederherstellen), damit `ShipTime` vom richtigen Satz kommt.

---

*Erstellt beim Handoff des Trader-MCP-Servers. Beide Punkte sind reine
Befunde – im trader.exe-Quellcode bewusst noch nicht geändert.*
