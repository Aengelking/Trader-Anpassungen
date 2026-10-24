PROCEDURE RUN_BUERKLIN_IMPORT
LOCAL cLiefma := Pad(HB_AnsiToOem("BÜRKLIN"),8)
LOCAL nP,oHttp
LOCAL aBrands,nX,cUrl,cData,aRegex,nR,cMatch,cPart
LOCAL oLI,oHTML,lAuslauf
LOCAL lFound

NetUse("artlief","alil",.F.,0)
NetUse("artikel","art",.F.,0)
CLS

aBrands := {}
Aadd(aBrands,"BULGIN") //Bulgin
//Aadd(aBrands,"ONPOW") //Onpow does not work, as the part nos are not correct
//Aadd(aBrands,"techno")


FOR nX := 1 TO Len(aBrands)
   ? aBrands[nX]   
   nP := 1

   DO WHILE Inkey(,128) != 27
      //cUrl := "https://www.buerklin.com/de/brands/manufacturer?name="+aBrands[nX]+"&pagesize=1000" //1000 parts per page seems to be max, but that is enough at the moment
      cUrl := "https://www.buerklin.com/de/search?q="+aBrands[nX]+"&pagesize=100&page="+Ltrim(str(nP-1))
      ? cUrl
      oHttp := TIpClientHttp():new( cUrl )
      oHttp:nConnTimeout := 20000
      If oHttp:open()
         lFound := .F.
         cData := oHttp:ReadAll()         
         IF cData == NIL            
            Alert("No data received.;"+IF(oHttp:nReplyCode==NIL,"Request timed out.","HTTP-Status: "+LTrim(Str(oHttp:nReplyCode))))
            EXIT
         ENDIF
         oHtml := THtmlDocument():New(cData)         
         FOR EACH oLI IN oHtml:body:findNodesByTagName("li")
            //? oLI:toString()            
            aRegex := HB_Regex("Bestell-Nr.\s*([^<\r\n]*).*\n.*\n.*Hersteller-Nr.\s*([^<\r\n]*)",oLI:toString(),.T.)
            IF Len(aRegex) != 0
               lFound := .T.
               lAuslauf := AT("Auslaufartikel",oLI:toString()) != 0
               cPart := aRegex[2]
               cMatch := aRegex[3]
               If art->(dbSeek( Pad(cMatch,25) ))
                  If Trim(cPart) == "Nicht zugewiesen"
                  ELSEIF lAuslauf
                     If alil->(dbSeek( cLiefma+Str(art->Artikelnr,6) ))
                        ?? cMatch," Auslaufartikel gel”scht"
                        alil->(Rec_Lock())
                        alil->(dbDelete())
                        alil->(dbUnLock())
                     ENDIF
                  Else
                     ? cMatch,"|",cPart                     
                     If alil->(dbSeek( cLiefma+Str(art->Artikelnr,6) ))
                        ?? " update"
                        alil->(Rec_Lock())
                     Else
                        alil->(Add_Rec())
                        alil->Artikelnr := art->Artikelnr
                        alil->Matchcode := art->Matchcode
                        alil->Kunde     := cLiefma   
                     Endif                     
                     alil->ArtLief := cPart
                     alil->(dbUnLock())
                  Endif
               Endif
            ENDIF
         NEXT

         IF ! lFound
            EXIT
         ENDIF
         /*aRegex := HB_RegexAll("Bestell-Nr.\s*([^<]*).*\n.*\n.*Hersteller-Nr.\s*([^<]*)",cData,.T.)

         IF Len(aRegex) == 0 //no parts found, end of list
            EXIT
         ENDIF

         FOR nR := 1 TO Len(aRegex)
            cPart := aRegex[nR,2]
            cMatch := aRegex[nR,3]
            If art->(dbSeek( Pad(cMatch,25) ))
               If Trim(cPart) == "Nicht zugewiesen"
               Else
                  ? cMatch,cPart
                  If alil->(dbSeek( cLiefma+Str(art->Artikelnr,6) ))
                     ?? " update"
                     alil->(Rec_Lock())
                  Else
                     alil->(Add_Rec())
                     alil->Artikelnr := art->Artikelnr
                     alil->Matchcode := art->Matchcode
                     alil->Kunde     := cLiefma

                  Endif
                  alil->ArtLief := cPart
                  alil->(dbUnLock())
               Endif
            Endif
         NEXT*/
      Endif
      nP++
   ENDDO
NEXT

? "DONE. Press any key."
Inkey(0,128)