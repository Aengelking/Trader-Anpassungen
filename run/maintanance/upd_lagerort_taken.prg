PROC RUN_UPD_LAGERORT_TAKEN
   LOCAL nDash,cRechnr,cPosnr,nRechnr,nPosnr,nNr
   LOCAL cLag1,cLag2,nPos
   LOCAL lTaken
   LOCAL aList := {}
   
   NetUse("engabg","abg")
   NetUse("englsre","re")
   NetUse("lagrech","lagr")
   NetUse("lagerne","lne")
   NetUse("lagent","lage")
   NetUse("lager","lag")
   NetUse("artikel","art")

   CLS
 
   

   Select("lag")
   SET FILTER TO lag->Taken

   lag->(dbGoTop())
   DO WHILE ! lag->(EOF()) .AND. Inkey(,128) != 27 
      IF Left(lag->Lagerort,3) <= "003" .AND. ! (lag->Lagerort >= "000/03A017" .AND. lag->Lagerort <= "000/03A076") .AND. ! (lag->Lagerort >= "000/04A017" .AND. lag->Lagerort <= "000/04A076")
         lTaken := .F.   
         art->(dbSetOrder( 2 ))
         art->(dbSeek( Str(lag->Artikelnr,6) ))
         //? art->Matchcode,lag->Artikelnr,lag->Lagerort         
         abg->(dbSeek( Descend(art->Matchcode) ))
         DO WHILE ! abg->(EOF()) .AND. abg->Matchcode == art->Matchcode  .AND. ! lTaken 
            IF Trim(abg->Buart) $ {"RNR","RAŽ","ZUG","ABG","ENT","ENŽ","INV"}
               //? abg->Datum,abg->Buart,abg->Menge,abg->Info
               IF Trim(abg->Buart) $ {"RNR","RAŽ"}
                  re->(dbSetOrder( 12 ))
                  nDash := AT("-",abg->Beleg)
                  cRechnr := PadL(SubStr(abg->Beleg,1,nDash),6)
                  cPosnr  := PadL(SubStr(abg->Beleg,nDash+1),3)
                  nRechnr := Val(cRechnr)
                  nPosnr  := Val(cPosnr)
            
                  lagr->(dbSeeK( cRechnr+cPosnr+STR(abg->Besnr,6) ))
                  DO WHILE lagr->Rechnr == nRechnr .AND. lagr->RePosnr == nPosnr .AND. lagr->Abnr == abg->Besnr
                     IF lagr->Lagerort == lag->Lagerort
                        lTaken := .T.
                     ENDIF
                     lagr->(dbSkip())
                  ENDDO
               ELSEIF Trim(abg->Buart) $ {"ENT","ENŽ"}
                  nNr := IF(Empty(abg->Beleg),abg->Besnr,Val(abg->Beleg))
                  lne->(dbSetOrder( 9 ))
                  lne->(dbSeeK( STR(nNr,6)+abg->Matchcode ))                  
                  //? lne->Nummer,nNr,abg->Beleg
                  

                  DO WHILE lne->Nummer == nNr .AND. lne->Matchcode == abg->Matchcode .AND. ! lne->(EOF())
                     lage->(dbSeek( Str(nNr,6)+Str(lne->Pos,3) ))
                     DO WHILE lage->Nummer == nNr .AND. lage->Pos == lne->pos .AND. ! lage->(EOF())
                        IF lage->Lagerort == lag->Lagerort
                           lTaken := .T.
                        ENDIF
                        lage->(dbSkip())
                     ENDDO
                     lne->(dbSkip())
                  ENDDO
               /*ELSEIF Trim(abg->Buart) == "UMB"
                  nPos := AT("=>",abg->Info)
                  cLag1 := Pad(SubStr(abg->Info,1,nPos-1),12)
                  cLag2 := Pad(SubStr(abg->Info,nPos+2),12)
                  ? cLag1,cLag2
                  IF cLag1 == lag->Lagerort .OR. cLag2 == lag->Lagerort
                     lTaken := .T.
                  ENDIF*/
               ELSEIF Trim(abg->Buart) == "INV"
                  IF Pad(abg->Info,12) == lag->Lagerort
                     EXIT
                  ENDIF            
               ELSE
                  IF Pad(abg->Info,12) == lag->Lagerort
                     lTaken := .T.
                  ENDIF
               ENDIF
               //?? "",IF(lTaken,"ja","nein")
               IF abg->Bestand == 0
                  EXIT
               ENDIF
            ENDIF
            abg->(dbSkip())
         ENDDO

         IF ! lTaken
            Aadd(aList,{art->Matchcode,lag->Artikelnr,lag->Lagerort})
            lag->(Rec_Lock(0))
            //lag->Taken := .F.
            lag->(dbUnLock())
         ENDIF
      ENDIF
      lag->(dbSkip())
   ENDDO

   lag->(dbClearFilter())


   StartPrint()
   SET DEVICE TO PRINTER
   SET PRINTER ON
   ASort(aList,,,{|x,y| x[3] < y[3] })
   FOR nX := 1 TO Len(aList)
      ? aList[nX,1],aList[nX,2],aList[nX,3]
   NEXT
   CopyPrint()
   SET DEVICE TO SCREEN
   SET PRINTER OFF

   ? "Press any key...."
   SInkey(0)


   


   