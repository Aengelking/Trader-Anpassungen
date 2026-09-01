/*
   FUNCTION: RUN_TestMailCheck

   DESCRIPTION:
   Testhilfe fuer die Rechnungsempfaenger-Mailpruefung. Zeigt fuer eine
   Kundennummer den hinterlegten Rechnungsempfaenger, den Pruefstand aus
   ExtraData und den Portal-Link - OHNE eine Mail zu verschicken und ohne
   irgendeinen Status zu veraendern.

   Der Link laesst sich mit STRG+C in die Zwischenablage kopieren und im
   Browser oeffnen.

   PARAMETERS:
   None

   RETURNS:
   None
*/
PROC RUN_TestMailCheck
   LOCAL getlist := {}
   LOCAL nNummer := 0
   LOCAL hC, hDue, oExtra, cLink
   LOCAL hAnr, aAnr, nX
   LOCAL nRow

   Head("Test: Pruefung der Rechnungs-Emailadresse")

   @ 01,00 SAY "Kundennummer" GET nNummer PICTURE "999999"
   READ

   IF LastKey() == 27 .OR. nNummer <= 0
      RETURN
   ENDIF

   LoadPrg(Path("run\invoicemailcheck.prg"))

   NetUse("engkund","ku")
   ku->(dbSetOrder( 8 ))
   IF ! ku->(dbSeek( Str(nNummer,6) ))
      Tr_MsgBox("Kunde "+LTrim(Str(nNummer))+" nicht gefunden")
      RETURN
   ENDIF

   nRow := 3
   @ nRow++,00 SAY "Kunde        : "+Trim(ku->Kunde)+"  "+Trim(ku->Name1)
   @ nRow++,00 SAY "Gruppe       : "+ku->Group+"   Rechnungsversand: "+Trim(ku->re_via)
   nRow++

   hC := HB_ExecFromArray("InvoiceMailCheckContact",{nNummer})
   IF hC == NIL
      @ nRow++,00 SAY "Rechnungsempfaenger: KEINER hinterlegt"
   ELSE
      @ nRow++,00 SAY "Rechnungsempfaenger: "+hC["name"]+" <"+hC["email"]+">"
      @ nRow++,00 SAY "Kontaktnummer      : "+LTrim(Str(hC["id"]))+ ;
                      "   Anrede: "+LTrim(Str(hC["anrede"]))+ ;
                      IF(hC["anrede"]<=0," (Sammeladresse - wird NICHT angefragt)","")
   ENDIF
   nRow++

   oExtra := HB_ExecFromArray("InvoiceMailCheckState",{nNummer})
   IF ValType(oExtra) == "H"
      @ nRow++,00 SAY "Bestaetigt am      : "+DToC(oExtra["checked"])
      @ nRow++,00 SAY "Bestaetigte Adresse: "+AllTrim(oExtra["address"])
      @ nRow++,00 SAY "Anfrage verschickt : "+DToC(oExtra["sent"])
      @ nRow++,00 SAY "Quelle             : "+AllTrim(oExtra["source"])
   ENDIF
   nRow++

   hDue := HB_ExecFromArray("InvoiceMailCheckDue",{nNummer})
   @ nRow++,00 SAY "Anfrage faellig    : "+IF(hDue==NIL,"nein","JA")
   nRow++

   //Anrede-Zuordnung fuer das Portal - stimmt sie nicht, lassen sich die
   //Werte BH_ANREDEM / BH_ANREDEF / BH_ANREDED / BH_ANREDEEN korrigieren
   hAnr := HB_ExecFromArray("InvoiceMailCheckAnreden",{})
   IF ValType(hAnr) == "H"
      @ nRow++,00 SAY "Anrede-Zuordnung   : m="+LTrim(Str(hAnr["m"]))+ ;
                      "  f="+LTrim(Str(hAnr["f"]))+ ;
                      "  divers="+LTrim(Str(hAnr["d"]))+ ;
                      "  englisch="+LTrim(Str(hAnr["en"]))
      aAnr := HB_ExecFromArray("InvoiceMailCheckAnredeList",{})
      FOR nX := 1 TO Len(aAnr)
         @ nRow++,04 SAY Str(aAnr[nX]["id"],3)+"  "+aAnr[nX]["label"]
      NEXT
   ENDIF
   nRow++

   cLink := HB_ExecFromArray("InvoiceMailCheckLink",{nNummer})
   IF Empty(cLink)
      @ nRow++,00 SAY "Link: -- kein Link erzeugbar --"
      @ nRow++,00 SAY "      (kein Rechnungsempfaenger mit Anrede, oder Keychain"
      @ nRow++,00 SAY "       Eintrag JWT_MAILCK fehlt)"
   ELSE
      @ nRow++,00 SAY "Link (STRG+C kopiert ihn):"
      @ nRow++,00 SAY SubStr(cLink,1,78)
      @ nRow++,00 SAY SubStr(cLink,79,78)
      @ nRow++,00 SAY SubStr(cLink,157,78)
      gtSetClipboard(cLink)
   ENDIF

   nRow++
   @ nRow++,00 SAY "Es wurde KEINE Mail verschickt und nichts gespeichert."
   @ nRow++,00 SAY "Taste druecken..."
   Inkey(0)

RETURN
