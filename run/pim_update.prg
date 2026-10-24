FUNCTION RUN_PIM_upDATE
   //LOCAL cFile := "\\EK-Server4\data\Dokumente und Einstellungen\Amos\Documents\PIM\Umsetzung\Daten_Engelking_DRUPAL_Trader_ce_varianten.xlsx"
   //LOCAL cFile := "\\EK-Server4\data\Dokumente und Einstellungen\samuel\Documents\Website\PIM\Drucktaster Neu.ods"
   LOCAL cFile := "\\EK-Server4\data\Dokumente und Einstellungen\Amos\Documents\PIM\Umsetzung\test.ods"
   LOCAL oOO,oDesk,aProps,oDoc,oSheets,oSheet
   LOCAL nC,cName,nCols,nMatchCol,nRows,nR,nX
   LOCAL aKnownVar := {}
   LOCAL hVarBase := {=>},oBase,oCell
   LOCAL nLen
   LOCAL cFilter,cMatch
   LOCAL hMap2 := {=>}
   LOCAL nCount := 0  , nCount2,nPr
   LOCAL hMap := {;
      "Schalterart"=>"Wippenform",;
      "Anschlussart"=>{"Anschlussart", "Terminals", "Termination", "Anschlsse", "Kabeleingang & Pin typ", "Anschluss"},;
      "Ausgang"=>"Eingang/Ausgang",;
      "Bet„tiger"=>"Actuator Type",;
      "Eingang"=>{"Eingang/Ausgang", "Eingang"},;
      "Farbe"=>"Farbe",;
      "Filter"=>"Filter",;
      "Geeignet fr"=>"Schaltertyp",;
      "Indikatorfarbe"=>"LED-Farbe",;
      "Kabelverschraubung"=>"Kabelverschraubung",;
      "Kodierung"=>{"Typ/Kodierung", "Codierung"},;
      "Konfiguration Seite 2"=>{"Geh„use 2 Seite", "Seite 2"},;
      "L„nge"=>"L„nge",;
      "LED Farbe"=>{"LED-Farbe", "Beleuchtungsfarbe"},;
      "Material"=>{"Material", "Kabeltyp", "Version", "Steckermaterial", "Kabelmaterial" },;
      "Montageart"=>{"Montage", "Geh„use"},;
      "Plattendicke"=>"Plattendicke",;
      "Polzahl"=>{"Polzahl", "Poles", "Typ/Anzahl Kontakte"} ,;
      "Schaltfunktion"=>{"Schaltfunktion", "Switch Function"},;
      "Vorwiderstand"=>{"LED-Spannung", "Beleuchtungsspannung"},;
      "Anzeigeelemente Serie"=>{"Serie", "Series"},;
      "Beleuchtung"=>{"LED-Typ", "Beleuchtung"},;
      "Beleuchtungsart"=>"Beleuchtungsart",;
      "Max Strom"=>"Bemessungsstrom Filter",;
      "Schalterfarbe"=>"Wippenfarbe",;
      "Beschriftung"=>{"Beschriftung","Bedruckung"},;
      "Geh„usefarbe"=>"Geh„usefarbe",;
      "Optionen"=>{"Optionen", "Options"},;
      "Geh„usetyp"=>{"Geh„usetyp","Body Type"},;
      "Schaltfunktion 1 Wippe"=>"Schaltfunktion 1 Wippe",;
      "Wippenform 1 Wippe"=>"Wippenform 1 Wippe",;
      "Wippenfarbe 1 Wippe"=>"Wippenfarbe 1 Wippe",;
      "Bedruckung 1 Wippe"=>"Bedruckung 1 Wippe",;
      "Beleuchtungsart 1 Wippe"=>"Beleuchtungsart 1 Wippe",;
      "Schaltfunktion 2 Wippe"=>"Schaltfunktion 2 Wippe",;
      "Wippenform 2 Wippe"=>"Wippenform 2 Wippe",;
      "Wippenfarbe 2 Wippe"=>"Wippenfarbe 2 Wippe",;
      "Bedruckung 2 Wippe"=>"Bedruckung 2 Wippe",;
      "Beleuchtungsart 2 Wippe"=>"Beleuchtungsart 2 Wippe",;
      "Flansch Typ"=>"Flansch Typ",;
      "L/C Schaltung Filter"=>"L/C Schaltung Filter",;
      "Weitere Kombinationen"=>"Weitere Kombinationen",;
      "Weitere Komponenten"=>"Weitere Komponenten",;
      "Tasfl„chentyp"=>"Tasfl„chentyp",;
      "Geh„useform"=>"Geh„useform",;
      "Bet„tiger Typ"=>{"Bet„tiger Typ","Head Type", "Tastentyp", "Tastfl„chentyp", "Tastknopf" },;
      "Ausrichtung"=>"Ausrichtung",;
      "Ausgang"=>"Ausgang",;
      "Steckertyp"=>{"Steckertyp","Geschlecht"},;
      "Seite 1"=>"Seite 1",;
      "Kabel"=>"Kabel",;
      "Verpackung"=>"Verpackung",;
      "Gr”áe"=>"Gr”áe";
   }

   //Duplicates
   //"Kabelaufnahme"=>"Kabeleingang & Pin typ",;
   //"Geh„usematerial"=>"Material",;
   //"Schnittstelle"=>"Typ/Anzahl Kontakte",;



   Head("Update PIM xlsx file")


   cFile := Wvt_GetOpenFileName( 0,"" , "Spreadsheet", { {"OpenDocument SpreadSheet (*.ods)","*.ods"},{"Microsoft Excel (*.xls)","*.ods"},{"Alle Dateien (*.*)","*.*"} }, , "" )

   IF Empty(cFile)
      RETURN .T.
   ENDIF
   

   NetUse("artikel","art")
   cFilter := 'variant =="B" .AND. ! obsolete'
   art->(dbSetFilter({|| art->(&(cFilter)) },cFilter))
   art->(dbGoTop())
   @ 01,00 SAY "Varianten werden eingelesen..."
   DO WHILE ! art->(EOF())
      @ 01,32 SAY art->Matchcode
      Aadd(aKnownVar,Trim(art->Matchcode))
      art->(dbSkip())
   ENDDO
   ASort(aKnownVar,,,{|x,y| Len(x) > Len(y) })

   @ 02,00 SAY "Tabelle wird ge”ffnet..."
   oOO := CreateObject("com.sun.star.ServiceManager")
   oDesk := oOO:createInstance("com.sun.star.frame.Desktop")
   IF oDesk == NIL
      Tr_MsgBox(t("OpenOffice konnte nicht geöffnet werden"))
      RETURN .F.
   ENDIF
   aProps := {}  
   //Aadd(aProps,OOProperty(oOO,"Hidden",.T.)) //this will hide the window, so the save happens in the background

   oDoc := oDesk:loadComponentFromURL("file:\\\"+cFile, "_blank", 0,aProps)  //create new document
   oSheets := oDoc:getSheets()
   oSheet := oSheets:getByIndex(0)

   @ 02,32 SAY "abgeschlossen"

   //number of columns and rows
   nCols := oSheet:getColumns():getCount()
   nRows := oSheet:getRows():getCount()

   @ 03,00 SAY "Tabellenk”pfe werden gelesen..."

   nPr := 5

   //first we get the names from the first row and check them against the map
   FOR nC := 0 TO nCols 
      cName := oSheet:getCellByPosition(nC,0):getFormula()
      IF Empty(cName)
         EXIT
      ENDIF
      @ 03,32 CLEAR
      @ 03,32 SAY cName
      IF Trim(cName) == "ANR"
         nMatchCol := nC
      ELSEIF HHasKey(hMap,Trim(cName))         
         IF ValType(hMap[Trim(cName)]) == "C"
            IF HHasKey(hMap2,hMap[Trim(cName)])
               Alert("ERROR: Dupplicate option association: "+hMap[Trim(cName)])
            ELSE
               hMap2[hMap[Trim(cName)]] := nC
            ENDIF
         ELSE
            FOR nX := 1 TO Len(hMap[Trim(cName)])
               IF HHasKey(hMap2,hMap[Trim(cName),nX])
                  Alert("ERROR: Dupplicate option association: "+hMap[Trim(cName),nX])
               ELSE
                  hMap2[hMap[Trim(cName),nX]] := nC
               ENDIF
            NEXT
         ENDIF
      ENDIF
   NEXT

   @ 04,00 SAY "Daten werden bearbeitet..."

   FOR nR := 1 TO nRows
      cMatch := oSheet:getCellByPosition(nMatchCol,nR):getFormula()
      IF Empty(cMatch)
         EXIT
      ENDIF
      nCount2 := 0
      //? cMatch
      
      FOR nX := 1 TO Len(aKnownVar)
         IF AT(aKnownVar[nX],cMatch) == 1
            @ 04,32 SAY Pad(cMatch,25)
            //@ 05,00 CLEAR
            IF ! HHasKey(hVarBase,aKnownVar[nX])
               oBase := OptionBase():New()
               oBase:Load( aKnownVar[nX] )
               hVarBase[aKnownVar[nX]] := oBase
            ELSE
               oBase := hVarBase[aKnownVar[nX]]
            ENDIF
            nLen := Len(Trim(oBase:Model))+1
            oBase:oTables:Each({|oTable|
               LOCAL oKey
               oKey := oTable:oKeys:GetRecord(SubStr( cMatch,nLen,oTable:Length ))               
               IF oKey != NIL                   
                  nLen += oTable:Length //this will not work if the key has been stripped as it is blank!
                  IF HHasKey(hMap2,Trim(oTable:Funktion("DE")))                     
                     oCell := oSheet:getCellByPosition(hMap2[Trim(oTable:Funktion("DE"))],nR)                     
                     IF Trim(oKey:descript("DE")) != oCell:getFormula()
                        //? oTable:funktion("DE")+":"+oKey:descript("DE")+" | "+oCell:getFormula()
                        oCell:setFormula(Trim(oKey:descript("DE")))
                        nCount++
                        nCount2++
                     ENDIF
                  ENDIF
               ENDIF
               RETURN NIL
            })
         ENDIF
      NEXT
      //IF nCount2 != 0
         /*IF nPr >= MaxRow()
            Scroll(05,00,MaxRow(),MaxCol(),1)
            nPr := MaxRow()-1
         ENDIF
         SetPos(nPr++,00)*/
        // ? nPr,cMatch,nCount2,"atrributes updated"
      //ENDIF
      IF Inkey() == 27
         EXIT
      ENDIF
   NEXT
   @ MaxRow(),00 SAY LTrim(Str(nCount))+" Werte aktualisiert"
   

   //oDoc:close(.F.)

   Sinkey(0)
RETURN NIL

FUNCTION OOProperty( oServiceManager, cName, uValue )
   LOCAL cStructure
   LOCAL oProperty

   cStructure := "com.sun.star.beans.PropertyValue"

   oProperty := oServiceManager:bridge_GetStruct( cStructure )
   oProperty:Name := cName
   oProperty:Value := uValue
RETURN oProperty