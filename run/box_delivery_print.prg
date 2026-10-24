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
LOCAL aPositions := {}, aDeliveryPositions
LOCAL nRow, nPos, nTotalBoxesToDeliver
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
      @ 01,22 SAY "Lieferant: " + AllTrim(bes->Liefma)
      aPositions := GetPackagingPositionsForPO(nBesnr, cVerpackung)

      IF Empty(aPositions)
         @ 03,00 SAY "Keine offenen Umlaufverpackungen fr diese Bestellung gefunden."
      ELSE
         @ 03,00 SAY PadR("Verpackung", 20) + PadL("Offene Menge", 14) + PadL("Ben”tigt", 12) + PadL("Verfgbar", 12) + PadL("Max.", 8) + "  Zu liefern"
         @ 04,00 SAY Replicate("-", 82)

         FOR nPos := 1 TO Len(aPositions)
            nRow := 04 + nPos
            @ nRow,00 SAY PadR(aPositions[nPos][1], 20)
            @ nRow,21 SAY PadL(Transform(aPositions[nPos][2], "999,999.99"), 14)
            @ nRow,36 SAY PadL(Transform(aPositions[nPos][3], "999,999"), 12)
            @ nRow,49 SAY PadL(Transform(aPositions[nPos][4], "999,999"), 12)
            @ nRow,62 SAY PadL(Transform(aPositions[nPos][5], "999,999"), 8)
            @ nRow,72 GET aPositions[nPos][6] PICTURE "999999" VALID aPositions[GetActive():Cargo][6] >= 0 .AND. aPositions[GetActive():Cargo][6] <= aPositions[GetActive():Cargo][5]
            Atail(getlist):Cargo := nPos
         NEXT
      ENDIF
   ENDIF

   nRow := Max(8, 06 + Len(aPositions))
   @ nRow,00 SAY "Lieferdatum" GET dDeliveryDate
   //@ 09,00 SAY "Lieferschein Nr." GET cDeliveryNote PICTURE "@!"
   
   //@ 11,00 SAY "Drucken?" GET lPrint PICTURE "Y"
   
   READ
   
   IF LastKey() == 27
      EXIT
   ENDIF

   aDeliveryPositions := GetSelectedDeliveryPositions(aPositions)
   nTotalBoxesToDeliver := GetTotalBoxesToDeliver(aDeliveryPositions)

   IF nBesnr > 0 .AND. Len(aDeliveryPositions) > 0 .AND. nTotalBoxesToDeliver > 0
      IF lPrint
         // Print the delivery note (PDF only)
         IF PrintBoxDeliveryDocument(nBesnr, aDeliveryPositions, dDeliveryDate, cDeliveryNote, @lPreview)
            IF ! lPreview
               // Update the tracking only if printing was successful
               UpdateBoxDeliveryTracking(nBesnr, aDeliveryPositions)
               Tr_MsgBox("Lieferschein erstellt: " + Ltrim(Str(Len(aDeliveryPositions))) + " Position(en), " + Ltrim(Str(nTotalBoxesToDeliver)) + " Verpackungen geliefert.")
            ENDIF
         ELSE
            Tr_MsgBox("Lieferschein konnte nicht erstellt werden.")
            LOOP
         ENDIF
      ELSE
         // Update tracking even without printing
         //UpdateBoxDeliveryTracking(nBesnr, aDeliveryPositions)
         Tr_MsgBox("Tracking aktualisiert: " + Ltrim(Str(nTotalBoxesToDeliver)) + " Verpackungen in " + Ltrim(Str(Len(aDeliveryPositions))) + " Position(en).")
      ENDIF
      
      // Reset for next entry
      nBesnr := 0
      cVerpackung := ""
      aPositions := {}
   ENDIF
ENDDO

RESTORE SCREEN FROM cScreen

RETURN

/*
 * Print the actual delivery note document
 */
STATIC FUNCTION PrintBoxDeliveryDocument(nBesnr, aDeliveryPositions, dDeliveryDate, cDeliveryNote, lPreview)

LOCAL oPrinter
LOCAL nRow, nNoticeRow
LOCAL aPosition

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

nRow := 27
FOR EACH aPosition IN aDeliveryPositions
   oPrinter:Data:AtSay(LTrim(Str(aPosition:__enumIndex())), nRow, 20)
   oPrinter:Data:AtSay(PadR(aPosition[1], 30), nRow, 50)
   oPrinter:Data:AtSay(Transform(aPosition[6], "999,999"), nRow, 90)
   nRow ++
NEXT

nNoticeRow := Max(51, nRow + 4)

// Important notices in a box
oPrinter:Data:SetFont("HELVETICA",0,9)
oPrinter:Data:Bold()
oPrinter:Data:AtSay("WICHTIGE HINWEISE:", nNoticeRow, 20)
oPrinter:Data:Normal()
oPrinter:Data:AtSay(HB_OemToAnsi("Diese Verpackungen sind Eigentum der Engelking Elektronik GmbH."), nNoticeRow + 2, 20)
oPrinter:Data:AtSay(HB_OemToAnsi("Nur fr die Lieferung unserer Drehteile verwenden."), nNoticeRow + 4, 20)
oPrinter:Data:AtSay(HB_OemToAnsi("Bei Verlust oder Besch„digung erfolgt Berechnung."), nNoticeRow + 6, 20)

CopyPrint()

RETURN .T.

/*
 * Build a list of packaging positions for this purchase order
 */
STATIC FUNCTION GetPackagingPositionsForPO(nBesnr, cOnlyVerpackung)

LOCAL aPositions := {}
LOCAL hPackaging := {=>}
LOCAL aKeys := {}
LOCAL aData
LOCAL oExtra
LOCAL oBesExtra
LOCAL cCurrentPackaging
LOCAL nOpenQty, nBoxesAvailable, nMaxBoxes, nCountPerBox, nSentBoxes, nBoxesNeeded
LOCAL aMatch
LOCAL cPackagingKey

bes->(dbSetOrder(1))
IF ! bes->(dbSeek(Str(nBesnr,6)))
   RETURN aPositions
ENDIF

DO WHILE bes->Besnr == nBesnr .AND. ! bes->(EOF())
   IF bes->BeStat < 3 .AND. bes->BeQty > bes->GelQty .AND. bes->Artikelnr > 0
      art->(dbSetOrder(2))
      
      IF art->(dbSeek(Str(bes->Artikelnr,6)))
         oExtra := art->(ExtraData():New(bes->Artikelnr))
         cCurrentPackaging := AllTrim(oExtra:Umlauf)
         cPackagingKey := AllTrim(cCurrentPackaging)

         IF ! Empty(cPackagingKey) .AND. (Empty(cOnlyVerpackung) .OR. cPackagingKey == AllTrim(cOnlyVerpackung))
            IF ! HHasKey(hPackaging, cPackagingKey)
               aMatch := HB_Regex("[0-9]+", cPackagingKey)
               IF Len(aMatch) > 0
                  nCountPerBox := Val(aMatch[1])
               ELSE
                  nCountPerBox := 1
               ENDIF

               oBesExtra := bes->(ExtraData():New(bes->Besnr))
               nSentBoxes := oBesExtra:&(cPackagingKey)
               IF ValType(nSentBoxes) != "N"
                  nSentBoxes := 0
               ENDIF

               hPackaging[cPackagingKey] := {0, nSentBoxes, nCountPerBox}
               AAdd(aKeys, cPackagingKey)
            ENDIF

            aData := hPackaging[cPackagingKey]
            nOpenQty := bes->BeQty - bes->GelQty
            aData[1] += nOpenQty
            hPackaging[cPackagingKey] := aData
         ENDIF
      ENDIF
   ENDIF
   bes->(dbSkip())
ENDDO

FOR EACH cPackagingKey IN aKeys
   aData := hPackaging[cPackagingKey]
   nBoxesAvailable := GetAvailableBoxes(cPackagingKey)
   nBoxesNeeded := Max(0, Ceiling(aData[1] / aData[3]) - aData[2])
   nMaxBoxes := Min(nBoxesNeeded, nBoxesAvailable)
   AAdd(aPositions, {cPackagingKey, aData[1], nBoxesNeeded, nBoxesAvailable, nMaxBoxes, nMaxBoxes})
NEXT

RETURN aPositions

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
 * Get available boxes of this type (simplified - could check actual inventory)
 */
STATIC FUNCTION GetAvailableBoxes(cVerpackung)
   LOCAL aData 
   LOCAL aInitQty := GetBoxInitialQuantities()

   LOCAL aReservedBoxes := {"BOXGEH50"=>4,"BOXTAST150"=>2,"BOXROS100"=>0,"BOXBIG50"=>0} //Quantities reserved for internal use

   aData := GetUmlaufStatus(cVerpackung)
   IF Empty(aData)
      RETURN 0
   ENDIF

   IF ! HHasKey(aInitQty, Trim(cVerpackung))
      RETURN 0
   ENDIF

RETURN aInitQty[Trim(cVerpackung)] - aData["SENT"] - IF(HHasKey(aReservedBoxes,Trim(cVerpackung)),aReservedBoxes[Trim(cVerpackung)],0)

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
LOCAL aPosition

// Get current tracking for this PO
oBesExtra := bes->(ExtraData():New(nBesnr))

IF ValType(cVerpackung) == "A"
   FOR EACH aPosition IN cVerpackung
      IF aPosition[6] > 0
         nCurrentSent := oBesExtra:&(aPosition[1])
         IF ValType(nCurrentSent) != "N"
            nCurrentSent := 0
         ENDIF

         oBesExtra:&(aPosition[1]) := nCurrentSent + aPosition[6]
      ENDIF
   NEXT

   oBesExtra:Save()
   RETURN .T.
ENDIF

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

/*
 * Filter positions with a quantity to deliver
 */
STATIC FUNCTION GetSelectedDeliveryPositions(aPositions)

LOCAL aSelected := {}
LOCAL aPosition

FOR EACH aPosition IN aPositions
   IF aPosition[6] > 0
      AAdd(aSelected, {aPosition[1], aPosition[2], aPosition[3], aPosition[4], aPosition[5], aPosition[6]})
   ENDIF
NEXT

RETURN aSelected

/*
 * Sum selected box quantities
 */
STATIC FUNCTION GetTotalBoxesToDeliver(aPositions)

LOCAL nTotal := 0
LOCAL aPosition

FOR EACH aPosition IN aPositions
   nTotal += aPosition[6]
NEXT

RETURN nTotal

#include 'showumlauf.prg'
