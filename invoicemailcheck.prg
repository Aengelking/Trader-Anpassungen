//#include 'trader.ch'

/*
   invoicemailcheck.prg - Pruefung der Rechnungsempfaenger-Emailadresse

   Wird bei der Anlage eines Auftrags angestossen und schickt dem
   Rechnungsempfaenger des Kunden einen Link ins Kundenportal, ueber den er
   ohne Login bestaetigen kann, dass die hinterlegte Emailadresse noch stimmt.

   Betroffen sind nur Kunden, bei denen der Rechnungsempfaenger eine Person
   mit Anrede ist (conts->Anrede > 0). Allgemeine Sammeladressen ohne Anrede
   werden nicht angefragt.

   Die Datei wird NICHT mitkompiliert. Sie wird zur Laufzeit geladen:

      LoadPrg(Trim(DATA)+"\run\invoicemailcheck.prg")
      HB_ExecFromArray("InvoiceMailCheck",{oAuftrag})

   Aufrufer:
      - hooks\after_save_auftrag.prg  (Desktop-Auftragsanlage)
      - source\auftrag_web.prg        (AufApiCreate, WebView-Anlage)
      - www\api\customer.prg          (Portal, ohne Login)

   Aufgeraeumt und nachgefasst wird im Nachlauf, siehe
   InvoiceMailCheckFollowup() und run\remail_followup.prg.

   Konfiguration liegt in der Values-Tabelle, Kategorie BH:
      BH_REMAILACTIVE  L  Pruefung aktiv
      BH_REMAILMONTHS  N  Gueltigkeit einer Bestaetigung in Monaten
      BH_REMAILREMIND  N  Frist bis zur naechsten Erinnerung, in Tagen
      BH_REMAILMAXREM  N  maximale Zahl an Erinnerungen an den Kunden
      BH_REMAILMAIL    C  Empfaenger der internen Meldung ("COMMON" = Archiv)
      BH_ANREDEM/F/D/EN N Zuordnung Geschlecht -> Satz der anrede-Tabelle

   Status je Kunde in ExtraData auf "KU":
      REMAILCHK   D  bestaetigt am
      REMAILADR   C  bestaetigte Adresse
      REMAILSENT  D  Anfrage verschickt am, leer = nichts offen
      REMAILSRC   C  Quelle der letzten Bestaetigung (PORTAL / INTERN)
      REMAILCNT   N  bereits verschickte Erinnerungen
      REMAILINFO  D  intern gemeldet am
*/

//Keychain-Namen duerfen hoechstens 10 Zeichen lang sein (Pad(cName,10) beim Seek)
#define REMAIL_KEYNAME    "JWT_MAILCK"
#define REMAIL_TOKENDAYS  30
#define REMAIL_PORTALURL  "https://portal.engelking.com/mail-check?token="
#define CRLF              Chr(13)+Chr(10)
//Name, unter dem ein allgemeines Postfach (keine Person) abgelegt wird
#define REMAIL_POOLNAME   "Rechnungen"


/*
   InvoiceMailCheck(oAuftrag)

   Einstieg aus der Auftragsanlage. Prueft, ob fuer den Kunden des Auftrags
   eine Anfrage faellig ist, und verschickt sie. Fehler werden geschluckt -
   eine nicht verschickte Anfrage darf niemals das Speichern des Auftrags
   stoeren, sie wird beim naechsten Auftrag erneut versucht.

   Rueckgabe: .T. wenn eine Anfrage verschickt wurde
*/
FUNCTION InvoiceMailCheck(oAuftrag)
   LOCAL aEnv := SaveEnv()
   LOCAL lSent := .F.
   LOCAL hDue, cToken, nNummer
   LOCAL oErr

   BEGIN SEQUENCE WITH {|e| Break(e)}
      IF ValType(oAuftrag) != "O" .OR. ! GetValue("BH_REMAILACTIVE",.T.,"Rechnungsmail-Pruefung aktiv")
         BREAK
      ENDIF

      nNummer := oAuftrag:Kunde:Nummer
      hDue    := InvoiceMailCheckDue(nNummer)
      IF hDue == NIL
         BREAK
      ENDIF

      cToken := _RemailToken(nNummer,hDue["id"])
      IF Empty(cToken)
         //JWT_Encode liefert nur dann nichts, wenn der Keychain-Eintrag fehlt
         _RemailLogFile("Kein Token erzeugt - Keychain-Eintrag "+REMAIL_KEYNAME+" fehlt")
         BREAK
      ENDIF

      lSent := _RemailSend(oAuftrag,hDue,cToken)
   RECOVER USING oErr
      lSent := .F.
      IF ValType(oErr) == "O"
         _RemailLogFile("Fehler bei Kunde "+ValToPrg(nNummer)+": "+oErr:Description)
      ENDIF
   END SEQUENCE

   RestEnv(aEnv,.F.)
RETURN lSent


/*
   InvoiceMailCheckDue(nNummer)

   Prueft, ob fuer den Kunden eine Anfrage faellig ist.

   Rueckgabe: Hash {id,name,email,anrede} oder NIL wenn nichts zu tun ist
*/
FUNCTION InvoiceMailCheckDue(nNummer)
   LOCAL hC, oExtra
   LOCAL dCheck, dSent, cAddr
   LOCAL nMonths := GetValue("BH_REMAILMONTHS",12,"Rechnungsmail: Gueltigkeit in Monaten")
   LOCAL nRemind := GetValue("BH_REMAILREMIND",7,"Rechnungsmail: Wiedervorlage in Tagen")

   IF ValType(nNummer) != "N" .OR. nNummer <= 0
      RETURN NIL
   ENDIF

   NetUse("engkund","ku")
   ku->(dbSetOrder( 8 ))
   IF ! ku->(dbSeek( Str(nNummer,6) )) .OR. ku->Group != "K"
      RETURN NIL
   ENDIF

   hC := _RemailContact(nNummer)
   IF hC == NIL                     //kein Rechnungsempfaenger hinterlegt
      RETURN NIL                    //darum kuemmert sich die bestehende Pruefung im Hook
   ENDIF
   IF hC["anrede"] <= 0             //Sammeladresse ohne Anrede - keine Person, nicht anfragen
      RETURN NIL
   ENDIF
   IF Empty(hC["email"]) .OR. ! _RemailValidMail(hC["email"])
      RETURN NIL                    //ohne brauchbare Adresse laesst sich nichts verschicken
   ENDIF

   oExtra := _RemailExtra(nNummer)
   dCheck := oExtra:Get("REMAILCHK")
   dSent  := oExtra:Get("REMAILSENT")
   cAddr  := AllTrim(oExtra:Get("REMAILADR"))

   //bestaetigt, unveraendert und noch gueltig
   IF ! Empty(dCheck) .AND. Lower(cAddr) == Lower(hC["email"]) .AND. dCheck+nMonths*30 > Date()
      RETURN NIL
   ENDIF

   //es laeuft bereits eine Anfrage
   IF ! Empty(dSent) .AND. dSent+nRemind > Date()
      RETURN NIL
   ENDIF

RETURN hC


/*
   InvoiceMailCheckFollowup(bProgress)

   Nachlauf fuer alle offenen Anfragen. Ersetzt die frueher beim Versand
   erzeugte Wiedervorlage - die konnte vom Ausgang nichts wissen, weil sich
   der Bestaetigungsklick im Portal abspielt und David-COM dort fehlt.

   Je Kunde:
      - bestaetigt (oder es gibt keine Person mehr) -> Stand aufraeumen
      - noch innerhalb der Frist                    -> nichts tun
      - Frist um, weniger als BH_REMAILMAXREM
        Erinnerungen verschickt                     -> Erinnerung an denselben
                                                       Kontakt, Frist neu
      - danach                                      -> einmalig interne Meldung
                                                       an BH_REMAILMAIL

   Gefahrlos wiederholbar: jeder Schritt haelt seinen Stand in ExtraData.
   bProgress ist optional und wird mit (nX,nGesamt,nKundennr) ausgewertet.

   Rueckgabe: Hash {checked,reminded,reported,cleared}
*/
FUNCTION InvoiceMailCheckFollowup(bProgress)
   LOCAL aEnv := SaveEnv()
   LOCAL hOut := {"checked"=>0,"reminded"=>0,"reported"=>0,"cleared"=>0}
   LOCAL nRemind := GetValue("BH_REMAILREMIND",7,"Rechnungsmail: Frist in Tagen")
   LOCAL nMax    := GetValue("BH_REMAILMAXREM",2,"Rechnungsmail: maximale Zahl an Erinnerungen")
   LOCAL aIds, nX, oErr

   NetUse("engkund","ku")
   aIds := GetIdsWithExtraField("KU","REMAILSENT")

   FOR nX := 1 TO Len(aIds)
      IF ValType(bProgress) == "B"
         Eval(bProgress,nX,Len(aIds),aIds[nX])
      ENDIF
      BEGIN SEQUENCE WITH {|e| Break(e)}
         _RemailFollowOne(aIds[nX],nRemind,nMax,hOut)
      RECOVER USING oErr
         IF ValType(oErr) == "O"
            _RemailLogFile("Nachlauf, Kunde "+LTrim(Str(aIds[nX]))+": "+oErr:Description)
         ENDIF
      END SEQUENCE
   NEXT

   RestEnv(aEnv,.F.)
RETURN hOut


//Ein Kunde im Nachlauf. Eigene Funktion, damit hier mit RETURN gearbeitet
//werden kann - in einem BEGIN SEQUENCE waere das nicht erlaubt.
STATIC FUNCTION _RemailFollowOne(nNummer,nRemind,nMax,hOut)
   LOCAL hC, oExtra, cToken
   LOCAL dSent, dCheck, cAddr, nCnt

   oExtra := _RemailExtra(nNummer)
   dSent  := oExtra:Get("REMAILSENT")
   IF Empty(dSent)
      RETURN .F.
   ENDIF
   hOut["checked"]++

   hC     := _RemailContact(nNummer)
   dCheck := oExtra:Get("REMAILCHK")
   cAddr  := AllTrim(oExtra:Get("REMAILADR"))

   //erledigt: bestaetigt, oder es gibt gar keinen Personen-Empfaenger mehr
   //(etwa weil der Kunde auf ein Sammelpostfach umgestellt hat)
   IF hC == NIL .OR. hC["anrede"] <= 0 .OR. ;
      (! Empty(dCheck) .AND. Lower(cAddr) == Lower(hC["email"]))
      oExtra:Set("REMAILSENT",StoD(""))
      oExtra:Set("REMAILCNT",0)
      oExtra:Set("REMAILINFO",StoD(""))
      oExtra:Save()
      hOut["cleared"]++
      RETURN .T.
   ENDIF

   IF dSent+nRemind > Date()      //noch in der Frist
      RETURN .F.
   ENDIF

   nCnt := oExtra:Get("REMAILCNT")

   IF nCnt < nMax
      cToken := _RemailToken(nNummer,hC["id"])
      IF Empty(cToken)
         _RemailLogFile("Nachlauf: kein Token fuer Kunde "+LTrim(Str(nNummer)))
         RETURN .F.
      ENDIF
      IF ! _RemailMail(nNummer,hC,cToken,"remailrem")
         RETURN .F.
      ENDIF
      oExtra:Set("REMAILSENT",Date())
      oExtra:Set("REMAILCNT",nCnt+1)
      oExtra:Save()
      _RemailLog(nNummer,"Erinnerung zur Rechnungsemail verschickt", ;
                 "Erinnerung "+LTrim(Str(nCnt+1))+" an "+hC["name"]+ ;
                 " <"+hC["email"]+">")
      hOut["reminded"]++
      RETURN .T.
   ENDIF

   //Erinnerungen ausgeschoepft - einmalig intern melden
   IF Empty(oExtra:Get("REMAILINFO"))
      IF _RemailReport(nNummer,hC,nCnt)
         oExtra:Set("REMAILINFO",Date())
         oExtra:Save()
         hOut["reported"]++
         RETURN .T.
      ENDIF
   ENDIF

RETURN .F.


//Interne Meldung, wenn der Kunde nach allen Erinnerungen nicht geantwortet
//hat. Empfaenger steht in BH_REMAILMAIL; "COMMON" legt die Mail in das
//gemeinsame Archiv, was ohne weitere Einrichtung funktioniert.
STATIC FUNCTION _RemailReport(nNummer,hC,nCnt)
   LOCAL cTo := AllTrim(GetValue("BH_REMAILMAIL","COMMON","Rechnungsmail: interne Meldung an"))
   LOCAL cText

   IF Empty(cTo)
      RETURN .F.
   ENDIF

   NetUse("engkund","ku")
   ku->(dbSetOrder( 8 ))
   IF ! ku->(dbSeek( Str(nNummer,6) ))
      RETURN .F.
   ENDIF

   cText := "Der Rechnungsempfaenger hat seine Emailadresse trotz "+ ;
            LTrim(Str(nCnt))+" Erinnerungen nicht bestaetigt."+CRLF+CRLF+ ;
            "Kunde:   "+Trim(ku->Kunde)+"  "+Trim(ku->Name1)+CRLF+ ;
            "Kontakt: "+hC["name"]+CRLF+ ;
            "Adresse: "+hC["email"]+CRLF+CRLF+ ;
            "Moeglicherweise ist die Adresse nicht mehr erreichbar. Bitte"+CRLF+ ;
            "beim Kunden nachfassen und den Kontakt in der Adresse pflegen."

   MailConnect()
   SendMail({{cTo,cTo}},"Rechnungsemail nicht bestaetigt: "+Trim(ku->Kunde),cText)

   _RemailLog(nNummer,"Rechnungsemail nicht bestaetigt - intern gemeldet", ;
              "Nach "+LTrim(Str(nCnt))+" Erinnerungen ohne Antwort."+CRLF+ ;
              "Kontakt: "+hC["name"]+" <"+hC["email"]+">")

RETURN .T.


/*
   InvoiceMailCheckInfo(cToken)

   Liest den Stand fuer die Portalseite. Kein Login, die Berechtigung steckt
   im signierten Token.

   Rueckgabe: Hash fuer das Portal oder NIL bei ungueltigem Token
*/
FUNCTION InvoiceMailCheckInfo(cToken)
   LOCAL hT := InvoiceMailCheckVerify(cToken)
   LOCAL hC, oExtra, hOut

   IF hT == NIL
      RETURN NIL
   ENDIF

   NetUse("engkund","ku")
   ku->(dbSetOrder( 8 ))
   IF ! ku->(dbSeek( Str(hT["k"],6) ))
      RETURN NIL
   ENDIF

   hC := _RemailContact(hT["k"])
   IF hC == NIL .OR. hC["id"] != hT["c"]
      //der Rechnungsempfaenger wurde zwischenzeitlich gewechselt - der Link ist verbraucht
      RETURN { "valid" => .T., "done" => .T., "company" => Trim(ku->Name1), ;
               "salutation" => "", "name" => "", "email" => "", "salutations" => {=>} }
   ENDIF

   oExtra := _RemailExtra(hT["k"])

   hOut := {=>}
   hOut["valid"]      := .T.
   hOut["done"]       := ! Empty(oExtra:Get("REMAILCHK")) .AND. ;
                         Lower(AllTrim(oExtra:Get("REMAILADR"))) == Lower(hC["email"])
   hOut["company"]    := Trim(ku->Name1)
   hOut["salutation"] := GetContactAnrede(hC["id"],.T.)
   hOut["name"]       := hC["name"]
   hOut["email"]      := hC["email"]
   hOut["salutations"] := InvoiceMailCheckAnreden()
RETURN hOut


/*
   InvoiceMailCheckApply(cToken,hData)

   Nimmt die Antwort des Kunden entgegen.

   hData["action"]:
      "confirm"  Adresse stimmt
      "replace"  andere Kontaktdaten - hData: general (L), gender (C),
                 name (C), email (C), lang (C)

   Bei "replace" wird die Emailadresse der bestehenden Person NICHT geaendert.
   Stattdessen wird ein neuer Kontakt angelegt und das Rechnungs-Flag umgehaengt.

   Rueckgabe: Hash {success,error}
*/
FUNCTION InvoiceMailCheckApply(cToken,hData)
   LOCAL hT := InvoiceMailCheckVerify(cToken)
   LOCAL cAction, hC, oExtra
   LOCAL cName, cEmail, nAnrede
   LOCAL cLang, cGender, hAnr
   LOCAL nNew

   IF hT == NIL
      RETURN { "success" => .F., "error" => "INVALID_TOKEN" }
   ENDIF
   IF ValType(hData) != "H" .OR. ! HHasKey(hData,"action") .OR. ValType(hData["action"]) != "C"
      RETURN { "success" => .F., "error" => "ACTION_REQUIRED" }
   ENDIF
   cAction := Lower(AllTrim(hData["action"]))

   NetUse("engkund","ku")
   ku->(dbSetOrder( 8 ))
   IF ! ku->(dbSeek( Str(hT["k"],6) ))
      RETURN { "success" => .F., "error" => "INVALID_TOKEN" }
   ENDIF

   hC := _RemailContact(hT["k"])
   IF hC == NIL .OR. hC["id"] != hT["c"]
      RETURN { "success" => .F., "error" => "ALREADY_CHANGED" }
   ENDIF

   oExtra := _RemailExtra(hT["k"])

   DO CASE
   CASE cAction == "confirm"
      oExtra:Set("REMAILCHK",Date())
      oExtra:Set("REMAILADR",hC["email"])
      oExtra:Set("REMAILSENT",StoD(""))
      oExtra:Set("REMAILSRC","PORTAL")
      oExtra:Save()
      _RemailLog(hT["k"],"Rechnungsemail vom Kunden bestaetigt", ;
                 "Bestaetigt ueber das Kundenportal."+CRLF+ ;
                 "Kontakt: "+hC["name"]+CRLF+ ;
                 "Adresse: "+hC["email"])

   CASE cAction == "replace"
      cEmail := Lower(AllTrim(_RemailStr(hData,"email")))
      cLang  := Lower(AllTrim(_RemailStr(hData,"lang")))
      IF ! _RemailValidMail(cEmail)
         RETURN { "success" => .F., "error" => "EMAIL_INVALID" }
      ENDIF

      IF _RemailBool(hData,"general")
         //Allgemeines Postfach: keine Person, also auch keine Anrede. Der
         //Name wird gesetzt, damit in der Kontaktliste etwas Sprechendes steht.
         nAnrede := 0
         cName   := REMAIL_POOLNAME
      ELSE
         cName := AllTrim(_RemailStr(hData,"name"))
         IF Empty(cName)
            RETURN { "success" => .F., "error" => "NAME_REQUIRED" }
         ENDIF
         hAnr := InvoiceMailCheckAnreden()
         IF cLang == "de"
            cGender := Lower(AllTrim(_RemailStr(hData,"gender")))
            IF ! (cGender == "m" .OR. cGender == "f" .OR. cGender == "d")
               RETURN { "success" => .F., "error" => "ANREDE_REQUIRED" }
            ENDIF
            nAnrede := hAnr[cGender]
         ELSE
            //ausserhalb des Deutschen gibt es keine Auswahl - immer "Dear"
            nAnrede := hAnr["en"]
         ENDIF
      ENDIF

      IF Lower(cEmail) == Lower(hC["email"]) .AND. Upper(cName) == Upper(hC["name"])
         RETURN { "success" => .F., "error" => "NO_CHANGE" }
      ENDIF

      nNew := _RemailNewContact(hT["k"],nAnrede,cName,cEmail,cLang)
      IF nNew == 0
         RETURN { "success" => .F., "error" => "SAVE_FAILED" }
      ENDIF
      _RemailDropInvoiceFlag(hT["k"],hC["id"])

      oExtra:Set("REMAILCHK",Date())
      oExtra:Set("REMAILADR",cEmail)
      oExtra:Set("REMAILSENT",StoD(""))
      oExtra:Set("REMAILSRC","PORTAL")
      oExtra:Save()

      _RemailLog(hT["k"],"Rechnungsempfaenger vom Kunden geaendert", ;
                 "Geaendert ueber das Kundenportal."+CRLF+ ;
                 "Bisher: "+hC["name"]+" <"+hC["email"]+"> (Kontakt "+LTrim(Str(hC["id"]))+")"+CRLF+ ;
                 "Rechnungs-Flag entfernt, Kontakt bleibt aktiv."+CRLF+ ;
                 "Neu:    "+cName+" <"+cEmail+"> (Kontakt "+LTrim(Str(nNew))+")")

   OTHERWISE
      RETURN { "success" => .F., "error" => "UNKNOWN_ACTION" }
   ENDCASE

RETURN { "success" => .T., "error" => "" }


/*
   InvoiceMailCheckAnreden()

   Liefert die Satznummern der anrede-Tabelle, die das Portal braucht:

      m   Herr        (nur deutsche Oberflaeche)
      f   Frau        (nur deutsche Oberflaeche)
      d   divers      (nur deutsche Oberflaeche)
      en  Dear        (alles ausser Deutsch - dort gibt es keine Auswahl)

   Die Zuordnung wird beim ersten Aufruf aus dem Text der Tabelle erraten und
   als Wert in Kategorie BH abgelegt. Stimmt sie nicht, laesst sie sich in der
   Werte-Maske korrigieren, ohne dass hier etwas angefasst werden muss:

      BH_ANREDEM   BH_ANREDEF   BH_ANREDED   BH_ANREDEEN

   Eine 0 bedeutet "keine passende Anrede" - dann greift die allgemeine
   Anrede aus GetContactAnrede().
*/
FUNCTION InvoiceMailCheckAnreden()
   LOCAL aEnv := SaveEnv()
   LOCAL hGuess := _RemailGuessAnreden()
   LOCAL hOut := {=>}

   hOut["m"]  := GetValue("BH_ANREDEM", hGuess["m"], "Rechnungsmail: Anrede maennlich")
   hOut["f"]  := GetValue("BH_ANREDEF", hGuess["f"], "Rechnungsmail: Anrede weiblich")
   hOut["d"]  := GetValue("BH_ANREDED", hGuess["d"], "Rechnungsmail: Anrede divers")
   hOut["en"] := GetValue("BH_ANREDEEN",hGuess["en"],"Rechnungsmail: Anrede englisch")

   RestEnv(aEnv,.F.)
RETURN hOut


//Raet die Satznummern aus dem Text der anrede-Tabelle. Nur der Startwert -
//gespeichert wird das Ergebnis in den BH_ANREDE*-Werten.
STATIC FUNCTION _RemailGuessAnreden()
   LOCAL hOut := {"m"=>0,"f"=>0,"d"=>0,"en"=>0}
   LOCAL cText, nRec

   NetUse("anrede","an",.F.,0)
   an->(dbGoTop())
   DO WHILE ! an->(Eof())
      cText := Lower(Trim(an->Anrede))
      nRec  := an->(RecNo())
      DO CASE
      CASE Empty(cText)
         //nichts
      CASE "dear" $ cText
         IF hOut["en"] == 0 ; hOut["en"] := nRec ; ENDIF
      CASE "damen" $ cText
         //"Sehr geehrte Damen und Herren" ist die allgemeine Form, keine Person
      CASE "frau" $ cText
         IF hOut["f"] == 0 ; hOut["f"] := nRec ; ENDIF
      CASE "herr" $ cText
         IF hOut["m"] == 0 ; hOut["m"] := nRec ; ENDIF
      CASE "divers" $ cText .OR. "guten tag" $ cText .OR. "*" $ cText .OR. ":" $ cText
         IF hOut["d"] == 0 ; hOut["d"] := nRec ; ENDIF
      ENDCASE
      an->(dbSkip())
   ENDDO

RETURN hOut


/*
   InvoiceMailCheckSendNow(nNummer,cTo,lStamp)

   Verschickt die Pruefmail sofort, ohne dass dafuer ein Auftrag angelegt
   werden muss. Damit laesst sich der ganze Weg testen: Vorlage, Versand
   ueber David, Link, Portalseite.

   cTo    - abweichender Empfaenger, leer = die hinterlegte Adresse
   lStamp - Status setzen, als waere es eine echte Anfrage. Ohne Angabe wird
            nur dann gesetzt, wenn an die hinterlegte Adresse geht - ein
            Testversand an die eigene Adresse soll den Kunden nicht als
            "angefragt" markieren und den Nachlauf nicht ausloesen.

   Der Link zeigt in jedem Fall auf den echten Kontakt des Kunden. Wer ihn
   anklickt, bestaetigt also dessen Adresse - beim Testen daran denken.

   Rueckgabe: Hash {ok,error,name,email,link,stamped}
*/
FUNCTION InvoiceMailCheckSendNow(nNummer,cTo,lStamp)
   LOCAL aEnv := SaveEnv()
   LOCAL hOut := {"ok"=>.F.,"error"=>"","name"=>"","email"=>"","link"=>"","stamped"=>.F.}
   LOCAL hC, cToken, oExtra, oErr

   IF ValType(cTo) != "C"
      cTo := ""
   ENDIF
   cTo := AllTrim(cTo)
   IF ValType(lStamp) != "L"
      lStamp := Empty(cTo)
   ENDIF

   BEGIN SEQUENCE WITH {|e| Break(e)}
      NetUse("engkund","ku")
      ku->(dbSetOrder( 8 ))
      IF ! ku->(dbSeek( Str(nNummer,6) ))
         hOut["error"] := "Kunde nicht gefunden"
         BREAK
      ENDIF

      hC := _RemailContact(nNummer)
      IF hC == NIL
         hOut["error"] := "Kein Rechnungsempfaenger hinterlegt"
         BREAK
      ENDIF
      IF hC["anrede"] <= 0
         hOut["error"] := "Rechnungsempfaenger ist keine Person (Anrede 0)"
         BREAK
      ENDIF
      IF ! Empty(cTo) .AND. ! _RemailValidMail(cTo)
         hOut["error"] := "Empfaengeradresse ungueltig"
         BREAK
      ENDIF
      IF Empty(cTo) .AND. ! _RemailValidMail(hC["email"])
         hOut["error"] := "Hinterlegte Adresse unbrauchbar: "+hC["email"]
         BREAK
      ENDIF

      cToken := _RemailToken(nNummer,hC["id"])
      IF Empty(cToken)
         hOut["error"] := "Kein Token - Keychain-Eintrag "+REMAIL_KEYNAME+" fehlt"
         BREAK
      ENDIF

      IF ! _RemailMail(nNummer,hC,cToken,"remail",cTo)
         hOut["error"] := "Versand fehlgeschlagen, siehe log\remail.log"
         BREAK
      ENDIF

      hOut["ok"]      := .T.
      hOut["name"]    := hC["name"]
      hOut["email"]   := IF(Empty(cTo),hC["email"],cTo)
      hOut["link"]    := REMAIL_PORTALURL+cToken
      hOut["stamped"] := lStamp

      IF lStamp
         oExtra := _RemailExtra(nNummer)
         oExtra:Set("REMAILSENT",Date())
         oExtra:Set("REMAILCNT",0)
         oExtra:Set("REMAILINFO",StoD(""))
         oExtra:Save()
      ENDIF

      _RemailLog(nNummer, ;
                 IF(lStamp,"Pruefung der Rechnungsemail verschickt", ;
                           "Testversand der Rechnungsmail-Pruefung"), ;
                 "Manuell ausgeloest, ohne Auftrag."+CRLF+ ;
                 "Kontakt:      "+hC["name"]+" <"+hC["email"]+">"+CRLF+ ;
                 "Versendet an: "+hOut["email"]+CRLF+ ;
                 IF(lStamp,"Status wurde gesetzt.", ;
                           "Testversand - Status blieb unveraendert."))
   RECOVER USING oErr
      hOut["ok"] := .F.
      IF ValType(oErr) == "O"
         hOut["error"] := oErr:Description
      ENDIF
   END SEQUENCE

   RestEnv(aEnv,.F.)
RETURN hOut


/*
   InvoiceMailCheckContact(nNummer)

   Der aktive Rechnungsempfaenger als Hash {id,name,email,anrede} oder NIL.
   Oeffentlich, damit die Testhilfe run	est_mailcheck.prg darauf kommt.
*/
FUNCTION InvoiceMailCheckContact(nNummer)
   LOCAL aEnv := SaveEnv()
   LOCAL hC := _RemailContact(nNummer)
   RestEnv(aEnv,.F.)
RETURN hC


/*
   InvoiceMailCheckState(nNummer)

   Der gespeicherte Pruefstand aus ExtraData, ohne ihn zu veraendern.
*/
FUNCTION InvoiceMailCheckState(nNummer)
   LOCAL aEnv := SaveEnv()
   LOCAL hOut := NIL
   LOCAL oExtra

   NetUse("engkund","ku")
   ku->(dbSetOrder( 8 ))
   IF ku->(dbSeek( Str(nNummer,6) ))
      oExtra := _RemailExtra(nNummer)
      hOut := { "checked" => oExtra:Get("REMAILCHK"), ;
                "address" => oExtra:Get("REMAILADR"), ;
                "sent"    => oExtra:Get("REMAILSENT"), ;
                "source"  => oExtra:Get("REMAILSRC") }
   ENDIF

   RestEnv(aEnv,.F.)
RETURN hOut


/*
   InvoiceMailCheckLink(nNummer)

   Erzeugt den Portal-Link fuer den aktuellen Rechnungsempfaenger des Kunden,
   OHNE eine Mail zu verschicken und ohne den Status zu veraendern. Fuer Tests
   und fuer den Support, wenn ein Kunde den Link direkt haben moechte.

   Rueckgabe: Link oder "" wenn kein passender Rechnungsempfaenger existiert
              bzw. der Keychain-Eintrag fehlt
*/
FUNCTION InvoiceMailCheckLink(nNummer)
   LOCAL aEnv := SaveEnv()
   LOCAL cLink := ""
   LOCAL hC, cToken

   NetUse("engkund","ku")
   ku->(dbSetOrder( 8 ))
   IF ku->(dbSeek( Str(nNummer,6) ))
      hC := _RemailContact(nNummer)
      IF hC != NIL .AND. hC["anrede"] > 0
         cToken := _RemailToken(nNummer,hC["id"])
         IF ! Empty(cToken)
            cLink := REMAIL_PORTALURL+cToken
         ENDIF
      ENDIF
   ENDIF

   RestEnv(aEnv,.F.)
RETURN cLink


/*
   InvoiceMailCheckVerify(cToken)

   Prueft die Signatur des Links und liefert {k,c} - Kundennummer und
   Kontaktnummer - oder NIL.
*/
FUNCTION InvoiceMailCheckVerify(cToken)
   LOCAL hP

   IF ValType(cToken) != "C" .OR. Empty(cToken) .OR. ! JWT_IsJWT(cToken)
      RETURN NIL
   ENDIF

   hP := JWT_Decode(cToken,REMAIL_KEYNAME)
   IF ValType(hP) != "H"
      RETURN NIL
   ENDIF
   IF ! HHasKey(hP,"sub") .OR. hP["sub"] != "remail"
      RETURN NIL
   ENDIF
   IF ! HHasKey(hP,"k") .OR. ! HHasKey(hP,"c")
      RETURN NIL
   ENDIF
   IF ! HHasKey(hP,"exp") .OR. ValType(hP["exp"]) != "N" .OR. hP["exp"] < JWT_CurrentTimestamp()
      RETURN NIL
   ENDIF

RETURN { "k" => Int(hP["k"]), "c" => Int(hP["c"]) }


/* ------------------------------------------------------------------ */
/* Interna                                                            */
/* ------------------------------------------------------------------ */

//Der aktive Rechnungsempfaenger des Kunden. Wie GetInvoiceContact(), liefert
//aber zusaetzlich die Anrede, die wir zur Unterscheidung Person / Sammeladresse
//brauchen.
STATIC FUNCTION _RemailContact(nNummer)
   LOCAL hC := NIL

   NetUse("contacts","conts")
   conts->(dbSetOrder( 2 ))
   conts->(dbSeek( Str(nNummer,6) ))
   DO WHILE ! conts->(Eof()) .AND. conts->Address == nNummer
      IF conts->Active .AND. conts->Invoice
         hC := { "id"     => conts->Number, ;
                 "name"   => Trim(conts->Name), ;
                 "email"  => Trim(conts->Email), ;
                 "anrede" => conts->Anrede }
         EXIT
      ENDIF
      conts->(dbSkip())
   ENDDO

RETURN hC


//ExtraData auf dem Kundensatz, Felder werden beim ersten Aufruf angelegt.
STATIC FUNCTION _RemailExtra(nNummer)
   LOCAL oExtra := ku->(ExtraData():New(nNummer))

   //nDecimal MUSS bei Typ "C" mitgegeben werden: ExtraData:Create()
   //defaultet den Parameter nur fuer "N" und schreibt sonst NIL ins
   //Feld DECIMAL - das quittiert Record:SetField mit "Type mismatch".

   IF ! oExtra:HasField("REMAILCHK")
      oExtra:Create("REMAILCHK","Rechnungsmail bestaetigt","D")
   ENDIF
   IF ! oExtra:HasField("REMAILADR")
      oExtra:Create("REMAILADR","Bestaetigte Rechnungsmail","C",Space(60),60,0)
   ENDIF
   IF ! oExtra:HasField("REMAILSENT")
      oExtra:Create("REMAILSENT","Rechnungsmail angefragt","D")
   ENDIF
   IF ! oExtra:HasField("REMAILSRC")
      oExtra:Create("REMAILSRC","Rechnungsmail Quelle","C",Space(10),10,0)
   ENDIF
   IF ! oExtra:HasField("REMAILCNT")
      oExtra:Create("REMAILCNT","Rechnungsmail Erinnerungen","N",0,2,0)
   ENDIF
   IF ! oExtra:HasField("REMAILINFO")
      oExtra:Create("REMAILINFO","Rechnungsmail intern gemeldet","D")
   ENDIF

RETURN oExtra


/*
   InvoiceMailCheckAnredeList()

   Die anrede-Tabelle als {id,label}. Nur zur Kontrolle - das Portal bekommt
   das fertige Mapping aus InvoiceMailCheckAnreden(). conts->Anrede ist die
   Satznummer, deshalb wird hier ueber RecNo() gezaehlt.
*/
FUNCTION InvoiceMailCheckAnredeList()
   LOCAL aOut := {}

   NetUse("anrede","an",.F.,0)
   an->(dbGoTop())
   DO WHILE ! an->(Eof())
      IF ! Empty(an->Anrede)
         AAdd(aOut,{ "id" => an->(RecNo()), "label" => Trim(an->Anrede) })
      ENDIF
      an->(dbSkip())
   ENDDO

RETURN aOut


STATIC FUNCTION _RemailToken(nNummer,nContact)
   LOCAL hPayload := {=>}

   hPayload["sub"] := "remail"
   hPayload["k"]   := nNummer
   hPayload["c"]   := nContact
   hPayload["iat"] := JWT_CurrentTimestamp()
   hPayload["exp"] := JWT_CurrentTimestamp() + REMAIL_TOKENDAYS*86400

RETURN JWT_Encode(hPayload,REMAIL_KEYNAME)


//Neuen Kontakt anlegen und als Rechnungsempfaenger markieren. Erst der neue,
//danach das Flag beim alten weg - sonst gibt es einen Moment ohne
//Rechnungsempfaenger und die Rechnungserstellung blockiert.
STATIC FUNCTION _RemailNewContact(nNummer,nAnrede,cName,cEmail,cLang)
   LOCAL oNew
   LOCAL nNumber := 1

   NetUse("contacts","conts")
   conts->(dbSetOrder( 2 ))
   conts->(dbSeek( Str(nNummer,6), .T. ))
   DO WHILE ! conts->(Eof()) .AND. conts->Address == nNummer
      nNumber := Max(nNumber,conts->Number+1)
      conts->(dbSkip())
   ENDDO

   oNew := Contact():New(.T.)
   oNew:Address := nNummer
   oNew:Number  := nNumber
   oNew:Anrede  := nAnrede
   oNew:Name    := cName
   oNew:Email   := cEmail
   oNew:Active  := .T.
   oNew:Invoice := .T.
   IF ValType(cLang) == "C" .AND. Len(AllTrim(cLang)) >= 2
      oNew:Lang := Upper(Left(AllTrim(cLang),2))
   ELSE
      oNew:Lang := IF(ku->Language=="D","DE","EN")
   ENDIF
   oNew:Save()

   //Der Hook pflegt das Telefonbuch und synchronisiert nach Agorum Core. Er
   //stammt aus der Desktop-Welt (TxtBox/SendMail), darf die Antwort an den
   //Kunden im Portal also unter keinen Umstaenden kippen.
   BEGIN SEQUENCE WITH {|e| Break(e)}
      Hook("after_save_contact",{.T.,oNew})
   RECOVER
      _RemailLogFile("Hook after_save_contact fehlgeschlagen fuer Kontakt "+ ;
                     LTrim(Str(nNummer))+"/"+LTrim(Str(nNumber)))
   END SEQUENCE

RETURN nNumber


STATIC FUNCTION _RemailDropInvoiceFlag(nNummer,nContact)
   LOCAL oOld

   NetUse("contacts","conts")
   conts->(dbSetOrder( 2 ))
   IF ! conts->(dbSeek( Str(nNummer,6)+Str(nContact,4) ))
      RETURN .F.
   ENDIF

   oOld := Contact():New(.F.)
   oOld:Invoice := .F.
   oOld:Save()

RETURN .T.


//Eintrag im Bewegungskonto des Kunden. BELEG ist nur C(70), der Volltext
//landet im Memo des gerade angelegten Satzes.
STATIC FUNCTION _RemailLog(nNummer,cShort,cDetail)

   NetUse("engkund","ku")
   ku->(dbSetOrder( 8 ))
   IF ! ku->(dbSeek( Str(nNummer,6) ))
      RETURN .F.
   ENDIF

   Bewegung({"STM",2,Date(),0,nNummer,0,0,0,0,Left(cShort,70),0,0,ku->Group,0})

   IF ! Empty(cDetail) .AND. Select("bew") != 0 .AND. bew->Kundennr == nNummer
      bew->(Rec_Lock(0))
      bew->Memo := cDetail
      bew->(dbUnLock())
   ENDIF

RETURN .T.


STATIC FUNCTION _RemailSend(oAuftrag,hDue,cToken)
   LOCAL nNummer := oAuftrag:Kunde:Nummer
   LOCAL oExtra, oNote

   IF ! _RemailMail(nNummer,hDue,cToken,"remail")
      RETURN .F.
   ENDIF

   oExtra := _RemailExtra(nNummer)
   oExtra:Set("REMAILSENT",Date())
   oExtra:Set("REMAILCNT",0)        //Erinnerungszaehler fuer den Nachlauf
   oExtra:Set("REMAILINFO",StoD(""))
   oExtra:Save()

   NetUse("notes","nts")
   oNote := nts->(Record():New(.T.))
   oNote:SetId("ID",4)
   oNote:Nummer  := oAuftrag:AbNr
   oNote:Betreff := "AUF"
   oNote:Date    := Date()
   oNote:Time    := Left(Time(),5)
   oNote:Type    := "NOTE"
   oNote:Person  := oAuftrag:Person
   oNote:Buyer   := SystemUser():Id
   oNote:Note    := "Pruefung der Rechnungs-Emailadresse an "+hDue["name"]+ ;
                    " <"+hDue["email"]+"> verschickt"
   oNote:Save()

   _RemailLog(nNummer,"Pruefung der Rechnungsemail verschickt", ;
              "Anfrage an "+hDue["name"]+" <"+hDue["email"]+">"+CRLF+ ;
              "Anlass: Auftrag "+LTrim(Str(oAuftrag:AbNr,6)))

RETURN .T.


//Verschickt eine Mail aus config\email\<cTemplate>_de|en.html an den
//Rechnungsempfaenger. Setzt keinen Status - das machen die Aufrufer.
STATIC FUNCTION _RemailMail(nNummer,hC,cToken,cTemplate,cTo)
   LOCAL cSubject := "", cHtml := ""
   LOCAL hRetData := {=>}, hContact := {=>}, hData := {=>}
   LOCAL cLang, cFrom := ""

   //ku muss fuer GetContactAnrede() auf dem Kunden stehen
   NetUse("engkund","ku")
   ku->(dbSetOrder( 8 ))
   IF ! ku->(dbSeek( Str(nNummer,6) ))
      RETURN .F.
   ENDIF
   cLang := IF(Empty(ku->Language),"D",ku->Language)

   hContact["anrede"] := GetContactAnrede(hC["id"])

   hData["name"]  := hC["name"]
   hData["email"] := hC["email"]
   hData["firma"] := Trim(ku->Name1)
   hData["link"]  := REMAIL_PORTALURL+cToken

   LoadEmailTemplate(cTemplate,cLang,@cSubject,@cHtml,hContact,hData,@hRetData,"UTF-8")
   IF Empty(cHtml)
      _RemailLogFile("Mailvorlage config\email\"+cTemplate+"_"+ ;
                     IF(cLang=="D","de","en")+".html fehlt")
      RETURN .F.
   ENDIF
   IF Empty(cSubject)
      cSubject := "Bitte bestaetigen Sie Ihre Emailadresse fuer den Rechnungsversand"
   ENDIF
   cHtml := LoadEmailConfigFile("header")+cHtml+LoadEmailConfigFile("footer")

   BEGIN SEQUENCE WITH {|e| Break(e)}
      cFrom := GetConfigValue("EMAIL-FROM_SALESORDER")
   RECOVER
      cFrom := ""
   END SEQUENCE

   MailConnect()
   IF ValType(cTo) != "C" .OR. Empty(AllTrim(cTo))
      cTo := hC["email"]
   ENDIF
   SendMail({{ AllTrim(cTo), hC["name"] }},cSubject,cHtml,{},.F.,0,.T.,cFrom,.F.,.F.)

RETURN .T.


STATIC FUNCTION _RemailValidMail(cMail)
   IF ValType(cMail) != "C" .OR. Empty(cMail) .OR. Len(AllTrim(cMail)) > 60
      RETURN .F.
   ENDIF
RETURN HB_RegexHas("^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$",AllTrim(cMail))


//Kleines Betriebslog. Bewusst eine eigene STATIC-Funktion, damit es nicht mit
//dem gelinkten LogMessage() aus ldap_startup.prg kollidiert.
STATIC FUNCTION _RemailLogFile(cMsg)
   LOCAL nH
   LOCAL cFile := Path("log\remail.log")

   nH := FOpen(cFile,1)          //1 = FO_WRITE
   IF nH == -1
      nH := FCreate(cFile)
   ELSE
      FSeek(nH,0,2)              //2 = FS_END
   ENDIF
   IF nH != -1
      FWrite(nH,DToC(Date())+" "+Time()+"  "+cMsg+CRLF)
      FClose(nH)
   ENDIF

RETURN .T.


STATIC FUNCTION _RemailStr(hData,cKey)
   IF ValType(hData) == "H" .AND. HHasKey(hData,cKey) .AND. ValType(hData[cKey]) == "C"
      RETURN hData[cKey]
   ENDIF
RETURN ""


STATIC FUNCTION _RemailBool(hData,cKey)
   IF ValType(hData) == "H" .AND. HHasKey(hData,cKey) .AND. ValType(hData[cKey]) == "L"
      RETURN hData[cKey]
   ENDIF
RETURN .F.


STATIC FUNCTION _RemailNum(hData,cKey)
   IF ValType(hData) == "H" .AND. HHasKey(hData,cKey) .AND. ValType(hData[cKey]) == "N"
      RETURN Int(hData[cKey])
   ENDIF
RETURN 0
