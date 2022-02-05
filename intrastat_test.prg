
FUNC Intrastat_test
   LOCAL lEG,lHasFolge
   LOCAL dStart := StoD("20200101")
   LOCAL dEnd   := StOD("20200131")

   LOCAL nYear,nMonth,hData := {=>}
   LOCAL nTotVal := 0

   NetUse("rechnung","reh")
   NetUse("englsre","re")
   NetUse("engkund","ku")
   NetUse("artikel","art")

   reh->(dbSetFilter({|| reh->Rechdat >= dStart .AND. rech->Rechdat <= dEnd /*.AND. (lKorrektur .OR. ! reh->Intrastat)*/ },"Rechdat >= StoD('"+DtoS(dStart)+"') .AND. Rechdat <= StoD('"+DtoS(dEnd)+"')" /*+IF(lKorrektur,""," .AND. ! Intrastat")*/ ))
   reh->(dbGoTop())

   re->(dbSetOrder( 12 ))
   art->(dbSetOrder( 2 ))

   CLS

   Do While ! reh->(Eof())
      
         ku->(dbSeek( Str(reh->KuNummer,6) ))
         TAXIT(reh->TaxCode,0,reh->Rechdat,.F.,@lEG)   
         nReVal := 0      

         If lEG .AND. re->(dbSeek( Str(reh->Rechnr,6) ))  //is EU-import and has positions
            Do While re->Rechnr == reh->Rechnr .AND. ! re->(Eof())
               IF re->REPosnr != 0 .AND. re->PosWt != 0 .AND. ! re->Folge
                  art->(dbSeek( Str(re->Artikelnr,6) ))
                  re->(dbSkip())
                  lHasFolge :=  re->Rechnr == reh->Rechnr .AND. re->Folge
                  re->(dbSkip(-1))
                  If art->Lagerart .OR. lHasFolge
                     /*if Empty(art->KnCode)
                        _IS_AddError("KN",hErrors)
                     Elseif ! kn->(dbSeek( Pad(StrTran(art->KnCode," ",""),10),.F. ))  //.OR. Pad(StrTran(art->KnCode," ",""),10) != Pad(StrTran(Kn->Code," ",""),10)
                        _IS_AddError("KN_WRONG",hErrors)
                     Elseif ! Empty(kn->SUPPLEMENT) .AND. Trim(kn->Supplement) != "p/st"
                        _IS_AddError("NO_SUPPLEMENT",hErrors)
                     Else*/
                        nYear := Year(reh->Rechdat)
                        nMonth := Month(reh->Rechdat)
                        If ! HHasKey(hData,nYear)
                           hData[nYear] := {=>}
                        Endif
                        If ! HHasKey(hData[nYear],nMonth)
                           hData[nYear][nMonth] := {=>}
                        Endif
                        /*nAG := 11 //Endgültiger Kauf mangels anderer Informationen
                        nVZ := 3 //Straßenverkehr mangels anderer Informationen
                        cKey := _IntraStatEinKey(nAG,nVZ)
                        If ! HHasKey(hData[nYear][nMonth],cKey)
                           hData[nYear][nMonth][cKey] := {;
                              "value"=>0,;
                              "weight"=>0,;
                              "VLD"=>ku->CountryIso,;  //Versendungsland
                              "BR"=>shIniData["LAENDER"]["Bestimmungsregion"],; //Bestimmungsregion
                              "AG"=>nAG,;     //Art des Geschäfts 
                              "VZ"=>nVZ,; //Verkehrszweig
                              "WNM"=>StrTran(Trim(art->KnCode)," ",""),; //Warennummer
                              "ULD"=>If(Empty(art->Ursprung),ku->CountryIso,art->Ursprung);
                           }
                        Endif*/                     

                        /*nWeight := If(!Empty(art->Gewicht),re->AoQty*art->Gewicht/1000,0.05/1000)
                        hData[nYear][nMonth][cKey]["value"] += re->PosWt
                        hData[nYear][nMonth][cKey]["weight"] += nWeight
                        If ! rech->Liefma+rech->Rechnr $ aInvoices
                           Aadd(aInvoices,rech->Liefma+rech->Rechnr)
                        Endif
                        Aadd(aInvoiceList,{rech->Liefma,rech->Rechnr,Trim(art->Matchcode),nValue,nWeight})*/
                        IF reh->Rechnr == 54916
                           ? re->Rechnr,re->Reposnr,re->Matchcode,re->PosWt
                        ENDIF
                        nTotVal += re->PosWt
                        nReVal += re->Poswt
                     Endif               
                  ENDIF
                  re->(dbSkip())
            Enddo
            ? reh->Rechnr,nReVal
         //Endif
      Endif
      reh->(dbSkip())
   Enddo
   reh->(dbClearFilter())
   //TxtClear()
   ? nTotVal
   Sinkey(0)