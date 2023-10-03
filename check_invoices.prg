PROCEDURE Check_Invoices

   /** SETTINGS **/
   LOCAL aExclude := {"CONNECTS","HECK"} //{"BULGIN","CONNECTS","HOPA","HECK","WETEC","EUROCIRC","FARNELL","GUDECO","RS","RGR","RATIOFOR","TECHNO"}
   LOCAL aSammel := {"RS","BSLASER","SIGNAL","BEHINDER"}
   LOCAL lDue //:= AddWorkingDays(Date(),-5,GetConfigValue("state"),.F.) //StoD("20201231")
   LOCAL nDaysBeforePayment := 5
   /****/   

   LOCAL cLiefma,hDelNotes := {=>},hMissing := {=>},hDels,hDel
   LOCAL cKey,nPosnr,nBesnr,nRec,dLastDel,nQty,nX,cBeleg,cMiskey,nMenge,oPrinter,oPdf
   LOCAL aErl := {}
   LOCAL aSkonto
   
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
         //IF AScan(aExclude,Trim(bes->Liefma)) != 0
            //ignore these
         //ELSE
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
                  //FOR EACH hDel IN hDelNotes[cKey]
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
               //cMisKey := bes->Liefma+cBeleg
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

//IF Len(hMissing) > 0
  SetConfigValue("BATCHMODE",.T.)
  SetPrinterMethodType(3)
  StartPrint(,,"PDF")
  oPrinter := GetCurrentPrinterObject()
  oPrinter:Email := "amos.engelking@engelking.de"
  oPrinter:Subject := "Nicht gebuchte Rechnungen"
  oPdf := oPrinter:Data
  oPdf:SetFont("COURIER")
  IF Len(aErl) > 0
      oPdf:NewPage()
      oPdf:AtSay("Erledigte Bestellungen")
      oPdf:NewLine()
      //oPdf:NewLine()
      FOR nX := 1 TO Len(aErl)
         oPdf:NewLine()
         oPdf:AtSay(aErl[nX])
      NEXT
  ENDIF
  cLiefma := ""
  FOR nX := 1 TO 2
     oPdf:NewPage()
     oPdf:AtSay(IF(nX==1,"Fehlende Gutschriften","Nicht gebuchte Rechnungen"))
     oPdf:NewLine()
     oPdf:NewLine()
     FOR EACH hDels IN hMissing
        art->(dbSetOrder( 1 ))
        //IF AT("MUSTER",Upper(hDel[1]["beleg"])) == 0 .AND. AT("SAMPLES",Upper(hDel[1]["beleg"])) == 0
           IF AScan(hDels,{|hDel| IF(nX==1,hDel["menge"]<0,hDel["menge"]>0)}) > 0
              IF hDels:__eNumIndex() > 1
               oPdf:NewLine()
              ENDIF
              oPdf:AtSay( hDels[1]["liefma"]+" "+Pad(hDels[1]["beleg"],15),,,"R" )
              FOR EACH hDel IN hDels //nX := 1 TO Len(hDel)
                  IF (nX == 1 .AND. hDel["menge"] < 0) .OR. (nX == 2 .AND. hDel["menge"] > 0)                     
                    art->(dbSeek( hDel["matchcode"] ))
                    IF hDel:__eNumIndex() > 1
                     oPdf:NewLine()
                    ENDIF
                    oPdf:AtSay( IF(hDel:__eNumIndex() > 1,Space(8+1+15),"")+Str(hDel["besnr"],6)+" "+DToC(hDel["date"])+" "+Pad(Transform(hDel["menge"],Me(art->me)),12)+" "+hDel["matchcode"]+IF(nX==1,hDel["AB"],""),,,"R" )

                    IF nX == 2
                        IF cLiefma != hDel["liefma"]
                              IF ! Empty(cLiefma) .AND. ! Empty(cText)
                                 //Would be good to add information about unbooked invoices
                                 SendMail({{"amos.engelking@engelking.de","Amos"}},"Rechnungen fehlen von "+cLiefma,cText)
                              ENDIF
                              cText := "Bes.Nr"+" "+Pad("Datum")+" "+Pad("Menge",12)+" "+Pad("Artikel",25)+"AB-Nr."
                              cLiefma := hDel["liefma"]
                        ENDIF
                        IF ! Empty(cText)
                              cText += Chr(13)+Chr(10)
                        ENDIF
                        cText += Str(hDel["besnr"],6)+" "+DToC(hDel["date"])+" "+Pad(Transform(hDel["menge"],Me(art->me)),12)+" "+hDel["matchcode"]+IF(nX==1,hDel["AB"],"")
                     ENDIF

                  ENDIF
              NEXT
            ENDIF
        //ENDIF
     NEXT
  NEXT
  oPdf:NewPage()
  oPdf:AtSay("Nicht übertragene Rechnungen")
  oPdf:NewLine()
  oPdf:NewLine()

  rech->(dbSetOrder( 3 ))
  rech->(dbSetFilter({|| ! rech->Transfer .AND. Trim(rech->Liefma) != "CONNECTS"},"! transfer .AND. Trim(liefma) != 'CONNECTS'"))
  rech->(dbSeek( "20120101", .T. ))
  reb->(dbSetOrder( 2 ))

  DO WHILE Year(rech->Rechdat) >= 2012 .AND. ! rech->(Eof())
      ku->(dbSeek( rech->Liefma+"L" ))
      oPdf:NewLine()
      oPdf:AtSay( rech->Liefma+" "+rech->Rechnr+" "+DToC(rech->Rechdat)+" "+Str(rech->Gramt,8,2)+" "+IF(rech->Booked,"abgeschlossen","offen") )
      IF reb->(dbSeek( Str(ku->Nummer,6)+rech->Rechnr )) .AND. rebn->(dbSeek(Str(reb->Id,9)))
         oPdf:AtSay( " "+HB_OemToAnsi(StrTran(StrTran(rebn->Notes,Chr(13)," "),Chr(10)," ")) )
      ENDIF
      rech->(dbSkip())
  ENDDO
  
  rech->(dbClearFilter())

  CopyPrint()
  SetPrinterMethodType(0)
  SetConfigValue("BATCHMODE",.F.)