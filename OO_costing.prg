PROC RUN_test_oo   
   RUN_export_calc()
   //? ValToPrg(RUN_GetCostFromOO(18331))
   //? ValToPrg(RUN_GetCostFromOO(18331,.F.))
   Sinkey(0)

PROC RUN_export_calc
      LOCAL aDirs := Directory("\\EK-SERVER4\Data\Dokumente und Einstellungen\All Users\Dokumente\Kalkulationen\" +"*.ods")
      LOCAL nArtnr,nX,aAlt,aUpd,nY
      LOCAL aData := {{"Artikel","Matchcode","Menge","Kosten","Kosten akt.","D/S Kosten","EK","VK","VK akt."}}
      LOCAL oArt
      NetUse("artikel","art")
      art->(dbSetOrder( 2 ))
      CLS
      FOR nX := 1 TO Len(aDirs)
         ? Left(aDirs[nX,1],AT("_",aDirs[nX,1])-1)
         nArtnr := Val(Left(aDirs[nX,1],AT("_",aDirs[nX,1])-1))
         art->(dbSetOrder( 2 ))
         IF art->(dbSeek( Str(nArtnr,6) ))
            aAlt := RUN_GetCostFromOO(nArtnr,.F.)         
            ? art->Matchcode
            oArt := Artikel():New(.F.)
            //oArt:Load(art->Artikelnr)
            IF Len(aAlt["DATA"]) >= 1
               aUpd := RUN_GetCostFromOO(nArtnr,.T.)//updated currency            
               FOR nY := 1 TO Len(aAlt["DATA"])
                  ? oArt:Matchcode,aAlt["DATA",nY,"QTY"],aAlt["DATA",nY,"COST"],aUpd["DATA",nY,"COST"],aAlt["DATA",nY,"PRICE"],aUpd["DATA",nY,"PRICE"]
                  Aadd(aData,{nArtnr,Trim(art->Matchcode),aAlt["DATA",nY,"QTY"],aAlt["DATA",nY,"COST"],aUpd["DATA",nY,"COST"],oArt:GetAvgBuyPrice(),oArt:GetBuyPriceForMargin(aAlt["DATA",nY,"QTY"],.T.,Date(),CWeek(Date())),aAlt["DATA",nY,"PRICE"],aUpd["DATA",nY,"PRICE"]})
               NEXT         
            ELSEIF aAlt["ERROR"] != 0
               ? aAlt["ERRORTEXT"]
               Aadd(aData,{nArtnr,Trim(art->Matchcode),,,,,,aAlt["ERRORTEXT"]})
            ELSE
               ? ValToPrg(aAlt)
               Aadd(aData,{nArtnr,Trim(art->Matchcode),,,,,,"Unbekannter Fehler"})
            ENDIF
         ELSE
            Aadd(aData,{nArtnr,,,,,,,"Artikel nicht gefunden"})
         ENDIF
      NEXT
      SaveAsCsv("\\EK-Server4\data\Dokumente und Einstellungen\Amos\Documents\Vertrieb\kalkulationspreise.csv",aData)
   
FUNCTION RUN_GetCostFileName(nArtnr,nNo)   
   LOCAL cPath := "\\EK-SERVER4\Data\Dokumente und Einstellungen\All Users\Dokumente\Kalkulationen\" 
   LOCAL aDirs := Directory(cPath+Ltrim(Str(nArtnr))+"*.ods")
   Default(@nNo,1)
   IF Len(aDirs) >= nNo
      RETURN cPath+aDirs[nNo,1]
   ENDIF
RETURN ""


FUNCTION RUN_GetCostFromOO(nArtnr,lUpdateCur)
   LOCAL oOO,oDesk
   LOCAL aProps,oDoc,oSheets
   LOCAL oSheet,oCell
   LOCAL lCost,nQtyRow,nCostRow,nPriceRow,nPrice
   LOCAL nR,cVal,nC,nQty,nVal
   LOCAL aPrices := {"ERROR"=>0,"ERRORTEXT"=>"","MSGTEXT"=>"","DATA"=>{}}
   LOCAL cFile := RUN_GetCostFileName(nArtnr)
   LOCAL nFile := 1
   LOCAL nCurCol,nExCol 
   LOCAL lHead,cCur,nCurRow,cSheet
  
   Default(@lUpdateCur,.T.)

   IF Empty(cFile) .OR. ! File(cFile)
      RETURN {"ERROR"=>1,"ERRORTEXT"=>"FILE NOT FOUND"}
   ENDIF

   NetUse("currency","cur")
   cur->(dbSetOrder( 2 )) //symbol

   DO WHILE ! Empty(cFile)
      oOO := CreateObject("com.sun.star.ServiceManager")
      oDesk := oOO:createInstance("com.sun.star.frame.Desktop")
      aProps := {}
      Aadd(aProps,OOProperty(oOO,"ReadOnly",.T.))
      Aadd(aProps,OOProperty(oOO,"Hidden",.T.))


      oDoc := oDesk:loadComponentFromURL("file:\\\"+cFile, "_blank", 0,aProps)
      
      
      oSheets := oDoc:getSheets()
      //aNames := oSheets:getElementNames()

      /**
      Update currency of the "Beistellware" and "Vorleistung"
      **/
      IF lUpdateCur
         FOR EACH cSheet IN {"Beistellware","Vorleistung"}
            IF ! oSheets:hasByName(cSheet) //Sheet not found output message
               IF ! Empty(aPrices["MSGTEXT"]); aPrices["MSGTEXT"] += ";"; ENDIF
               aPrices["MSGTEXT"] += "SHEET '"+cSheet+"' NOT FOUND"
            ELSE
               oSheet := oSheets:getByName(cSheet)
               //look for the header and the columns
               FOR nR := 1 To 100 //look in the first x rows
                  IF nCurCol == NIL
                     oCell := oSheet:getCellByPosition(0,nR)
                     cVal := Upper(Trim(oCell:getFormula()))            
                     IF cVal == "ARTIKEL"  //this might be the header row, move right and look for the columns
                        lHead := .F. //might only be the header, still need to find the second column
                        FOR nC := 1 TO 10 //look in the first 20 columns
                           oCell := oSheet:getCellByPosition(nC,nR)
                           cVal := Upper(Trim(oCell:getFormula()))                                    
                           IF ! lHead .AND. cVal == "ANZAHL" //Yes this is the header
                              lHead := .T.                    
                           ELSEIF ! lHead //Not the header, exit the search
                              EXIT
                           ELSEIF cVal == "W„HRUNG"
                              nCurCol := nC
                           ELSEIF cVal == "KURS"
                              nExCol := nC
                           ENDIF
                           IF nCurCol != NIL .AND. nExCol != NIL //we have found both columns
                              EXIT
                           ENDIF
                        NEXT               
                     ENDIF
                  ELSE
                     oCell := oSheet:getCellByPosition(nCurCol,nR)
                     cCur  := Upper(Trim(oCell:getFormula()))
                     IF ! Empty(cCur)               
                        oCell := oSheet:getCellByPosition(nExCol,nR)               
                        IF cur->(dbSeek( cCur ))                  
                           oCell:setFormula(1/Currate(cur->Code,"E")) //update the exchange rate
                        ENDIF
                     ENDIF
                  ENDIF               
               NEXT   
            ENDIF
         NEXT
      ENDIF
      
      /**
      Look for cost and update currency of the work
      **/
      oSheet := oSheets:getByIndex(0)
      
      lCost := .F.
      nQtyRow := 0
      nCostRow := 0
      nCurRow := 0
      
      FOR nR := 1 To 100 //look in the first x rows
         oCell := oSheet:getCellByPosition(0,nR)
         cVal := Upper(Trim(oCell:getFormula()))

         IF !lCost .AND. cVal  == "GESAMTKOSTEN"
            lCost := .T.
         ELSEIF lUpdateCur .AND. cVal == "W„HRUNG"
            nCurRow := nR
            oCell := oSheet:getCellByPosition(1,nR) //get the next right column
            cCur := Upper(Trim(oCell:getFormula()))
         ELSEIF lUpdateCur .AND. nCurRow != 0 .AND. cVal == "KURS"  //this is the exchange rate row matching the currency we found before
            IF cur->(dbSeek( cCur ))                 
               oCell := oSheet:getCellByPosition(1,nR) //get the next right column               
               oCell:setFormula(1/Currate(cur->Code,"E")) //update the exchange rate
            ENDIF
         ELSEIF lCost
            IF nQtyRow == 0 .AND. cVal == "MENGE"
               nQtyRow := nR
            ELSEIF cVal == "GESAMTKOSTEN"
               nCostRow := nR
            ELSEIF cVal == "VK"
               nPriceRow := nR
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
            oCell := oSheet:getCellByPosition(nC,nPriceRow)
            nPrice := oCell:getValue()      
            IF nQty != 0 .AND. nVal != 0
               Aadd(aPrices["DATA"],{"QTY"=>nQty,"COST"=>nVal,"PRICE"=>nPrice})
            ENDIF
         NEXT
         IF Len(aPrices["DATA"]) == 0
            aPrices["ERROR"] := 4
            aPrices["ERRORTEXT"] := "NO PRICES OR QUANTITIES FOUND"   
         ENDIF
      ELSEIF nQtyRow == 0
         aPrices["ERROR"] := 3
         aPrices["ERRORTEXT"] := "NO QUANTITY FIELD FOUND"
      ELSE
         aPrices["ERROR"] := 2
         aPrices["ERRORTEXT"] := "NO COST FIELD FOUND"
      ENDIF
      

      oDoc:close(.F.)
      cFile := RUN_GetCostFileName(nArtnr,++nFile)
   ENDDO
RETURN aPrices

#include 'X:\run\oo.prg'

