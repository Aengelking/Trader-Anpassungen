LOCAL cUrl,nCount,lSuccess
LOCAL aData,oHttp
LOCAL cArtLief,cMatch

NetUse("artlief","ali",.F.,0)
NetUse("artikel","art",.F.,0)
CLS

hParts := {=>}

//FOR nX := 1 TO Len(aBrands)
   nNo := 1
   DO WHILE .T.
      ? "Seite: "+Ltrim(Str(nNo))
      //cUrl := "https://www.conrad.biz/de/Search.html?search="+aBrands[nX]+"&searchType=REGULAR&page="+LTrim(Str(nNo))
      cUrl := "https://www.conrad.biz/de.search.json"

      aData := {=>}
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
      oHttp:hFields["Accept"] := "application/json;charset=UTF-8"
//      oHttp:hFields["Cookie"] := "optimizelyEndUserId=oeu1487684964278r0.70601101010659; sessionid=e0dd9142-6e6c-48af-9e40-fe3496679053; AMCVS_5ADE1335537E10800A490D4D%40AdobeOrg=1; s_ce074=A; _hjIncludedInSample=1; s_ce074b=A; login-token=login%3aSCHLUESSEL_ENTFERNT%3acrx.default; ccp_dscs=eyJkZWxpdmVyeVR5cGUiOiJiYXNpcy5kZWxpdmVyeSIsIlBBWU1FTlRfUEFVU0VfVkFMVUUiOiIifQ==; test=testcookie; ccp_lscs=eyJwc3VpZCI6Ijg1ZWFiZTYyMTk2YjAzMDA5ZGJmNGQxZGM4MTg2YjBmIiwidHJhY2tpbmdJZCI6IjY4NDc2MzJmLWQwMGEtNGNjYi1iNjA3LTI1ZGNlYmIxMzdmZCIsImxhc3Qtc2Vlbi1wcm9kdWN0cyI6WyI3MDA0NDMiLCI3NDA0MzEiLCIxMzg0ODA4IiwiNzQwNTM4IiwiNzQwNjA0Il19; s_lastvisit=1491602802004; AMCV_5ADE1335537E10800A490D4D%40AdobeOrg=2096510701%7CMCIDTS%7C17264%7CMCMID%7C38891254143895566491593302685218797466%7CMCAAMLH-1492173182%7C6%7CMCAAMB-1492207608%7CNRX38WO0n5BH8Th-nqAG_A%7CMCOPTOUT-1491610008s%7CNONE%7CMCAID%7C2A116F438530CA3E-6000030720023677%7CMCSYNCSOP%7C411-17271%7CvVersion%7C2.0.0; s_sq=%5B%5BB%5D%5D; s_nr=1491603565870-Repeat; s_cc=true; s_ppvl=Suchergebnisse%2C100%2C100%2C960%2C1920%2C560%2C1920%2C1080%2C1%2CP; s_ud=6d663fa8544daa56acce2b9e17b5ddb9; s_ts=20170407221923; _ga=GA1.2.1611678660.1486132049; AlteonP=AP/gZNPzGqxX0y0GlxemKQ$$; ccp_scs=9ozy39uodwFv2bnYsI4OvHIZ_0sFQL_T2JZSRAbEkbckjOFWLTIr76gnNkjoQufESQFNFP9twYY4HZvoYS5UScYAJSUcKhdkbigZzW_C96KTF-UKze19DliuiNXaV7YIv_uZmoC3OzgIjkOqgI0MG7jfISyB7eU55rnl9cpsxHb7hsPcnqjjRmaeJ9sd2cGDwmj9Tqg3NxzLx-T3RCtIaTtOD4GfAVtDkLUTSLzWuQ5IKJpPvQx0nZz3LFB8y3d2BwWc_pAofYHZia6ecPGVTLURSGljop3UeZGFGw5FOvJi0uBEyXkhTi6cDYUjBPAX; s_ppv=Suchergebnisse%2C15%2C8%2C978%2C1920%2C560%2C1920%2C1080%2C1%2CP; ccp_sscs=eyJwYWdlQWN0aW9uSWQiOiJhYmMyOTlhMC1hZWU3LTRhZmUtOWQwNC1iZDcwMWE3YjFmYjYifQ==; optimizelySegments=%7B%228215093343%22%3A%22direct%22%2C%228216658729%22%3A%22false%22%2C%228222542708%22%3A%22none%22%2C%228222493885%22%3A%22gc%22%7D; optimizelyBuckets=%7B%228286265034%22%3A%228286920801%22%2C%228293033310%22%3A%228292042628%22%7D; optimizelyPendingLogEvents=%5B%5D"
      //? HB_JsonEncode(aData)

      If oHttp:open()
         oHttp:Post(HB_JsonEncode(aData))
         cData := oHttp:ReadAll()

         IF cData == NIL
          LOOP
         ENDIF
//       ? cData
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

      ELSE
         ? "Open failed"
      ENDIF
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