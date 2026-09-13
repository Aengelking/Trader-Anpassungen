/*  agorum_status.prg  -  Bestandsaufnahme der Agorum-Archivierung
 *
 *  Liest die echte ac_doc ueber LetoDBF und stellt gegenueber, welche Belege
 *  in Agorum liegen und welche nicht. Reine Leseoperation. Das Ergebnis steht
 *  auf dem Bildschirm und zusaetzlich in x:\run\agorum_status.txt.
 *
 *  Aufruf ueber das Run-Menue.
 */
PROCEDURE RUN_AGORUM_STATUS()

   #define CRLF Chr(13)+Chr(10)
   #include 'x:\hooks\archive.ch'   //hTypes: Verzeichnis je Belegart

   LOCAL cOut := ""
   LOCAL hTyp := {=>}, aTyp, xItem, cKey
   LOCAL nTotal := 0, nNoUuid := 0, nNotUp := 0
   LOCAL cDoc, nNo, dDat
   LOCAL nReOrd, nReTot := 0, nReHit := 0, nReMin := 0, nReMax := 0
   LOCAL dReFirst := StoD(""), dReLast := StoD("")
   LOCAL nRe2 := 0, dRe2 := StoD("")
   LOCAL hJahr := {=>}, aJahr, nJ
   LOCAL nLsHit := 0, nLs2 := 0
   LOCAL aFehlt := {}, aOffen := {}
   LOCAL nAbJahr := 2025      //ab hier laeuft die Archivierung produktiv
   LOCAL nMaxList := 200      //Notbremse, falls die Luecke doch gross ist
   LOCAL cToken, cFile, nX
   LOCAL cReDir, lDatei
   LOCAL oAdrExtra, nAdrK := 0, nAdrL := 0, nAdrKId := 0, nAdrLId := 0

   CLS
   Head("Agorum: Bestandsaufnahme")

   /*  ---------- 1. ac_doc komplett auswerten ---------- */

   NetUse("ac_doc","acd")
   acd->(dbSetOrder(0))
   acd->(dbGoTop())
   ? "Lese ac_doc..."
   DO WHILE ! acd->(Eof())
      IF ! acd->(Deleted())
         cDoc := Trim(acd->DocType)
         nNo  := acd->No
         IF ! cDoc $ hTyp
            //  { Anzahl, minNo, maxNo, ohneUUID, nicht UpToDate }
            hTyp[cDoc] := { 0, nNo, nNo, 0, 0 }
         ENDIF
         aTyp := hTyp[cDoc]
         aTyp[1] ++
         aTyp[2] := Min(aTyp[2],nNo)
         aTyp[3] := Max(aTyp[3],nNo)
         IF Empty(acd->UUID)
            aTyp[4] ++
            nNoUuid ++
         ENDIF
         IF ! acd->UpToDate
            aTyp[5] ++
            nNotUp ++
            IF Len(aOffen) < nMaxList
               Aadd(aOffen,{ cDoc, nNo, acd->UUID })
            ENDIF
         ENDIF
         nTotal ++
      ENDIF
      acd->(dbSkip())
   ENDDO

   cOut += "AGORUM STATUS  " + DToC(Date()) + " " + Time() + CRLF
   cOut += "Firma: " + GetConfigValue("FIRMPATH") + "   Leto: " + GetConfigValue("LETO_SERVER") + CRLF
   cOut += Replicate("=",72) + CRLF + CRLF
   cOut += "ac_doc gesamt: " + LTrim(Str(nTotal)) + " Saetze, " ;
         + LTrim(Str(nNoUuid)) + " ohne UUID, " ;
         + LTrim(Str(nNotUp)) + " nicht UpToDate" + CRLF + CRLF
   cOut += PadR("Typ",8) + PadL("Anzahl",8) + PadL("von Nr",10) + PadL("bis Nr",10) ;
         + PadL("ohneUUID",10) + PadL("!uptodate",11) + CRLF

   FOR EACH xItem IN hTyp
      cKey := xItem:__eNumKey()
      cOut += PadR(cKey,8) + Str(xItem[1],8) + Str(xItem[2],10) + Str(xItem[3],10) ;
            + Str(xItem[4],10) + Str(xItem[5],11) + CRLF
   NEXT
   cOut += CRLF

   /*  ---------- 2. Rechnungen gegenpruefen ----------
    *  RE ist der einzige Typ, der laut Hook fuer alle Benutzer laufen soll.
    *  englsre Order 8 = Reposnr(3) + Rechnr(6); Kopfsatz ist Reposnr == 0.   */

   ? ""
   ? "Pruefe Rechnungen gegen ac_doc..."

   NetUse("englsre","re")
   nReOrd := re->(IndexOrd())
   re->(dbSetOrder(8))
   IF re->(IndexOrd()) != 8
      //  Ohne diese Ordnung stimmt der Durchlauf nicht - lieber gar keine Zahl
      //  als eine falsche.
      nReTot := -1
      re->(dbSetOrder(nReOrd))
   ELSE
      re->(dbSeek( Str(0,3) ))
   ENDIF
   acd->(dbSetOrder(1))
   DO WHILE nReTot >= 0 .AND. ! re->(Eof()) .AND. re->Reposnr == 0
      nNo  := re->Rechnr
      dDat := re->Rechdat
      IF nNo > 0
         nReTot ++
         IF nReMin == 0 .OR. nNo < nReMin
            nReMin   := nNo
            dReFirst := dDat
         ENDIF
         IF nNo > nReMax
            nReMax  := nNo
            dReLast := dDat
         ENDIF
         nJ := Year(dDat)
         IF ! nJ $ hJahr
            hJahr[nJ] := { 0, 0, 0 }      // { Rechnungen, RE in Agorum, LS in Agorum }
         ENDIF
         aJahr := hJahr[nJ]
         aJahr[1] ++
         IF acd->(dbSeek( Pad("LS",7) + Str(nNo,6) ))
            nLsHit ++
            aJahr[3] ++
            nLs2 := Max(nLs2,nNo)
         ENDIF
         IF acd->(dbSeek( Pad("RE",7) + Str(nNo,6) ))
            nReHit ++
            aJahr[2] ++
            IF nNo > nRe2                 //hoechste Rechnung, die es nach Agorum geschafft hat
               nRe2 := nNo
               dRe2 := dDat
            ENDIF
         ELSEIF nJ >= nAbJahr .AND. Len(aFehlt) < nMaxList
            Aadd(aFehlt,{ nNo, dDat })
         ENDIF
      ENDIF
      re->(dbSkip())
   ENDDO
   re->(dbSetOrder(nReOrd))

   cOut += "RECHNUNGEN" + CRLF
   IF nReTot < 0
      cOut += "  Index 8 (Reposnr+Rechnr) nicht verfuegbar - Pruefung uebersprungen." + CRLF + CRLF
   ELSE
      cOut += "  Rechnungen in englsre (Kopfsaetze) : " + LTrim(Str(nReTot)) + CRLF
      cOut += "  Nummernbereich                     : " + LTrim(Str(nReMin)) ;
            + " (" + DToC(dReFirst) + ")  bis  " + LTrim(Str(nReMax)) ;
            + " (" + DToC(dReLast) + ")" + CRLF
      cOut += "  davon in Agorum (ac_doc)           : " + LTrim(Str(nReHit))
      IF nReTot > 0
         cOut += "  = " + LTrim(Str(nReHit*100/nReTot,6,2)) + "%"
      ENDIF
      cOut += CRLF
      cOut += "  letzte archivierte Rechnung        : " + LTrim(Str(nRe2)) ;
            + " vom " + DToC(dRe2) + CRLF
      cOut += "  seither nicht archiviert           : " + LTrim(Str(nReMax-nRe2)) ;
            + " Rechnungsnummern" + CRLF + CRLF

      cOut += "  Lieferscheine in Agorum            : " + LTrim(Str(nLsHit)) ;
            + ", hoechster " + LTrim(Str(nLs2)) + CRLF + CRLF

      cOut += "  Je Jahr (Belegnummer ist fuer RE und LS dieselbe)" + CRLF
      cOut += "  " + PadR("Jahr",6) + PadL("Rechnungen",12) + PadL("RE Agorum",11) ;
            + PadL("fehlen",9) + PadL("Quote",8) + PadL("LS Agorum",11) + CRLF
      FOR nJ := 1998 TO Year(Date())
         IF nJ $ hJahr
            aJahr := hJahr[nJ]
            IF aJahr[2] > 0 .OR. nJ >= 2022
               cOut += "  " + PadR(LTrim(Str(nJ)),6) + Str(aJahr[1],12) + Str(aJahr[2],11) ;
                     + Str(aJahr[1]-aJahr[2],9) ;
                     + Str(aJahr[2]*100/aJahr[1],7,1) + "%" ;
                     + Str(aJahr[3],11) + CRLF
            ENDIF
         ENDIF
      NEXT
      cOut += CRLF
   ENDIF

   /*  ---------- 2b. Luecken benennen ---------- */

   /*  Eine fehlende Rechnung ist nur dann eine echte Luecke, wenn es im
    *  Dateiarchiv ueberhaupt ein PDF gibt. Ohne Datei wurde der Beleg nie
    *  gedruckt - dann fehlt er in Agorum voellig zu Recht.               */
   cReDir := GetConfigValue("ARCHIVE_DIR") + hTypes["RE"]:Dir + "\"

   cOut += "FEHLENDE RECHNUNGEN AB " + LTrim(Str(nAbJahr)) + CRLF
   IF Len(aFehlt) == 0
      cOut += "  keine" + CRLF
   ELSE
      cOut += "  Nr      Datum      Datei im Archiv" + CRLF
      FOR nX := 1 TO Len(aFehlt)
         lDatei := Len(Directory(cReDir + "RE" + StrZero(aFehlt[nX,1],6) + "*.*")) > 0
         cOut += "  " + Str(aFehlt[nX,1],6) + "   " + DToC(aFehlt[nX,2]) ;
               + "   " + IF(lDatei,"ja  <-- echte Luecke","nein (nie gedruckt)") + CRLF
      NEXT
      IF Len(aFehlt) >= nMaxList
         cOut += "  ... Liste bei " + LTrim(Str(nMaxList)) + " abgeschnitten" + CRLF
      ENDIF
   ENDIF
   cOut += CRLF

   cOut += "SAETZE MIT UpToDate = .F. (Update nach Agorum offen)" + CRLF
   IF Len(aOffen) == 0
      cOut += "  keine" + CRLF
   ELSE
      FOR nX := 1 TO Len(aOffen)
         cOut += "  " + PadR(aOffen[nX,1],6) + Str(aOffen[nX,2],8) ;
               + "   " + Trim(aOffen[nX,3]) + CRLF
      NEXT
   ENDIF
   cOut += CRLF

   /*  ---------- 2c. Adressbestand ----------
    *  Agorum nimmt einen Beleg nur an, wenn die Adresse dort existiert.
    *  Fuer eine Migration des Altbestands ist das die Vorbedingung.      */

   ? "Zaehle Adressen..."
   NetUse("engkund","ku")
   ku->(dbSetOrder(0))
   ku->(dbGoTop())
   DO WHILE ! ku->(Eof())
      IF ! ku->(Deleted()) .AND. ku->Group $ {"K","L"}
         oAdrExtra := ku->(ExtraData():New(ku->Nummer))
         IF ku->Group == "K"
            nAdrK ++
            IF ! Empty(Trim(oAdrExtra:AgorumId))
               nAdrKId ++
            ENDIF
         ELSE
            nAdrL ++
            IF ! Empty(Trim(oAdrExtra:AgorumId))
               nAdrLId ++
            ENDIF
         ENDIF
      ENDIF
      ku->(dbSkip())
   ENDDO

   cOut += "ADRESSBESTAND (Vorbedingung fuer jede Belegablage)" + CRLF
   cOut += "  " + PadR("Gruppe",10) + PadL("in Trader",11) + PadL("in Agorum",11) ;
         + PadL("fehlen",9) + PadL("Quote",8) + CRLF
   cOut += "  " + PadR("Kunden",10) + Str(nAdrK,11) + Str(nAdrKId,11) ;
         + Str(nAdrK-nAdrKId,9) + Str(nAdrKId*100/Max(nAdrK,1),7,1) + "%" + CRLF
   cOut += "  " + PadR("Lieferanten",10) + Str(nAdrL,11) + Str(nAdrLId,11) ;
         + Str(nAdrL-nAdrLId,9) + Str(nAdrLId*100/Max(nAdrL,1),7,1) + "%" + CRLF
   cOut += CRLF

   /*  ---------- 3. Konfiguration ---------- */

   cToken := GetValue("AGORUM_CUSTOM_TOKEN")
   cOut += "KONFIGURATION" + CRLF
   cOut += "  ARCHIVE_DIR         : " + GetConfigValue("ARCHIVE_DIR") + CRLF
   IF ValType(cToken) == "C" .AND. ! Empty(cToken)
      //  Der Token selbst wird bewusst nicht protokolliert.
      cOut += "  AGORUM_CUSTOM_TOKEN : gesetzt, Laenge " + LTrim(Str(Len(Trim(cToken)))) + CRLF
   ELSE
      cOut += "  AGORUM_CUSTOM_TOKEN : NICHT GESETZT" + CRLF
   ENDIF
   cOut += "  curl.exe vorhanden  : " + IF(File("C:\Curl\bin\curl.exe"),"ja","NEIN") + CRLF

   /*  ---------- 4. Ausgabe ---------- */

   cFile := Path("run\agorum_status.txt")
   MemoWrit(cFile,cOut)

   //  Alles auf den Bildschirm - unter "trader.exe -G -R agorum_status" ist
   //  das stdout, im Run-Menue die Anzeige.
   ? ""
   FOR nX := 1 TO MlCount(cOut,200)
      ? MemoLine(cOut,200,nX)
   NEXT
   ? ""
   ? "Geschrieben nach: " + cFile

   //  Kein Sinkey - das wuerde den CGI-Lauf blockieren.
   Inkey(5)

RETURN
