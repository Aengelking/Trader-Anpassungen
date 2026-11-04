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
 *   config/menu.json -> DATA\config\menu.json  (Menue und Tasten, menuconfig.prg)
 *   config/cron.json -> DATA\config\cron.json  (zeitgesteuerte Laeufe, cron.prg)
 *   config/email/<datei>, config/email/<firma>/<datei>
 *                  ->  DATA\config\email\...   (E-Mail-Vorlagen, email_templates.prg)
 *
 * Aus config/ nur die freigegebenen Dateien (SA_CONFIG) und die E-Mail-Vorlagen
 * (*.txt, *.html, hoechstens ein Unterordner fuer FIRMPATH): in DATA\config
 * liegen auch trader.ini und Schluessel, die nie aus dem Repository kommen.
 * JSON-Dateien werden vor dem Ersetzen geparst - kaputtes JSON bleibt liegen.
 * E-Mail-Vorlagen behalten ihren Zeichensatz: LoadEmailTemplate liest sie als
 * ISO-8859-1, einzelne Aufrufer als UTF-8. Kommt eine vorhandene Vorlage mit
 * anderem Zeichensatz (UTF-8 statt ISO-8859-1 oder umgekehrt), bleibt die alte
 * liegen - sonst waeren die Umlaute in den Mails kaputt.
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
 * Fehlerberichte: Vor dem Abgleich schickt der Lauf die Berichte aus DATA\fehler\
 * (abgelegt vom Fehler-Handler, tr_001.prg) an <SCHNEIDERE_URL>fehler und
 * loescht sie nach Annahme; ohne Annahme bleiben sie liegen.
 *
 * Meldungen: Antworten der Entwicklung auf 'Problem melden' kommen als
 * Chat-Nachricht zur Meldung (MELD/bericht_id) mit Benachrichtigung an den
 * Melder; was Benutzer in diesen Chats antworten, geht an die AppSchneiderei
 * zurueck. Absender im Chat: SCHNEIDERE_USER.
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
 *   SCHNEIDERE_LOGTAGE  Protokolle nach so vielen Tagen loeschen, 0 = nie
 *                     (Standard 30)
 *
 * Schluesselbund: Eintrag SCHNEIDERE (Namen haben hoechstens 10 Zeichen) mit
 * dem Abhol-Token (trd_...) aus demselben Reiter als Kennwort, eingesetzt fuer
 * $APIKEY$ im Header.
 *
 * Protokoll: Path("run\logs\")schneiderei_abholen_<Datum>.log - eine Datei je
 * Tag, an die jeder Lauf anhaengt. Geschrieben wird nur, wenn etwas passiert ist
 * (Datei ersetzt, Fehler, Warnung, Testlauf) oder der Lauf im Dialog kam; ein
 * Lauf ohne Aenderung hinterlaesst nichts. Die Rueckmeldung an die
 * AppSchneiderei geht trotzdem bei jedem Lauf raus. Protokolle der Abholung,
 * die aelter sind als SCHNEIDERE_LOGTAGE Tage (Datum im Dateinamen), loescht
 * jeder Lauf.
 */

#define SA_LOGDIR   "run\logs\"
#define SA_KEYNAME  "SCHNEIDERE"                // Schluesselbund: hoechstens 10 Zeichen
#define SA_CONFIG   {"menu.json", "cron.json"}  // erlaubte Dateien unter config/
#define SA_EMAILEXT {".txt", ".html"}           // erlaubte Vorlagen unter config/email/
#define SA_FEHLERMAX 100   // Fehlerberichte je Lauf


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
   SA_LogsAufraeumen()

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

   // 0. Fehlerberichte des Fehler-Handlers senden (nicht im Testlauf)
   IF ! lTest
      SA_FehlerSenden(cBase + "fehler", cLogFile)
   ENDIF

   // 0b. Antworten auf Meldungen zustellen, Antworten der Benutzer zurueckschicken (nicht im Testlauf)
   IF ! lTest
      SA_MeldungenAbgleichen(cBase, cLogFile)
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
      IF Lower(Right(cPfad, 5)) == ".json" .AND. ! SA_JsonOk(cInhalt)
         AAdd(aFehler, cPfad + ": kein gueltiges JSON - nicht ersetzt")
         LOOP
      ENDIF
      IF lDa .AND. SA_IstVorlage(cPfad) .AND. ! SA_GleicherZs(cAlt, cInhalt)
         AAdd(aFehler, cPfad + ": Zeichensatz geaendert (" + SA_ZsName(cAlt) + " -> " + ;
              SA_ZsName(cInhalt) + ") - nicht ersetzt")
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

   SA_Ende(cLogFile, lBatch, IF(nFehler == 0, "", LTrim(Str(nFehler)) + " Datei(en) nicht eingespielt - siehe Protokoll."), ;
           lTest .OR. nNeu > 0)
RETURN


FUNCTION Schneiderei_Abholen_Setup()
   GetValue("SCHNEIDERE_URL", "", "Adresse der Abholung (Reiter Abholung der AppSchneiderei)")
   GetValue("SCHNEIDERE_LOGTAGE", 30, "Protokolle der Abholung nach so vielen Tagen loeschen (0 = nie)")
   GetValue("SCHNEIDERE_USER", 0, "Benutzernummer, unter der Antworten der Entwicklung im Meldungs-Chat erscheinen (0 = ohne Namen)")
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
   CASE cTeil == "config"
      IF AScan(SA_CONFIG, {|c| c == Lower(cRest) }) == 0 .AND. ! SA_IstVorlage(cPfad)
         RETURN ""                               // nur freigegebene Dateien
      ENDIF
      cDir := SA_Data() + "\config\"
   OTHERWISE
      RETURN ""
   ENDCASE
RETURN cDir + hb_utf8ToStr(cRest)


// E-Mail-Vorlage: config/email/<datei> oder config/email/<firma>/<datei>,
// nur *.txt und *.html
STATIC FUNCTION SA_IstVorlage(cPfad)
   LOCAL cLow := Lower(cPfad)
   LOCAL cRest, nTiefe

   IF ! Left(cLow, 13) == "config/email/"
      RETURN .F.
   ENDIF
   cRest  := SubStr(cLow, 14)
   nTiefe := Len(cRest) - Len(StrTran(cRest, "/", ""))
   IF Empty(cRest) .OR. nTiefe > 1 .OR. Left(cRest, 1) == "/" .OR. "/." $ "/" + cRest
      RETURN .F.
   ENDIF
RETURN AScan(SA_EMAILEXT, {|c| Right(cRest, Len(c)) == c .AND. Len(cRest) > Len(c) }) > 0


// Zeichensatz einer Datei: "A" nur ASCII, "U" UTF-8, "8" anderer 8-Bit-Zeichensatz
STATIC FUNCTION SA_Zs(cText)
   LOCAL nX

   FOR nX := 1 TO Len(cText)
      IF Asc(SubStr(cText, nX, 1)) > 127
         RETURN IF(hb_StrIsUTF8(cText), "U", "8")
      ENDIF
   NEXT
RETURN "A"


STATIC FUNCTION SA_ZsName(cText)
   LOCAL cZs := SA_Zs(cText)
RETURN IF(cZs == "U", "UTF-8", IF(cZs == "8", "ISO-8859-1", "ASCII"))


// Nur ASCII passt zu allem; sonst muss der Zeichensatz gleich bleiben
STATIC FUNCTION SA_GleicherZs(cAlt, cNeu)
   LOCAL cA := SA_Zs(cAlt), cN := SA_Zs(cNeu)
RETURN cA == "A" .OR. cN == "A" .OR. cA == cN


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


// Fehlerberichte, die der Fehler-Handler von Trader (tr_001.prg, _FehlerAblegen)
// in DATA\fehler\ ablegt, an die AppSchneiderei schicken - aelteste zuerst,
// hoechstens SA_FEHLERMAX je Lauf. Geloescht wird eine Datei, wenn die
// AppSchneiderei sie angenommen (2xx) oder als unbrauchbar abgelehnt hat (400),
// ebenso kaputtes JSON. Bei jedem anderen Ergebnis (Netz weg, 401, 404 bei
// einer AppSchneiderei ohne Fehlerannahme, 5xx) bleibt sie liegen, der Lauf hoert
// mit dem Senden auf und versucht es beim naechsten Mal wieder.
// Zwischendateien (*.tmp), die aelter als ein Tag sind, werden geloescht.
STATIC FUNCTION SA_FehlerSenden(cUrl, cLogFile)
   LOCAL cDir := SA_Data() + "\fehler\"
   LOCAL aDateien, aDatei, xBericht, nStatus
   LOCAL nGesendet := 0, nVerworfen := 0

   IF ! hb_DirExists(cDir)
      RETURN NIL
   ENDIF
   FOR EACH aDatei IN Directory(cDir + "*.tmp")
      IF aDatei[3] < Date() - 1
         FErase(cDir + aDatei[1])
      ENDIF
   NEXT
   aDateien := Directory(cDir + "*.json")
   ASort(aDateien,,, {|a, b| a[1] < b[1] })
   FOR EACH aDatei IN aDateien
      IF aDatei:__enumIndex() > SA_FEHLERMAX
         EXIT
      ENDIF
      xBericht := hb_jsonDecode(hb_MemoRead(cDir + aDatei[1]))
      IF ValType(xBericht) != "H"
         SA_Log(cLogFile, "WARNING", "Fehlerbericht " + aDatei[1] + " ist kein gueltiges JSON - verworfen")
         FErase(cDir + aDatei[1])
         nVerworfen++
         LOOP
      ENDIF
      nStatus := SA_PostJson(cUrl, xBericht)
      IF (nStatus >= 200 .AND. nStatus < 300) .OR. nStatus == 400
         FErase(cDir + aDatei[1])
         IF nStatus == 400
            SA_Log(cLogFile, "WARNING", "Fehlerbericht " + aDatei[1] + " abgelehnt (unbrauchbar) - verworfen")
            nVerworfen++
         ELSE
            nGesendet++
         ENDIF
      ELSE
         SA_Log(cLogFile, "WARNING", "Fehlerberichte senden: HTTP " + LTrim(Str(nStatus)) + " - " + ;
                LTrim(Str(Len(aDateien) - nGesendet - nVerworfen)) + " bleiben liegen")
         EXIT
      ENDIF
   NEXT
   IF nGesendet > 0
      SA_Log(cLogFile, "INFO", "Fehlerberichte gesendet: " + LTrim(Str(nGesendet)))
   ENDIF
RETURN NIL


// POST eines JSON-Objekts mit dem Abhol-Token; liefert den HTTP-Status (-1: Fehler im Aufruf)
STATIC FUNCTION SA_PostJson(cUrl, hBody)
   LOCAL oRest   := RestApi():New()
   LOCAL aHeader := {"Authorization: Bearer $APIKEY$", "Content-Type: application/json"}
   LOCAL nStatus := 0

   oRest:cBaseUrl    := ""
   oRest:cApiKeyName := SA_KEYNAME
   BEGIN SEQUENCE WITH {|e| Break(e)}
      oRest:Execute(cUrl, "POST", hBody, aHeader, .T., @nStatus)
   RECOVER
      nStatus := -1
   END SEQUENCE
RETURN nStatus


// Gespraech zu den Meldungen der Benutzer ("Problem melden", problemmelden.prg im
// Kern): Antworten der Entwicklung aus der AppSchneiderei als Chat-Nachricht zur
// Meldung (REFTYPE MELD, REFKEY bericht_id) ablegen, den Melder benachrichtigen
// und die Zustellung bestaetigen. Danach alles, was Benutzer in den noch offenen
// Meldungs-Chats geschrieben haben (letzte 30 Tage), zurueckschicken - doppelte
// erkennt die AppSchneiderei an der UUID der Chat-Nachricht.
STATIC FUNCTION SA_MeldungenAbgleichen(cBase, cLogFile)
   LOCAL cFehler := ""
   LOCAL xAus, hN, hO, aIds := {}, nBot, cKey, cText, nUser, nStatus
   LOCAL oChat, oNotif, hBody, nEin := 0

   xAus := SA_Json(SA_Get(cBase + "meldungen/ausgang", @cFehler))
   IF ValType(xAus) != "H"
      IF ! "HTTP 404" $ cFehler
         SA_Log(cLogFile, "WARNING", "Meldungen: Ausgang nicht abrufbar: " + cFehler)
      ENDIF
      RETURN NIL
   ENDIF
   nBot := GetValue("SCHNEIDERE_USER", 0)
   IF ValType(nBot) != "N"
      nBot := 0
   ENDIF

   FOR EACH hN IN SA_HDef(xAus, "nachrichten", {})
      BEGIN SEQUENCE WITH {|e| Break(e)}
         cKey  := Pad(SA_Str(SA_HDef(hN, "bericht_id", "")), 36)
         cText := hb_utf8ToStr(SA_Str(SA_HDef(hN, "text", "")))
         IF ! SA_ChatDa(cKey)                    // erste Nachricht: worum es ging
            cText := "Zu Ihrer Meldung: " + Chr(34) + hb_utf8ToStr(SA_Str(SA_HDef(hN, "meldung", ""))) + Chr(34) + ;
                     Chr(13) + Chr(10) + Chr(13) + Chr(10) + cText
         ENDIF
         oChat := Chat():New(.T.)
         oChat:USER    := nBot
         oChat:REFTYPE := "MELD"
         oChat:REFKEY  := cKey
         oChat:MESSAGE := cText
         oChat:Save()
         nUser := Val(SA_Str(SA_HDef(hN, "benutzer", "")))
         IF nUser > 0
            oNotif := Notification():New(.T.)
            oNotif:USER    := nUser
            oNotif:REFTYPE := "MELD"
            oNotif:REFKEY  := cKey
            oNotif:TITLE   := "Antwort der Entwicklung zu Ihrer Meldung"
            oNotif:MESSAGE := Left(StrTran(StrTran(hb_utf8ToStr(SA_Str(SA_HDef(hN, "text", ""))), Chr(13), " "), Chr(10), " "), 200)
            oNotif:SENDER  := nBot
            oNotif:Save()
         ENDIF
         AAdd(aIds, SA_Str(SA_HDef(hN, "id", "")))
      RECOVER
         SA_Log(cLogFile, "ERROR", "Meldungen: Antwort zu " + AllTrim(SA_Str(SA_HDef(hN, "bericht_id", ""))) + " nicht zugestellt")
      END SEQUENCE
   NEXT
   IF Len(aIds) > 0
      nStatus := SA_PostJson(cBase + "meldungen/zugestellt", {"ids" => aIds})
      IF nStatus >= 200 .AND. nStatus < 300
         SA_Log(cLogFile, "INFO", "Meldungen: " + LTrim(Str(Len(aIds))) + " Antwort(en) zugestellt")
      ELSE
         SA_Log(cLogFile, "WARNING", "Meldungen: Zustellung nicht bestaetigt, HTTP " + LTrim(Str(nStatus)) + " - kommt beim naechsten Lauf doppelt")
      ENDIF
   ENDIF

   // Antworten der Benutzer
   FOR EACH hO IN SA_HDef(xAus, "offen", {})
      cKey := Pad(SA_Str(SA_HDef(hO, "bericht_id", "")), 36)
      IF ! SA_ChatDa(cKey)
         LOOP
      ENDIF
      DO WHILE ! cmsg->(EOF()) .AND. cmsg->REFTYPE == "MELD" .AND. cmsg->REFKEY == cKey
         IF cmsg->USER != nBot .AND. cmsg->DATE >= Date() - 30 .AND. ! Empty(cmsg->MESSAGE)
            hBody := {=>}
            hBody["bericht_id"] := AllTrim(cKey)
            hBody["uuid"]       := AllTrim(cmsg->UUID)
            hBody["benutzer"]   := LTrim(Str(cmsg->USER))
            hBody["text"]       := hb_strToUtf8(AllTrim(cmsg->MESSAGE))
            hBody["zeit"]       := Left(DToS(cmsg->DATE), 4) + "-" + SubStr(DToS(cmsg->DATE), 5, 2) + "-" + SubStr(DToS(cmsg->DATE), 7, 2) + "T" + Left(cmsg->TIME, 8)
            hBody["utc_offset"] := hb_UTCOffset()
            nStatus := SA_PostJson(cBase + "meldungen/eingang", hBody)
            IF nStatus >= 200 .AND. nStatus < 300
               nEin++
            ELSEIF nStatus != 404
               SA_Log(cLogFile, "WARNING", "Meldungen: Antwort aus Chat " + AllTrim(cKey) + " nicht gesendet, HTTP " + LTrim(Str(nStatus)))
            ENDIF
         ENDIF
         cmsg->(dbSkip())
      ENDDO
   NEXT
   HB_SYMBOL_UNUSED(nEin)
RETURN NIL


// Gibt es zur Meldung schon einen Chat? Steht danach auf seiner ersten Nachricht.
STATIC FUNCTION SA_ChatDa(cKey)
   NetUse("chatmsg", "cmsg")
   cmsg->(dbSetOrder(2))
RETURN cmsg->(dbSeek("MELD" + cKey))


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


// JSON ohne Fehler lesbar (sonst wuerde Trader auf die Tabelle zurueckfallen)
STATIC FUNCTION SA_JsonOk(cText)
   LOCAL xVal
   IF Left(cText, 3) == Chr(239) + Chr(187) + Chr(191)
      cText := SubStr(cText, 4)
   ENDIF
RETURN hb_jsonDecode(cText, @xVal) > 0 .AND. ValType(xVal) == "H"


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


// Abschluss: Fehler protokollieren und - im Dialog - anzeigen. Das Protokoll
// wird nur geschrieben, wenn etwas passiert ist (lWichtig, Fehler, Warnung)
// oder der Lauf im Dialog kam.
STATIC FUNCTION SA_Ende(cLogFile, lBatch, cFehler, lWichtig)
   IF ! Empty(cFehler)
      SA_Log(cLogFile, "ERROR", cFehler)
   ENDIF
   IF lWichtig == .T. .OR. SA_Puffer()["wichtig"] .OR. ! lBatch
      SA_LogSchreiben(cLogFile)
   ENDIF
   IF ! lBatch
      Tr_MsgBox(IF(Empty(cFehler), "Fertig - Protokoll: " + cLogFile, cFehler))
   ENDIF
RETURN NIL


// Protokoll des Laufs: Zeilen sammeln sich in SA_Puffer() und werden erst am
// Ende an die Tagesdatei angehaengt
STATIC FUNCTION SA_LogFile()
   LOCAL hPuffer := SA_Puffer()

   hPuffer["zeilen"]  := {}
   hPuffer["wichtig"] := .F.
   SA_Log("-", "INFO", "Lauf gestartet")
RETURN Path(SA_LOGDIR) + "schneiderei_abholen_" + DToS(Date()) + ".log"


// Alte Protokolle loeschen - das Datum steht im Dateinamen
// (schneiderei_abholen_<JJJJMMTT>[_<Zeit>].log), nicht das Dateidatum
STATIC FUNCTION SA_LogsAufraeumen()
   LOCAL nTage := GetValue("SCHNEIDERE_LOGTAGE", 30)
   LOCAL cDir  := Path(SA_LOGDIR)
   LOCAL aDatei, dDatei

   IF ValType(nTage) != "N" .OR. nTage <= 0
      RETURN NIL
   ENDIF
   FOR EACH aDatei IN Directory(cDir + "schneiderei_abholen_*.log")
      dDatei := SToD(SubStr(aDatei[1], 21, 8))
      IF ! Empty(dDatei) .AND. dDatei < Date() - nTage
         FErase(cDir + aDatei[1])
      ENDIF
   NEXT
RETURN NIL


STATIC FUNCTION SA_Puffer()
   STATIC s_hPuffer := NIL

   IF s_hPuffer == NIL
      s_hPuffer := {"zeilen" => {}, "wichtig" => .F.}
   ENDIF
RETURN s_hPuffer


STATIC FUNCTION SA_Log(cLogFile, cLevel, cMessage)
   LOCAL hPuffer := SA_Puffer()

   IF Empty(cLogFile)
      RETURN NIL
   ENDIF
   AAdd(hPuffer["zeilen"], "[" + DToC(Date()) + " " + Time() + "] [" + cLevel + "] " + cMessage)
   IF cLevel == "ERROR" .OR. cLevel == "WARNING"
      hPuffer["wichtig"] := .T.
   ENDIF
RETURN NIL


STATIC FUNCTION SA_LogSchreiben(cLogFile)
   LOCAL cDir := Left(cLogFile, RAt("\", cLogFile) - 1)
   LOCAL cText := "", cZeile, nHandle

   FOR EACH cZeile IN SA_Puffer()["zeilen"]
      cText += cZeile + Chr(13) + Chr(10)
   NEXT
   SA_Verzeichnis(cDir)
   nHandle := FOpen(cLogFile, 2)                 // FO_READWRITE
   IF nHandle == -1
      nHandle := FCreate(cLogFile)
   ENDIF
   IF nHandle != -1
      FSeek(nHandle, 0, 2)                       // FS_END
      FWrite(nHandle, cText)
      FClose(nHandle)
   ENDIF
   SA_Puffer()["zeilen"] := {}
RETURN NIL
