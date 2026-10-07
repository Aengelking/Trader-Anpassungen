// Konkurrenzpreise unbeaufsichtigt im Browser erfassen (geplante Aufgabe, nachts)
//
// Fuer alle Artikel der Hersteller aManu mit Lagerbestand werden nacheinander die Shops im
// Standardbrowser geoeffnet (prices\capture im Auto-Modus). Die Browser-Erweiterung
// "Engelking Konkurrenzpreise" (ab 0.5.0) speichert eindeutige Preise selbst, schliesst danach
// alle Tabs und meldet das Ergebnis je Shop an die Website; hier wird darauf gewartet und die
// Preistabelle des Artikels neu berechnet.
//
// Aufruf:
//    MBaseRun(Trim(Tr_getini(1))+"\run\prices\capture_batch")             BULGIN (1), ITW (3), max. 50
//    MBaseRun(Trim(Tr_getini(1))+"\run\prices\capture_batch",{20,{1}})    nur BULGIN, max. 20
//
// - Artikel mit einem erfassten Angebot juenger als 30 Tage werden ausgelassen, ebenso Artikel,
//   die in den letzten 30 Tagen schon erfasst wurden (auch wenn dabei kein Preis herauskam).
// - Ein Artikel nach dem anderen, danach 60 Sekunden Pause.
// - Liefern 3 Artikel hintereinander kein einziges klares Ergebnis (nur "pruefen" oder keine
//   Rueckmeldung), bricht der Lauf ab - das deutet auf eine Sperre durch die Shops hin.
//   Es wird nichts versucht, den Bot-Schutz der Shops zu umgehen.
// - Nur ein Lauf je Rechner (Sperrdatei in %TEMP%): Ein zweiter Lauf wuerde im selben Browser
//   die Auftraege des ersten abbrechen.
// - Am Ende geht eine Zusammenfassung mit den zu pruefenden Shops per Mail raus.
//
// Voraussetzung: angemeldete Windows-Sitzung, Chrome als Standardbrowser mit der Erweiterung
// und Website-Zugriff "Auf allen Websites" fuer die Shops.

#define CRLF Chr(13)+Chr(10)

#define BATCH_MAXAGE   30    //Tage: juengere Angebote oder Erfassung -> Artikel auslassen
#define BATCH_PAUSE    60    //Sekunden zwischen zwei Artikeln
#define BATCH_POLL     15    //Sekunden zwischen zwei Abfragen des Auftrags
#define BATCH_WAIT     420   //Sekunden: so lange auf die Erweiterung warten
#define BATCH_BLOCKED  3     //Artikel hintereinander ohne klares Ergebnis -> Abbruch

FUNCTION RUN_PRICES_CAPTURE_BATCH( nMax, aManu )
LOCAL aCand := {}, aCheck := {}
LOCAL nArtnr, cMpn, hResp, cJob, hJob, hRow
LOCAL nX, nY, lGood, cShops, cState
LOCAL nDone := 0, nFresh := 0, nNone := 0, nSaved := 0, nBad := 0, nNoWeb := 0
LOCAL cAbort := "", cBody, dStart, nStart
LOCAL cLock := GetEnv("TEMP")+"\ek_capture_batch.lck", nLock

Default(@nMax,50)
Default(@aManu,{1,3})   //BULGIN, ITW

Head("Konkurrenzpreise im Browser erfassen (max. "+LTrim(Str(nMax))+" Artikel)")

//Sperre: Die Datei bleibt bis zum Ende exklusiv geoeffnet (gibt Windows auch bei Absturz frei)
IF ! File(cLock)
   FClose(FCreate(cLock))
ENDIF
nLock := FOpen(cLock, 2+16)  //FO_READWRITE + FO_EXCLUSIVE
IF nLock < 0
   ? "Laeuft bereits (anderes Trader-Fenster) - abgebrochen"
   IF ! GetConfigValue("BATCHMODE")
      Inkey(5,128)
   ENDIF
   RETURN .F.
ENDIF

NetUse("artikel","art")
NetUse("ptcache","ptc")

//Erst die Kandidaten sammeln: capture/updcompet bewegen den Satzzeiger
art->(dbSetOrder( 2 ))
art->(dbGoTop())
DO WHILE ! art->(EOF())
   IF AScan(aManu, art->Manufactur) > 0 .AND. art->Bestand > 0 .AND. art->Artikelnr > 0 ;
      .AND. ! Empty(StrTran(Trim(art->Matchcode),"#MT",""))
      Aadd(aCand, art->Artikelnr)
   ENDIF
   art->(dbSkip())
ENDDO
? LTrim(Str(Len(aCand)))+" Artikel mit Bestand"

FOR nX := 1 TO Len(aCand)
   IF nDone >= nMax
      EXIT
   ENDIF
   nArtnr := aCand[nX]
   art->(dbSetOrder( 2 ))
   IF ! art->(dbSeek( Str(nArtnr,6) ))
      LOOP
   ENDIF
   cMpn := StrTran(Trim(art->Matchcode),"#MT","")

   hResp := WebCompetResponse(nArtnr, cMpn)
   IF hResp == NIL
      IF ++nNoWeb >= 3
         cAbort := "Website nicht erreichbar"
         EXIT
      ENDIF
      LOOP
   ENDIF
   nNoWeb := 0
   IF _BatchFresh(hResp, BATCH_MAXAGE)
      nFresh++
      LOOP
   ENDIF

   cJob := "B"+DtoS(Date())+"-"+LTrim(Str(nArtnr))+"-"+StrTran(Time(),":","")
   IF ! MBaseRun(Trim(Tr_getini(1))+"\run\prices\capture",{nArtnr,.T.,cJob})
      nNone++  //alle Shops ausgelassen (Suche fand nichts, 90 Tage)
      LOOP
   ENDIF
   nDone++
   ? Str(nArtnr,6), Pad(cMpn,25), ""

   //Auf die Rueckmeldung der Erweiterung warten
   dStart := Date()
   nStart := Seconds()
   hJob := {=>}
   DO WHILE hJob != NIL .AND. Len(hJob) == 0 .AND. _BatchElapsed(dStart,nStart) < BATCH_WAIT
      Inkey( BATCH_POLL, 0 )
      hJob := WebCompetJob(cJob)
   ENDDO

   IF hJob == NIL .OR. Len(hJob) == 0
      ?? "keine Rueckmeldung"
      Aadd(aCheck, Str(nArtnr,6)+" "+cMpn+": keine Rueckmeldung der Browser-Erweiterung")
      nBad++
   ELSE
      lGood := .F.
      cShops := ""
      FOR nY := 1 TO Len(hJob["results"])
         hRow := hJob["results"][nY]
         IF ValType(hRow) != "H"
            LOOP
         ENDIF
         cState := IF(ValType(hRow["state"]) == "C", hRow["state"], "")
         IF cState == "gespeichert"
            nSaved++
            lGood := .T.
         ELSEIF cState == "nicht im Sortiment"
            lGood := .T.
         ELSE  //pruefen (auch: keine Rueckmeldung der Seite) oder vom Benutzer geschlossen
            cShops += CRLF+"      "+hb_UTF8ToStr(hRow["shop"])+": "+hb_UTF8ToStr(hRow["detail"])
         ENDIF
      NEXT
      IF ! Empty(cShops)
         Aadd(aCheck, Str(nArtnr,6)+" "+cMpn+":"+cShops)
      ENDIF
      nBad := IF(lGood, 0, nBad+1)
      ?? IF(lGood, "ok", "nur pruefen")
   ENDIF

   //Preistabelle neu berechnen lassen: Cache verwerfen, Konkurrenzpreise neu zusammenstellen
   art->(dbSetOrder( 2 ))
   IF art->(dbSeek( Str(nArtnr,6) ))
      IF ptc->(dbSeek( Str(nArtnr,6) ))
         ptc->(Rec_Lock(0))
         ptc->LastDate := StoD("")
         ptc->(dbUnLock())
      ENDIF
      MBaseRun(Trim(Tr_getini(1))+"\run\prices\updcompet",{.F.,.F.})
   ENDIF

   IF nBad >= BATCH_BLOCKED
      cAbort := LTrim(Str(nBad))+" Artikel hintereinander ohne klares Ergebnis - moeglicherweise blockt ein Shop"
      EXIT
   ENDIF

   IF nDone < nMax .AND. nX < Len(aCand)
      Inkey( BATCH_PAUSE, 0 )
   ENDIF
NEXT

cBody := "Artikel mit Bestand: "+LTrim(Str(Len(aCand)))+CRLF
cBody += "Erfasst: "+LTrim(Str(nDone))+" Artikel, "+LTrim(Str(nSaved))+" Shop-Preise gespeichert"+CRLF
cBody += "Ausgelassen: "+LTrim(Str(nFresh))+" (Preise oder Erfassung juenger als "+LTrim(Str(BATCH_MAXAGE))+" Tage), "+ ;
         LTrim(Str(nNone))+" (kein Shop fuehrt den Artikel)"+CRLF
IF ! Empty(cAbort)
   cBody += CRLF+"ABGEBROCHEN: "+cAbort+CRLF
ENDIF
IF Len(aCheck) > 0
   cBody += CRLF+"Bitte pruefen (Artikelmaske -> Neu erfassen):"+CRLF
   FOR nX := 1 TO Len(aCheck)
      cBody += "  "+aCheck[nX]+CRLF
   NEXT
ENDIF
SendMail({{"amos.engelking@engelking.de","Amos"}}, ;
   "Konkurrenzpreise: "+LTrim(Str(nDone))+" Artikel erfasst"+IF(Empty(cAbort),""," - ABGEBROCHEN"), cBody)

FClose(nLock)
? "done"
IF ! GetConfigValue("BATCHMODE")
   Inkey(0,128)
ENDIF
RETURN Empty(cAbort)

// Gibt es ein erfasstes Angebot oder einen Erfassungsauftrag, der hoechstens nMaxAge Tage alt ist?
// Ohne den Auftrag kaemen Artikel, bei denen kein Shop einen Preis hat, jede Nacht wieder dran.
STATIC FUNCTION _BatchFresh(hResp, nMaxAge)
   LOCAL nX, hRow
   IF HHasKey(hResp,"last_jobs") .AND. ValType(hResp["last_jobs"]) == "A"
      FOR nX := 1 TO Len(hResp["last_jobs"])
         hRow := hResp["last_jobs"][nX]
         IF ValType(hRow) == "H" .AND. HHasKey(hRow,"finished_at") .AND. ValType(hRow["finished_at"]) == "C" ;
            .AND. StoD(StrTran(Left(hRow["finished_at"],10),"-","")) >= Date()-nMaxAge
            RETURN .T.
         ENDIF
      NEXT
   ENDIF
   FOR nX := 1 TO Len(hResp["offers"])
      IF ValType(hResp["offers"][nX]) == "H" .AND. WebCompetDate(hResp["offers"][nX]) >= Date()-nMaxAge
         RETURN .T.
      ENDIF
   NEXT
RETURN .F.

// Sekunden seit dStart/nStart, auch ueber Mitternacht
STATIC FUNCTION _BatchElapsed(dStart, nStart)
RETURN (Date()-dStart)*86400 + Seconds() - nStart

#include 'x:\run\prices\websiteoffers.prg'
