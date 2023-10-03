//search for products which can be made from one part
PROC STOCK_USE
   
   LOCAL nArtnr := 0
   LOCAL lBuy := .T.
   LOCAL lManu := .T.
   LOCAL lNeed := .F.
   LOCAL getlist := {}

   NetUse("parts","part",.F.,0)
   NetUse("artikel","art")

   art->(dbSetOrder(2))
   
   Head("Aufbrauchen von Lagerbest„nden")
   DO WHILE .T.
      @ 01,00 SAY "Artikelnummer     " GET nArtnr PICTURE "999999" VALID {||
         IF nArtnr == 0 .OR. ! art->(dbSeek(Str(nArtnr,6)))
            @ 01,26 SAY Space(25)
            RETURN .F.
         ENDIF
         @ 01,26 SAY art->Matchcode
         RETURN .T.
      }
      @ 02,00 SAY "Artikel zukaufen  " GET lBuy PICTURE "Y"
      @ 03,00 SAY "Artikel herstellen" GET lManu PICTURE "Y"
      @ 04,00 SAY "Nur mit Bedarf    " GET lNeed PICTURE "Y"
      READ

      IF LastKey() == 27
         RETURN
      ENDIF

      //? "Fertigbare Menge:",QtyProducible(nArtNr)


      part->(dbSetOrder(2))

      @ 05,00 CLEAR           
      
      

      part->(dbSeek( Str(nArtNr,6), .T. ))
   
      @ 05,00 SAY "Matchcode"
      @ 05,26 SAY PadL("Menge",12)
      @ 05,39 SAY PadL("Bedarf/Monat",12)
      DO WHILE part->PartArt == nArtnr .AND. ! part->(EOF())
         art->(dbSeek( Str(part->ListArt,6) ))
         hReqInc := GetProductRequirementAndIncoming(art->artikelnr)
         IF ! lNeed .OR. hReqInc["avgrequirement"] > 0
            ? art->Matchcode,PadL(Transform(QtyProducible(part->ListArt,,lBuy,lManu,nArtnr),Me(art->Me)),12),PadL(Transform(hReqInc["avgrequirement"],Me(art->Me)),12)
         ENDIF
         part->(dbSkip())
      ENDDO

   ENDDO   
RETURN 

FUNCTION QtyProducible(nArtnr,nEndStep,lBuy,lManu,nPart)   
   Local aEnv := SaveEnv(),nTot,nX,xKey,nTot2 := 0
   
   Default(@nEndStep,99)
   
   NetUse("artikel","art",.F.,0)
   NetUse("parts","part",.F.,0)
   NetUse("artlief","ali")

   NetUse("manufact","manu",.F.,0)

   art->(dbSetOrder(2))
   If ! art->(dbSeek(Str(nArtnr,6))) .OR. ! part->(dbSeek( Str(nArtnr,6) )) //we do note use art->Bezug then we can also check on purchasable parts
      RestEnv(aEnv,.F.)
      RETURN 0
   Endif
   
   nTot := _QtyProducable(nArtnr,nEndStep,1,1,lBuy,lManu,nPart)

 
   RestEnv(aEnv,.F.)
Return nTot

STATIC Function _QtyProducable(nArtnr,nEndStep,nStep,nFactor,lBuy,lManu,nPart)
   LOCAL nProducible,nStock,nRec := part->(Recno())


   part->(dbSetOrder(1))
   If ! part->(dbSeek( Str(nArtnr,6) )) //doch kein Fertigungsartikel
      art->(dbSetOrder(2))
      art->(dbSeek( Str(nArtnr,6) ))
      part->(dbGoTo(nRec))

      nProducible := LagGetStock(nArtnr,1)*nFactor
      
      return nProducible
   Endif
   
   DO WHILE part->Pos == 0 .AND. ! part->(EOF())
      part->(dbSkip()) //skip the header
   ENDDO


   DO WHILE ! part->(EOF()) .AND. (part->listart == nArtnr)
      art->(dbSetOrder(2))
      IF ! art->(dbSEEK(str(part->partart,6)))
         part->(dbGoTo(nRec))
         RETURN 0
      ENDIF

      IF lManu .AND. art->bezug >= 5 .AND. nStep+1 <= nEndStep //Fertigungsartikel         
         nStock := _QtyProducable(art->Artikelnr,nEndStep,nStep+1,1/part->qty/part->Factor,lBuy,nPart)         
      ELSE //kein Fertigungsartikel oder End-Baustufe erreicht, verfgbarer Lagerbestand verwenden         
         IF part->Qty > 0
            ali->(dbSetOrder( 1 ))
            IF lBuy .AND. art->Artikelnr != nPart .AND. ali->(dbSeek( Pad("TECHNO",8)+Str(art->Artikelnr,6) )) //Fehlende Artikel, k”nnen bestellt werden
               nStock := 999999 
            ELSE               
               nStock := LagGetStock(art->Artikelnr,1)
            ENDIF
            nStock := (nStock/part->Qty)/part->Factor*nFactor //wir k”nnten noch in die Zukunft schauen welche Artikel innerhalb der Lieferzeit verbraucht werden                                    
            IF Round(nStock,GetMeDecimals(art->Me)) > nStock //it has been rounded up            
               nStock := Round(nStock,GetMeDecimals(art->Me))- (1/10^GetMeDecimals(art->Me))
            ELSE
               nStock := Round(nStock,GetMeDecimals(art->Me))
            ENDIF
            //? art->Matchcode,nStock
         ENDIF
      ENDIF        
      IF nProducible == NIL .OR. nStock < nProducible
         nProducible := nStock
      ENDIF       
      
      part->(dbSkip())
   ENDDO
   part->(dbGoTo(nRec))
RETURN nProducible
