//search for products which can be made from one part
PROC STOCK_USE
   
   LOCAL nArtnr := 11925
   LOCAL getlist := {}
   
   Head("Aufbrauchen von Lagerbest„nden")
   @ 01,00 SAY "Artikelnr." GET nArtnr
   READ

   IF LastKey() == 27
      RETURN
   ENDIF

   //? "Fertigbare Menge:",QtyProducible(nArtNr)

   NetUse("parts","part",.F.,0)
   NetUse("artikel","art")

   part->(dbSetOrder(2))
   art->(dbSetOrder(2))

   part->(dbSeek( Str(nArtNr,6), .T. ))

   DO WHILE part->PartArt == nArtnr .AND. ! part->(EOF())
      art->(dbSeek( Str(part->ListArt,6) ))
      ? art->Matchcode,QtyProducible(part->ListArt) 
      part->(dbSkip())
   ENDDO

   Sinkey(0)
RETURN 

FUNCTION QtyProducible(nArtnr,nEndStep)   
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
   nTot := _QtyProducable(nArtnr,nEndStep,1,1)

 
   RestEnv(aEnv,.F.)
Return nTot

STATIC Function _QtyProducable(nArtnr,nEndStep,nStep,nFactor)
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

      IF art->bezug >= 5 .AND. nStep+1 <= nEndStep //Fertigungsartikel         
         nStock := 0 //_QtyProducable(art->Artikelnr,nEndStep,nStep+1,1/part->qty/part->Factor)         
      ELSE //kein Fertigungsartikel oder End-Baustufe erreicht, verfgbarer Lagerbestand verwenden         
         IF part->Qty > 0
            ali->(dbSetOrder( 1 ))
            IF ali->(dbSeek( Pad("TECHNO",8)+Str(art->Artikelnr,6) )) // == 17127 //Fehlende Deckel, k”nnen bestellt werden
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
