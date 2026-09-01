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

   Konfiguration liegt in der Values-Tabelle, Kategorie BH:
      BH_REMAILACTIVE  L  Pruefung aktiv
      BH_REMAILMONTHS  N  Gueltigkeit einer Bestaetigung in Monaten
      BH_REMAILREMIND  N  Wiedervorlage / Sperrfrist fuer neue Anfragen in Tagen

   Status je Kunde in ExtraData auf "KU":
      REMAILCHK   D  bestaetigt am
      REMAILADR   C  bestaetigte Adresse
      REMAILSENT  D  Anfrage verschickt am
      REMAILSRC   C  Quelle der letzten Bestaetigung (PORTAL / INTERN)
*/

//Keychain-Namen duerfen hoechstens 10 Zeichen lang sein (Pad(cName,10) beim Seek)
#define REMAIL_KEYNAME    "JWT_MAILCK"
#define REMAIL_TOKENDAYS  30
#define REMAIL_PORTALURL  "https://portal.engelking.com/mail-check?token="
#define CRLF              Chr(13)+Chr(10)


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

      cToken := _RemailToken(nNummer,hDue["contact"])
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

   Rueckgabe: Hash {contact,name,email,anrede} oder NIL wenn nichts zu tun ist
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
               "salutation" => "", "name" => "", "email" => "", "anreden" => {} }
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
   hOut["anreden"]    := _RemailAnreden()
RETURN hOut


/*
   InvoiceMailCheckApply(cToken,hData)

   Nimmt die Antwort des Kunden entgegen.

   hData["action"]:
      "confirm"  Adresse stimmt
      "replace"  anderer Ansprechpartner - hData: anrede (N), name (C), email (C)
      "unknown"  Kunde weiss es nicht / ist nicht zustaendig

   Bei "replace" wird die Emailadresse der bestehenden Person NICHT geaendert.
   Stattdessen wird ein neuer Kontakt angelegt und das Rechnungs-Flag umgehaengt.

   Rueckgabe: Hash {success,error}
*/
FUNCTION InvoiceMailCheckApply(cToken,hData)
   LOCAL hT := InvoiceMailCheckVerify(cToken)
   LOCAL cAction, hC, oExtra
   LOCAL cName, cEmail, nAnrede
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
      cName   := AllTrim(_RemailStr(hData,"name"))
      cEmail  := Lower(AllTrim(_RemailStr(hData,"email")))
      nAnrede := _RemailNum(hData,"anrede")
      IF Empty(cName)
         RETURN { "success" => .F., "error" => "NAME_REQUIRED" }
      ENDIF
      IF ! _RemailValidMail(cEmail)
         RETURN { "success" => .F., "error" => "EMAIL_INVALID" }
      ENDIF
      IF nAnrede <= 0
         RETURN { "success" => .F., "error" => "ANREDE_REQUIRED" }
      ENDIF
      IF Lower(cEmail) == Lower(hC["email"]) .AND. Upper(cName) == Upper(hC["name"])
         RETURN { "success" => .F., "error" => "NO_CHANGE" }
      ENDIF

      nNew := _RemailNewContact(hT["k"],nAnrede,cName,cEmail)
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

   CASE cAction == "unknown"
      //Keine Bestaetigung: REMAILCHK bleibt leer, damit intern nachgefasst wird.
      //REMAILSENT wird aber vorgezogen, sonst bekaeme genau die Person, die
      //gerade "nicht zustaendig" gemeldet hat, nach der Wiedervorlagefrist
      //dieselbe Mail noch einmal.
      oExtra:Set("REMAILSENT",Date()+30)
      oExtra:Save()
      _RemailLog(hT["k"],"Rechnungsempfaenger: Kunde nicht zustaendig", ;
                 "Der Empfaenger "+hC["name"]+" <"+hC["email"]+"> hat angegeben, "+ ;
                 "fuer den Rechnungsempfang nicht zustaendig zu sein."+CRLF+ ;
                 "Bitte intern klaeren.")

   OTHERWISE
      RETURN { "success" => .F., "error" => "UNKNOWN_ACTION" }
   ENDCASE

RETURN { "success" => .T., "error" => "" }


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

RETURN oExtra


//Anrede-Liste fuer die Portalseite. conts->Anrede ist die Satznummer in der
//anrede-Tabelle, deshalb wird hier ueber Recno() gezaehlt.
STATIC FUNCTION _RemailAnreden()
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
STATIC FUNCTION _RemailNewContact(nNummer,nAnrede,cName,cEmail)
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
   LOCAL cSubject := "", cHtml := ""
   LOCAL hRetData := {=>}, hContact := {=>}, hData := {=>}
   LOCAL cLang := IF(Empty(oAuftrag:Kunde:Language),"D",oAuftrag:Kunde:Language)
   LOCAL cFrom := ""
   LOCAL nNummer := oAuftrag:Kunde:Nummer
   LOCAL oExtra, oNote

   //ku muss fuer GetContactAnrede() auf dem Kunden stehen
   NetUse("engkund","ku")
   ku->(dbSetOrder( 8 ))
   IF ! ku->(dbSeek( Str(nNummer,6) ))
      RETURN .F.
   ENDIF

   hContact["anrede"] := GetContactAnrede(hDue["contact"])

   hData["nr"]    := LTrim(Str(oAuftrag:AbNr,6))
   hData["name"]  := hDue["name"]
   hData["email"] := hDue["email"]
   hData["firma"] := Trim(ku->Name1)
   hData["link"]  := REMAIL_PORTALURL+cToken

   LoadEmailTemplate("remail",cLang,@cSubject,@cHtml,hContact,hData,@hRetData,"UTF-8")
   IF Empty(cHtml)
      _RemailLogFile("Mailvorlage config\email\remail_"+IF(cLang=="D","de","en")+".html fehlt")
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
   SendMail({{ hDue["email"], hDue["name"] }},cSubject,cHtml,{},.F.,0,.T.,cFrom,.F.,.F.)

   oExtra := _RemailExtra(nNummer)
   oExtra:Set("REMAILSENT",Date())
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

   AddWiedervorlage(Date()+GetValue("BH_REMAILREMIND",7,"Rechnungsmail: Wiedervorlage in Tagen"), ;
                    "Rechnungsemail "+Trim(ku->Kunde)+" nicht bestaetigt", ;
                    "Der Rechnungsempfaenger "+hDue["name"]+" <"+hDue["email"]+">"+CRLF+ ;
                    "von "+Trim(ku->Name1)+" ("+Trim(ku->Kunde)+")"+CRLF+ ;
                    "hat die Emailadresse nicht bestaetigt."+CRLF+CRLF+ ;
                    "Anlass war Auftrag "+LTrim(Str(oAuftrag:AbNr,6))+".", ;
                    "REMAIL"+Str(nNummer,6),,oAuftrag:Buyer)

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


STATIC FUNCTION _RemailNum(hData,cKey)
   IF ValType(hData) == "H" .AND. HHasKey(hData,cKey) .AND. ValType(hData[cKey]) == "N"
      RETURN Int(hData[cKey])
   ENDIF
RETURN 0
