PROC FA_NOTSHIPPED
   LOCAL cWeek := CalWeek(Date())
   LOCAL cFilter := 'status == 0 .AND. termin <= '+cWeek
   LOCAL cText,nLiefma,lFound,hFreigabe,lFoundFreigabe
   LOCAL cTextFreigabe,cLine
   LOCAL nOrder,nReleaseQty,nPlanQty,nRec,nAufNo,nWeek
   NetUse("engkund","ku")
   NetUse("werkauf","wer")
   NetUSe("artikel","art")
   NetUse("ppf","ppf")
   
   art->(dbSetOrder( 2 ))

   wer->(dbSetOrder( 7 ))
   wer->(dbSetFilter({|| wer->(&(cFilter))},cFilter))

   CLS

   ku->(dbSetOrder( 8 ))

   
   FOR EACH nLiefma IN GetIdsWithExtraField("KU","FA_NOSHIP") //{Pad("WHTECH",8)}
      ku->(dbSeek( Str(nLiefma,6) ))
      
      IF ku->(ExtraData():New(nLiefma)):FA_NOSHIP
         wer->(dbSeek( ku->Kunde ))
         ? ku->Kunde
         lFound := .F.
         lFoundFreigabe := .F.

         cText := "Hallo,<br><br>das Beistellmaterial fÅr folgende FertigungsauftrÑge wurde nicht an "+Trim(ku->Kunde)+" versandt:<br><pre>"
         cText += "Auf.Nr "+Pad("Artikel",25)+" "+PadL("Menge",12)+" Woche"

         cTextFreigabe := "Hallo,<br><br>fÅr die folgende FertigungsauftrÑge ist die Freigabe nicht ausreichend:<br><pre>"
         cTextFreigabe += "Auf.Nr "+Pad("Artikel",25)+" "+PadL("Menge",12)+" Woche"
      
         DO WHILE ! wer->(EOF()) .AND. wer->Liefma == ku->Kunde
            art->(dbSeek( Str(wer->Artno,6) ))
         
            cLine := "<br>"+Str(wer->Aufno,6)+" "+art->Matchcode+" "+PadL(Transform(wer->Qty,Me(art->me)),12)+" "+NiceWeek(wer->Termin)
            ? cLine
            IF ! Empty(art->Zeichnung)
               hFreigabe := art->(GetFreigabeBesState(WAGetLiefnr()))            
               IF ! hFreigabe:lBes  
                  ?? " Freigabe nicht ausreichend"             
                  cTextFreigabe += cLine
                  lFoundFreigabe := .T.               
               ELSEIF hFreigabe:nMaxQty != 0
                  nOrder := wer->(dbSetOrder(2))
                  nRec := wer->(RecNo())
                  nAufNo := wer->Aufno
                  nWeek := wer->Termin
                  nPlanQty := 0
                  nReleaseQty := 0
                  wer->(dbSeek(Str(art->Artikelnr,6)))                  
                  DO WHILE wer->Artno == art->Artikelnr 
                     IF wer->Liefma == ku->Kunde .AND. wer->Aufno != nAufno
                        IF wer->Status >= 1 .AND. wer->Status <= 3 
                           nReleaseQty  += wer->Qty-wer->GelQty-wer->Planbad
                        ELSEIF wer->Status == 0 .AND. wer->Termin <= nWeek
                           nPlanQty += wer->Qty-wer->PlanBad
                        ENDIF
                     ENDIF
                     wer->(dbSkip())
                  ENDDO
                  wer->(dbSetOrder( nOrder ))
                  wer->(dbGoto(nRec))
                  If wer->Qty-wer->PlanBad+nReleaseQty+nPlanQty > hFreigabe:nMaxQty
                     cTextFreigabe += cLine+" "+t("(Max. "+Ltrim(Transform(hFreigabe:nMaxQty,Me(art->Me)))+" "+art->Me+")") // +"(Ist:"+Ltrim(Transform(wer->Qty-wer->PlanBad+nReleaseQty+nPlanQty,Me(art->Me)))+")")
                     lFoundFreigabe := .T.               
                  ELSE
                     cText += cLine
                     lFound := .T.
                  ENDIF
               ELSE
                  cText += cLine
                  lFound := .T.
               ENDIF
            ELSE
               cText += cLine
               lFound := .T.
            ENDIF      
                 
            wer->(dbSkip())
         ENDDO
         IF lFound
            SendMessage("Einkauf | Beistellmaterial nicht versendet","FertigungsauftrÑge fÅr "+Trim(ku->Kunde),cText)
         ENDIF
         IF lFoundFreigabe
            SendMessage("Projektmanagement | Freigabe fÅr FertigungsauftrÑge","FertigungsauftrÑge fÅr "+Trim(ku->Kunde),cTextFreigabe)
         ENDIF
//      SendMail({{"daniel.becker@engelking.de","Daniel"},{"amos.engelking@engelking.de","Amos"}},"FertigungsauftrÑge fÅr "+Trim(cLiefma),cText,,,,.T.)
      ENDIF      
   NEXT

  //Sinkey(0)
