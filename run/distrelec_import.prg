LOCAL aParts,aBrands,oHtml,oHttp
LOCAL aRegex,aRegexAll
LOCAL cLief := Pad("DISTRELEC",8)
LOCAL nArtnr := 0

NetUse("artlief","alil",.F.,0)
NetUse("artikel","art",.F.,0)
CLS

aParts := {}
aBrands := {"bulgin"} //,"itw-switches"}

alil->(dbSetOrder( 1 ))

//replace schurich with distrelec, the program had not been changed!
/*alil->(dbSeek( Pad("SCHURICH",8) ))
DO WHILE Trim(alil->Kunde) == "SCHURICH" .AND. ! alil->(EOF())
   alil->(Rec_Lock())
   alil->Kunde := cLief
   alil->(dbUnLock())
   alil->(dbSkip())
ENDDO*/

//Remove duplicates
/*alil->(dbSeek( cLief ))
DO WHILE alil->Kunde == cLief
   IF alil->Artikelnr == nArtnr
      alil->(Rec_Lock())
      alil->(dbDelete())
      alil->(dbUnlock())
   ELSE
      nArtnr := alil->Artikelnr
   ENDIF
   alil->(dbSkip())
ENDDO */

FOR nX := 1 TO Len(aBrands)
   nLast := 99999
   FOR nNo := 1 TO nLast
      ? "Seite: "+Ltrim(Str(nNo))
   	//cUrl := "http://www.conrad.biz/ce/de/Search.html?search="+aBrands[nX]+"&page="+LTrim(Str(nNo))
   	cUrl := "https://www.distrelec.de/de/manufacturer/"+aBrands[nX]+"/man_"+Left(aBrands[nX],3)+"?pageSize=100&page="+Ltrim(Str(nNo)) //100 per Page seems to be max

   	oHttp := TIpClientHttp():new( cUrl )
      oHttp:nConnTimeout := 10000
   	If oHttp:open()
   		cData := oHttp:ReadAll()
   		IF cData == NIL
   		 LOOP
   		ENDIF
   		IF nLast == 99999 //look for number of pages
            aRegex := HB_Regex("ul.*pagination(?:.*\R.*){1,10}>([^<]{1,}).*<\/li>\R.*<\/ul>",cData) //(.*\R.*){1,100}([0-9]{1,2}).*<\/li>\R.*<\/ul>",cData,.T.,.T.)

            IF Len(aRegex) == 2
               //Alert("Page count;"+ValToPrg(aRegex))
               nLast := Val(aRegex[2])
            ELSE
               //Alert("No page count;"+ValToPrg(aRegex))
               EXIT
            ENDIF
         ENDIF
         IF nNo == 4
            gtSetClipboard( cData )
         ENDIF

         aRegexAll := HB_RegExAll("Art.Nr.*<span.*>\s*([0-9\-]{1,})(?:.*\R.*){1,20}Typ.*\R[^>]*>([^<]*)",cData)
         IF Len(aRegexAll) == 0 //no more records found
            EXIT
         ENDIF
         FOR EACH aRegex IN aRegexAll
            ? aRegex[3]
            IF art->(dbSeek( aRegex[3] )) .AND. Trim(art->Matchcode) == Trim(aRegex[3])
               IF alil->(dbSeek( cLief+Str(art->Artikelnr,6) ))
                  ?? " update"
                  alil->(Rec_Lock())
               ELSE
                  ?? " new"
                  alil->(Add_Rec())
                  alil->Artikelnr := art->Artikelnr
                  alil->Matchcode := art->Matchcode
                  alil->Kunde     := cLief
               ENDIF
               alil->ArtLief := aRegex[2]
               alil->(dbUnLock())
            ELSE
               ?? " NOT FOUND"
            ENDIF
         NEXT
      ENDIF
   NEXT
NEXT
? "DONE"
SInkey(0,128)