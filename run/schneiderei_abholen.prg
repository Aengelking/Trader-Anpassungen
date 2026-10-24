/*
 * schneiderei_abholen.prg  -  freigegebene Trader-Anpassungen aus der AppSchneiderei einspielen.
 * -----------------------------------------------------------------------
 * Hooks, Run-Skripte und Masken entstehen im Repository Trader-Anpassungen
 * (hooks/, run/, mask/) und werden in der AppSchneiderei geprueft und
 * freigegeben. Dieser Lauf holt den freigegebenen Stand ab und legt jede
 * Datei dorthin, wo Trader sie sucht:
 *
 *   hooks/<pfad>   ->  DATA\hooks\<pfad>        (wie Hook() in hooks.prg)
 *   run/<pfad>     ->  Path("run\")<pfad>       (x:\run\...)
 *   mask/<pfad>    ->  Path(,"MASK")<pfad>
 *
 * Alles andere im Repository (README.md, CLAUDE.md ...) bleibt liegen.
 *
 * Abgleich ueber die Git-Blob-SHA: Die AppSchneiderei liefert zu jeder Datei
 * ihre SHA; hier wird dieselbe SHA ueber die vorhandene Datei gebildet
 * (SHA-1 von "blob <laenge>" + Chr(0) + Inhalt). Nur was sich unterscheidet,
 * wird geholt - und nach dem Holen noch einmal geprueft, bevor die alte Datei
 * ersetzt wird. Ersetzt wird ueber eine Zwischendatei (*.neu), damit nie eine
 * halbe Datei liegt.
 *
 * Zeilenenden zaehlen nicht: Im Repository stehen die meisten Dateien mit LF,
 * in Trader mit CR/LF, manche enden mit Ctrl-Z (Chr(26)). Darum wird die SHA
 * auch ueber die Datei ohne CR und ohne Ctrl-Z am Ende gebildet. Passt keine,
 * wird die Datei geholt; unterscheidet sie sich nur in den Zeilenenden, bleibt
 * die Datei in Trader unveraendert (Protokoll: "nur Zeilenenden").
 *
 * Geloescht wird nichts: Fehlt eine Datei im Repository, bleibt sie in Trader
 * liegen (in den Verzeichnissen gibt es auch Dateien, die nie im Repository
 * waren). Zum Entfernen die Datei in Trader von Hand loeschen.
 *
 * Danach meldet der Lauf der AppSchneiderei, welcher Stand eingespielt ist
 * (oder was schiefging) - das zeigt dort der Reiter "Abholung".
 *
 * Aufruf (Run-Script, z. B. alle 10 Minuten aus der Aufgabenplanung):
 *   trader:-R&schneiderei_abholen               einspielen
 *   trader:-R&schneiderei_abholen&{"J"}         Testlauf: nur protokollieren, nichts schreiben
 *
 * Config (GetValue, siehe Schneiderei_Abholen_Setup; Kategorie = Teil vor dem
 * ersten "_", hoechstens 10 Zeichen - daher SCHNEIDERE wie im Schluesselbund):
 *   SCHNEIDERE_URL    Adresse der Abholung, wie im Reiter "Abholung" der
 *                     AppSchneiderei angezeigt, z. B.
 *                     https://runner.appschneiderei.cloud/v1/trader/
 *
 * Schluesselbund: Eintrag SCHNEIDERE (Namen haben hoechstens 10 Zeichen) mit
 * dem Abhol-Token (trd_...) aus demselben Reiter als Kennwort, eingesetzt fuer
 * $APIKEY$ im Header.
 *
 * Protokoll: Path("run\logs\")schneiderei_abholen_<Datum>_<Zeit>.log
 */

#define SA_LOGDIR   "run\logs\"
#define SA_KEYNAME  "SCHNEIDERE"                // Schluesselbund: hoechstens 10 Zeichen


PROCEDURE RUN_SCHNEIDEREI_ABHOLEN(cTestlauf)
   LOCAL lTest    := SA_IsYes(cTestlauf)
   LOCAL lBatch   := GetConfigValue("BATCHMODE")
   LOCAL cLogFile := SA_LogFile()
   LOCAL cBase, xStand, hFreigabe, aDateien, hDatei
   LOCAL cCommit, cPfad, cZiel, cSha, cInhalt, cFehler
   LOCAL nGleich := 0, nNeu := 0, nFehler := 0, nZeilen := 0, nX
   LOCAL lDa, cAlt
   LOCAL aFehler := {}

   Schneiderei_Abholen_Setup()

   cBase := AllTrim(SA_Str(GetValue("SCHNEIDERE_URL")))
   IF Empty(cBase)
      SA_Ende(cLogFile, lBatch, "SCHNEIDERE_URL ist nicht gesetzt.")
      RETURN
   ENDIF
   IF Right(cBase, 1) != "/"
      cBase += "/"
   ENDIF

   IF ! lBatch
      Head("AppSchneiderei - Trader-Anpassungen einspielen")
      ? "Freigegebener Stand wird abgefragt..."
   ENDIF

   // 1. freigegebener Stand mit Dateiliste
   xStand := SA_Json(SA_Get(cBase + "stand", @cFehler))
   IF ValType(xStand) != "H"
      SA_Ende(cLogFile, lBatch, "Stand nicht abrufbar: " + cFehler)
      RETURN
   ENDIF
   hFreigabe := SA_HDef(xStand, "freigabe", NIL)
   IF ValType(hFreigabe) != "H"
      SA_Log(cLogFile, "INFO", "Noch nichts freigegeben.")
      SA_Ende(cLogFile, lBatch, "")
      RETURN
   ENDIF
   cCommit  := SA_Str(SA_HDef(hFreigabe, "commit", ""))
   aDateien := SA_HDef(xStand, "dateien", {})
   SA_Log(cLogFile, "INFO", "Freigegebener Stand " + Left(cCommit, 7) + " vom " + ;
          SA_Str(SA_HDef(hFreigabe, "freigegeben_at", "")) + ", " + ;
          LTrim(Str(Len(aDateien))) + " Dateien" + IF(lTest, " (Testlauf)", ""))

   // 2. je Datei vergleichen und, wenn noetig, holen und ersetzen
   FOR nX := 1 TO Len(aDateien)
      hDatei := aDateien[nX]
      cPfad  := SA_Str(SA_HDef(hDatei, "pfad", ""))
      cSha   := Lower(SA_Str(SA_HDef(hDatei, "sha", "")))
      cZiel  := SA_Ziel(cPfad)
      IF Empty(cZiel)
         LOOP                                    // nicht hooks/, run/, mask/
      ENDIF
      lDa  := File(cZiel)
      cAlt := IF(lDa, hb_MemoRead(cZiel), "")
      IF lDa .AND. SA_Gleich(cAlt, cSha)
         nGleich++
         LOOP
      ENDIF

      // holen (auch im Testlauf - nur so sind reine Zeilenend-Unterschiede erkennbar)
      cInhalt := SA_Get(cBase + "datei/" + cCommit + "/" + SA_UrlPfad(cPfad), @cFehler)
      IF cInhalt == NIL
         AAdd(aFehler, cPfad + ": " + cFehler)
         LOOP
      ENDIF
      IF SA_BlobSha(cInhalt) != cSha
         AAdd(aFehler, cPfad + ": Inhalt passt nicht zur SHA - nicht ersetzt")
         LOOP
      ENDIF
      IF lDa .AND. SA_Norm(cAlt) == SA_Norm(cInhalt)
         SA_Log(cLogFile, "INFO", "nur Zeilenenden: " + cPfad)
         nZeilen++
         LOOP
      ENDIF

      SA_Log(cLogFile, "INFO", IF(lDa, "geaendert: ", "neu: ") + cPfad + " -> " + cZiel)
      IF lTest
         nNeu++
      ELSEIF ! SA_Schreiben(cZiel, cInhalt, @cFehler)
         AAdd(aFehler, cPfad + ": " + cFehler)
      ELSE
         nNeu++
      ENDIF
   NEXT

   nFehler := Len(aFehler)
   FOR nX := 1 TO nFehler
      SA_Log(cLogFile, "ERROR", aFehler[nX])
   NEXT
   SA_Log(cLogFile, "INFO", "Unveraendert " + LTrim(Str(nGleich)) + ", nur Zeilenenden " + LTrim(Str(nZeilen)) + ", " + ;
          IF(lTest, "wuerde ersetzen ", "ersetzt ") + LTrim(Str(nNeu)) + ", Fehler " + LTrim(Str(nFehler)))

   // 3. Rueckmeldung an die AppSchneiderei (nicht im Testlauf)
   IF ! lTest
      SA_Melden(cBase + "abgeholt", cCommit, nFehler == 0, ;
                IF(nFehler == 0, LTrim(Str(nNeu)) + " Datei(en) ersetzt", SA_Join(aFehler)), cLogFile)
   ENDIF

   SA_Ende(cLogFile, lBatch, IF(nFehler == 0, "", LTrim(Str(nFehler)) + " Datei(en) nicht eingespielt - siehe Protokoll."))
RETURN


FUNCTION Schneiderei_Abholen_Setup()
   GetValue("SCHNEIDERE_URL", "", "Adresse der Abholung (Reiter Abholung der AppSchneiderei)")
RETURN NIL


// Repository-Pfad -> Datei in Trader. Leer: gehoert nicht zu den Anpassungen
// oder ist kein erlaubter Pfad.
STATIC FUNCTION SA_Ziel(cPfad)
   LOCAL nPos := At("/", cPfad)
   LOCAL cTeil, cRest, cDir

   IF nPos == 0 .OR. ".." $ cPfad .OR. ":" $ cPfad .OR. "\" $ cPfad
      RETURN ""
   ENDIF
   cTeil := Lower(Left(cPfad, nPos - 1))
   cRest := StrTran(SubStr(cPfad, nPos + 1), "/", "\")
   IF Empty(cRest)
      RETURN ""
   ENDIF
   DO CASE
   CASE cTeil == "hooks"
      cDir := SA_Data() + "\hooks\"
   CASE cTeil == "run"
      cDir := Path("run\")
   CASE cTeil == "mask"
      cDir := Path(, "MASK")
   OTHERWISE
      RETURN ""
   ENDCASE
RETURN cDir + hb_utf8ToStr(cRest)


// Datenverzeichnis wie DATA in trader.ch (dort sucht Hook() die Hooks)
STATIC FUNCTION SA_Data()
   LOCAL cDir := Tr_GetIni(35)
RETURN Trim(IF(Empty(cDir), Tr_GetIni(1), cDir))


// Git-Blob-SHA: SHA-1 von "blob <laenge>" + Chr(0) + Inhalt
STATIC FUNCTION SA_BlobSha(cInhalt)
RETURN Lower(hb_SHA1("blob " + LTrim(Str(Len(cInhalt))) + Chr(0) + cInhalt))


// Gleicher Inhalt wie im Repository - auch wenn die Datei in Trader andere
// Zeilenenden hat (CR/LF statt LF) oder mit Ctrl-Z endet
STATIC FUNCTION SA_Gleich(cInhalt, cSha)
   LOCAL cOhneZ

   IF SA_BlobSha(cInhalt) == cSha
      RETURN .T.
   ENDIF
   cOhneZ := SA_OhneZ(cInhalt)
RETURN SA_BlobSha(cOhneZ) == cSha .OR. SA_BlobSha(StrTran(cInhalt, Chr(13), "")) == cSha .OR. ;
       SA_BlobSha(StrTran(cOhneZ, Chr(13), "")) == cSha


// Inhalt ohne CR und ohne Ctrl-Z am Ende - zum Vergleich ohne Zeilenenden
STATIC FUNCTION SA_Norm(cInhalt)
RETURN StrTran(SA_OhneZ(cInhalt), Chr(13), "")


STATIC FUNCTION SA_OhneZ(cInhalt)
   DO WHILE Right(cInhalt, 1) == Chr(26)
      cInhalt := Left(cInhalt, Len(cInhalt) - 1)
   ENDDO
RETURN cInhalt


// Ueber Zwischendatei ersetzen, Unterverzeichnisse bei Bedarf anlegen
STATIC FUNCTION SA_Schreiben(cZiel, cInhalt, cFehler)
   LOCAL cNeu := cZiel + ".neu"

   SA_Verzeichnis(Left(cZiel, RAt("\", cZiel) - 1))
   IF ! hb_MemoWrit(cNeu, cInhalt) .OR. hb_FSize(cNeu) != Len(cInhalt)
      FErase(cNeu)
      cFehler := "Zwischendatei nicht schreibbar"
      RETURN .F.
   ENDIF
   IF File(cZiel) .AND. FErase(cZiel) != 0
      FErase(cNeu)
      cFehler := "alte Datei nicht ersetzbar (gesperrt?)"
      RETURN .F.
   ENDIF
   IF FRename(cNeu, cZiel) != 0
      cFehler := "Umbenennen fehlgeschlagen - neue Datei liegt als " + cNeu
      RETURN .F.
   ENDIF
RETURN .T.


STATIC FUNCTION SA_Verzeichnis(cDir)
   LOCAL nPos

   IF Empty(cDir) .OR. hb_DirExists(cDir)
      RETURN NIL
   ENDIF
   nPos := RAt("\", cDir)
   IF nPos > 0
      SA_Verzeichnis(Left(cDir, nPos - 1))
   ENDIF
   MakeDir(cDir)
RETURN NIL


// GET mit dem Abhol-Token; NIL bei Fehler (cFehler sagt warum)
STATIC FUNCTION SA_Get(cUrl, cFehler)
   LOCAL oRest   := RestApi():New()
   LOCAL aHeader := {"Authorization: Bearer $APIKEY$"}
   LOCAL nStatus := 0
   LOCAL cAntwort

   oRest:cBaseUrl    := ""
   oRest:cApiKeyName := SA_KEYNAME
   cFehler := ""
   BEGIN SEQUENCE WITH {|e| Break(e)}
      cAntwort := oRest:Execute(cUrl, "GET", NIL, aHeader, .F., @nStatus)
   RECOVER
      cAntwort := NIL
      nStatus  := -1
   END SEQUENCE
   IF nStatus < 200 .OR. nStatus >= 300 .OR. cAntwort == NIL
      cFehler := "HTTP " + LTrim(Str(nStatus)) + " " + Left(SA_Str(cAntwort), 300)
      RETURN NIL
   ENDIF
RETURN cAntwort


STATIC FUNCTION SA_Melden(cUrl, cCommit, lOk, cText, cLogFile)
   LOCAL oRest   := RestApi():New()
   LOCAL aHeader := {"Authorization: Bearer $APIKEY$", "Content-Type: application/json"}
   LOCAL hBody   := {=>}
   LOCAL nStatus := 0

   hBody["commit"] := cCommit
   hBody["ok"]     := lOk
   hBody["text"]   := hb_strToUtf8(Left(cText, 2000))
   oRest:cBaseUrl    := ""
   oRest:cApiKeyName := SA_KEYNAME
   BEGIN SEQUENCE WITH {|e| Break(e)}
      oRest:Execute(cUrl, "POST", hBody, aHeader, .T., @nStatus)
   RECOVER
      nStatus := -1
   END SEQUENCE
   IF nStatus < 200 .OR. nStatus >= 300
      SA_Log(cLogFile, "WARNING", "Rueckmeldung an die AppSchneiderei fehlgeschlagen, HTTP " + LTrim(Str(nStatus)))
   ENDIF
RETURN NIL


// Pfad fuer die URL: jedes Segment prozentkodiert, "/" bleibt
STATIC FUNCTION SA_UrlPfad(cPfad)
   LOCAL cOut := "", cZ, nX

   FOR nX := 1 TO Len(cPfad)
      cZ := SubStr(cPfad, nX, 1)
      IF IsAlpha(cZ) .AND. Asc(cZ) < 128 .OR. IsDigit(cZ) .OR. cZ $ "-._~/"
         cOut += cZ
      ELSE
         cOut += "%" + hb_NumToHex(Asc(cZ), 2)
      ENDIF
   NEXT
RETURN cOut


STATIC FUNCTION SA_Json(cText)
   IF cText == NIL
      RETURN NIL
   ENDIF
RETURN hb_jsonDecode(cText)


STATIC FUNCTION SA_HDef(hHash, cKey, xDef)
   IF ValType(hHash) == "H" .AND. HHasKey(hHash, cKey)
      RETURN hHash[cKey]
   ENDIF
RETURN xDef


STATIC FUNCTION SA_Str(xVal)
   DO CASE
   CASE ValType(xVal) == "C"
      RETURN xVal
   CASE ValType(xVal) == "N"
      RETURN LTrim(Str(xVal))
   CASE ValType(xVal) == "L"
      RETURN IF(xVal, ".T.", ".F.")
   ENDCASE
RETURN ""


STATIC FUNCTION SA_Join(aZeilen)
   LOCAL cOut := "", nX
   FOR nX := 1 TO Len(aZeilen)
      cOut += IF(nX > 1, Chr(10), "") + aZeilen[nX]
   NEXT
RETURN cOut


STATIC FUNCTION SA_IsYes(xVal)
RETURN ValType(xVal) == "C" .AND. Upper(Left(AllTrim(xVal), 1)) $ "JY1T"


// Abschluss: Fehler protokollieren und - im Dialog - anzeigen
STATIC FUNCTION SA_Ende(cLogFile, lBatch, cFehler)
   IF ! Empty(cFehler)
      SA_Log(cLogFile, "ERROR", cFehler)
   ENDIF
   IF ! lBatch
      Tr_MsgBox(IF(Empty(cFehler), "Fertig - Protokoll: " + cLogFile, cFehler))
   ENDIF
RETURN NIL


STATIC FUNCTION SA_LogFile()
   LOCAL cDir := Path(SA_LOGDIR)
   LOCAL cFile

   SA_Verzeichnis(Left(cDir, Len(cDir) - 1))
   cFile := cDir + "schneiderei_abholen_" + DToS(Date()) + "_" + StrTran(Time(), ":", "") + ".log"
   SA_Log(cFile, "INFO", "Protokoll gestartet: " + DToC(Date()) + " " + Time())
RETURN cFile


STATIC FUNCTION SA_Log(cLogFile, cLevel, cMessage)
   LOCAL nHandle
   LOCAL cLine := "[" + DToC(Date()) + " " + Time() + "] [" + cLevel + "] " + cMessage + Chr(13) + Chr(10)

   IF Empty(cLogFile)
      RETURN NIL
   ENDIF
   nHandle := FOpen(cLogFile, 2)                 // FO_READWRITE
   IF nHandle == -1
      nHandle := FCreate(cLogFile)
   ENDIF
   IF nHandle != -1
      FSeek(nHandle, 0, 2)                       // FS_END
      FWrite(nHandle, cLine)
      FClose(nHandle)
   ENDIF
RETURN NIL
