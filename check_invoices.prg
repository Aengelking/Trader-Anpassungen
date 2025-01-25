#define CRLF Chr(13)+Chr(10)

PROCEDURE Check_Invoices

   /** SETTINGS **/
   LOCAL aExclude := {"CONNECTS","HECK"} //{"BULGIN","CONNECTS","HOPA","HECK","WETEC","EUROCIRC","FARNELL","GUDECO","RS","RGR","RATIOFOR","TECHNO"}
   LOCAL aSammel := {"RS","BSLASER","SIGNAL","BEHINDER"}
   LOCAL lDue //:= AddWorkingDays(Date(),-5,GetConfigValue("state"),.F.) //StoD("20201231")
   LOCAL nDaysBeforePayment := GetValue("REB_TOLDATE",2,"Toleranz fr Zahldatum")+3   
   /****/   

   LOCAL cLiefma,hDelNotes := {=>},hMissing := {=>},hDels,hDel
   LOCAL cKey,nPosnr,nBesnr,nRec,dLastDel,nQty,nX,cBeleg,cMiskey,nMenge,oPrinter,oPdf
   LOCAL aErl := {}
   LOCAL aSkonto
   LOCAL hBes
   
   LOCAL cText 

   NetUse("engabg","abg")
   NetUse("artikel","art")
   NetUse("engbes","bes")
   NetUse("rechpos","rpos")
   NetUse("engrech","rech")
   NetUse("me","me")
   NetUse("engkund","ku")
   NetUse("reb","reb")
   NetUse("rebnotes","rebn")
   NetUse("rebprot","rebp")
   NetUse("skontob","skb")

CLS

//COLLECT DELIVERY NOTES
abg->(dbSetOrder(4))
abg->(dbGoTop())
//abg->(dbSeek("EDAC",.T.))

DO WHILE ! abg->(EOF())
   cLiefma := abg->Liefma
   @ 01,00 SAY cLiefma
   @ 02,00 CLEAR

   IF AScan(aExclude,Trim(cLiefma)) != 0
      DO WHILE ! abg->(Eof()) .AND. abg->Liefma == cLiefma
         abg->(dbSkip())
      ENDDO
   ELSE

      DO WHILE ! abg->(Eof()) .AND. abg->Liefma == cLiefma
         IF Trim(abg->BuArt) == "WE" .AND. ! Empty(abg->Liefma) //StoD("20100101")
            @ 01,00 SAY abg->Liefma+abg->Beleg
            //? abg->Liefma+" "+abg->Beleg+" "+DToC(abg->Datum)
            cKey := abg->Liefma+Str(abg->Besnr,6)+Str(abg->bespos,3) //abg->Matchcode
            IF ! HHasKey(hDelNotes,cKey)
               hDelNotes[cKey] := {=>}
            ENDIF
            IF ! HHasKey(hDelNotes[cKey],abg->Beleg)
               hDelNotes[cKey][abg->Beleg] := {"liefma"=>abg->Liefma,"beleg"=>abg->Beleg,"date"=>abg->Datum,"matchcode"=>abg->Matchcode,"menge"=>abg->Menge,"besnr"=>abg->Besnr,"pos"=>abg->bespos}
            ELSE
               hDelNotes[cKey][abg->Beleg]["menge"] += abg->Menge
            ENDIF   		
         ENDIF
         abg->(dbSkip())
      ENDDO

      bes->(dbSetOrder( 2 ))
      bes->(dbSeek( cLiefma + Str(1,3) , .T. ))

      DO WHILE ! bes->(EOF()) .AND. bes->Liefma == cLiefma .AND. bes->Bestat < 3 .AND. Inkey() != 27
         art->(dbSetOrder( 1 ))
         art->(dbSeek( bes->Matchcode ))
         IF ! art->Lagerart
            nPosnr := bes->Posnr
            nBesnr := bes->Besnr
            bes->(dbSkip())
            IF bes->besnr == nBesnr .AND. bes->Folgeto == nPosnr
               art->(dbSeek( bes->Matchcode ))
            ELSE
               bes->(dbSkip(-1))
            ENDIF
         ENDIF
         nRec := NIL

         IF bes->GelQty > 0 .AND. bes->GelQty <= 10 .AND. bes->EkPr == 0  .AND. bes->Besda <= Date()-120 //wahrscheinlich Muster, werden auf erledigt gesetzt
            ? "Bestellung erledigt",bes->Besnr,bes->Posnr
            Aadd(aErl,Str(bes->Besnr,6)+" - "+Str(bes->posnr,3))
            bes->(dbSkip(1)) //goto next record and remember the position
            nRec := bes->(Recno())
            bes->(dbSkip(-1))
            bes->(Rec_Lock(0))
            bes->BeStat := 3
            bes->(dbUnLock())
         ELSEIF ((bes->GelQty < 0 .AND. bes->ZoQty < 0) .OR. (bes->GelQty > 0 .AND. bes->ZoQty > IF(bes->GelQty>bes->BeQty,bes->GelQty-bes->BeQty,0) .AND. bes->EkPr != 0) .OR. (! art->Lagerart .AND. bes->BeQty < 0)) .AND. Year(bes->Besda) >= 2018 //.AND. bes->Besda < Date()-30
            cKey := bes->Liefma+Str(bes->Besnr,6)+Str(bes->PosNr,3) //abg->Matchcode
            ? "Suche Lieferschein",bes->Besnr,bes->Posnr
            IF HHAsKey(hDelNotes,cKey)
               dLastDel := CToD("")
               FOR EACH hDel IN hDelNotes[cKey]
                  IF hDel["date"] > dLastDel
                     dLastDel := hDel["date"]
                  ENDIF
               NEXT

               ku->(dbSeek( bes->Liefma+"L" ))

               IF skb->(IsPrepay( ku->Skonto ))                  
                  lDue := dLastDel < Date()-15
               ELSE
                  aSkonto := skb->(GetSkonto(ku->Skonto,dLastDel))                                    
                  lDue := dLastDel+IF(aSkonto[1,2]==0.AND.Len(aSkonto)>1,aSkonto[2,2],aSkonto[1,2])-nDaysBeforePayment <= Date()
               ENDIF

               
               IF (! Trim(cLiefma) $ aSammel .OR. Month(dLastDel) < Month(Date())) .AND. lDue//ignore positions where there has been a delivery in the last 5 days, and by RS only if it is from the last month (Sammelrechnung)                  
                  nQty := bes->ZoQty
                  FOR nX := Len(hDelNotes[cKey]) TO 1 STEP -1
                     hDel := HGetValueAt(hDelNotes[cKey],nX)
                     hDel["AB"] := bes->AbNr
                     cBeleg := Trim(hDel["beleg"])
                     cMisKey := bes->Liefma+cBeleg
                     IF ! HHasKey(hMissing,cMisKey)
                        //? cBeleg
                        hMissing[cMisKey] := {}
                     ENDIF
                     Aadd(hMissing[cMisKey],hDel)
                     IF bes->ZoQty < 0
                        nQty += hDel["menge"]
                     ELSE
                        nQty -= hDel["menge"]
                     ENDIF
                     IF (bes->ZoQty < 0 .AND. nQty >= 0) .OR. (bes->ZoQty >= 0 .AND. nQty <= 0)
                        EXIT
                     ENDIF
                  NEXT
               ELSE
                  ? "Zahlung noch nicht bald f„llig"                  
               ENDIF
            ELSE
               cBeleg := Replicate("-",15)               
               cMisKey := bes->Liefma+"B"+LTrim(Str(bes->Besnr))+"/"+Ltrim(Str(bes->Posnr))
               nMenge := IF(!art->Lagerart.AND.bes->BeQty<0,bes->BeQty,bes->GelQty)
               IF ! HHasKey(hMissing,cMisKey)
                  hMissing[cMisKey] := {{"beleg"=>cBeleg,"liefma"=>bes->Liefma,"besnr"=>bes->Besnr,"date"=>bes->Besda,"menge"=>nMenge,"matchcode"=>bes->Matchcode,"AB"=>bes->Abnr}}
               ELSE
                  hMissing[cMisKey][1]["menge"] += nMenge
               ENDIF
      //         ?? "Kein LS"
            ENDIF
         ENDIF
         IF nRec != NIL //we have remember the next position, goto this record
            bes->(dbGoTo(nRec))
         ELSE
            bes->(dbSkip())
         ENDIF
      ENDDO
   ENDIF
ENDDO

  cLiefma := ""
  hBes := {}
  FOR nX := 1 TO 2
      ? IF(nX==1,"Fehlende Gutschriften","Nicht gebuchte Rechnungen")

      FOR EACH hDels IN hMissing
        art->(dbSetOrder( 1 ))
        
         IF AScan(hDels,{|hDel| IF(nX==1,hDel["menge"]<0,hDel["menge"]>0)}) > 0
            ? hDels[1]["liefma"]+" "+Pad(hDels[1]["beleg"],15)

            FOR EACH hDel IN hDels //nX := 1 TO Len(hDel)
               ? Str(hDel["besnr"],6)
               IF ! hDel["besnr"] $ hBes
                  Aadd(hBes,hDel["besnr"])
               ENDIF
               IF (nX == 1 .AND. hDel["menge"] < 0) .OR. (nX == 2 .AND. hDel["menge"] > 0)                     
                  art->(dbSeek( hDel["matchcode"] ))
                     IF cLiefma != hDel["liefma"]
                           IF ! Empty(cLiefma) .AND. ! Empty(cText)
                              ku->(dbSeek( cLiefma+"L" ))

                              reb->(dbSetOrder( 6 ))
                              reb->(dbSeek( Str(ku->Nummer,6) ))
                              rebp->(dbSetOrder( 1 ))
                              cText += "<br><h3>Nicht verbuchte Rechnungen:</h3>"
                              cText += Pad("Beleg.nr.",30)+" "+"Eingangsdat."
                              DO WHILE reb->Liefnr == ku->Nummer .AND. ! reb->(Eof())
                                 IF reb->Status < 8                                    
                                    rebp->(dbSeek( Str(reb->ID,9), .T. ))
                                    cText += CRLF+reb->Beleg+" "+DtoC(Stot(rebp->DateTime))
                                 ENDIF   
                                 reb->(dbSkip())                                 
                              ENDDO
                              FOR EACH nBesnr IN hBes
                                 cText += GetNotesForEmail("BES",nBesnr,.T.)
                              NEXT
                                                               
                              SendMail({{"amos.engelking@engelking.de","Amos"}},IF(nX==1,"Gutschriften","Rechnungen")+" fehlen von "+cLiefma,cText)
                              hBes := {}
                           ENDIF
                           cText := "Bes.Nr"+" "+Pad("Datum",8)+" "+Pad("Menge",12)+" "+Pad("Artikel",25)+"AB-Nr."
                           cLiefma := hDel["liefma"]
                     ENDIF
                     IF ! Empty(cText)
                           cText += Chr(13)+Chr(10)
                     ENDIF
                     cText += Str(hDel["besnr"],6)+" "+DToC(hDel["date"])+" "+Pad(Transform(hDel["menge"],Me(art->me)),12)+" "+hDel["matchcode"]+IF(nX==1,hDel["AB"],"")
               ENDIF
            NEXT
         ENDIF
     NEXT
  NEXT

  rech->(dbClearFilter())

RETURN