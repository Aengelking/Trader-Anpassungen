PROC RUN_REPORT_RECH_ABGR
LOCAL aMonths := Array(12)
LOCAL dStart := StoD("20231201")
LOCAL nYear := 2024
LOCAL nM,nMonth,nAmount
LOCAL hLS := {=>}
LOCAL cKey,nMenge,nInv,nRoh,dEOM,lCurrent

AFill(aMonths,0)

Head("Rechnungsabgrenzung berechnen")

NetUse("lspos","lsp")
NetUse("ls","ls")
//NetUse("lsbook","lsbk")
NetUse("rechpos","rpos")
NetUse("engbes","bes")
NetUse("artikel","art")
NetUse("engrech","rech")
NetUse("inventur","inv")
NetUse("stats","st",.F.,0)

inv->(dbSetOrder( 2 ))
lsp->(dbSetOrder( 3 ))
rech->(dbsetOrder(3))
rech->(dbSeek( DtoS(dStart),.T. ))

Do While ! rech->(EOF())
   //? rech->RechDat,rech->Liefma

   rpos->(dbSeek( rech->Liefma+rech->Rechnr ))
   DO WHILE rpos->Liefma == rech->Liefma .AND. rpos->Beleg == rech->Rechnr
      //? rpos->Besnr,rpos->Posnr
      IF rpos->Besnr != 0
         lsp->(dbSeek( Str(rpos->Besnr,6)+Str(rpos->Posnr,3) )) 
         //bes->(dbSeek( Str(rpos->Besnr,6)+Str(rpos->Bespos,3) ))              
         DO WHILE lsp->Besnr == rpos->Besnr .AND. lsp->Bespos == rpos->Posnr
            ls->(dbSeek( lsp->Liefma+lsp->Beleg ))
            //?? DToC(ls->Datum)
            nMonth := Month(ls->Datum)
            IF nMonth != Month(rech->RechDat)
               nMenge := Min(lsp->Menge,rpos->Menge)
               cKey := lsp->Beleg+Str(lsp->Pos)
               IF HHasKey(hLS,cKey)
                  nMenge -= hLS[cKey]
                  IF nMenge < 0
                     nMenge := 0
                  ENDIF
                  hLS[cKey] += nMenge
               ELSE
                  hLS[cKey] := nMenge
               ENDIF
               IF nMenge > 0
               nAmount := nMenge*rpos->EkPr/rpos->Pe*(1-rpos->Rabatt/100)*rech->Rate
               ? rech->RechDat,ls->Datum,rech->Liefma,rech->Rechnr,rpos->Besnr,rpos->Posnr,nMonth,nAmount
               
               IF Year(rech->Rechdat) == nYear
                  IF Month(rech->Rechdat) == 5
                    // Sinkey(0)
                  ENDIF
                  aMonths[Month(rech->RechDat)] -= nAmount
               ENDIF
               IF Year(ls->Datum) == nYear
                  aMonths[nMonth] += nAmount
               ENDIF
            ENDIF
            ENDIF
            lsp->(dbSkip())   
         ENDDO
      ENDIF
      rpos->(dbSkip())
   ENDDO
   
   IF inkey() == 27
      EXIT  
   ENDIF
   rech->(dbSkip())
ENDDO


/*bes->(dbGoTop())
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
ENDDO*/
? "Monat",Pad("RAP",12),Pad("Einkauf",12),Pad("Bestandsver.",12),Pad("Umsatz",12),Pad("Rohertr.",12),,Pad("Rohertr.+RAP",12)
nTotUmsatz := nTotRoh := 0
FOR nM := 1 TO 12
   dEOM := Eom(StoD(Str(nYear,4)+StrZero(nM,2)+"01"))
   lCurrent := nM == Month(Date())
   st->(dbSeek( Str(nYear,4)+Str(nM,3)  ))
   inv->(dbSeek( Descend(DtoS(IF(lCurrent,Date(),dEoM))), .T. ))
   nInv := inv->Rhb+inv->Ware+inv->Unfertig
   inv->(dbSeek( Descend(DtoS(Eom(AddMonth(IF(lCurrent,Date(),dEoM),-1)))), .T. ))
   nInv -= inv->Rhb+inv->Ware+inv->Unfertig
   nRoh := st->Billings-st->Invoices+nInv
   ? Str(nM,5),Str(aMonths[nM],12,2),st->Invoices,nInv,Str(st->Billings,12,2),Str(nRoh,12,2),Str(nRoh-aMonths[nM],12,2),IF(st->Billings!=0,(nRoh-aMonths[nM])/st->Billings,"")
   nTotUmsatz += st->Billings
   nTotRoh    += nRoh-aMonths[nM]
NEXT
? nTotUmsatz,nTotRoh,nTotRoh/nTotUmsatz
Inkey(0,128)
