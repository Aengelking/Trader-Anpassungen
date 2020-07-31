LOCAL aMonths := Array(12)

Head("Rechnungsabgrenzung berechnen")

NetUse("lspos","lsp")
NetUse("lsbook","lsbk")
NetUse("rechpos","rpos")
NetUse("engbes","bes")
NetUse("artikel","art")
NetUse("engrech","rech")

AFill(aMonths,0)

bes->(dbGoTop())
DO WHILE ! bes->(EOF())
   art->(dbSetORder( 2 ))
   art->(dbSeek( Str(bes->Artikelnr,6) ))

//   bes->(dbSeek( Str(rpos->Besnr,6)+Str(rpos->Bespos,3) ))
   IF art->LagerArt
      rpos->(dbSetOrder( 2 ))
      rpos->(dbSeek( Str(bes->Besnr,6)+Str(bes->Posnr,3) ))

      IF YEAR(rpos->Date) == 2013
         rech->( dbSeek( rpos->Liefma+rpos->Beleg ))

         DO WHILE rpos->Besnr == bes->Besnr .AND. rpos->Posnr == bes->Posnr .AND. rpos->Menge > 0 .AND. rpos->EkPr > 0 
            nZoQty := rpos->Menge

            lsp->(dbSetOrder( 3 ))
            lsp->(dbSeek( Str(rpos->Besnr,6)+Str(rpos->posnr,3) ))
            DO WHILE lsp->Besnr == rpos->Besnr .AND. lsp->Bespos == rpos->posnr
               lsbk->(dbSeek( Str(lsp->LsPosnr,10) ))
               DO WHILE lsbk->LsPosnr == lsp->LsPosnr
                  IF lsbk->Datum <= EOM(rpos->Date) .AND. Year(lsbk->Datum) == 2013
                     nZoQty -= lsbk->Menge //rpos->Menge*rpos->EkPr/rpos->Pe*(1-rpos->Rabatt/100)*rech->Rate
//                     aMonths[Month(lsbk->Datum)] += nAmount
                  ENDIF
                  lsbk->(dbSkip())
               ENDDO
               lsp->(dbSkip())
            ENDDO
            IF nZoQty > 0
               aMonths[Month(rpos->Date)] += nZoQty*rpos->EkPr/rpos->Pe*(1-rpos->Rabatt/100)*rech->Rate
            ENDIF
            rpos->(dbSkip())
         ENDDO
      ENDIF
   ENDIF
   bes->(dbSkip())
ENDDO

FOR nM := 1 TO 12
   ? nM,Str(aMonths[nM],12,2)
NEXT
Inkey(0,128)
