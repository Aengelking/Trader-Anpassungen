/**
  * RUN_VAT_DUMP - Kontierungsstammdaten abziehen
  *
  * Liest und schreibt nichts. Zieht die drei Quellen ab, aus denen Trader
  * seinen Buchungssatz bildet, damit sich daraus das Kontierungsregelwerk
  * fuer Finova bauen laesst:
  *
  *   vat           Steuersaetze mit Erloes-, Wareneingangs-, Skonto- und
  *                 Steuerkonten. Der Schluessel ist die SATZNUMMER: taxit()
  *                 macht ein schlichtes "GO mitax", re->TaxCode und
  *                 rech->Steuer sind also Satznummern in dieser Tabelle.
  *                 TaxCode 0 heisst "keine Steuer".
  *
  *   lexware.ini   die Auffangkonten, wenn kein Steuersatz greift
  *                 (ErloeseOhneUSt, WareneingangOhneUSt, SkontiOhneUSt),
  *                 die EG-Steuerkonten und die Skontotoleranzen.
  *
  *   skontoa       Zahlungsbedingungen: Ziele und Skontosaetze. Die
  *                 Faelligkeit am Beleg entsteht daraus.
  *
  * ALLE FELDER, NICHT DIE BEKANNTEN
  *
  * Der Abzug laeuft ueber FCount()/FieldName(), nicht ueber eine Liste im
  * Quelltext. Zwei Gruende: die Struktur kann sich je Firma unterscheiden,
  * und genau die Felder, die hier niemand erwartet, sind die interessanten.
  * In mwst_browse.prg sind die Spalten fuer die Fibu-Steuerschluessel
  * (vatumst, vatvorst) und die Steuerkonten auskommentiert - ob sie noch
  * gepflegt sind, sieht man nur am Inhalt.
  *
  * JE FIRMA EINMAL
  *
  * vat und skontoa liegen im Datenverzeichnis der Firma, lexware.ini unter
  * FIRMPATH. Der Abzug gilt also fuer die Firma, in der er laeuft - fuer
  * Automotive und Elektronik ist er zweimal zu starten.
  *
  * AUFRUF
  *
  *   RUN_VAT_DUMP()
  *
  * Das Ergebnis landet unter \export\vat_dump_<Firma>_<Datum>_<Zeit>.txt und
  * wird am Ende geoeffnet.
  **/

//#include 'trader.ch'

#define CRLF Chr(13)+Chr(10)

STATIC snDatei := 0

FUNCTION RUN_VAT_DUMP()
   LOCAL cDatei
   LOCAL cFirma := AllTrim(GetConfigValue("FIRMPATH"))

   IF Empty(cFirma)
      cFirma := "default"
   ENDIF

   cDatei := Path("\export\vat_dump_" + cFirma + "_" + DToS(Date()) + "_" + ;
                  StrTran(Time(), ":", "-") + ".txt")
   snDatei := FCreate(cDatei)

   Head("Kontierungsstammdaten abziehen")
   _Log("Trader Kontierungsstammdaten")
   _Log("Firma: " + cFirma + "   " + DToC(Date()) + " " + Time())
   _Log("Nur gelesen - es wird nichts geaendert.")
   _Log("")

   _DumpTabelle("vat", "vat", "STEUERSAETZE (vat) - Schluessel ist die Satznummer")
   _DumpIni()
   _DumpTabelle("skontoa", "sk", "ZAHLUNGSBEDINGUNGEN (skontoa) - Schluessel ist die Satznummer minus 1")

   _Log("")
   _Log("Ende.")

   IF snDatei > 0
      FClose(snDatei)
      snDatei := 0
   ENDIF

   IF ! GetConfigValue("BATCHMODE")
      WAPI_ShellExecute(NIL, "open", cDatei, "", "")
      Sinkey(0)
   ENDIF

RETURN .T.

/**
  * Eine Tabelle vollstaendig ausgeben - erst als Feldliste, dann Satz fuer
  * Satz, und am Ende noch einmal als Semikolon-Liste zum Weiterverarbeiten.
  *
  * Leere Felder werden im Satzteil uebergangen. Bei zwanzig Feldern, von
  * denen die Haelfte nie gepflegt wurde, ist die kurze Liste die lesbare -
  * und dass ein Feld fehlt, ist selbst die Auskunft.
  **/
STATIC FUNCTION _DumpTabelle(cTabelle, cAlias, cUeberschrift)
   LOCAL nFeld, nFelder
   LOCAL cZeile, xWert, cWert
   LOCAL nSatz
   LOCAL aNamen := {}

   _Log(Replicate("=", 70))
   _Log(cUeberschrift)
   _Log(Replicate("=", 70))

   BEGIN SEQUENCE
      NetUse(cTabelle, cAlias, .F., 0)
   RECOVER
      _Log("*** Tabelle " + cTabelle + " liess sich nicht oeffnen.")
      _Log("")
      RETURN NIL
   END SEQUENCE

   nFelder := (cAlias)->(FCount())
   FOR nFeld := 1 TO nFelder
      AAdd(aNamen, (cAlias)->(FieldName(nFeld)))
   NEXT

   _Log("Felder (" + LTrim(Str(nFelder)) + "): " + _Join(aNamen, ", "))
   _Log("")

   (cAlias)->(dbGoTop())
   DO WHILE ! (cAlias)->(EOF())
      nSatz := (cAlias)->(RecNo())
      _Log("Satz " + Str(nSatz, 3) + IF((cAlias)->(Deleted()), "   [GELOESCHT]", ""))

      FOR nFeld := 1 TO nFelder
         xWert := (cAlias)->(FieldGet(nFeld))
         cWert := _Wert(xWert)
         IF ! Empty(cWert)
            _Log("   " + PadR(aNamen[nFeld], 14) + cWert)
         ENDIF
      NEXT

      (cAlias)->(dbSkip())
   ENDDO

   //Zum Weiterverarbeiten: dieselben Daten noch einmal, aber maschinenlesbar.
   _Log("")
   _Log("--- " + cTabelle + " als CSV ---")
   _Log("satz;" + _Join(aNamen, ";"))

   (cAlias)->(dbGoTop())
   DO WHILE ! (cAlias)->(EOF())
      cZeile := LTrim(Str((cAlias)->(RecNo())))
      FOR nFeld := 1 TO nFelder
         cZeile += ";" + StrTran(_Wert((cAlias)->(FieldGet(nFeld))), ";", ",")
      NEXT
      _Log(cZeile)
      (cAlias)->(dbSkip())
   ENDDO

   _Log("")

RETURN NIL

/**
  * Die Auffangkonten und Werte aus der lexware.ini.
  *
  * Der Abschnitt DATABASE bleibt draussen - dort steht die ODBC-Verbindung,
  * und die hat in einem Abzug nichts zu suchen, der per Mail weitergereicht
  * wird.
  **/
STATIC FUNCTION _DumpIni()
   LOCAL cFile := Path(AllTrim(GetConfigValue("FIRMPATH")) + "\lexware.ini")
   LOCAL hIni, hAbschnitt, xWert
   LOCAL cName

   _Log(Replicate("=", 70))
   _Log("AUFFANGKONTEN UND WERTE (lexware.ini)")
   _Log(Replicate("=", 70))
   _Log("Datei: " + cFile)

   IF ! File(cFile)
      _Log("*** nicht vorhanden")
      _Log("")
      RETURN NIL
   ENDIF

   BEGIN SEQUENCE
      hIni := HB_ReadIni(cFile)
   RECOVER
      hIni := NIL
   END SEQUENCE

   IF ValType(hIni) != "H"
      _Log("*** nicht lesbar")
      _Log("")
      RETURN NIL
   ENDIF

   FOR EACH hAbschnitt IN hIni
      cName := Upper(AllTrim(hAbschnitt:__eNumKey()))
      IF cName == "DATABASE"
         _Log("[DATABASE] - uebergangen (enthaelt die Verbindungsangaben)")
         LOOP
      ENDIF
      _Log("[" + hAbschnitt:__eNumKey() + "]")
      IF ValType(hAbschnitt) == "H"
         FOR EACH xWert IN hAbschnitt
            _Log("   " + PadR(xWert:__eNumKey(), 24) + _Wert(xWert))
         NEXT
      ENDIF
   NEXT

   _Log("")

RETURN NIL

/**
  * Feldwert als Text. Memofelder melden sich als "M", nicht als "C" - ohne
  * den Fall bliebe ein Memo hier unsichtbar.
  **/
STATIC FUNCTION _Wert(xWert)
   LOCAL cTyp := ValType(xWert)

   DO CASE
   CASE cTyp == "C" .OR. cTyp == "M"
      RETURN AllTrim(xWert)
   CASE cTyp == "N"
      RETURN AllTrim(Str(xWert, 18, 4))
   CASE cTyp == "D"
      RETURN IF(Empty(xWert), "", DToC(xWert))
   CASE cTyp == "L"
      RETURN IF(xWert, "ja", "nein")
   ENDCASE

RETURN ""

STATIC FUNCTION _Join(aTexte, cTrenner)
   LOCAL cAus := ""
   LOCAL cText

   FOR EACH cText IN aTexte
      cAus += IF(Empty(cAus), "", cTrenner) + AllTrim(cText)
   NEXT

RETURN cAus

STATIC FUNCTION _Log(cText)
   ? cText
   IF snDatei > 0
      FWrite(snDatei, cText + CRLF)
   ENDIF

RETURN NIL
