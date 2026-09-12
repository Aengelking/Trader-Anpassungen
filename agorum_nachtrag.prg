/*  agorum_nachtrag.prg  -  fehlende Rechnungen nach Agorum nachtragen
 *
 *  Sucht Rechnungen, die ein PDF im Dateiarchiv haben, aber keinen Satz in
 *  ac_doc, und laedt sie ueber denselben Weg nach Agorum wie der normale
 *  Druck (AgorumCustomApi:AddFile). Gegenstueck zur Auswertung in
 *  agorum_status.prg.
 *
 *  Standard ist ein PROBELAUF - es wird nur aufgelistet, was uebertragen
 *  wuerde. Der echte Upload laeuft nur, wenn die Marker-Datei
 *
 *      x:\run\agorum_nachtrag.go
 *
 *  existiert. So kann der Lauf headless gestartet werden, ohne dass ein
 *  versehentlicher Aufruf Dokumente schreibt.
 *
 *      x:\prg\trader.8.0020.exe -G -R agorum_nachtrag
 *
 *  Ausgabe auf stdout und zusaetzlich nach x:\run\agorum_nachtrag.txt.
 */
PROCEDURE RUN_AGORUM_NACHTRAG()

   #define CRLF Chr(13)+Chr(10)
   #include 'x:\hooks\archive.ch'   //hTypes: Verzeichnis je Belegart

   LOCAL lUpload  := File(Path("run\agorum_nachtrag.go"))
   LOCAL nAbJahr  := 2025     //davor ist nichts archiviert, das ist Altbestand
   LOCAL nMax     := 50       //Notbremse gegen einen Massenlauf aus Versehen
   LOCAL cReDir, cOut := "", cFile
   LOCAL aLuecke := {}, aFiles
   LOCAL nReOrd, nNo, dDat, nX
   LOCAL oAgorum, oRechnung
   LOCAL nOk := 0, nFehler := 0

   CLS
   Head("Agorum: fehlende Rechnungen nachtragen")

   cReDir := GetConfigValue("ARCHIVE_DIR") + hTypes["RE"]:Dir + "\"

   /*  ---------- 1. Luecken suchen ----------
    *  Echte Luecke = Rechnung ohne ac_doc-Satz, aber mit Datei im Archiv.
    *  Ohne Datei wurde der Beleg nie gedruckt und gehoert auch nicht hin.  */

   ? "Suche Luecken..."

   NetUse("ac_doc","acd")
   acd->(dbSetOrder(1))
   NetUse("englsre","re")
   nReOrd := re->(IndexOrd())
   re->(dbSetOrder(8))
   IF re->(IndexOrd()) != 8
      ? "Index 8 (Reposnr+Rechnr) nicht verfuegbar - Abbruch."
      re->(dbSetOrder(nReOrd))
      Inkey(5)
      RETURN
   ENDIF

   re->(dbSeek( Str(0,3) ))
   DO WHILE ! re->(Eof()) .AND. re->Reposnr == 0 .AND. Len(aLuecke) < nMax
      nNo  := re->Rechnr
      dDat := re->Rechdat
      IF nNo > 0 .AND. Year(dDat) >= nAbJahr
         IF ! acd->(dbSeek( Pad("RE",7) + Str(nNo,6) ))
            IF Len(Directory(cReDir + "RE" + StrZero(nNo,6) + "*.*")) > 0
               Aadd(aLuecke,{ nNo, dDat })
            ENDIF
         ENDIF
      ENDIF
      re->(dbSkip())
   ENDDO
   re->(dbSetOrder(nReOrd))

   /*  ---------- 2. Uebertragen ---------- */

   cOut += "AGORUM NACHTRAG  " + DToC(Date()) + " " + Time() + CRLF
   cOut += "Modus: " + IF(lUpload,"UPLOAD (Marker-Datei vorhanden)","Probelauf - es wird nichts geschrieben") + CRLF
   cOut += "Luecken ab " + LTrim(Str(nAbJahr)) + ": " + LTrim(Str(Len(aLuecke))) + CRLF
   IF Len(aLuecke) >= nMax
      cOut += "ACHTUNG: Obergrenze " + LTrim(Str(nMax)) + " erreicht, Liste ist unvollstaendig." + CRLF
   ENDIF
   cOut += Replicate("=",72) + CRLF

   IF lUpload
      oAgorum := AgorumCustomApi():New()
   ENDIF

   FOR nX := 1 TO Len(aLuecke)
      nNo := aLuecke[nX,1]

      //  Neueste Fassung nehmen - GetArchiveFiles liefert nach Datum sortiert.
      aFiles := GetArchiveFiles( {"RE"=>nNo} )
      IF Len(aFiles) == 0
         cOut += Str(nNo,6) + "  " + DToC(aLuecke[nX,2]) + "  keine Datei ueber den Hook gefunden" + CRLF
         nFehler ++
         LOOP
      ENDIF
      cFile := ATail(aFiles)[6]

      cOut += Str(nNo,6) + "  " + DToC(aLuecke[nX,2]) + "  " + cFile + CRLF
      ? Str(nNo,6) + "  " + cFile

      IF ! lUpload
         LOOP
      ENDIF

      oRechnung := Rechnung():New()
      oRechnung:Load(nNo)
      IF oRechnung:Rechnr != nNo
         cOut += "        -> FEHLER: Rechnung nicht ladbar" + CRLF
         nFehler ++
         LOOP
      ENDIF

      IF oAgorum:AddFile("RE",cFile,oRechnung)
         cOut += "        -> uebertragen" + CRLF
         nOk ++
      ELSE
         cOut += "        -> FEHLER: " + oAgorum:cErrorText + CRLF
         nFehler ++
      ENDIF
   NEXT

   cOut += Replicate("=",72) + CRLF
   IF lUpload
      cOut += "uebertragen: " + LTrim(Str(nOk)) + "   Fehler: " + LTrim(Str(nFehler)) + CRLF
   ELSE
      cOut += "Probelauf - zum Uebertragen x:\run\agorum_nachtrag.go anlegen." + CRLF
   ENDIF

   cFile := Path("run\agorum_nachtrag.txt")
   MemoWrit(cFile,cOut)

   ? ""
   FOR nX := 1 TO MlCount(cOut,200)
      ? MemoLine(cOut,200,nX)
   NEXT
   ? ""
   ? "Geschrieben nach: " + cFile

   Inkey(5)

RETURN
