/*  agorum_adresse.prg  -  Adressabgleich Trader <-> Agorum pruefen
 *
 *  Der Upload eines Belegs scheitert mit
 *      400 Bad Request  Customer not found by match code "XYZ"
 *  wenn Agorum die Adresse unter diesem Matchcode nicht kennt. Dieses
 *  Script sagt, woran es liegt: ob in ExtraData eine AgorumID steht, ob die
 *  in Agorum noch aufloest, und welchen Matchcode Agorum dort fuehrt.
 *
 *  Standard ist rein lesend (nur GET). Existiert die Marker-Datei
 *
 *      x:\run\agorum_adresse.go
 *
 *  wird fuer Adressen ohne AgorumID zusaetzlich SaveAddress aufgerufen und
 *  dessen Fehler ausgegeben - denn genau dessen Rueckgabewert wirft AddFile
 *  weg, weshalb der Upload danach kommentarlos mit 400 scheitert.
 *
 *      x:\prg\trader.8.0020.exe -G -R agorum_adresse
 */
PROCEDURE RUN_AGORUM_ADRESSE()

   #define CRLF Chr(13)+Chr(10)
   #include 'x:\hooks\archive.ch'

   LOCAL lFix := File(Path("run\agorum_adresse.go"))
   LOCAL nAbJahr := 2025
   LOCAL nMax    := 50
   LOCAL cReDir, cOut := "", cFile
   LOCAL aLuecke := {}, aMatch := {}
   LOCAL nReOrd, nNo, dDat, nX
   LOCAL oAgorum, oRechnung, oAddress, oExtra
   LOCAL cMatch, nNummer, cUUID
   LOCAL hRet, nResponse := 0, cResponse := "", cData := ""

   CLS
   Head("Agorum: Adressabgleich pruefen")

   cReDir := GetConfigValue("ARCHIVE_DIR") + hTypes["RE"]:Dir + "\"

   NetUse("engkund","ku")
   NetUse("ac_doc","acd")
   acd->(dbSetOrder(1))
   NetUse("englsre","re")
   nReOrd := re->(IndexOrd())
   re->(dbSetOrder(8))
   IF re->(IndexOrd()) != 8
      ? "Index 8 nicht verfuegbar - Abbruch."
      re->(dbSetOrder(nReOrd))
      Inkey(5)
      RETURN
   ENDIF

   //  dieselben Luecken wie in agorum_nachtrag
   ? "Suche Luecken..."
   re->(dbSeek( Str(0,3) ))
   DO WHILE ! re->(Eof()) .AND. re->Reposnr == 0 .AND. Len(aLuecke) < nMax
      nNo  := re->Rechnr
      dDat := re->Rechdat
      IF nNo > 0 .AND. Year(dDat) >= nAbJahr
         IF ! acd->(dbSeek( Pad("RE",7) + Str(nNo,6) ))
            IF Len(Directory(cReDir + "RE" + StrZero(nNo,6) + "*.*")) > 0
               Aadd(aLuecke,nNo)
            ENDIF
         ENDIF
      ENDIF
      re->(dbSkip())
   ENDDO
   re->(dbSetOrder(nReOrd))

   cOut += "AGORUM ADRESSABGLEICH  " + DToC(Date()) + " " + Time() + CRLF
   cOut += "Betroffene Rechnungen: " + LTrim(Str(Len(aLuecke))) + CRLF
   cOut += "Modus: " + IF(lFix,"SaveAddress wird aufgerufen (Marker-Datei vorhanden)", ;
                             "nur lesen") + CRLF
   cOut += Replicate("=",72) + CRLF

   oAgorum := AgorumCustomApi():New()

   FOR nX := 1 TO Len(aLuecke)
      oRechnung := Rechnung():New()
      oRechnung:Load(aLuecke[nX])
      oAddress := oRechnung:oRechnungsAdresse
      IF oAddress == NIL
         cOut += Str(aLuecke[nX],6) + "  keine Rechnungsadresse" + CRLF
         LOOP
      ENDIF
      cMatch  := Trim(oAddress:Kunde)
      nNummer := oAddress:Nummer
      IF AScan(aMatch,{|c| c == cMatch }) != 0
         cOut += Str(aLuecke[nX],6) + "  " + cMatch + " (schon geprueft)" + CRLF
         LOOP
      ENDIF
      Aadd(aMatch,cMatch)

      oExtra := ku->(ExtraData():New(nNummer))
      cUUID  := Trim(oExtra:AgorumId)

      cOut += Str(aLuecke[nX],6) + "  Matchcode " + cMatch ;
            + "  Kundennr " + LTrim(Str(nNummer)) + CRLF
      cOut += "        Name       : " + Trim(oAddress:Name1) + CRLF
      IF Empty(cUUID)
         cOut += "        AgorumID   : LEER - die Adresse wurde nie nach Agorum" + CRLF
         cOut += "                     angelegt (oder SaveAddress ist fehlgeschlagen)" + CRLF
         IF lFix
            //  AddFile ruft SaveAddress an dieser Stelle auch auf, wertet den
            //  Rueckgabewert aber nicht aus. Hier interessiert genau der.
            IF oAgorum:SaveAddress(oAddress)
               oExtra := ku->(ExtraData():New(nNummer))
               cOut += "        SaveAddress: OK, neue AgorumID " + Trim(oExtra:AgorumId) + CRLF
            ELSE
               cOut += "        SaveAddress: FEHLER " + LTrim(Str(oAgorum:nError)) ;
                     + " - " + oAgorum:cErrorText + CRLF
            ENDIF
         ENDIF
         LOOP
      ENDIF

      cOut += "        AgorumID   : " + cUUID + CRLF
      nResponse := 0
      cResponse := ""
      cData     := ""
      hRet := oAgorum:Execute("engelking.customers.customerService.noauth/" + cUUID, ;
                              "GET",,@nResponse,@cResponse,@cData)
      cOut += "        GET uuid   : " + LTrim(Str(nResponse)) + " " + cResponse + CRLF
      IF nResponse == 404
         cOut += "                     -> in Agorum geloescht, ExtraData zeigt ins Leere" + CRLF
      ELSEIF ValType(hRet) == "H" .AND. HHasKey(hRet,"ek_matchcode")
         cOut += "        Agorum fuehrt Matchcode: " + hRet["ek_matchcode"] + CRLF
         IF hRet["ek_matchcode"] != cMatch
            cOut += "                     -> WEICHT AB von Trader (" + cMatch + ")" + CRLF
         ENDIF
      ELSE
         cOut += "                     Antwort: " + Left(cData,300) + CRLF
      ENDIF
   NEXT

   cFile := Path("run\agorum_adresse.txt")
   MemoWrit(cFile,cOut)

   ? ""
   FOR nX := 1 TO MlCount(cOut,200)
      ? MemoLine(cOut,200,nX)
   NEXT
   ? ""
   ? "Geschrieben nach: " + cFile

   Inkey(5)

RETURN
