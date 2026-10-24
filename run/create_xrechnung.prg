/*
   Programm to create X-Rechnung XML file with the PDF24 Creator and attach to the invoice PDF
*/



/*
   PDF24 JSON-Feldnamen: verifiziert gegen den JSON-Export einer
   Beispielrechnung aus dem PDF24 E-Rechnungs-Generator (07/2026):
   - "orderPosition" (BT-132) und "description" (BT-154) je Position
   - "buyerId" (BT-156, Artikelnummer des Kaeufers) je Position
   Nicht umgesetzt:
   - BT-16 (despatchAdviceReference) und BT-71 (delivery.locationId):
     koennen nicht angegeben werden (Vorgabe Buchhaltung)
   - BT-159 (Artikelherkunftsland): der PDF24-Export enthaelt kein
     entsprechendes Item-Feld, wird von PDF24 aktuell nicht unterstuetzt
   Nachgepatcht:
   - BT-8 (DueDateTypeCode): kennt PDF24 nicht, Conrad verlangt ihn aber.
     Wird nach dem PDF24-Lauf direkt im eingebetteten XML ergaenzt
     (SetDueDateTypeCode), siehe dort.
*/

PROC CreateXRechung(nRechnr,cFile)
   LOCAL hData := {=>}
   LOCAL oRechnung
   LOCAL cLang
   LOCAL cTaxCode,lParentLagerArt := .T.
   LOCAL hMeMap := {"l"=>"LTR","g"=>"GRM","kg"=>"KGM","m"=>"MTR","STD"=>"HUR"}
   LOCAL nH,oErr
   LOCAL hContact,cFirm
   LOCAL cDir
   LOCAL cPDF24Dir := "C:\Program Files\PDF24\"
   LOCAL cJsonFile
   LOCAL nProc,nErrOut,nErrBytes,cData,cStdErr
   LOCAL cAufNr,lOneAufnr := .T.,cProc
   LOCAL cKunde,cPosText,nBestPos


   NetUse("englsre","re")
   NetUse("engkund","ku")
   NetUse("ups","ups")
   NetUse("artikel","art")
   NetUse("artkund","aku")
   NetUse("engtext2","tx")
   NetUse("me","me")
   
   ups->(dbSetOrder(3))
   re->(dbSetOrder( 4 ))
   art->(dbSetOrder( 2 ))
   ku->(dbSetOrder(1))
   aku->(dbSetOrder(1))

   IF ! File(cFile)
      oErr := ErrorNew()
      oErr:SubSystem   := "TRADER"
      oErr:Description := "Datei nicht gefunden: "+cFile
      oErr:Args        := {cFile}
      Throw(oErr)
      RETURN
   ELSEIF ! re->(dbSeek( Str(nRechnr,6) ))
      oErr := ErrorNew()
      oErr:SubSystem   := "TRADER"
      oErr:Description := "Rechnung nicht gefunden"
      oErr:Args        := {nRechnr}
      Throw(oErr)
      RETURN
   ELSEIF re->Money != "E"
      IF ! GetConfigValue("BATCHMODE")
         Alert("Rechnung nicht in Euro")
      ENDIF
      RETURN
   ELSEIF ! re->Packed 
      IF ! GetConfigValue("BATCHMODE")
         //Alert("Rechnung nicht gepackt")
      ENDIF
      RETURN
   ENDIF

   ku->(dbSetOrder( 1))
   ku->(dbSeek( re->Kunde+"K" ))

   IF ku->Re_Via != "EMAI"
      IF ! GetConfigValue("BATCHMODE")
         Alert("Rechnungsversand nicht per E-Mail")
      ENDIF
      RETURN
   ELSEIF ku->CountryIso != "DE"
      IF ! GetConfigValue("BATCHMODE")
         Alert("Rechnungsversand nicht nach Deutschland")
      ENDIF
      RETURN
   ENDIF
   
   hContact := GetInvoiceContact()
   IF hContact == NIL
      oErr := ErrorNew()
      oErr:SubSystem   := "TRADER"
      oErr:Description := "Kein Rechnungskontakt vorhanden. Rechnung: "+LTrim(Str(nRechnr))
      oErr:Args        := {nRechnr}
      Throw(oErr)
      RETURN
   ENDIF

   cLang := ku->Language

   oRechnung := Rechnung():New()
   oRechnung:Load(nRechnr)

   re->(dbSkip(1)) //skip the header record
   cAufNr := re->Aufnr
   Do While ! re->(EOF()) .AND. re->rechnr == nRechnr
      IF re->Aufnr != cAufNr
         lOneAufnr := .F.
         EXIT
      ENDIF
      re->(dbSkip())
   ENDDO
      
   re->(dbSeek( Str(nRechnr,6) ))
   
   hData["currencyCode"] := "EUR"
   hData["currencySymbol"] := "ƒ?ª"
   IF oRechnung:Brutto > 0
      hData["title"] := IF(cLang!="D","Invoice","Rechnung")
      hData["typeCode"] := "380"
   ELSE
      hData["title"] := IF(cLang!="D","Credit note","Stornorechnung")
      hData["typeCode"] := "384" //Rechnungskorrektur
   ENDIF
   cKunde := re->Kunde  //Rechnungskunde vom Kopfsatz merken (fuer artkund/BT-156)

   hData["number"] := LTrim(Str(re->Rechnr))
   hData["issueDate"] := _DtoC(re->Rechdat)
   hData["dueDate"] :=  _DtoC(re->Rechdat+sk->(GetSkontoWait(re->skonto,re->rechdat)))
   hData["deliveryDate"] := _DtoC(IF(ups->(dbSeek( Str(re->Rechnr,10) )),ups->Datum,re->Rechdat))
   IF lOneAufnr
      hData["purchaseOrderReference"] := Trim(re->AufNr)
   ENDIF
   /*"billingPeriodStartDate": "",
   "billingPeriodEndDate": "",
   "projectReference": "",
   "contractReference": "",
   "purchaseOrderReference": "",
    "note": "",
    "introText": "",
        "documentReferences": [],
    "objectReferences": [],
    "invoiceReferences": [],
    "buyerReference": "", //Pflicht bei Beh”rden
    */
   hData["buyerReferenceDisabled"] := .T.
   hData["note"] := ""
   cFirm := "Engelking Elektronik GmbH"
   hData["seller"] := {;
      "name"=>cFirm,; //automotive anpassen      
      "vatId"=>"DE189714518",;  //automotive anpassen
      "weeeId"=>"DE43356265",;  //automotive anpassen
      "electronicAddress"=>"buchhaltung@engelking.de",; //automotive anpassen    
      "id"=>Trim(oRechnung:oLeistungsAdresse:Kundennr),;
      "electronicAddressTypeCode"=>"EM",;
      "address"=>{;
         "line1"=>"Albstr. 16",;
         "line2"=>"",;
         "postCode"=>"78609",;
         "city"=>"Tuningen",;
         "countryCode"=>"DE";
      },;
      "contact"=>{;
          "name"=>"Buchhaltung",;
          "email"=>"buchhaltung@engelking.de",;  //automotive anpassen
          "phone"=>"+49 7464 9865 22";
      };
   }
   hData["buyer"] := {;
      "name"=>hb_strtoutf8(Trim(oRechnung:oLeistungsAdresse:cName)),;        
      "address"=>{;
         "line1"=>hb_strtoutf8(Trim(oRechnung:oLeistungsadresse:cStrasse)),;         
         "postCode"=>Trim(oRechnung:oLeistungsadresse:cPLZ),;
         "city"=>hb_strtoutf8(Trim(oRechnung:oLeistungsadresse:cStadt)),;
         "countryCode"=>oRechnung:oLeistungsAdresse:countryiso;
      },;
      "electronicAddress"=>Trim(hContact["email"]);
   }
    
   oRechnung:GotoTaxCustomer()
   IF ! Empty(ku->Vatnr)
         hData["buyer"]["vatId"] := Trim(ku->Vatnr)
   ENDIF
   
   IF re->TaxCode == 3
      cTaxCode := "K" //innergemeinschaftliche Lieferung
   ELSEIF re->TaxCode == 0
      cTaxCode := "G" //Export
   ELSE
      cTaxCode := "S" //Standard
   ENDIF


/*        "electronicAddress": "",
        "electronicAddressTypeCode": "EM",

                "contact": {
            "name": "",
            "email": "",
            "phone": ""
        }

*/

   hData["delivery"] := {;
      "recipientName"=>hb_strtoutf8(Trim(oRechnung:oLieferAdresse:cName)),;   
      "address"=>{;
         "line1"=>hb_strtoutf8(Trim(oRechnung:oLieferadresse:cStrasse)),;                
         "postCode"=>Trim(oRechnung:oLieferadresse:cPLZ),;
         "city"=>hb_strtoutf8(Trim(oRechnung:oLieferadresse:cStadt)),;
         "countryCode"=>oRechnung:oLieferAdresse:countryiso;
      };
   }

   sk->(dbGoto(re->skonto+1))
   hData["payment"] := {;
      "terms"=>Trim(SK->(SKONT(,,sk->ziel1,sk->ziel2,sk->ziel3,sk->rate1,sk->rate2,sk->rate3,cLang,.F.,re->Rechdat))),;            
      "methods"=>{;
         {;
            "typeCode"=>"58",;
            "iban"=>"DE85664927000088839102",;            
            "accountName"=>cFirm,;
            "bic"=>"GENODE61KZT",;
            "bankName"=>"Volksbank Mittlerer Schwarzwald";
         },;
         {;
            "typeCode"=>"58",;
            "iban"=>"DE37694500650151009240",;            
            "accountName"=>cFirm,;
            "bic"=>"SOLADES1VSS",;
            "bankName"=>"Sparkasse Schwarzwald Baar";
         };
      };
   }

    //Kontonummern k”nnen in der Rechnung hinterlegt werden
    /*"reference": "",
    "methods": [
      {
          "typeCode": "58",
          "iban": "",
          "ban": "",
          "bic": "",
          "bankName": "",
          "accountName": ""
      }
  ]*/


   hData["items"] := {}       

   re->(dbSkip(1)) //skip the header record
   Do While ! re->(EOF()) .AND. re->rechnr == nRechnr
      if oRechnung:reart == 0 .OR.;
         oRechnung:reart == 2 .OR.;
         ((oRechnung:reart = 1 .OR. oRechnung:reart == 3) .AND. re->aoqty <> 0) .AND. (lParentLagerArt .OR. ! re->Folge .OR. re->Preis != 0)
      
         art->(dbseek(STR(re->artikelnr,6)))

         Aadd(hData["items"],{;            
            "id"=>Trim(IF(art->PRMATCH,re->matchcode,IF(LEFT(re->matchcode,1) = "@",Pad(tx->(DispText(re->Textnr,0,0,80,1)),35),re->artikel))),;
            "name"=>IF(art->Prmatch,hb_strtoutf8(Trim(re->Artikel)),""),;            
            "basisQuantity"=>re->Pe,;
            "quantity"=>Val(TransForm(re->aoqty,me->(ME(art->me)))),;
            "quantityUnit"=>IF(Trim(art->Me)$hMeMap,hMeMap[Trim(art->Me)],"H87"),;
            "vatCode"=>cTaxCode,;
            "vatRate"=>oRechnung:MwStRate,;
            "netUnitPrice"=>re->Preis;              
         })
         cPosText := ""
         IF re->Textnr != 0
            cPosText := tx->(ReadText(re->Textnr))
         ENDIF

         //BT-159 Ursprungsland als ISO code
         ATail(hData["items"])["originCountry"] := art->Ursprung

         //BT-132 Referenz zur Bestellposition: Zeile "Position: n" aus dem
         //Positionstext (wird bei Kunden mit oExtra:AufPos gepflegt,
         //vgl. hook before_save_aufpos). Fallback wie bisher: Auftragsnummer
         //je Position, wenn mehrere Auftraege in der Rechnung stecken.
         nBestPos := 0
         IF AT("Position:",cPosText) != 0
            nBestPos := Val(LTrim(SubStr(cPosText,AT("Position:",cPosText)+Len("Position:"))))
         ENDIF
         IF nBestPos != 0
            ATail(hData["items"])["orderPosition"] := LTrim(Str(nBestPos))
         ELSEIF ! lOneAufnr
            ATail(hData["items"])["orderPosition"] := Trim(re->Aufnr)
         ENDIF

         //BT-154 Artikelbeschreibung: Positionslangtext (bei @-Textpositionen
         //steckt der Text bereits in der id, daher dort nicht doppelt ausgeben)
         IF ! Empty(cPosText) .AND. LEFT(re->matchcode,1) != "@"
            ATail(hData["items"])["description"] := hb_strtoutf8(Trim(cPosText))
         ENDIF

         //BT-156 Artikelnummer des Kaeufers: Kundenartikelnummer aus artkund
         IF aku->(dbSeek( cKunde+Str(re->Artikelnr,6) )) .AND. ! Empty(aku->ArtLief)
            ATail(hData["items"])["buyerId"] := hb_strtoutf8(Trim(aku->ArtLief))
         ENDIF
         IF ! Empty(re->Rabatt)
            ATail(hData["items"])["allowances"] := {{;
               "percent"=>re->Rabatt,;
               "reason"=>IF(cLang!="D","Discount","Rabatt"),;
               "type"=>"percentage";
            }}
         ENDIF
         //"description": "",
         //"netAmount": null,
         //"charges": []
         //IF(re->reart = 0 .OR. re->reart = 3,StrZero(re->reposnr,2),StrZero(miitm,2))

         IF oRechnung:Porto != 0
            hData["charges"] := {;
               { "netAmount"=>oRechnung:Porto,;
                  "vatRate"=>oRechnung:MwStRate,;
                  "vatCode"=>cTaxCode,;
                  "reason"=> IF(cLang!="D","Freight","Porto und Verpackung"),;
                  "type"=>"absolute" ;
               };
            }
         ENDIF

         IF ! re->Folge
            lParentLagerArt := art->Lagerart
         ENDIF
      ENDIF      
    

      //outputOptions
      hData["format"] := "zugferd"
      hData["decimalSeparator"] := ","
      hData["thousandsSeparator"] := "."
      hData["dateFormat"] := "dd.mm.yyyy"
      hData["langCode"] := IF(cLang!="E","de","en")
      hData["quantityUnitDisplayMode"] := "separated"
      hData["taxCategoryDisplayMode"] := "shown"
      hData["taxDisplayMode"] := "shown"
      hData["taxExemptionReasonsDisplayMode"] := "shown"
      

      re->(dbSkip())
   ENDDO
   
   cDir := GetEnv("TEMP")
   cJsonFile := cDir+"\zugferd_"+LTrim(Str(nRechnr))+".json"
   nH := FCreate(cJsonFile)
   IF nH <= 0 .OR. ! File(cJsonFile) 
      IF ! GetConfigValue("BATCHMODE")
         //Alert("JSON Datei konnte nicht erstellt werden")
      ENDIF
      oErr := ErrorNew()
      oErr:SubSystem   := "TRADER"
      oErr:Description := "JSON Datei konnte nicht erstellt werden"
      oErr:Args        := {nRechnr}
      Throw(oErr)
   ENDIF
   FWrite(nH,HB_JsonEncode(hData))
   FClose(nH)


   IF ! GetConfigValue("BATCHMODE")
      //Alert("JSON Datei: "+cJsonFile)
   ENDIF
   //Create Zugferd PDF
   cProc := cPDF24Dir+'pdf24-Toolbox.exe -createInvoice "'+cJsonFile+'" "'+cFile+'" -outputType zugferd -pdfFile "'+cFile+'"'

   nProc := HB_OpenProcess(cProc,,,@nErrOut)
   nErrBytes := 1
   cStdErr := ""
   DO WHILE nErrBytes > 0
      cData := Space( 1000 )
      nErrBytes := Fread( nErrOut, @cData, 1000 ) //Len(cData) )
      cStdErr += HB_AnsiToOem( Left( cData, nErrBytes ) )
   ENDDO
   HB_ProcessValue(nProc) //wait for PDF24 to end

   FErase(cJsonFile)

   IF ! Empty(cStdErr)
      oErr := ErrorNew()
      oErr:SubSystem   := "TRADER"
      oErr:Description := "Fehler beim Erstellen der X-Rechnung: "+cStdErr
      oErr:Args        := {nRechnr,cStdErr}
      Throw(oErr)
   ENDIF

   //BT-8 ergaenzen (Conrad: "Value added tax point date code")
   IF ! SetDueDateTypeCode(cFile)
      oErr := ErrorNew()
      oErr:SubSystem   := "TRADER"
      oErr:Description := "BT-8 (DueDateTypeCode) konnte nicht in die X-Rechnung eingefuegt werden: "+cFile
      oErr:Args        := {nRechnr,cFile}
      Throw(oErr)
   ENDIF

   STATIC Func _DtoC(dDate)
   RETURN Str(Year(dDate),4)+"-"+StrZero(Month(dDate),2)+"-"+StrZero(Day(dDate),2)   

/*
   Fuegt <ram:DueDateTypeCode>5</ram:DueDateTypeCode> (5 = Rechnungsdatum)
   in jeden ApplicableTradeTax-Block der ApplicableHeaderTradeSettlement ein,
   direkt vor RateApplicablePercent (Reihenfolge laut CII-Schema).
   PDF24 bettet das XML unkomprimiert ein und /Params traegt keine
   Pruefsumme. Damit Stream-/Length, /Params /Size und die xref-Offsets
   gueltig bleiben, wird die Laenge des XML exakt beibehalten: fuer die
   eingefuegten Bytes werden Einrueckungs-Tabs entfernt.
*/
STATIC FUNC SetDueDateTypeCode(cFile)
   LOCAL cTag := "<ram:DueDateTypeCode>5</ram:DueDateTypeCode>"
   LOCAL cEndTag := "</rsm:CrossIndustryInvoice>"
   LOCAL cPdf,cXml,cNew,cIns,cIndent,cEol
   LOCAL nStart,nEnd,nPos,nEndTax,nRate,nLine,nDiff
   LOCAL lFound := .F.,lRemoved

   cPdf := hb_MemoRead(cFile)
   nStart := At("<rsm:CrossIndustryInvoice",cPdf)
   IF nStart == 0
      RETURN .F.
   ENDIF
   nEnd := hb_At(cEndTag,cPdf,nStart)
   IF nEnd == 0
      RETURN .F.
   ENDIF
   nEnd += Len(cEndTag)-1
   cXml := SubStr(cPdf,nStart,nEnd-nStart+1)
   IF "DueDateTypeCode" $ cXml
      RETURN .T. //schon vorhanden (z.B. kuenftige PDF24-Version)
   ENDIF

   cNew := cXml
   nPos := At("<ram:ApplicableHeaderTradeSettlement>",cNew)
   IF nPos == 0
      RETURN .F.
   ENDIF
   //nach dem Kopf-Settlement kommen nur noch Kopf-Steuerbloecke (je Steuersatz einer)
   DO WHILE (nPos := hb_At("<ram:ApplicableTradeTax>",cNew,nPos)) > 0
      nEndTax := hb_At("</ram:ApplicableTradeTax>",cNew,nPos)
      IF nEndTax == 0
         RETURN .F.
      ENDIF
      nRate := hb_At("<ram:RateApplicablePercent>",cNew,nPos)
      IF nRate == 0 .OR. nRate > nEndTax
         nRate := nEndTax
      ENDIF
      //Einrueckung und Zeilenende der Zielzeile uebernehmen
      nLine := RAt(Chr(10),Left(cNew,nRate-1))
      cIndent := SubStr(cNew,nLine+1,nRate-nLine-1)
      IF nLine > 0 .AND. Empty(cIndent)
         cEol := IF(SubStr(cNew,nLine-1,1) == Chr(13),Chr(13)+Chr(10),Chr(10))
         cIns := cTag+cEol+cIndent
      ELSE
         cIns := cTag
      ENDIF
      cNew := Left(cNew,nRate-1)+cIns+SubStr(cNew,nRate)
      nPos := nEndTax+Len(cIns)
      lFound := .T.
   ENDDO
   IF ! lFound
      RETURN .F.
   ENDIF

   //Laenge ausgleichen: fuehrende Tabs entfernen (Whitespace zwischen Elementen)
   nDiff := Len(cNew)-Len(cXml)
   DO WHILE nDiff > 0
      lRemoved := .F.
      nPos := 1
      DO WHILE nDiff > 0 .AND. (nPos := hb_At(Chr(10)+Chr(9),cNew,nPos)) > 0
         cNew := Left(cNew,nPos)+SubStr(cNew,nPos+2)
         nDiff--
         lRemoved := .T.
         nPos++
      ENDDO
      IF ! lRemoved
         RETURN .F.
      ENDIF
   ENDDO

   cPdf := Left(cPdf,nStart-1)+cNew+SubStr(cPdf,nStart+Len(cXml))
   RETURN hb_MemoWrit(cFile,cPdf)
      


