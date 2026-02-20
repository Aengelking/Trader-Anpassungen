/*
 * Export Customer Price List to XLSX
 *
 * Description: Exports customer-specific price list with price tiers to Excel format
 * Author: Claude Code
 * Date: 2025-11-09
 */

#include "inkey.ch"
#include "setcurs.ch"

FUNCTION ExportCustomerPriceList()
   LOCAL cKunde := Space(8)
   LOCAL cFile
   LOCAL aData := {}
   LOCAL hRow
   LOCAL nCount := 0
   LOCAL oArtikel
   LOCAL aPrices
   LOCAL nX
   LOCAL cCurrency
   LOCAL getlist := {}
   LOCAL hMatch, aMatchList,cKuArt
   LOCAL nP,nY
   LOCAL hData := {=>}

   Head("Kundenpreisliste exportieren")

   // Get customer code
   @ 5, 10 SAY "Kunde:" GET cKunde PICTURE "@!" VALID ! Empty(cKunde)
   READ

   IF LastKey() == K_ESC .OR. Empty(cKunde)
      RETURN NIL
   ENDIF

   // Verify customer exists
   NetUse("engkund","ku",.F.,0)
   ku->(dbSetOrder(1))  // Index by customer code
   IF ! ku->(dbSeek(cKunde+"K"))
      Tr_MsgBox("Kunde " + Trim(cKunde) + " nicht gefunden!")
      ku->(dbCloseArea())
      RETURN NIL
   ENDIF

   cCurrency := Trim(ku->Money)

   // Get save file name
   cFile := Wvt_GetSaveFileName(0, "", "XLSX Datei", ;
      { {"Spreadsheet (*.xlsx)","*.xlsx"}, {"Alle Dateien (*.*)","*.*"} }, , ;
      Path("export\"), "xlsx" )

   IF Empty(cFile)
      ku->(dbCloseArea())
      RETURN NIL
   ENDIF

   // Ensure .xlsx extension
   IF RAT(".xlsx", Lower(cFile)) != Len(cFile)-4
      cFile += ".xlsx"
   ENDIF

   // Show progress
   TxtBox("Preisliste wird erstellt...")

   // Open required tables
   NetUse("artkund","aku",.F.,0)
   NetUse("artikel","art",.F.,0)

   // Build header row (adjust language if needed based on ku->Language)
   IF ku->Language == "E"
      Aadd(aData, {"Part No.", "Matchcode","Delivery time", "Customer Part No.", ;
                   "Unit"})
   ELSE
      Aadd(aData, {"Artikelnr", "Matchcode", "Lieferzeit", "Kunden-Artikelnr", ;
                    "Mengeneinheit"})
   ENDIF

   hData["IEC-LOCK"] := AClone(aData)
   hData["ENGELKING"] := AClone(aData)

   // Query customer article assignments
   aku->(dbSetOrder(1))  // Index by customer+article
  
   aMatchList := {;
      {"MATCH_START"=>"NZ/","MANUFACTURER"=>9,"LIST"=>"IEC-LOCK"},;
      {"MATCH_START"=>"PA","MANUFACTURER"=>9,"LIST"=>"IEC-LOCK"},;
      {"MATCH_START"=>"CM","MANUFACTURER"=>5,"LIST"=>"ENGELKING"} ;
   }
   art->(dbSetOrder(1)) // Index by Matchcode
   FOR EACH hMatch IN aMatchList
      art->(dbSeek(hMatch["MATCH_START"]))
      aData := hData[hMatch["LIST"]]
      DO WHILE ! art->(Eof()) .AND. Left(Trim(art->Matchcode), Len(hMatch["MATCH_START"])) == hMatch["MATCH_START"]
         IF art->Manufactur == hMatch["MANUFACTURER"]
            @ MaxRow(),00 SAY art->Matchcode
            @ MaxRow()-1,00 SAY Str(nCount+1)
            // Get customer-specific prices using Artikel class
            oArtikel := Artikel():New(.F.)
            oArtikel:Load(art->Artikelnr)
            aPrices := oArtikel:GetSellPrices(Date(), cKunde)

            // Add a row for each price tier
            IF Len(aPrices) > 0 .AND. aPrices[1,2] > 0
               IF aku->(dbSeek(cKunde+Str(art->Artikelnr,6)))
                  cKuArt := Trim(aku->Matchcode)
               ELSE
                  cKuArt := ""
               ENDIF

               hRow := Array(Len(aData[1]))
               hRow[1] := "#"+LTrim(Str(art->Artikelnr,6))
               hRow[2] := Trim(art->Matchcode)
               hRow[3] := art->LZ
               hRow[4] := cKuArt
               hRow[5] := Trim(art->Me)
                  
               FOR nX := 1 TO Len(aPrices)
                  nP := AScan(aData[1],{|x| ValType(x) == "N" .AND. x == aPrices[nX,1] })
                  IF nP == 0
                     nP := AScan(aData[1],{|x| ValType(x) == "N" .AND. x > aPrices[nX,1] })
                     IF nP != 0
                        HB_AINS(aData[1], nP, aPrices[nX,1], .T.)
                        //extend all existing rows
                        FOR nY := 2 TO Len(aData)
                           HB_AINS(aData[nY], nP, "", .T.)
                        NEXT
                     ELSE
                        Aadd(aData[1], aPrices[nX,1])
                        nP := Len(aData[1])
                     ENDIF
                     HB_Ains(hRow,nP,0,.T.) //extend row
                  ENDIF
                  hRow[nP] := Round(aPrices[nX,2] * Currate(cCurrency,"V"),2)
               NEXT
               nCount++
               Aadd(aData, hRow)
            ELSE
               // No price tiers, add basic info only
               /*aRow := { ;
                  Trim(cKunde), ;
                  art->Artikelnr, ;
                  Trim(art->Matchcode), ;
                  Trim(aku->Matchcode), ;
                  0, ;
                  0, ;
                  Trim(art->Me) ;
               }

               Aadd(aData, aRow)
               nCount++*/
            ENDIF
         ENDIF

         art->(dbSkip())
      ENDDO
   NEXT

   // Close tables
   aku->(dbCloseArea())
   art->(dbCloseArea())
   ku->(dbCloseArea())

   // Check if we have data
   IF nCount == 0
      TxtClear()
      Tr_MsgBox("Keine Artikel fÅr Kunde " + Trim(cKunde) + " gefunden!")
      RETURN NIL
   ENDIF

   // Export to XLSX
   IF SaveToOO(cFile, hData, , "XLSX", .F.)
      TxtClear()
      Tr_MsgBox({"Preisliste exportiert: " + cFile, ;
                "Anzahl Positionen: " + Ltrim(Str(nCount))})
   ELSE
      TxtClear()
      Tr_MsgBox("Fehler beim Speichern der Datei!")
      RETURN NIL
   ENDIF

RETURN cFile



