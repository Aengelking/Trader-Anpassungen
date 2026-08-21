/*****************************************************************************
 *  creditlimit_firmgroup_check.prg
 *
 *  Prueft vor dem Scharfschalten der Kreditlimit-Kopplung (CREDITLIMITS_FIRMGROUP),
 *  welche Kunden der aktuellen Firma in der Master-Firma FEHLEN. Fuer diese Kunden
 *  gibt es nach der Kopplung kein Kreditlimit mehr - sie muessen dort mit dem
 *  gleichen Matchcode angelegt werden.
 *
 *  Ausgabe: Bildschirm + Textdatei im lokalen Trader-Verzeichnis.
 *
 *  In der angehaengten Firma (z.B. automotive) starten: Interpreter -> dieses
 *  Script. Setzt einen Trader-Build voraus, der die Kopplung enthaelt.
 *****************************************************************************/

PROCEDURE Run_CreditLimit_FirmGroup_Check()

LOCAL cMaster, cFirm, cPre
LOCAL aMissing := {}, aRow
LOCAL hMasterNames := {=>}, cKey
LOCAL nTotal := 0, nMissing := 0, nRisk := 0
LOCAL hUse
LOCAL cText := "", cLine
LOCAL cFile
LOCAL nX

cFirm   := GetConfigValue("FIRMPATH")
cMaster := CreditLimitMasterFirm()

IF Empty(cMaster)
   Tr_MsgBox({"Keine Kreditlimit-Gruppe konfiguriert.","In config\trader.ini: [CREDITLIMITS] FIRMGROUP=.,automotive"})
   RETURN
ENDIF

IF ! IsCreditLimitLinked()
   Tr_MsgBox({"Diese Firma ist die Master-Firma der Kreditlimit-Gruppe.","Das Script bitte in der angehaengten Firma starten."})
   RETURN
ENDIF

cPre := IF(Trim(cMaster) == ".", ".", Trim(cMaster)) + "\"

Head("Kreditlimit-Kopplung: fehlende Kunden in " + Trim(cMaster))
SetPos(01,00)
? "Bitte warten, Kundenstamm wird verglichen..."

//Namensindex der Master-Firma aufbauen, um Kunden mit ABWEICHENDEM Matchcode zu finden
NetUse(cPre + "engkund", "mku", .F., 2)
mku->(dbSetOrder(2))   //group+kunde
mku->(dbSeek("K"))
DO WHILE ! mku->(Eof()) .AND. mku->Group == "K"
   cKey := NormName(mku->Name1)
   IF ! Empty(cKey) .AND. ! HB_HHasKey(hMasterNames, cKey)
      hMasterNames[cKey] := Trim(mku->Kunde) + " (" + Trim(mku->Name1) + ", " + Trim(mku->Town) + ")"
   ENDIF
   mku->(dbSkip())
ENDDO

//Kunden der eigenen Firma durchgehen
NetUse("engkund", "ku", .F., 0)
ku->(dbSetOrder(2))
ku->(dbSeek("K"))
mku->(dbSetOrder(1))   //kunde+group
DO WHILE ! ku->(Eof()) .AND. ku->Group == "K"
   nTotal++
   IF ! mku->(dbSeek(Pad(ku->Kunde, 8) + "K"))
      nMissing++
      hUse := GetFirmCreditUsage(cFirm, ku->Kunde)
      nRisk += hUse["total"]
      cKey := NormName(ku->Name1)
      AAdd(aMissing, { Trim(ku->Kunde), ;
                       Trim(ku->Name1), ;
                       Trim(ku->Town), ;
                       ku->CredLimit, ;
                       hUse["invoices"], ;
                       hUse["orders"], ;
                       IF(HB_HHasKey(hMasterNames, cKey), hMasterNames[cKey], "") } )
   ENDIF
   ku->(dbSkip())
ENDDO

//die mit offener Auslastung nach oben - die tun beim Umschalten sofort weh
ASort(aMissing, , , {|a, b| a[5] + a[6] > b[5] + b[6] })

CLS
Head("Kreditlimit-Kopplung: " + LTrim(Str(nMissing)) + " von " + LTrim(Str(nTotal)) + " Kunden fehlen in " + Trim(cMaster))
SetPos(01, 00)

cLine := Pad("Matchcode", 9) + Pad("Name", 30) + Pad("Ort", 18) + PadL("Limit", 10) + ;
         PadL("offen Re", 12) + PadL("offen Auf", 12) + "  Kandidat gleicher Name"
? cLine
cText := cLine + Chr(13) + Chr(10)

FOR nX := 1 TO Len(aMissing)
   aRow  := aMissing[nX]
   cLine := Pad(aRow[1], 9) + Pad(aRow[2], 30) + Pad(aRow[3], 18) + ;
            PadL(Transform(aRow[4], "@E 9,999,999"), 10) + ;
            PadL(Transform(aRow[5], "@E 9,999,999.99"), 12) + ;
            PadL(Transform(aRow[6], "@E 9,999,999.99"), 12) + "  " + aRow[7]
   ? cLine
   cText += cLine + Chr(13) + Chr(10)
   IF Row() >= MaxRow() - 1
      ? "-- weiter mit einer Taste --"
      SInkey(0)
      CLS
      SetPos(00, 00)
   ENDIF
NEXT

cLine := "Summe offene Rechnungen + Auftraege dieser Kunden: " + Transform(nRisk, "@E 99,999,999.99")
?
? cLine
cText += Chr(13) + Chr(10) + cLine + Chr(13) + Chr(10)

cFile := GetConfigValue("configdir") + "creditlimit_firmgroup_check.txt"
IF MemoWrit(cFile, cText)
   ? "Liste gespeichert:", cFile
ENDIF

? "Ende mit einer Taste"
SInkey(0)

RETURN

/*  Name auf einen vergleichbaren Kern reduzieren: Grossschreibung, ohne
 *  Leer- und Sonderzeichen und ohne die gaengigen Rechtsformen. Findet
 *  Kunden, die in beiden Firmen stehen, aber unter abweichendem Matchcode.  */
STATIC FUNCTION NormName(cName)
   LOCAL cOut := "", nX, cChar
   LOCAL aForms := {"GMBHCOKG", "GMBHCO", "GMBH", "AKTIENGESELLSCHAFT", "COKG", "KGAA", "OHG", "GBR", "EK", "SE", "UG", "AG", "KG", "EG"}

   IF ValType(cName) != "C"
      RETURN ""
   ENDIF
   cName := Upper(Trim(cName))
   FOR nX := 1 TO Len(cName)
      cChar := SubStr(cName, nX, 1)
      IF (cChar >= "A" .AND. cChar <= "Z") .OR. (cChar >= "0" .AND. cChar <= "9")
         cOut += cChar
      ENDIF
   NEXT
   FOR nX := 1 TO Len(aForms)
      IF Len(cOut) > Len(aForms[nX]) .AND. Right(cOut, Len(aForms[nX])) == aForms[nX]
         cOut := Left(cOut, Len(cOut) - Len(aForms[nX]))
         EXIT
      ENDIF
   NEXT
RETURN Left(cOut, 12)
