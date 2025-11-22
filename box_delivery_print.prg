//#include 'trader.ch'

/*
 * Program: Box Delivery Note Print
 * Purpose: Print delivery notes for returnable packaging (Umlaufverpackungen)
 *         and update the delivered quantity tracking
 * Author: GitHub Copilot
 * Date: November 17, 2025
 */

PROCEDURE PrintBoxDeliveryNote(nBesnr, cVerpackung)

LOCAL getlist := {}
LOCAL nBoxesToDeliver := 0, nMaxBoxes := 0
LOCAL nOpenQty, nBoxesNeeded, nBoxesAvailable
LOCAL cScreen := SaveScreen()
LOCAL lPrint := .T.
LOCAL dDeliveryDate := Date()
LOCAL cDeliveryNote := ""
LOCAL lPreview := .F.

MEMVAR p

// Parameter validation
IF ValType(nBesnr) != "N"
   nBesnr := 0
ENDIF

IF ValType(cVerpackung) != "C"
   cVerpackung := ""
ENDIF

// Open required databases
NetUse("engbes", "bes")
NetUse("artikel", "art") 
NetUse("engkund", "ku")
NetUse("extraval", "exv")

DO WHILE .T.
   Head("Lieferschein fr Umlaufverpackungen")
   
   bes->(dbSetOrder(1))
   @ 01,00 SAY "Bestellung Nr." GET nBesnr PICTURE "999999" VALID nBesnr > 0 .AND. bes->(dbSeek(Str(nBesnr,6)))
   READ
   
   IF LastKey() == 27
      EXIT
   ENDIF
   
   IF nBesnr > 0 .AND. bes->(dbSeek(Str(nBesnr,6)))
      @ 01,20 SAY "Lieferant: " + AllTrim(bes->Liefma)
      
      // Get packaging types for this supplier
      IF Empty(cVerpackung)
         cVerpackung := GetPackagingForPO(nBesnr)
      ENDIF
      
      @ 02,00 SAY "Verpackung "+cVerpackung // PICTURE "@!" VALID !Empty(cVerpackung)
      
      IF !Empty(cVerpackung)
         // Calculate how many boxes are needed and available
         nOpenQty := GetOpenQtyForPO(nBesnr, cVerpackung)
         nBoxesNeeded := GetBoxesNeededForPO(nBesnr, cVerpackung)
         nBoxesAvailable := GetAvailableBoxes(cVerpackung)
         nMaxBoxes := Min(nBoxesNeeded, nBoxesAvailable)
         
         @ 03,00 SAY "Offene Menge ben”tigt:" + Str(nOpenQty)
         @ 04,00 SAY "Ben”tigte Verpackungen:" + Str(nBoxesNeeded)
         @ 05,00 SAY "Verfgbare Verpackungen:" + Str(nBoxesAvailable)
         @ 06,00 SAY "Max. zu liefern:" + Str(nMaxBoxes)
         
         nBoxesToDeliver := nMaxBoxes
         @ 07,00 SAY "Anzahl zu liefern" GET nBoxesToDeliver PICTURE "999999" VALID nBoxesToDeliver >= 0 .AND. nBoxesToDeliver <= nMaxBoxes
      ENDIF
      
   ENDIF
   
   @ 08,00 SAY "Lieferdatum" GET dDeliveryDate
   //@ 09,00 SAY "Lieferschein Nr." GET cDeliveryNote PICTURE "@!"
   
   //@ 11,00 SAY "Drucken?" GET lPrint PICTURE "Y"
   
   READ
   
   IF LastKey() == 27
      EXIT
   ENDIF
   
   IF nBesnr > 0 .AND. !Empty(cVerpackung) .AND. nBoxesToDeliver > 0
      IF lPrint
         // Print the delivery note (PDF only)
         IF PrintBoxDeliveryDocument(nBesnr, cVerpackung, nBoxesToDeliver, dDeliveryDate, cDeliveryNote,@lPreview)
            IF ! lPreview
               // Update the tracking only if printing was successful
               UpdateBoxDeliveryTracking(nBesnr, cVerpackung, nBoxesToDeliver)
               Tr_MsgBox("Lieferschein erstellt und " + Ltrim(Str(nBoxesToDeliver)) + " Verpackungen geliefert.")
            ENDIF
         ELSE
            Tr_MsgBox("Lieferschein konnte nicht erstellt werden.")
            LOOP
         ENDIF
      ELSE
         // Update tracking even without printing
         //UpdateBoxDeliveryTracking(nBesnr, cVerpackung, nBoxesToDeliver)
         Tr_MsgBox("Tracking aktualisiert: " + Str(nBoxesToDeliver) + " Verpackungen als geliefert markiert.")
      ENDIF
      
      // Reset for next entry
      nBesnr := 0
      cVerpackung := ""
      nBoxesToDeliver := 0
   ENDIF
ENDDO

RESTORE SCREEN FROM cScreen

RETURN

/*
 * Print the actual delivery note document
 */
STATIC FUNCTION PrintBoxDeliveryDocument(nBesnr, cVerpackung, nBoxesToDeliver, dDeliveryDate, cDeliveryNote,lPreview)

LOCAL oPrinter

// Start printing - only accept PDF printers for consistent formatting
// and to ensure proper handling of special characters
oPrinter := StartPrint(,,"PDF")

IF oPrinter == NIL .OR. oPrinter:Type != "PDF"
   Tr_MsgBox("Nur PDF-Drucker werden untersttzt!")
   RETURN .F.
ENDIF

lPreview := oPrinter:lPreview

oPrinter:Data:NewPage("A4", "P")

// Company header/logo area
Schacht(9)

// Get supplier information
bes->(dbSetOrder(1))
bes->(dbSeek(Str(nBesnr,6)))
ku->(dbSetOrder( 1 ))
ku->(dbSeek(bes->Liefma+"L"))


//print address block
oPrinter:Data:SetFont("HELVETICA",0,10)
oPrinter:Data:AtSay(Trim(ku->Name1)+" "+ku->Name2,13,25 )
oPrinter:Data:AtSay(AllTrim(ku->Street),15,25 )
oPrinter:Data:AtSay(Trim(ku->PLZ)+" "+AllTrim(ku->Town),16,25 )
oPrinter:Data:AtSay(GetCountryName(ku->CountryIso),17,25 )

//PrintTextFile(Trim(Tr_Getini(1))+"\config\texts\address_"+If(ku->language=="D","de","en")+".txt")

// Document header with reference information (right aligned)
oPrinter:Data:SetFont("HELVETICA",0,9)
oPrinter:Data:AtSay("Bestellung Nr.",15,115)
oPrinter:Data:AtSay( Str(nBesnr,6),,140)
oPrinter:Data:AtSay("Lieferdatum",16,115)
oPrinter:Data:AtSay(DToC(dDeliveryDate),16,140)
IF ! Empty(ku->Kundennr)
   oPrinter:Data:AtSay(IF(ku->language="E","Supplier #","Lieferant Nr."),17,115)
   oPrinter:Data:AtSay(AllTrim(ku->Kundennr),17,140)
ENDIF

IF !Empty(cDeliveryNote)
   oPrinter:Data:AtSay("Lieferschein Nr.",18,115)
   oPrinter:Data:AtSay(cDeliveryNote,18,140)
ENDIF

// Reset to left margin and add spacing
oPrinter:Data:PDFLEFT := 10
oPrinter:Data:NewLine(2)

// Main document title
oPrinter:Data:ReportLine := 20
oPrinter:Data:SetFont("HELVETICA",0,16)
oPrinter:Data:Bold()
oPrinter:Data:AtSay(HB_OemToAnsi("LIEFERSCHEIN FšR UMLAUFVERPACKUNGEN"),24,20)
oPrinter:Data:Normal()

// Items table header
oPrinter:Data:SetFont("HELVETICA",0,10)
oPrinter:Data:Bold()
oPrinter:Data:AtSay("Pos.", 26,20)
oPrinter:Data:AtSay("Verpackungstyp",26, 50)
oPrinter:Data:AtSay("Anzahl", 26, 90 )
oPrinter:Data:NewLine(1)

// Items data
oPrinter:Data:Normal()
oPrinter:Data:AtSay("1", 27, 20)
oPrinter:Data:AtSay(PadR(cVerpackung, 30), 27, 50)
oPrinter:Data:AtSay(Transform(nBoxesToDeliver, "999,999"), 27, 90)
oPrinter:Data:NewLine(1)

// Important notices in a box
oPrinter:Data:SetFont("HELVETICA",0,9)
oPrinter:Data:Bold()
oPrinter:Data:AtSay("WICHTIGE HINWEISE:", 51, 20)
oPrinter:Data:Normal()
oPrinter:Data:AtSay("Diese Verpackungen sind Eigentum der Engelking Elektronik GmbH.", 53,20)
oPrinter:Data:AtSay("Nur fr die Lieferung unserer Drehteile verwenden.", 55,20)
oPrinter:Data:AtSay("Bei Verlust oder Besch„digung erfolgt Berechnung.", 57,20)

CopyPrint()

RETURN .T.

/*
 * Get the packaging type used for this purchase order
 */
STATIC FUNCTION GetPackagingForPO(nBesnr)

LOCAL cVerpackung := ""
LOCAL oExtra

// Check each position in the PO for packaging requirements  
bes->(dbSeek(Str(nBesnr,6)))

DO WHILE bes->Besnr == nBesnr .AND. !bes->(EOF())
   IF bes->Artikelnr > 0
      art->(dbSetOrder(2))
      IF art->(dbSeek(Str(bes->Artikelnr,6)))
         oExtra := art->(ExtraData():New(bes->Artikelnr))
         IF !Empty(oExtra:Umlauf)
            cVerpackung := AllTrim(oExtra:Umlauf)
            EXIT
         ENDIF
      ENDIF
   ENDIF
   bes->(dbSkip())
ENDDO

RETURN cVerpackung

/*
 * Get total open quantity for PO that needs this packaging
 */
STATIC FUNCTION GetOpenQtyForPO(nBesnr, cVerpackung)

LOCAL nTotalOpenQty := 0
LOCAL oExtra

bes->(dbSeek(Str(nBesnr,6)))

DO WHILE bes->Besnr == nBesnr .AND. !bes->(EOF())
   IF bes->BeStat < 3 .AND. bes->BeQty > bes->GelQty
      IF bes->Artikelnr > 0
         art->(dbSetOrder(2))
         IF art->(dbSeek(Str(bes->Artikelnr,6)))
            oExtra := art->(ExtraData():New(bes->Artikelnr))
            IF AllTrim(oExtra:Umlauf) == cVerpackung
               nTotalOpenQty += (bes->BeQty - bes->GelQty)
            ENDIF
         ENDIF
      ENDIF
   ENDIF
   bes->(dbSkip())
ENDDO

RETURN nTotalOpenQty

/*
 * Calculate how many boxes are needed for this PO
 */
STATIC FUNCTION GetBoxesNeededForPO(nBesnr, cVerpackung)

LOCAL nBoxesNeeded := 0
LOCAL nOpenQty, nCountPerBox, nSentBoxes
LOCAL oExtra, oBesExtra
LOCAL aMatch

// Get count per box from packaging name
aMatch := HB_Regex("[0-9]+", cVerpackung)
IF Len(aMatch) > 0
   nCountPerBox := Val(aMatch[1])
ELSE
   nCountPerBox := 1
ENDIF

bes->(dbSeek(Str(nBesnr,6)))

DO WHILE bes->Besnr == nBesnr .AND. !bes->(EOF())
   IF bes->BeStat < 3 .AND. bes->BeQty > bes->GelQty
      IF bes->Artikelnr > 0
         art->(dbSetOrder(2))
         IF art->(dbSeek(Str(bes->Artikelnr,6)))
            oExtra := art->(ExtraData():New(bes->Artikelnr))
            IF AllTrim(oExtra:Umlauf) == cVerpackung
               nOpenQty := bes->BeQty - bes->GelQty
               
               // Check how many boxes already sent
               oBesExtra := bes->(ExtraData():New(bes->Besnr))
               nSentBoxes := oBesExtra:&(cVerpackung)
               nSentBoxes -= Ceiling(bes->GelQty/nCountPerBox) // subtract already returned boxes
               IF nSentBoxes < 0
                  nSentBoxes := 0
               ENDIF
               
               nBoxesNeeded += Max(0, Ceiling(nOpenQty/nCountPerBox) - nSentBoxes)
            ENDIF
         ENDIF
      ENDIF
   ENDIF
   bes->(dbSkip())
ENDDO

RETURN nBoxesNeeded

/*
 * Get available boxes of this type (simplified - could check actual inventory)
 */
STATIC FUNCTION GetAvailableBoxes(cVerpackung)
   LOCAL aData 
   LOCAL aInitQty := GetBoxInitialQuantities()

   aData := GetUmlaufStatus(cVerpackung)
   IF Empty(aData)
      RETURN 0
   ENDIF

RETURN aInitQty[Trim(cVerpackung)] - aData["SENT"]

/*
 * Get total boxes already sent out (simplified calculation)
 */
STATIC FUNCTION GetTotalSentBoxes(cVerpackung)

LOCAL nTotalSent := 0, nSentBoxes
LOCAL oExtra, oBesExtra

// This is a simplified calculation - in practice you would
// scan through all open POs and sum up sent boxes
bes->(dbSetOrder(2)) // by supplier
bes->(dbGoTop())

DO WHILE !bes->(EOF())
   IF bes->BeStat < 3 .AND. bes->BeQty > bes->GelQty
      IF bes->Artikelnr > 0
         art->(dbSetOrder(2))
         IF art->(dbSeek(Str(bes->Artikelnr,6)))
            oExtra := art->(ExtraData():New(bes->Artikelnr))
            IF AllTrim(oExtra:Umlauf) == cVerpackung
               oBesExtra := bes->(ExtraData():New(bes->Besnr))
               nSentBoxes := oBesExtra:&(cVerpackung)
               nTotalSent += nSentBoxes
            ENDIF
         ENDIF
      ENDIF
   ENDIF
   bes->(dbSkip())
ENDDO

RETURN nTotalSent

/*
 * Update the tracking to record boxes delivered
 */
STATIC FUNCTION UpdateBoxDeliveryTracking(nBesnr, cVerpackung, nBoxesToDeliver)

LOCAL oBesExtra
LOCAL nCurrentSent

// Get current tracking for this PO
oBesExtra := bes->(ExtraData():New(nBesnr))

// Get current count
nCurrentSent := oBesExtra:&(cVerpackung)
IF ValType(nCurrentSent) != "N"
   nCurrentSent := 0
ENDIF

// Add delivered boxes
nCurrentSent += nBoxesToDeliver

// Update the tracking
oBesExtra:&(cVerpackung) := nCurrentSent
oBesExtra:Save()

RETURN .T.

/*
 * Helper function to count items per packaging unit
 */
STATIC FUNCTION CountPerUmlauf(cVerpackung)

LOCAL aMatch, nCount := 1

aMatch := HB_Regex("[0-9]+", cVerpackung)
IF Len(aMatch) > 0
   nCount := Val(aMatch[1])
ENDIF

RETURN nCount

#include 'showumlauf.prg'
