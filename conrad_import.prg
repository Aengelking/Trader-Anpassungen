
#include 'y:\hb34\contrib\hbcurl\hbcurl.ch'

PROC RUN_CONRAD_IMPORT
LOCAL cUrl,nCount,lSuccess
LOCAL aData,oHttp
LOCAL cArtLief,cMatch
LOCAL cData
LOCAL pCurl := Curl_Easy_Init()
LOCAL aHeader := {"accept: application/json, text/plain"}

NetUse("artlief","ali",.F.,0)
NetUse("artikel","art",.F.,0)
CLS

hParts := {=>}

//FOR nX := 1 TO Len(aBrands)
   nNo := 1
   DO WHILE .T.
      ? "Seite: "+Ltrim(Str(nNo))
      //cUrl := "https://www.conrad.biz/de/Search.html?search="+aBrands[nX]+"&searchType=REGULAR&page="+LTrim(Str(nNo))
      cUrl := "https://api.conrad.de/search/1/v3/facetSearch/de/de/b2b?&optimizegaexp=GAX1.2.AfbtF5n9RlGhRmxr-_Tz1Q.18913.1!l20bl1roSjmxe6gJngdrNw.18913.1!wzUc_3pTQLq8YwTLlwow4w.18900.0"
      //cUrl := "https://www.conrad.biz/search/1/v3/facetSearch/de/de/b2b?"
      //cUrl += "apikey=eB6SoveLt6wWbRQuIeYtZnBAL6lUo38b"

      /*aData := {=>}
      aData["query"] := ""
      aData["disabledFeatures"] := {"cut_results","category_ids"}
      aData["from"] := (nNo-1)*200
      aData["size"] := 200 //max seems to be 200
      aData["facets"] := {{"field"=>"storeAvailability","size"=>6}}
      aData["partialThreshold"] := 10
      aData["partialQueries"] := 3
      aData["partialQuerySize"] := 6
      aData["sort"] := {{"field"=>"_score","order"=>"desc"}}
      aData["facetFilter"] := {{"field"=>"brand","type"=>"TERM_SINGLE","values"=>{"Bulgin"}}}
      aData["globalFilter"] := {}

      oHttp := TIpClientHttp():new( cUrl )
      oHttp:nConnTimeout := 10000
      oHttp:hFields["Content-Type"] := "application/json;charset=UTF-8"
      oHttp:hFields["Accept"] := "application/json;charset=UTF-8"*/
      

      curl_easy_setopt(pCurl, HB_CURLOPT_HTTPHEADER, aHeader )
      curl_easy_setopt(pCurl, HB_CURLOPT_SSL_VERIFYPEER,0)
      curl_easy_setopt(pCurl, HB_CURLOPT_DL_BUFF_SETUP )
      curl_easy_setopt(pCurl, HB_CURLOPT_URL, cUrl )
      Curl_Easy_Perform(pCurl)
      curl_easy_setopt(pCurl, HB_CURLOPT_DL_BUFF_GET, @cData )
      
      Curl_Easy_CleanUp(pCurl)
      nResponse := curl_easy_getinfo(pCurl,HB_CURLINFO_RESPONSE_CODE)


      /*If oHttp:open()
         oHttp:Post(HB_JsonEncode(aData))
         cData := oHttp:ReadAll()*/

         IF cData == NIL
          LOOP
         ENDIF
       ? cData
//         gtSetClipboard(cData)
         HB_JSonDecode(cData,@aData)
         //gtSetClipboard(ValToPrg(aData))
         //? ValToPrg(aData)
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

      /*ELSE
         ? "Open failed"
      ENDIF*/
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

cLief := Pad("CONRAD",8)
ali->(dbSetOrder( 1 ))
FOR EACH cMatch IN hParts
   IF ! Empty(cMatch)
      cArtLief := cMatch:__eNumKey()
      ? cArtLief
      IF art->(dbSeek( cMatch )) .AND. Trim(art->Matchcode) == Trim(cMatch)
         ?? "",art->Matchcode,art->Artikelnr
         IF ali->(dbSeek( cLief+Str(art->Artikelnr,6) ))
           ?? " update",ali->Artlief
           ali->(Rec_Lock())
         ELSE
            ali->(Add_Rec())
            ali->Artikelnr := art->Artikelnr
            ali->Matchcode := art->Matchcode
            ali->Kunde     := cLief
            ?? " added"
         ENDIF
         ali->ArtLief := cArtLief
         ali->(dbUnLock())
      ELSE
         ?? "",cMatch," PART NOT FOUND"
      ENDIF
   ENDIF
NEXT

? "DONE"
Inkey(0,128)