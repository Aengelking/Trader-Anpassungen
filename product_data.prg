#include 'y:\hb32\include\hbmxml.ch'
PROCEDURE ProductDataXML

/******** SETTINGS ********/
LOCAL nQtyNoStock := 1000  //Menge die bei Artikeln angegeben wird die nicht auf Lager sind
LOCAL nMaxLZ      := 12     //Max Lieferzeit in Wochen
LOCAL nPriceMulti := 1.18  //Multiply price with this factor, this covers the commission of conrad
LOCAL nWaldomLZ   := 14    //Delivery time (in Days) for waldom parts

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
LOCAL lArtFound,nArtLZ,nLZ,aMatches,bAddQuote,lQuit
LOCAL hExclude
LOCAL hManuHoliday := {=>},aWaldHoliday := {Date()+1,Date()-1,0}

LOCAL nH,nH2
LOCAL cPDFile := Path("export\conrad\pd_"+Lower(cCat)+"_"+cBrand+".csv")
LOCAL cQuoteFile := Path("export\conrad\quote_"+Lower(cCat)+"_"+cBrand+".csv")
LOCAL nMwSt,oErr

LOCAL bQtyBlock,bPrBlock,nTeMulti,nLastQty,nLastPrice
LOCAL oExtra

Taxit(1,@nMwSt,Date())
nMwSt := 1+nMwSt/100

NetUse("artikel","art")
NetUse("artlief","ali")
NetUse("liefstock","lsto")
NetUse("buyprice","bpr")
NetUse("waldom","wald")
NetUse("manufact","manu")
NetUse("engkund","ku")
IF Select("bte") != 0
   bte->(dbCloseArea())
ENDIF
Net_Use("\\EK-Server4\data\Dokumente und Einstellungen\Amos\Documents\Conrad\te","bte",.F.,0,"DBFCDX")
bte->(dbSetIndex("\\EK-Server4\data\Dokumente und Einstellungen\Amos\Documents\Conrad\te.cdx"))

DO WHILE (nH := FCreate(cPDFile,0)) == -1
   IF GetConfigValue("BATCHMODE")
      oErr := ErrorNew()
      oErr:SubSystem   := "PRODUCT-DATA-UPLOAD"
      oErr:Description := "File creation error ("+cPDFile+" Error: "+LTrim(Str(FError()))+")"      
      Throw(oErr)   
   ELSEIF Tr_MsgBox("Datei konnte nicht erstellt werden (ERROR: "+LTrim(Str(FError()))+")",,{"erneut versuchen","abbrechen"}) == 2
      RETURN
   ENDIF
ENDDO
DO WHILE (nH2 := FCreate(cQuoteFile,0)) == -1
   IF GetConfigValue("BATCHMODE")
      oErr := ErrorNew()
      oErr:SubSystem   := "PRODUCT-DATA-UPLOAD"
      oErr:Description := "File creation error ("+cQuoteFile+" Error: "+LTrim(Str(FError()))+")"      
      Throw(oErr)   
   ELSEIF Tr_MsgBox("Datei konnte nicht erstellt werden (ERROR: "+LTrim(Str(FError()))+")",,{"erneut versuchen","abbrechen"}) == 2
      RETURN
   ENDIF
ENDDO

//Collect Holiday
ku->(dbSeek( Pad("WALDOM",8)+"L" ))
oExtra := ku->(ExtraData():New(ku->Nummer))
IF ku->En_Holiday >= Date()
   aWaldHoliday[1] := ku->St_Holiday
   aWaldHoliday[2] := ku->En_Holiday
   aWaldHoliday[3] := oExtra:RecvTime
ENDIF
manu->(dbGoTop())
ku->(dbSetOrder( 8 ))
DO WHILE ! manu->(EOF())
   IF manu->Principal
      ku->(dbSeek( Str(manu->Address,6) ))
      oExtra := ku->(ExtraData():New(ku->Nummer))
      IF ku->En_Holiday >= Date()
         hManuHoliday[manu->ID] := {ku->St_Holiday,ku->En_Holiday,oExtra:RecvTime}
      ENDIF
   ENDIF
   manu->(dbSkip())
ENDDO


bAddQuote := {|cSku,lArtFound,cProdIdType|
   LOCAL nKey

   IF art->obsolete .AND. art->Bestand == 0
      RETURN .T.
   ENDIF

   nArtLZ := IF(art->LZ==0,12,art->LZ)

   hPriceData["product-id"] := cSku
   hPriceData["product-id-type"] := cProdIdType
   hPriceData["leadtime-to-ship"] := (nArtLZ+1)*5  //lieferzeit in werktagen                     
   hPriceData["state"] := 11 //"Neu"
   hPriceData["reversecharge"] := "false"
   hPriceData["warehouse"] := 1

   oArtikel := Artikel():New()
   oArtikel:Load(art->Artikelnr)
   aPrices := oArtikel:GetSellPrices(Date())
   IF Len(aPrices) >= 1 .AND. aPrices[1,2] != 0  //nur Artikel mit Preisen werden hinzugefÅgt

      hPriceData["price"] :=  aPrices[1,2]/oArtikel:VkPe*nMwSt*nPriceMulti //Preis fÅr ein StÅck
      hPriceData["min-order-quantity"] := Max(1,aPrices[1,1]) //Mindestbestellmenge auf die erste Staffel setzten

      hPriceData["discount-ranges"] := ""
      FOR nX := 2 TO Len(aPrices)
         IF aPrices[nX,1] <= 100 //we do not display prices for qty's greater than 100pcs
            IF nX > 2
               hPriceData["discount-ranges"] += ","
            ENDIF   
            hPriceData["discount-ranges"] += LTrim(Str(aPrices[nX,1],12,0))+"|"+lTrim(Str(aPrices[nX,2]/oArtikel:VkPe*nMwSt*nPriceMulti))
         ENDIF
      NEXT
   
      IF lArtFound
         aAvail := GetKwQty(art->Artikelnr)
         
         nStock := art->Bestand //GetKwStock(art->Artikelnr,AddWeeks(nCurWeek,nArtLZ+1),aAvail) //VerfÅgbarer Lagerbestand. Wir verwenden die Menge die nach der LZ noch verfÅgbar wÑre
         For nX := 1 To Len(aAvail)
            If aAvail[nX,1] <= AddWeeks(nCurWeek,nArtLZ+1)
               nStock := Min(nStock,aAvail[nX,6])
            Endif
         Next      

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
            //AddHash(aPriceData,hPriceData) //upload this, to make sure that the stock will be reset if there was any
            //we use the upload type replace instead so this does not need to be uploaded
         ENDIF

         bpr->(dbSetOrder( 2 ))

         hPriceData["sku"] := LTrim(Str(art->Artikelnr,6))+"W"
         IF lsto->(dbSeek(Pad("WALDOM",8)+Str(art->Artikelnr,6))) .AND. lsto->Stock > 0 .AND. bpr->(dbSeek(Str(art->Artikelnr,6)+Pad("WALDOM",8))) //Waldom hat Bestand  
            hPriceData["update-delete"] := ""                            
            hPriceData["quantity"] := lsto->Stock
            hPriceData["leadtime-to-ship"] := _AddHoliday(nWaldomLZ,aWaldHoliday) //LZ in Tagen, mindestens 1
            AddHash(aPriceData,hPriceData)   
            nKey := AScan(aPriceData[1],"min-order-quantity")         
            Atail(aPriceData)[nKey] := bpr->Qty
         ELSE
            hPriceData["quantity"] := 0
            hPriceData["leadtime-to-ship"] := 0
            hPriceData["update-delete"] := "delete"
            //AddHash(aPriceData,hPriceData) //upload this, to make sure that the stock will be reset if there was any   
         ENDIF         
         

         hPriceData["sku"] := LTrim(Str(art->Artikelnr,6))+"I"
         IF nStock > art->bestand //Wir haben auch noch welche im Zulauf  
            hPriceData["update-delete"] := ""                            
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
            //AddHash(aPriceData,hPriceData) //upload this, to make sure that the stock will be reset if there was any
         ENDIF
      ENDIF

      IF nArtLZ+1 <= nMaxLZ //die Standardlieferzeit auf diesem Artikel ist geringer als die Maximal erlaubte                            
         hPriceData["sku"] := LTrim(Str(art->Artikelnr,6))+"P"
         IF ! lArtFound
            aMatches := HB_Regex("\/(06|24)\/",cMatch)
            hPriceData["sku"] += "-"+aMatches[2]
         ENDIF  
         hPriceData["update-delete"] := ""                                                     
         hPriceData["quantity"] := nQtyNoStock
         IF HHasKey(hManuHoliday,art->Manufactur)
            hPriceData["leadtime-to-ship"] := _AddHoliday( (nArtLZ+1)*5, hManuHoliday[art->Manufactur] )
         ELSE
            hPriceData["leadtime-to-ship"] := (nArtLZ+1)*5                           
         ENDIF
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

IF GetConfigValue("BATCHMODE") .OR. Tr_MsgBox("Artikel mit Conrad-Artikelnr",,{"Ja","Nein"}) == 1
   hExclude := {} /*407657,407662,407693,407697,407702,407705,407706,407708,407718,407719,407727,407744,407754,501614,529891,529953,700510,701528,701567,708508,740104,740235,740236,740249,740262,740288,;
   740327,740369,740418,740431,740432,740445,740457,740471,740484,740498,740523,740552,740655,740688,740717,740718,740732,740747,740773,740797,740815,740824,740839,740855,740866,740930,;
   740933,740947,740957,740959,740973,740999,741022,741026,741040,741056,741057,741072,741111,741125,747237,747238,747249,1210937,1305625,1305626,1384779,1384780,1384781,1384785,1384786,;
   1384787,1384788,1384789,1384790,1384791,1384792,1384793,1384794,1384796,1384797,1384799,1384800,1384801,1384802,1384804,1384806,1384809,1384810,1384811,1384813,1384814,1384815,1384816,;
   1384817,1384818,1384820,1384822,1384824,1384826,1384829,1384831,1384833,1384835,1384837,1384839,1384840,1384841,1384842,1492552,1492554,1492562,1492563,1492572,740960,407709,740881,740801,;
   1492564,701515,740353,1384782,701277,407717,1384805,747225,700502,407653,529928,700053,741039}*/

   Select("art")
   SET FILTER TO art->Manufactur == 1
   art->(dbGoTop())

   DO WHILE ! art->(EOF())
      IF ali->(dbSeek(Pad("CONRAD",8)+Str(art->Artikelnr,6))) .AND. ! Empty(ali->Artlief) .AND. ! Val(ali->Artlief) $ hExclude
         hPriceData := {=>} 
         Eval(bAddQuote,Trim(ali->Artlief),.T.,"SKU")
      ENDIF
      art->(dbSkip())
   ENDDO

   art->(dbClearFilter())
ENDIF


//add the waldom stock of TE parts we do not have on the system
wald->(dbSetFilter({|| wald->Stock != 0 },"stock != 0")) //.AND. Trim(wald->prc) $ {'BUL','ARC'}
wald->(dbGoTop())

nTeMulti := 1.5

DO WHILE ! wald->(EOF())
   IF bte->(dbSeek( Trim(wald->Part) ))
      ? wald->Part,bte->Hersteller,bte->Bestellnr,wald->Price1*nTeMulti

      hPriceData := {=>} 
      hPriceData["product-id"] := Trim(bte->Bestellnr)
      hPriceData["product-id-type"] := "SKU"
      hPriceData["state"] := 11 //"Neu"
      hPriceData["reversecharge"] := "false"
      hPriceData["sku"] := Trim(wald->Part)
      
      hPriceData["quantity"] := wald->Stock
      
      IF wald->Stock == 0         
         //hPriceData["leadtime-to-ship"] := 0
         //hPriceData["update-delete"] := "delete"
      ELSE
         //hPriceData["update-delete"] := "update"                            
      
         hPriceData["leadtime-to-ship"] := nWaldomLZ //LZ in WerkTagen, mindestens 1
         hPriceData["min-order-quantity"] := Max(1,wald->MOQ) //Eval(bQtyBlock)

         hPriceData["discount-ranges"] := ""
         nLastQty := 0
         nLastPrice := 0
         FOR nX := 1 TO 9
            Select("wald")
            bPrBlock := wald->(FieldBlock("Price"+LTrim(Str(nX))))
            bQtyBlock := wald->(FieldBlock("Break"+LTrim(Str(nX))))
            IF Eval(bPrBlock) > nLastPrice .AND. Eval(bQtyBlock) > nLastQty .AND. Eval(bQtyBlock) >= wald->MOQ
               IF ! HHasKey(hPriceData,"price")
                  hPriceData["price"] :=  Eval(bPrBlock)*nMwSt*nTeMulti //Preis fÅr MOQ                  
               ELSE
                  IF ! Empty(hPriceData["discount-ranges"])
                     hPriceData["discount-ranges"] += ","
                  ENDIF   
                  hPriceData["discount-ranges"] += LTrim(Str(Eval(bQtyBlock),12,0))+"|"+lTrim(Str(Eval(bPrBlock)*nMwSt*nTeMulti))
               ENDIF
               nLastQty := Eval(bQtyBlock)
               nLastPrice := Eval(bPrBlock)
            ENDIF
         NEXT

         IF HHasKey(hPriceData,"price") .AND. hPriceData["price"] > 0
            AddHash(aPriceData,hPriceData)  
         ENDIF
      ENDIF 
      
   ENDIF
   wald->(dbSkip())
ENDDO
wald->(dbClearFilter())

CLS
? "Anzahl:",Len(aData)-1
? "Anzahl Preise:",Len(aPriceData)-1
IF ! GetConfigValue("BATCHMODE")
   Sinkey(0)
ENDIF

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

STATIC FUNCTION _AddHoliday(nLZ,aHoliday)
   IF Date() <= aHoliday[2]; //we are before the End of the the holiday
      .AND. Date()+nLZ-aHoliday[3] >= aHoliday[1] //and it will not be shipped before their holiday 
      
      nLZ := aHoliday[2]-Date()+1+nLZ //nLZ from the day after the holiday

   ENDIF
RETURN nLZ
