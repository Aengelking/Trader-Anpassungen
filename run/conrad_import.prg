
#include 'y:\hb34\contrib\hbcurl\hbcurl.ch'

PROC RUN_CONRAD_IMPORT
LOCAL cUrl,nCount,lSuccess
LOCAL aData,oHttp
LOCAL cArtLief,cMatch
LOCAL cData
LOCAL pCurl := Curl_Easy_Init()
LOCAL aHeader := {"accept: application/json, text/plain"}
LOCAL aList,nX,nP,hPrices

NetUse("artlief","ali",.F.,0)
NetUse("artikel","art",.F.,0)
NetUse("comprice2","cmp2")

CLS

//hParts := {=>}

cFile := WVT_GetOpenFileName(0,"","Bitte die Datei von BrowseAI ausw„hlen",{{"JSON Dateien","*.json"},{"Alle Dateien","*.*"}},,"")
//cFile := "c:\Users\Amos\Downloads\bulgin-products-list-(conrad)_bulgin-products_captured-list_2025-08-28_16-34-56_0198f117-e15d-7688-944f-6981017ce7e1.json"

IF ! File(cFile)
   Alert("Datei "+cFile+" nicht gefunden")
   RETURN
ENDIF

hData := HB_JsonDecode( FileStr(cFile) )

IF ValType(hData) != "H" .OR. ! HHasKey(hData,"data")
   Alert("Datei "+cFile+" ist keine gltige JSON Datei")
   RETURN
ENDIF

aList := hData["data"]

/*
   nNo := 1
   DO WHILE .T.
      ? "Seite: "+Ltrim(Str(nNo))
      cUrl := "https://api.conrad.de/search/1/v3/facetSearch/de/de/b2b?&optimizegaexp=GAX1.2.AfbtF5n9RlGhRmxr-_Tz1Q.18913.1!l20bl1roSjmxe6gJngdrNw.18913.1!wzUc_3pTQLq8YwTLlwow4w.18900.0"

      curl_easy_setopt(pCurl, HB_CURLOPT_HTTPHEADER, aHeader )
      curl_easy_setopt(pCurl, HB_CURLOPT_SSL_VERIFYPEER,0)
      curl_easy_setopt(pCurl, HB_CURLOPT_DL_BUFF_SETUP )
      curl_easy_setopt(pCurl, HB_CURLOPT_URL, cUrl )
      Curl_Easy_Perform(pCurl)
      curl_easy_setopt(pCurl, HB_CURLOPT_DL_BUFF_GET, @cData )
      
      Curl_Easy_CleanUp(pCurl)
      nResponse := curl_easy_getinfo(pCurl,HB_CURLINFO_RESPONSE_CODE)


      IF cData == NIL
         LOOP
      ENDIF
      ? cData
      HB_JSonDecode(cData,@aData)
      ? Len(aData["hits"])
      IF Len(aData["hits"]) == 0 .OR. (Len(aData["hits"]) == 1 .AND. HHasKey(hParts,aData["hits"][1]["productId"])) //at the end conrad continues showing the last product
         EXIT
      ENDIF
      AEval(aData["hits"],{|aProd|
         IF HHasKey(hParts,aProd["productId"])
            ? "Double",aProd["productId"]
         ENDIF
         hParts[aProd["productId"]] := ""
      })

      IF Inkey() == 27
         EXIT
      ENDIF
      nNo++
   ENDDO

   ? "Anzahl Artikel: "+Str(Len(hParts))

   FOR nP := 1 TO Len(hParts)
      cArtLief := HGetKeyAt(hParts,nP)
      //IF ! alil->(dbSeek(Pad("CONRAD",8)+cArtLief))
         ? cArtLief
            cUrl := "https://www.conrad.biz/de/product-"+Trim(cArtLief)+".html"
            nCount := 0
            lSuccess := .F.
            DO WHILE ! lSuccess .AND. nCount < 10
               oHttp := TIpClientHttp():new( cUrl )
               oHttp:nConnTimeout := 10000
               oHttp:open()

               oHttp:Post() //{"symbol"=>cMatch,"brutto"=>"","onlyPrices"=>1})
               cData := oHttp:readAll()
               IF oHttp:nReplyCode == 301
                  nCount++
                  cUrl := oHttp:hHeaders["Location"]
               ELSE
                  lSuccess := .T.
               ENDIF
            ENDDO

            cData := StrTran(StrTran(cData,Chr(13),""),Chr(10),"")
            aRegex := HB_RegEx("Herst\.-Teilenr\..*?<dd[^>]*>\s*([^<]*)",cData)
            IF Len(aRegex) >= 2
               hParts[cArtLief] := aRegex[2]
               ?? "",aRegex[2]
            ELSE //sometime they put it under "Typ"
               gtSetClipBoard(cData)
               aRegex := HB_RegEx("div>\s*Typ.*?<dd[^>]*>\s*([^<]*)",cData)
               IF Len(aRegex) >= 2
                  hParts[cArtLief] := aRegex[2]
                  ?? "",aRegex[2]
               ENDIF
            ENDIF
      //ENDIF

   NEXT
//NEXT
*/
CLS
cLief := Pad("CONRAD",8)
nLief := 4830
ali->(dbSetOrder( 1 ))
//FOR EACH cMatch IN hParts
? "Anzahl Artikel: "+Str(Len(aList))
FOR nX := 1 TO Len(aList)
   IF HHasKey(aList[nX],"Hersteller Teilenummer")
      cMatch := Upper(aList[nX,"Hersteller Teilenummer"])

      IF ! Empty(cMatch)
      
         nPos := AT("-",aList[nX,"Bestellnummer"])
         IF nPos != 0
            cArtLief := Trim(Substr(aList[nX,"Bestellnummer"],1,nPos-1))
         ELSE
            cArtLief := Trim(aList[nX,"Bestellnummer"])
         ENDIF
         IF art->(dbSeek( cMatch )) .AND. Trim(art->Matchcode) == Trim(cMatch)
            ? art->Matchcode,art->Artikelnr         
            ali->(dbSeek( cLief+Str(art->Artikelnr,6) ))
            IF ali->(Found()) .AND. Trim(ali->Artlief) == cArtlief
                  ?? " no change"
            ELSE
               IF ali->(Found())
                  ?? " update",ali->Artlief               
                  ali->(Rec_Lock())
               ELSE
                  ali->(Add_Rec())
                  ali->Artikelnr := art->Artikelnr
                  ali->Matchcode := art->Matchcode
                  ali->Priority  := 8
                  ali->Kunde     := cLief
                  ?? " added"
               ENDIF
               ali->ArtLief := cArtLief
               ali->(dbUnLock())
            ENDIF
            IF HHAsKey(aList[nX],"Seller") .AND. aList[nX,"Seller"] != "Engelking"
               hPrices := {=>}
               IF Len(aList[nX]["Preise"]) > 0                
                  FOR nP := 1 TO Len(aList[nX,"Preise"])
                     hPrices[Val(aList[nX]["Preise"][nP]["Menge"])] := Val(StrTran(aList[nX]["Preise"][nP]["Staffelpreis"],",","."))
                  NEXT
               ELSE
                  IF ValType(aList[nX]["Rabattierter Preis"]) == "C"
                     hPrices := {1=>Val(StrTran(aList[nX]["Rabattierter Preis"],",","."))}
                  ENDIF
               ENDIF
               IF Len(hPrices) > 0
                  IF ! cmp2->(dbSeek( Str(art->Artikelnr,6)+Str(nLief,6) ))
                     cmp2->(Add_Rec(0))
                     cmp2->Artikelnr := art->Artikelnr
                     cmp2->Lieferant := nLief
                  ELSE
                     cmp2->(Rec_Lock())
                  ENDIF
                  cmp2->Datum := Date()
                  cmp2->Daten := HB_Serialize(hPrices)
                  cmp2->(dbUnLock())
               ENDIF
            ENDIF
         ELSE
            ? cMatch," PART NOT FOUND"
         ENDIF
      ENDIF
   ENDIF
NEXT

? "DONE"
Inkey(0,128)