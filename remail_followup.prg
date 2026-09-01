/*
   FUNCTION: RUN_RemailFollowup

   DESCRIPTION:
   Nachlauf zur Pruefung der Rechnungsempfaenger-Emailadressen. Geht alle
   Kunden durch, bei denen eine Anfrage offen ist, schickt nach Ablauf der
   Frist eine Erinnerung an denselben Kontakt und meldet den Fall danach
   einmalig intern.

   Gedacht als taeglicher Lauf. Gefahrlos wiederholbar - jeder Schritt haelt
   seinen Stand in ExtraData, es geht also nichts doppelt raus.

   Die Logik selbst steht in run\invoicemailcheck.prg, hier ist nur die
   Bedienung.

   PARAMETERS:
   lBatch - .T. laeuft ohne Bildschirmausgabe und ohne Tastendruck

   RETURNS:
   Hash {checked,reminded,reported,cleared}
*/
PROC RUN_RemailFollowup(lBatch)
   LOCAL hRes
   LOCAL bProgress := NIL

   IF ValType(lBatch) != "L"
      lBatch := .F.
   ENDIF

   LoadPrg(Path("run\invoicemailcheck.prg"))

   IF ! lBatch
      Head("Nachlauf: Pruefung der Rechnungs-Emailadressen")
      @ 02,00 SAY "Offene Anfragen werden geprueft..."
      bProgress := {|nX,nAll,nNr| ;
         hb_DispOutAt(03,00,"Kunde "+Str(nX,5)+" von "+Str(nAll,5)+ ;
                   "   ("+LTrim(Str(nNr))+")     "), .T. }
   ENDIF

   hRes := HB_ExecFromArray("InvoiceMailCheckFollowup",{bProgress})

   IF ! lBatch
      @ 05,00 SAY "geprueft          : "+Str(hRes["checked"],5)
      @ 06,00 SAY "Erinnerung raus   : "+Str(hRes["reminded"],5)
      @ 07,00 SAY "intern gemeldet   : "+Str(hRes["reported"],5)
      @ 08,00 SAY "erledigt/aufgeraeumt: "+Str(hRes["cleared"],5)
      @ 10,00 SAY "Taste druecken..."
      Inkey(0)
   ENDIF

RETURN
