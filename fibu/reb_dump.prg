/**
  * RUN_REB_DUMP - die rohen Lexware-Buchungszeilen zu einem reb-Beleg
  *
  * Diagnose, kein Sammler. Sie beantwortet eine einzige Frage: wie sieht eine
  * Buchung in Lexware wirklich aus, wenn reb_push.prg meldet, dass Zeilen den
  * Kreditor nicht beruehren?
  *
  *   DIESES PROGRAMM SCHREIBT NICHTS - weder in Trader noch nach Finova.
  *
  * Der Trockenlauf vom 26.09. hat 206 Belege ohne Sachkonto gezeigt und 230
  * Zeilen auf Konto 0. Die Vermutung: Lexware bucht eine Aufteilung so, dass
  * die Kreditorzeile auf der Gegenseite eine 0 traegt und nur die Summe ist,
  * waehrend die Aufwandszeilen daneben stehen - mit 0 auf der Kreditorseite.
  * Dann nimmt reb_push.prg genau die falsche Haelfte.
  *
  * Bestaetigen laesst sich das nur an den Zeilen selbst. Deshalb hier alles,
  * ungefiltert und ungedeutet: Soll, Haben, Netto, USt, Text, Datum.
  *
  * Aufruf: RUN_REB_DUMP()      die ersten 12 auffaelligen Belege
  *         RUN_REB_DUMP(30)    die ersten 30
  *
  * Auffaellig heisst: mindestens eine Buchungszeile beruehrt reb->Konto nicht.
  * Genau die Faelle, ueber die der Sammler stolpert.
  *
  * Protokoll unter \export\rebdump_<Datum>_<Zeit>.txt
  **/

#define CRLF Chr(13)+Chr(10)

STATIC snProtokoll := 0

FUNCTION RUN_REB_DUMP(nMax)
   LOCAL cProtokoll
   LOCAL nJahr, cJahr
   LOCAL aBookings, hBuchung
   LOCAL nGezeigt := 0, nScanned := 0
   LOCAL nFremd, nEigen
   LOCAL dFrom := SToD("20260101")

   Default(@nMax, 12)

   cProtokoll := Path("\export\rebdump_" + DToS(Date()) + "_" + ;
                      StrTran(Time(), ":", "-") + ".txt")
   snProtokoll := FCreate(cProtokoll)

   Head("Rohe Lexware-Buchungen zu reb-Belegen")
   _DLog("Diagnose, " + DToC(Date()) + " " + Time())
   _DLog("Es wird nur gelesen. Hoechstens " + LTrim(Str(nMax)) + " Belege.")
   _DLog("")

   NetUse("reb", "reb")
   reb->(dbClearFilter())
   reb->(dbSetOrder(1))

   FOR nJahr := Year(dFrom) TO Year(Date())
      cJahr := Right(Str(nJahr, 4), 2)
      reb->(dbSeek(cJahr + Replicate("0", 7), .T.))

      DO WHILE ! reb->(Eof()) .AND. Left(Str(reb->ID, 9), 2) == cJahr .AND. ;
               nGezeigt < nMax

         nScanned++
         aBookings := _DBuchungen(reb->ID)

         IF Len(aBookings) > 0
            //Zaehlen, wie viele Zeilen den Kreditor beruehren - nur die
            //auffaelligen Belege sind interessant.
            nFremd := 0
            nEigen := 0
            FOR EACH hBuchung IN aBookings
               IF hBuchung["SOLL"] == reb->Konto .OR. hBuchung["HABEN"] == reb->Konto
                  nEigen++
               ELSE
                  nFremd++
               ENDIF
            NEXT

            IF nFremd > 0
               nGezeigt++
               _DLog(Replicate("-", 78))
               _DLog("reb-ID " + Str(reb->ID, 9) + ;
                     "   Beleg " + Trim(reb->Beleg) + ;
                     IF(Empty(reb->Beleg_Kurz), "", " (kurz: " + Trim(reb->Beleg_Kurz) + ")"))
               _DLog("  Name      " + Trim(reb->Name))
               _DLog("  Konto     " + LTrim(Str(reb->Konto)) + ;
                     "      Liefnr " + LTrim(Str(reb->Liefnr)) + ;
                     "      KS " + Trim(reb->KS))
               _DLog("  Betrag    " + Str(reb->Betrag, 14, 2) + ;
                     "      Status " + LTrim(Str(reb->Status)))
               _DLog("  Buchungen " + LTrim(Str(Len(aBookings))) + ;
                     " (" + LTrim(Str(nEigen)) + " am Kreditor, " + ;
                     LTrim(Str(nFremd)) + " nicht)")
               _DLog("")
               _DLog("    NR      DATUM       SOLL    HABEN        NETTO         UST  K  TEXT")

               FOR EACH hBuchung IN aBookings
                  _DLog("    " + ;
                        PadR(LTrim(Str(hBuchung["NR"])), 8) + ;
                        PadR(DToC(hBuchung["DATUM"]), 12) + ;
                        PadL(LTrim(Str(hBuchung["SOLL"])), 5) + "  " + ;
                        PadL(LTrim(Str(hBuchung["HABEN"])), 7) + ;
                        Str(hBuchung["NETTO"], 13, 2) + ;
                        Str(hBuchung["UST"], 12, 2) + ;
                        IF(hBuchung["SOLL"] == reb->Konto .OR. ;
                           hBuchung["HABEN"] == reb->Konto, "  *", "   ") + ;
                        " " + Trim(hBuchung["TEXT"]))
               NEXT
               _DLog("")
               _DLog("    * = beruehrt den Kreditor " + LTrim(Str(reb->Konto)))
               _DLog("")
            ENDIF
         ENDIF

         reb->(dbSkip())
      ENDDO
   NEXT

   reb->(dbClearFilter())

   _DLog(Replicate("=", 78))
   _DLog("Gelesen: " + LTrim(Str(nScanned)) + "   Gezeigt: " + LTrim(Str(nGezeigt)))

   IF snProtokoll > 0
      FClose(snProtokoll)
      snProtokoll := 0
   ENDIF
   Alert("Fertig: " + cProtokoll)

RETURN .T.

STATIC FUNCTION _DBuchungen(nId)
   LOCAL aBookings

   BEGIN SEQUENCE
      aBookings := LX_GetBookingsForID("ER" + Str(nId, 9), .F.)
   RECOVER
      aBookings := {}
   END SEQUENCE

   IF ValType(aBookings) != "A"
      aBookings := {}
   ENDIF

RETURN aBookings

STATIC FUNCTION _DLog(cText)
   ? cText
   IF snProtokoll > 0
      FWrite(snProtokoll, cText + CRLF)
   ENDIF
RETURN NIL
