LOCAL cUrl,nCount,lSuccess
LOCAL aData,oHttp
LOCAL cArtLief,cMatch
LOCAL oTR

LOCAL aBrands := {"bulgin"}

NetUse("artlief","ali",.F.,0)
NetUse("artikel","art",.F.,0)
CLS

hParts := {=>}

FOR nX := 1 TO Len(aBrands)
   nNo := 1
   DO WHILE .T.
      ? "Seite: "+Ltrim(Str(nNo))

      cUrl := "https://de.farnell.com/w/search/prl/ergebnisse/"+Ltrim(Str(nNo))+"?brand="+aBrands[nX]

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
      aData["globalFilter"] := {}*/

      oHttp := TIpClientHttp():new( cUrl )
      oHttp:lPersistent := .T.
      oHttp:hFields["Connection"] := "keep-alive"
//      oHttp:hFields["Accept-Encoding"] := "gzip, deflate"
//      oHttp:hFields["Accept"] := "text/html"
      oHttp:hFields["Accept"] := "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8"
      oHttp:hFields["Accept-Language"] := "de-DE,de;q=0.9,en-US;q=0.8,en;q=0.7,nl;q=0.6"
      oHttp:cUserAgent := "Mozilla/5.0 (Windows NT 6.2; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/63.0.3239.84 Safari/537.36"

      oHttp:nConnTimeout := 10000

      If oHttp:open()
         //oHttp:Post(HB_JsonEncode(aData))
         cData := oHttp:ReadAll()

         IF cData == NIL
            ? "No data"
          LOOP
         ENDIF
         oHTML := THtmlDocument():New(cData)
         oTable := oHTML:findNext() //oHtml:body:findNodesByTagName("table")
         ? Len(oTable)
         IF oTable != NIL
            ? "Table found",Len(oTable:findNodesByTagName("tr"))
            ? Left(oTable:toString(),100)
            FOR EACH oTR IN oTable:findNodesByTagName("tr")
               aTDS :=  oTR:findNodesByTagName("td")
               IF Len(aTDs) > 0
                  ? Left(aTDs[2]:toString(),10),Left(aTDs[3]:toString(),10)                  
               ENDIF
            NEXT
         ENDIF
      ELSE
         ? "Open failed"
      ENDIF
      IF Inkey() == 27
         EXIT
      ENDIF
      nNo++
      Sinkey(0)
      EXIT
   ENDDO

   /*? "Anzahl Artikel: "+Str(Len(hParts))

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

   NEXT*/
NEXT

/*cLief := Pad("CONRAD",8)
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
NEXT*/

? "DONE"
Inkey(0,128)