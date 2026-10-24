/*
   before_print_rechnung.prg

   Wird aus rechnung_print.prg aufgerufen, bevor die Rechnung bzw. Gutschrift
   gedruckt oder verschickt wird. ku steht zu diesem Zeitpunkt auf der
   Rechnungsadresse.

   hSettings wird per Referenz uebergeben und vom Aufrufer ausgewertet:
      "from"  C  Absenderadresse, vorbelegt aus EMAIL-FROM_SALESINVOICE
      "cc"    A  zusaetzliche Empfaenger, werden als CC an die Mail gehaengt

   Kunden, bei denen ein Ansprechpartner die Rechnung in Kopie erhalten soll,
   bekommen dessen Kontaktnummer in der ExtraData-Variablen REMAILCC auf dem
   Kundensatz. Gepflegt wird sie in der Adressmaske im Tab "Variablen", die
   Auswahlart "Kontaktpersonen" liefert dort die Auswahlliste. Hinterlegt ist
   die Kontaktnummer und nicht die Adresse, eine Aenderung der Emailadresse
   beim Ansprechpartner zieht also automatisch nach.

   Siehe auch run\invoicemailcheck.prg, das die uebrigen REMAIL*-Variablen
   fuer die Pruefung der Rechnungsempfaenger-Emailadresse pflegt.
*/

FUNCTION Before_Print_Rechnung(oRechnung,hSettings)
   LOCAL oExtra,nCont

   HB_SYMBOL_UNUSED(oRechnung)

   oExtra := ku->(ExtraData():New(ku->Nummer))

   //Feld beim ersten Durchlauf anlegen, ExtraData:Get() wirft sonst einen
   //Fehler. Auswahlart "CO" = Kontaktpersonen, dazu gehoert Typ N Laenge 2.
   IF ! oExtra:HasField("REMAILCC")
      oExtra:Create("REMAILCC","Rechnung in Kopie an","N",0,2,0,'Group=="K"',"CO")
   ENDIF

   nCont := oExtra:Get("REMAILCC")
   IF ValType(nCont) != "N" .OR. nCont <= 0
      RETURN .T.
   ENDIF

   //Kein GetContact(), weil hier zusaetzlich auf Active geprueft wird.
   NetUse("contacts","conts",.F.,0)
   conts->(dbSetOrder(2))
   IF conts->(dbSeek( Str(ku->Nummer,6)+Str(nCont,4) )) .AND. conts->Active ;
      .AND. ! Empty(conts->Email)
      Aadd(hSettings["cc"],AllTrim(conts->Email))
   ENDIF

RETURN .T.
