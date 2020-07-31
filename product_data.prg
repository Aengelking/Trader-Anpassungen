#include 'y:\hb32\include\hbmxml.ch'
PROCEDURE ProductDataXML

/******** SETTINGS ********/
LOCAL nQtyNoStock := 1000  //Menge die bei Artikeln angegeben wird die nicht auf Lager sind
LOCAL nMaxLZ      := 6     //Max Lieferzeit in Wochen
//LOCAL cFTPUrl     := "sftp://24982-conrad:H7f2e6ardK(z@ftp.engelking.de/"
LOCAL cFTPUrl     := "sftp://24982-conrad:H7f2e6ardK(z@ftp.engelking-elektronik.de/"
//LOCAL cFTPHostKey := "ssh-rsa 2048 SopeNvOCO4EQRUXtLfArGX5IgtALtD7g2DVw5YqMwPc="
LOCAL cFTPHostKey := "ssh-rsa 2048 aKuZdTEQ9+UBaEwamAfdNkFL3Ab1rTyldK1vfEjdMs4="
LOCAL cSCPDir     := "C:\Program Files (x86)\WinSCP\"

/*************************/
LOCAL cBrand := "Engelking"
//LOCAL cBrand := "Bulgin"
//LOCAL cBrand := "ITW Switches"
LOCAL cCat   := "Drucktaster"
&&LOCAL cCat   := "All"
LOCAL cDir   := "Y:\Dokumente und Einstellungen\Amos\Documents\ProductData\"
//export this file from Drupal at http://dev2.engelking.de/products_download (url can be built via http://dev2.engelking.de/products)
LOCAL cFile := cDir+"products-type_"+cCat+"-name_"+cBrand+".xml"
LOCAL oXML := TXMLDocument():New(cFile)
LOCAL oIter := TXmlIteratorScan():New(oXml:oRoot)
LOCAL oIter2,oNode,oHtml,oTable,oTD,oTR
LOCAL oNode2
LOCAL oDesc,cText,oText
LOCAL aFeatures
LOCAL hAttributes,aAttributes,cAtt,aAtt
LOCAL aData := {{}},hData
LOCAL aPriceData := {{}},hPriceData
LOCAL cMatch,cTitle,aImages,cImage,oImg
LOCAL cImageData,bConvImage
LOCAL oArtikel,aPrices,nX
LOCAL nCurWeek := CWeek(Date())
LOCAL aAvail,nStock
LOCAL aParts := {}
LOCAL lArtFound,nArtLZ,nLZ,aMatches,bAddQuote,lQuit,hExtra,nEx

LOCAL nH,nH2
LOCAL cPDFile := Path("export\conrad\pd_"+Lower(cCat)+"_"+cBrand+".csv")
LOCAL cQuoteFile := Path("export\conrad\quote_"+Lower(cCat)+"_"+cBrand+".csv")
LOCAL nMwSt

Taxit(1,@nMwSt,Date())
nMwSt := 1+nMwSt/100

NetUse("artikel","art")
DO WHILE (nH := FCreate(cPDFile,0)) == -1
   IF Tr_MsgBox("Datei konnte nicht erstellt werden (ERROR: "+LTrim(Str(FError()))+")",,{"erneut versuchen","abbrechen"}) == 2
      RETURN
   ENDIF
ENDDO
DO WHILE (nH2 := FCreate(cQuoteFile,0)) == -1
   IF Tr_MsgBox("Datei konnte nicht erstellt werden (ERROR: "+LTrim(Str(FError()))+")",,{"erneut versuchen","abbrechen"}) == 2
      RETURN
   ENDIF
ENDDO

bAddQuote := {|cSku,lArtFound,cProdIdType|
   nArtLZ := IF(art->LZ==0,12,art->LZ)

   hPriceData["product-id"] := cSku
   hPriceData["product-id-type"] := cProdIdType
   hPriceData["leadtime-to-ship"] := (nArtLZ+1)*5  //lieferzeit in werktagen                     
   hPriceData["state"] := 11 //"Neu"
   hPriceData["reversecharge"] := "false"

   oArtikel := Artikel():New()
   oArtikel:Load(art->Artikelnr)
   aPrices := oArtikel:GetSellPrices(Date())
   IF Len(aPrices) >= 1 .AND. aPrices[1,2] != 0  //nur Artikel mit Preisen werden hinzugefÅgt

      hPriceData["price"] :=  aPrices[1,2]*nMwSt //Preis fÅr ein StÅck
      hPriceData["min-order-quantity"] := Max(1,aPrices[1,1]) //Mindestbestellmenge auf die erste Staffel setzten

      hPriceData["discount-ranges"] := ""
      FOR nX := 2 TO Len(aPrices)
         IF aPrices[nX,1] <= 1000 //we do not display prices for qty's greater than 1000pcs
            IF nX > 2
               hPriceData["discount-ranges"] += ","
            ENDIF   
            hPriceData["discount-ranges"] += LTrim(Str(aPrices[nX,1],12,0))+"|"+lTrim(Str(aPrices[nX,2]*nMwSt))
         ENDIF
      NEXT
   
      IF lArtFound
         aAvail := GetKwQty(art->Artikelnr)
         
         nStock := GetKwStock(art->Artikelnr,AddWeeks(nCurWeek,nArtLZ+1),aAvail) //VerfÅgbarer Lagerbestand. Wir verwenden die Menge die nach der LZ noch verfÅgbar wÑre
         hPriceData["sku"] := LTrim(Str(art->Artikelnr,6))+"S"
         IF art->Bestand > 0 .AND. nStock > 0 //Lagerbestand                                                      
            hPriceData["quantity"] := Val(Transform(Min(nStock,art->Bestand),Me(art->Me)))
            IF hPriceData["min-order-quantity"] > hPriceData["quantity"]
               hPriceData["min-order-quantity"] := Max(1,hPriceData["quantity"])
            ENDIF
            hPriceData["leadtime-to-ship"] := 1
            AddHash(aPriceData,hPriceData)
         ELSE
            hPriceData["quantity"] := 0
            hPriceData["leadtime-to-ship"] := 0
            hPriceData["update-delete"] := "delete"
            AddHash(aPriceData,hPriceData) //upload this, to make sure that the stock will be reset if there was any
         ENDIF

         hPriceData["sku"] := LTrim(Str(art->Artikelnr,6))+"I"
         IF nStock > art->bestand //Wir haben auch noch welche im Zulauf                              
            hPriceData["quantity"] := nStock-art->Bestand
            nLZ := WeeksBetween(nCurWeek,GetAvailKw( art->Artikelnr, nStock, aAvail )) //Lieferzeit in Wochen                           
            IF nLz <= nMaxLZ .AND. nLZ < nArtLZ //nur hinzufÅgen wenn innerhalb der max. erlaubten Lieferzeit und kleiner als die Standardlieferzeit
               hPriceData["leadtime-to-ship"] := Max(1,nLZ*5) //LZ in Tagen, mindestens 1
               AddHash(aPriceData,hPriceData)
            ENDIF
         ELSE
            hPriceData["quantity"] := 0
            hPriceData["leadtime-to-ship"] := 0
            hPriceData["update-delete"] := "delete"
            AddHash(aPriceData,hPriceData) //upload this, to make sure that the stock will be reset if there was any
         ENDIF
      ENDIF

      IF nArtLZ+1 <= nMaxLZ //die Standardlieferzeit auf diesem Artikel ist geringer als die Maximal erlaubte                            
         hPriceData["sku"] := LTrim(Str(art->Artikelnr,6))+"P"
         IF ! lArtFound
            aMatches := HB_Regex("\/(06|24)\/",cMatch)
            hPriceData["sku"] += "-"+aMatches[2]
         ENDIF                           
         hPriceData["quantity"] := nQtyNoStock
         hPriceData["leadtime-to-ship"] := (nArtLZ+1)*5                           
         AddHash(aPriceData,hPriceData)
      ENDIF          
   ENDIF
   RETURN .T.
}

CLS

oNode := oIter:Find("product")
IF ! GetConfigValue("BATCHMODE") .AND. Tr_MsgBox("Nur Zusatzdaten?",,{"Ja","Nein"}) == 1
   oNode := NIL
ENDIF
DO WHILE oNode != NIL
   oIter2 := TXmlIteratorScan():New(oNode)

   cTitle := ""
   IF (oNode2 := oIter2:Find("title")) != NIL
      cTitle := oNode2:cData
   ENDIF

   aImages := {}
   oIter2:Rewind()
   IF (oNode2 := oIter2:Find("pictures")) != NIL .AND. ValType(oNode2:cData) == "C"
      cImageData := HtmlToEntities(oNode2:cData)
      bConvImage := {|cImg| StrTran(StrTran(StrTran(cImg,"dev2.",""),"http:","https:"),Chr(13)+Chr(10),"") }
      IF AT("<div",cImageData) != 0
         oHTML := THtmlDocument():New(cImageData)
         FOR EACH oImg IN oHtml:body:findNodesByTagName("div")
            Aadd(aImages,Eval(bConvImage,oImg:getText()))
         NEXT
      ELSE
         Aadd(aImages,Eval(bConvImage,cImageData))
      ENDIF
   ENDIF
   IF Len(aImages) == 0 
      ? cTitle,"NO IMAGES"
   ELSE //mindestens ein Bild, dies ist fÅr Conrad kînnte parametrisiert werden   
      oIter2:Rewind()
      oDesc := oIter2:Find("features")
      //Alert(oDesc:cData)
      hAttributes := {=>}
      aAttributes := HB_ATokens(oDesc:cData,";")
      FOR EACH cAtt IN aAttributes
         aAtt := HB_ATokens(cAtt,":")
         IF HHasKey(hAttributes,hb_utf8tostr(aAtt[1]))
            hAttributes[hb_utf8tostr(aAtt[1])] += ", "+hb_utf8tostr(aAtt[2])
         ELSE  
            hAttributes[hb_utf8tostr(aAtt[1])] := hb_utf8tostr(aAtt[2])
         ENDIF
      NEXT
      //? ValToPrg(hAttributes)

      //Au·endurchmesser durch Einbaudurchmesser ersetzen
      IF HHasKey(hAttributes,"Einbaudurchmesser")
         cTitle := HB_RegexReplace("^\s*[0-9\,]{1,}mm",cTitle,hAttributes["Einbaudurchmesser"])
      ENDIF

      oIter2:Rewind()
      oDesc := oIter2:Find("description")

      cText := oDesc:cData
      cText := HtmlToEntities(cText)

      aFeatures := {}
      oHtml := THtmlDocument():New(cText)

      oText := THtmlDocument():New(cText)
      FOR EACH oTable IN oText:body:findNodesByTagName("table")
         oTable:Delete()
      NEXT
      cText := StrTran(StrTran(StrTran(oText:body:toString(),Chr(13)+Chr(10),""),"<body>",""),"</body>","")
      lQuit := .F.
      FOR EACH oTable IN oHtml:body:findNodesByTagName("table")
         FOR EACH oNode IN oTable:findNodesByTagName("th")
            Aadd(aFeatures,RemoveLineChars(oNode:getText()))
            
            //? Asc(SubStr(Atail(aFeatures),Len(Atail(aFeatures))))
         NEXT
         //? ValToPrg(aFeatures)
         FOR EACH oTR IN oTable:findNodesByTagName("tr")
            hData := {=>}   
            hPriceData := {=>}         
            FOR EACH oTD IN oTR:findNodesByTagName("td")
               IF oTD:__eNumIndex == 1 //aFeatures[oTD:__eNumIndex] == "Artikelnummer"
                  cMatch := RemoveLineChars(oTD:getText())               
                  hData["category"] := cCat
                  hData["EAN"] := "2146-"+cMatch
                  hData["Matchcode"] := cMatch
                  hData["Brand"] := cBrand
                  hData["ManufacturerPartNo"] := cMatch
                  hData["Unit"] := "STCK"
                  hData["QtyPerUnit"] := "1"
                  hData["UnitPerUnit"] := "STCK"
                  FOR EACH cImage IN aImages
                     hData["Image"+LTrim(Str(cImage:__eNumIndex))] := cImage
                  NEXT
                  hData["TaxIndicator"] := "Normal tax"
                  hData["RoHS"] := "Y"
                  hData["Title"] := cTitle
                  hData["Features"] := StrTran(cText,";","")
                  //hData["Features"] := ""
                  lArtFound := art->(dbSeek(cMatch))

                  IF art->Artikelnr == 4612
                     //lQuit := .T.
                  ENDIF

                  IF AScan(aParts,cMatch) == 0 .AND. (lArtFound .OR. art->(dbSeek( HB_RegexReplace("\/(06|24)\/",cMatch,"/12/") )) .OR. art->(dbSeek( HB_RegexReplace("\/(06|24)\/",cMatch,"/00/") )) .OR. art->(dbSeek( HB_RegexReplace("\/(06|24)\/",cMatch,"/06/") )))
                     Aadd(aParts,cMatch)
                     Eval(bAddQuote,hData["EAN"],lArtFound,"SHOP_SKU")
                  ELSE  //wenn der Artikel nicht angelegt ist, haben wir keine Preise, hier sollten wir uns was Åberlegen!
                     //hPriceData["leadtime-to-ship"] := 4
                     ? "Nicht gefunden: ",cMatch
                  ENDIF

               ELSE
                  IF Len(aFeatures) >= oTD:__eNumIndex //Wert ist vorhanden
                     IF HHasKey(hAttributes,aFeatures[oTD:__eNumIndex]) //Dies ist eines der Attribute, dann erstzen wir den Wert
                        hAttributes[aFeatures[oTD:__eNumIndex]] := RemoveLineChars(oTD:getText())
                     ENDIF

                     hData["Title"] += ","+RemoveLineChars(oTD:getText()) //Titel um die Bschreibung ergÑnzen, Titel nicht voranstellen ansonsten wird es zu lang

                  ENDIF
               ENDIF
            NEXT
            
            IF Len(hData) > 0
               //hData["features"]
               //? ValToPrg(hAttributes)
               AddHash(aData,hData)
            ENDIF

            IF lQuit
               EXIT
            ENDIF
         NEXT  
         IF lQuit
            EXIT
         ENDIF    
      NEXT  
   ENDIF
   oNode := oIter:Next()
   IF lQuit
      EXIT
   ENDIF
ENDDO


hExtra := {"PX0587"=>"741023","PX0842/A"=>"800112327","FX0456"=>"529655","PX0686"=>"740689"} //,"FX0457"=>"529667"}

FOR nEX := 1 TO Len(hExtra)
   art->(dbSeek( Pad(HGetKeyAt(hExtra,nEX),25)))
   hPriceData := {=>}
   Eval(bAddQuote,HGetValueAt(hExtra,nEX),.T.,"SKU")
NEXT


? "Anzahl:",Len(aData)-1

FClosE(nH)
FClose(nH2)

SaveAsCSV(cPDFile,aData,.T.)
SaveAsCSV(cQuoteFile,aPriceData,.T.)
IF GetConfigValue("BATCHMODE") .OR. Tr_MsgBox("Run upload script?",,{"Yes","No"}) == 1
   WAPI_ShellExecute(,"open",'"'+cScpDir+'\WinScp.com"',;
         '/command "open '+cFTPUrl+' -hostkey=""'+cFTPHostKey+'""" '+;
         '"put '+cQuoteFile+'" "exit"')    //-hostkey="ssh-rsa 2048 '+cFTPHostKey+'"'+;
ENDIF


STATIC FUNCTION RemoveLineChars(cText)
RETURN StrTran(StrTran(StrTran(cText,Chr(9),""),Chr(10),""),Chr(13),"")

FUNCTION HtmlToEntities(cText)
   LOCAL aChar

   FOR EACH aChar IN { ;
      { "&", "&amp;"  }, ;
      { '"', "&quot;" }, ;
      { "'", "&#039;" }, ;
      { "<", "&lt;"   }, ;
      { ">", "&gt;"   }, ;
      { "Å" , "&uuml;"}, ;
      { "Ñ", "&auml;" }, ;
      { "î", "&ouml;" }, ;   
      { "ö" , "&Uuml;"}, ;
      { "é", "&Auml;" }, ;
      { "ô", "&Ouml;" }, ;
      { "·" , "&szlig;"},;
      {" ","&nbsp;"} }

      cText := StrTran(cText,aChar[2],aChar[1])
   NEXT
RETURN cText

STATIC FUNCTION AddHash(aData,hData)
   LOCAL cValue,cKey,nKey   
   Aadd(aData,Array(Len(aData[1])))
   FOR EACH cValue IN hData
      cKey := cValue:__eNumKey()
      nKey := AScan(aData[1],cKey)
      IF nKey == 0
         Aadd(aData[1],cKey)
         Aadd(Atail(aData),NIL)
         nKey := Len(aData[1])
      ENDIF
      Atail(aData)[nKey] := cValue
   NEXT
RETURN NIL