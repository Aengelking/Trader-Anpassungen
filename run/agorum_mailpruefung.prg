/*  agorum_mailpruefung.prg  -  Adressen mit Nicht-ASCII in Mailadressen
 *
 *  AgorumCustomApi:SaveAddress wandelt Name und Matchcode mit hb_strtoutf8()
 *  um, die Mailadressen aber nicht (modules/agorum.prg Zeile 92 und 98).
 *  Steht in einer Mailadresse ein Umlaut, landet dessen CP865-Byte roh in der
 *  JSON-Nutzlast, der Custom-Service bekommt ungueltiges UTF-8 und antwortet
 *  mit 500. AddFile prueft den Rueckgabewert von SaveAddress nicht und laedt
 *  trotzdem hoch - Agorum lehnt dann mit
 *      400  Customer not found by match code "XYZ"
 *  ab. Alle Belege dieser Adresse bleiben unarchiviert.
 *
 *  Dieses Script zaehlt, wie viele Adressen davon betroffen sind. Rein lesend.
 *
 *      x:\prg\trader.8.0020.exe -G -R agorum_mailpruefung
 */
PROCEDURE RUN_AGORUM_MAILPRUEFUNG()

   #define CRLF Chr(13)+Chr(10)

   LOCAL cOut := "", cFile
   LOCAL hAdr := {=>}          //Adressnr => { Matchcode, Gruppe, Grund, Mailadresse }
   LOCAL nKu := 0, nCo := 0, nX
   LOCAL nNummer, cMail, xItem
   LOCAL nOhneId := 0, nMitId := 0, nGesamt := 0
   LOCAL oExtra, oAddress, aListe := {}

   CLS
   Head("Agorum: Mailadressen auf Umlaute pruefen")

   /*  ---------- 1. Adressen selbst ---------- */

   ? "Pruefe Adressen..."
   NetUse("engkund","ku")
   ku->(dbSetOrder(0))
   ku->(dbGoTop())
   DO WHILE ! ku->(Eof())
      IF ! ku->(Deleted()) .AND. ku->Group $ {"K","L"} .AND. ku->(FieldPos("EMAIL")) > 0
         nGesamt ++
         cMail := Trim(ku->Email)
         IF _HatNichtAscii(cMail)
            hAdr[ku->Nummer] := { Trim(ku->Kunde), ku->Group, "Adresse", cMail }
            nKu ++
         ENDIF
      ENDIF
      ku->(dbSkip())
   ENDDO

   /*  ---------- 2. Kontaktpersonen ---------- */

   ? "Pruefe Kontaktpersonen..."
   NetUse("contacts","conts")
   conts->(dbSetOrder(0))
   conts->(dbGoTop())
   DO WHILE ! conts->(Eof())
      IF ! conts->(Deleted()) .AND. conts->(FieldPos("EMAIL")) > 0
         cMail := Trim(conts->Email)
         IF _HatNichtAscii(cMail)
            nNummer := conts->Address
            IF ! nNummer $ hAdr
               hAdr[nNummer] := { "", "", "Kontakt", cMail }
            ENDIF
            nCo ++
         ENDIF
      ENDIF
      conts->(dbSkip())
   ENDDO

   /*  ---------- 3. Auf Gruppe und AgorumID pruefen ---------- */

   ? "Pruefe AgorumID..."
   FOR EACH xItem IN hAdr
      nNummer := xItem:__eNumKey()
      oAddress := Adresse():New()
      oAddress:Load(nNummer)
      IF oAddress:nRecno == 0 .OR. ! oAddress:Group $ {"K","L"}
         LOOP      //geloescht oder weder Kunde noch Lieferant - SaveAddress lehnt die ohnehin ab
      ENDIF
      oAddress:GotoRec()
      oExtra := ku->(ExtraData():New(nNummer))
      IF Empty(Trim(oExtra:AgorumId))
         nOhneId ++
      ELSE
         nMitId ++
      ENDIF
      Aadd(aListe,{ nNummer, Trim(oAddress:Kunde), oAddress:Group, ;
                    Empty(Trim(oExtra:AgorumId)), xItem[3], xItem[4] })
   NEXT

   ASort(aListe,,,{|x,y| x[2] < y[2] })

   /*  ---------- 4. Ausgabe ---------- */

   cOut += "MAILADRESSEN MIT NICHT-ASCII-ZEICHEN  " + DToC(Date()) + " " + Time() + CRLF
   cOut += Replicate("=",72) + CRLF + CRLF
   cOut += "Adressen der Gruppen K und L insgesamt  : " + LTrim(Str(nGesamt)) + CRLF
   cOut += "Treffer in engkund (Adress-Mailadresse) : " + LTrim(Str(nKu)) + CRLF
   cOut += "Treffer in contacts (Kontakt-Mail)      : " + LTrim(Str(nCo)) + CRLF
   cOut += "betroffene Adressen (K/L, entdoppelt)   : " + LTrim(Str(Len(aListe))) + CRLF + CRLF
   cOut += "  davon ohne AgorumID : " + LTrim(Str(nOhneId)) ;
         + "   <- Belege koennen gar nicht archiviert werden" + CRLF
   cOut += "  davon mit AgorumID  : " + LTrim(Str(nMitId)) ;
         + "   <- Ablage laeuft, aber jede Aktualisierung scheitert" + CRLF + CRLF

   cOut += PadR("Matchcode",12) + PadL("Nummer",8) + "  G  " + PadR("AgorumID",10) ;
         + PadR("Quelle",9) + "Mailadresse" + CRLF
   FOR nX := 1 TO Len(aListe)
      cOut += PadR(aListe[nX,2],12) + Str(aListe[nX,1],8) + "  " + aListe[nX,3] + "  " ;
            + PadR(IF(aListe[nX,4],"fehlt","vorhanden"),10) ;
            + PadR(aListe[nX,5],9) + aListe[nX,6] + CRLF
   NEXT

   cFile := Path("run\agorum_mailpruefung.txt")
   MemoWrit(cFile,cOut)

   ? ""
   FOR nX := 1 TO MlCount(cOut,200)
      ? MemoLine(cOut,200,nX)
   NEXT
   ? ""
   ? "Geschrieben nach: " + cFile

   Inkey(5)

RETURN

/*  Alles jenseits von ASCII laesst die JSON-Nutzlast platzen, sobald es nicht
 *  durch hb_strtoutf8() gelaufen ist.                                      */
STATIC FUNCTION _HatNichtAscii(cText)
   LOCAL nX
   FOR nX := 1 TO Len(cText)
      IF Asc(SubStr(cText,nX,1)) > 126
         RETURN .T.
      ENDIF
   NEXT
RETURN .F.
