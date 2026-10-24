/*
 * dump_qs.prg  -  liest das Artikelstamm-Kennzeichen "WE-QS Pruefung"
 * ------------------------------------------------------------------
 * Gegenstueck zu set_qs.prg, das dieses Kennzeichen setzt. Hier wird nur
 * gelesen, nie geschrieben.
 *
 * art->QS (artikel_edit.prg:380, PICTURE "Y") steuert seit der QM-Anbindung,
 * ob zu einer Lieferung eine Wareneingangspruefung entsteht: der Wert geht als
 * qs_required an das QM-Portal (qm_we_register.prg), und ein nicht gesetztes
 * Kennzeichen verhindert dort eine neue Pruefung.
 *
 * Aufruf
 *   RUN_DUMP_QS("KS16279;NZ/KSL/KPS/590/300/SW/EW")
 *     -> je Matchcode eine CSV-Zeile, zum Kopieren gedacht:
 *        matchcode;qs;zeichnung;zeichindex;obsolete;gefunden
 *
 *   RUN_DUMP_QS()
 *     -> Ueberblick ueber den gesamten Artikelstamm: wie viele Artikel das
 *        Kennzeichen tragen, und vor allem die beiden Abweichungen zur Regel
 *        aus set_qs.prg ("Zeichnung vorhanden => QS"). Genau die sind
 *        interessant, wenn man wissen will, ob das Kennzeichen gepflegt ist.
 *
 * Trennzeichen fuer die Liste: Semikolon, Komma oder Zeilenumbruch.
 */

#define DQ_MAXLIST 60      // so viele Abweichungen werden je Gruppe gezeigt

FUNCTION RUN_DUMP_QS(cList)
   LOCAL aMatch, nX, cMc
   LOCAL lBatch := GetConfigValue("BATCHMODE")

   NetUse("artikel", "art")

   IF ValType(cList) == "C" .AND. ! Empty(cList)
      aMatch := _DqTokens(cList)
      ? "matchcode;qs;zeichnung;zeichindex;obsolete;gefunden"
      art->(dbSetOrder(1))            // 1 = Matchcode
      FOR nX := 1 TO Len(aMatch)
         cMc := AllTrim(aMatch[nX])
         IF Empty(cMc)
            LOOP
         ENDIF
         // Der Seek ist ein Praefix-Treffer auf den gepaddeten Schluessel,
         // deshalb den Satz danach gegenpruefen.
         IF art->(dbSeek(Pad(cMc, 25))) .AND. AllTrim(art->Matchcode) == cMc
            ? cMc + ";" + _DqBool(art->QS) + ";" + AllTrim(art->Zeichnung) + ";" + ;
              AllTrim(art->ZeichIndex) + ";" + _DqBool(art->Obsolete) + ";true"
         ELSE
            ? cMc + ";;;;;false"
         ENDIF
      NEXT
   ELSE
      _DqOverview()
   ENDIF

   IF ! lBatch
      ?
      ? "Fertig - Taste druecken"
      Sinkey(0)
   ENDIF
RETURN NIL

// Ueberblick ueber den gesamten Stamm samt der beiden Abweichungen zur
// Regel aus set_qs.prg. Nur die nicht obsoleten Artikel zaehlen mit.
STATIC FUNCTION _DqOverview()
   LOCAL nAll := 0, nQs := 0, nDraw := 0
   LOCAL aDrawNoQs := {}, aQsNoDraw := {}
   LOCAL nMoreA := 0, nMoreB := 0

   art->(dbSetOrder(1))
   art->(dbGoTop())
   DO WHILE ! art->(Eof())
      IF ! art->Obsolete
         nAll++
         IF art->QS
            nQs++
         ENDIF
         IF ! Empty(art->Zeichnung)
            nDraw++
         ENDIF
         IF ! Empty(art->Zeichnung) .AND. ! art->QS
            IF Len(aDrawNoQs) < DQ_MAXLIST
               Aadd(aDrawNoQs, AllTrim(art->Matchcode))
            ELSE
               nMoreA++
            ENDIF
         ELSEIF Empty(art->Zeichnung) .AND. art->QS
            IF Len(aQsNoDraw) < DQ_MAXLIST
               Aadd(aQsNoDraw, AllTrim(art->Matchcode))
            ELSE
               nMoreB++
            ENDIF
         ENDIF
      ENDIF
      art->(dbSkip())
   ENDDO

   ? "Artikel (ohne obsolete) : " + LTrim(Str(nAll))
   ? "davon mit QS-Kennzeichen: " + LTrim(Str(nQs))
   ? "davon mit Zeichnung     : " + LTrim(Str(nDraw))
   ?
   ? "Zeichnung vorhanden, QS NICHT gesetzt (set_qs.prg wuerde sie setzen): " + ;
     LTrim(Str(Len(aDrawNoQs) + nMoreA))
   _DqList(aDrawNoQs, nMoreA)
   ?
   ? "QS gesetzt, aber KEINE Zeichnung: " + LTrim(Str(Len(aQsNoDraw) + nMoreB))
   _DqList(aQsNoDraw, nMoreB)
RETURN NIL

STATIC FUNCTION _DqList(aList, nMore)
   LOCAL nX
   FOR nX := 1 TO Len(aList)
      ? "   " + aList[nX]
   NEXT
   IF nMore > 0
      ? "   ... und " + LTrim(Str(nMore)) + " weitere"
   ENDIF
RETURN NIL

STATIC FUNCTION _DqTokens(cList)
   LOCAL c := Trim(cList)
   c := StrTran(c, Chr(13), ",")
   c := StrTran(c, Chr(10), ",")
   c := StrTran(c, ";", ",")
RETURN hb_ATokens(c, ",")

STATIC FUNCTION _DqBool(lValue)
RETURN IF(ValType(lValue) == "L" .AND. lValue, "true", "false")
