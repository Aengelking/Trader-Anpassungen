#define CL Chr(13)+Chr(10)
FUNCTION Stock_Supplier(lShowStock)
   LOCAL cLief := Space(8)
   LOCAL hArtikel := {=>}
   LOCAL getlist := {},aCSV,hData,cFileName
   LOCAL cMatchField,cStockField,cInProdField
   LOCAL bNewEntry
   LOCAL lUnusedAsMat := .F.
   LOCAL lFinished := .T.

   Default(@lShowStock,.T.)

   Head(t("Bestände bei einem Lieferanten"))

   NetUse("artikel","art",.F.,0)
   NetUse("werkauf","wer",.F.,0)
   //NetUse("engabg","abg")
   //NetUse("engbes","bes")
   NetUse("artlief","ali")
   NetUse("engabg","abg",.F.,0)
   NetUse("werks","we")

   NetUse("artlief","ali")

   NetUse("lager","lag")
   NetUse("lagerort","lago")
   NetUse("engkund","ku")


   @ 01,00 SAY "Lieferant            " GET cLief PICTURE "@!" VALID FindAd(cLief,"L",01,30)
   @ 02,00 SAY "Fertigartikel listen " GET lFinished PICTURE "Y"
   IF lShowStock
      @ 03,00 SAY "Unfertig als Material" GET lUnusedAsMat PICTURE "Y"
   ENDIF
   READ

   IF LastKey() == 27
      RETURN NIL
   ENDIF

   IF ku->Language == "D"
      cMatchField := "Artikel"
      cStockField := "Bestand"
      cInProdField := "Unfertig"
   ELSE
      cMatchField := "Part"
      cStockField := "Stock"
      cInProdField := "In production"
   ENDIF      

   bNewEntry := {||
      hArtikel[art->Artikelnr] := {=>}
      hArtikel[art->Artikelnr]["MATCHCODE"] := art->Matchcode      
      hArtikel[art->Artikelnr]["STOCK"] := 0
      hArtikel[art->Artikelnr]["INPROD"] := 0
      RETURN NIL
   }


   lago->(dbSetOrder( 3 ))
   art->(dbSetOrder( 2 ))
   lag->(dbSetOrder( 2 ))

   lago->(dbSeek( Str(ku->Nummer,6) ))

   DO WHILE ! lago->(EOF()) .AND. lago->Address == ku->Nummer
      
      lag->(dbSeek( lago->Lagerort ))

      DO WHILE lag->Lagerort == lago->Lagerort
         
         @ 25,00 SAY lag->Lagerort

         IF ! HHasKey(hArtikel,lag->Artikelnr)
            @ 24,00 SAY art->Matchcode

            art->(dbSeek( Str(lag->Artikelnr,6) ))         
            Eval(bNewEntry)
         ENDIF
         IF lShowStock
            hArtikel[lag->Artikelnr]["STOCK"] += lag->Lagermenge
         ENDIF

         lag->(dbSkip())
      ENDDO

      lago->(dbSkip())
   ENDDO

   wer->(dbSetOrder( 7 ))
   wer->(dbSetFilter( {|| wer->Status == 3 },"status == 3"))
   wer->(dbSeek( cLief ))

   DO WHILE ! wer->(Eof()) .AND. wer->Liefma == cLief
      
      art->(dbSetOrder(2))         

      IF lFinished
         art->(dbSeek(Str(wer->artno,6)))
         IF ! HHasKey(hArtikel,wer->artno)               
            Eval(bNewEntry)               
         ENDIF
         IF lShowStock .AND. ! lUnusedAsMat
            hArtikel[art->Artikelnr]["INPROD"] += wer->Qty-wer->gelqty            
         ENDIF
      ENDIF

      we->(dbSeek( Str(wer->Aufno,6) ))

      //add all sub parts to the list with 0 (for couting purposes)
      DO WHILE we->Aufno == wer->Aufno .AND. ! we->(EOF())
         IF ! HHasKey(hArtikel,we->partart)
            art->(dbSeek( Str(we->partart,6) ))         
            Eval(bNewEntry)               
         ENDIF
         IF lUnusedAsMat
            hArtikel[we->partart]["INPROD"] += we->BookQty
         ENDIF   
         we->(dbSkip())
      ENDDO
      
      wer->(dbSkip())
   Enddo
   wer->(dbClearFilter())

   aCSV := {{cMatchField,cStockField,cInProdField}}
   
   FOR EACH hData IN hArtikel
      IF lShowStock
         Aadd(aCSV,{hData:Matchcode,hData:Stock,hData:InProd})
      ELSE
         Aadd(aCSV,{hData:Matchcode,"",""})
      ENDIF
   NEXT
   
   cFileName := Wvt_GetSaveFileName( 0,Trim(cLief)+"_inventory_count_"+Str(Year(Date()),4)+".xlsx" , "XLSX Datei", { {"Excel Spreadsheet (*.xlsx)","*.xlsx"},{"Alle Dateien (*.*)","*.*"} } )
   SaveToOO(cFileName,aCSV,,"XLSX",.T.)

   //SaveAsCSVInterface(aCSV)
   //WAPI_ShellExecute(,cProtokoll,"OPEN")

#include "x:\run\savetooo.prg"
