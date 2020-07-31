/*PROC RUN_test_oo
   CLS
   ? ValToPrg(RUN_GetCostFromOO(RUN_GetCostFileName("KS17535/58.0059.3800.00")))
   Sinkey(0)*/

FUNCTION RUN_GetCostFileName(nArtnr,nNo)   
   LOCAL cPath := "\\EK-SERVER4\Data\Dokumente und Einstellungen\All Users\Dokumente\Kalkulationen\" 
   LOCAL aDirs := Directory(cPath+Ltrim(Str(nArtnr))+"*.ods")
   Default(@nNo,1)
   IF Len(aDirs) >= nNo
      RETURN cPath+aDirs[nNo,1]
   ENDIF
RETURN ""


FUNCTION RUN_GetCostFromOO(nArtnr,nMaxAge)
   LOCAL oOO,oDesk
   LOCAL aProps,oDoc,oSheets
   LOCAL oSheet,oCell
   LOCAL lCost,nQtyRow,nCostRow
   LOCAL nR,cVal,nC,nQty,nVal
   LOCAL aPrices := {"ERROR"=>0,"ERRORTEXT"=>"","DATA"=>{}}
   LOCAL cFile := RUN_GetCostFileName(nArtnr)
   LOCAL nFile := 1

   Default(@nMaxAge,999)

   IF Empty(cFile) .OR. ! File(cFile)
      RETURN {"ERROR"=>-1,"ERRORTEXT"=>"FILE NOT FOUND"}
   ENDIF

   DO WHILE ! Empty(cFile)
      oOO := CreateObject("com.sun.star.ServiceManager")
      oDesk := oOO:createInstance("com.sun.star.frame.Desktop")
      aProps := {}
      Aadd(aProps,OOProperty(oOO,"ReadOnly",.T.))
      Aadd(aProps,OOProperty(oOO,"Hidden",.T.))


      oDoc := oDesk:loadComponentFromURL("file:\\\"+cFile, "_blank", 0,aProps)
      
      
      oSheets := oDoc:getSheets()
      //aNames := oSheets:getElementNames()
      
      oSheet := oSheets:getByIndex(0)
      
      lCost := .F.
      nQtyRow := 0
      nCostRow := 0
      
      FOR nR := 1 To 100 //look in the first x rows
         oCell := oSheet:getCellByPosition(0,nR)
         cVal := Upper(Trim(oCell:getFormula()))

         IF !lCost .AND. cVal  == "GESAMTKOSTEN"
            lCost := .T.
         ELSEIF lCost
            IF nQtyRow == 0 .AND. cVal == "MENGE"
               nQtyRow := nR
            ELSEIF cVal == "GESAMTKOSTEN"
               nCostRow := nR
               EXIT
            ENDIF
         ENDIF
      NEXT
      
      
      IF nCostRow != 0 .AND. nQtyRow != 0
         FOR nC := 1 TO 20 //look for column 1 to xx
            oCell := oSheet:getCellByPosition(nC,nQtyRow)
            nQty := oCell:getValue()
            oCell := oSheet:getCellByPosition(nC,nCostRow)
            nVal := oCell:getValue()      
            IF nQty != 0 .AND. nVal != 0
               Aadd(aPrices["DATA"],{"QTY"=>nQty,"COST"=>nVal})
            ENDIF
         NEXT
      ELSE
         aPrices["ERROR"] := -2
         aPrices["ERRORTEXT"] := "NO COST FIELD FOUND"
      ENDIF

      oDoc:close(.F.)
      cFile := RUN_GetCostFileName(nArtnr,++nFile)
   ENDDO
RETURN aPrices

#include 'X:\run\oo.prg'

