PROC MASK_TRD_06
LOCAL nLastRow
LOCAL hAlt,hNeu,cField,nX

NetUse("engkund","ku",.F.,0)
ku->(dbSetOrder(1))

SetColor(c_five)

Tr_Box(08,10,21,60)

DevPos( 09, 11 )
DevOut( "Datum......: "+DTOC(abg->DATUM) )
@ 10,11 SAY "Buchungdat.: "+DToC(abg->TransDate)+" "+abg->TransTime
@ 11,11 SAY  "Menge......: "+LTrim(TRANSFORM(abg->menge,me->(me(art->me))))+" "+art->me
@ 12,11 SAY "Bestand....: "+LTrim(TRANSFORM(abg->bestand,me->(me(art->me))) )+" "+art->me
DevPos( 13, 11 )
DevOut( "Art........: "+BuArtName(Trim(abg->BuArt)) )

If abg->Group == "K"
	@ 14,11 SAY "Kunde......:"
Elseif abg->Group == "L"
	@ 14,11 SAY "Lieferant..:"
Else
//	@14,11 SAY abg->Liefma+" -- "+abg->Group
Endif
//@ 14,23 SAY abg->LIEFMA
If ! Empty(abg->LIEFMA) .AND. ku->(dbSeek(abg->Liefma+abg->Group))
	@ 14,24 SAY ku->Name1
Endif
If Trim(abg->Buart) $ "ENT ZUG ABG"
	@ 15,11 SAY "Zweck......:"
Else
	@ 15,11 SAY "Beleg......:"
Endif
@ 15,24 SAY LTrim(abg->Beleg)
@ 16,11 SAY "Preis......: "+LTrim(Str(abg->preis))
@ 17,11 SAY "PE.........: "+Ltrim(Str(abg->pe))
If Trim(abg->Buart) $ "RNR RA�"
	@ 18,11 SAY "Auftrag....:"
Elseif Trim(abg->Buart) $ "WE RE"
	@ 18,11 SAY "Bestellung.:"
Else
	@ 18,11 SAY "Nummer.....:"
Endif
@ 18,24 SAY Ltrim(Str(abg->besnr,6))+"/"+LTrim(Str(abg->Bespos))
@ 19,11 SAY "Mitarbeiter: "+Buy(abg->Buyer,.T.)
IF Trim(abg->Buart) $ "UMG ZUG ABG"
   @ 20,11 SAY "Lagerort...:"
ELSE
   @ 20,11 SAY "Info.......:"
ENDIF
@ 20,24 SAY abg->Info
IF Trim(abg->Buart) == "STD" //�nderung Stammdataen
   NetUSe("log","log")
   IF log->(dbSeek( "ART "+Str(art->Artikelnr,6)+abg->Beleg ))
      hAlt := HB_DeSerialize(log->Data)
      log->(dbSkip(1))
      IF Trim(log->Alias) == "ART" .AND. log->ID == art->Artikelnr
         hNeu := HB_DeSerialize(log->Data)
      ELSE
         hNeu := {"DATA"=>{=>}}
      ENDIF      
      @ 21,10 SAY Chr(179)+"Ge�nderte Felder: "
      @ 21,29 SAY Replicate(Chr( 196 ),31)+Chr(193)+Replicate(Chr(196),47)+Chr( 191 )
      nLastRow := 21
      FOR nX := 1 TO Len(hAlt["DATA"])
         cField := HGetKeyAt(hAlt["DATA"],nX)
         nLastRow++
         
         @ nLastRow,10 SAY Chr(179)+Space(1)         
         @ nLastRow,12 SAY Pad(cField,20) +": "+Pad(HB_ValToStr(hAlt["DATA"][cField])+" -> " + HB_ValToStr(IF(HHasKey(hNeu["DATA"],cField),hNeu["DATA"][cField],art->(FieldGet(FieldPos(cField))))),74)+Chr(179)
      NEXT
      @ ++nLastRow,10 SAY Chr( 192 )+Replicate(Chr( 196 ),97)+Chr( 217 )
   ENDIF
ELSEIF Trim(abg->Buart) $ "RNR ENT"
   @ 21,10 SAY Chr(186)+"Lagerorte..: "
   nLastRow := 21
   IF Trim(abg->Buart) $ "RNR"
      NetUse("englsre","re")
      NetUse("lagrech","lagr")
      re->(dbSetOrder( 12 ))
      nDash := AT("-",abg->Beleg)
      cRechnr := PadL(SubStr(abg->Beleg,1,nDash),6)
      cPosnr  := PadL(SubStr(abg->Beleg,nDash+1),3)
      nRechnr := Val(cRechnr)
      nPosnr  := Val(cPosnr)
//      re->(dbSeek( cRechnr+cPosnr ))

      lagr->(dbSeeK( cRechnr+cPosnr+STR(abg->Besnr,6) ))
      DO WHILE lagr->Rechnr == nRechnr .AND. lagr->RePosnr == nPosnr .AND. lagr->Abnr == abg->Besnr.AND. nLastRow < MaxRow()
         IF nLastRow > 21
            @ nLastRow,10 SAY Chr(186)+Space(13)
         ENDIF
         @ nLastRow,24 SAY Pad(lagr->Lagerort+TRANSFORM(lagr->Lagermenge,me->(me(art->me)))+" "+art->Me,36)+Chr(186)
         nLastRow++
         IF ! Empty(lagr->Batch)
            IF nLastRow > 21
               @ nLastRow,10 SAY Chr(186)+Space(13)
            ENDIF   
            @ nLastRow,24 SAY Pad("  Charge: "+Trim(lagr->Batch),36)+Chr(186)
            nLastRow++
         ENDIF

         lagr->(dbSkip())
      ENDDO
   ELSE
      NetUse("lagerne","lne")
      NetUse("lagent","lage")
      nNr := IF(Empty(abg->Beleg),abg->Besnr,Val(abg->Beleg))
      lne->(dbSetOrder( 9 ))
      lne->(dbSeeK( STR(nNr,6)+art->Matchcode ))
      DO WHILE lne->Nummer == nNr .AND. lne->Matchcode == art->Matchcode .AND. ! lne->(EOF())
         lage->(dbSeek( Str(nNr,6)+Str(lne->Pos,3) ))
         DO WHILE lage->Nummer == nNr .AND. lage->Pos == lne->pos .AND. ! lage->(EOF())
            IF nLastRow > 21
               @ nLastRow,10 SAY Chr(186)+Space(13)
            ENDIF
            @ nLastRow,24 SAY Pad(lage->Lagerort+TRANSFORM(lage->Lagermenge,me->(me(art->me)))+" "+art->Me,36)+Chr(186)
            nLastRow++
            IF ! Empty(lage->Batch)
               IF nLastRow > 21
                  @ nLastRow,10 SAY Chr(186)+Space(13)
               ENDIF
               @ nLastRow,24 SAY Pad("  Charge: "+Trim(lage->Batch),36)+Chr(186)
               nLastRow++
            ENDIF
            lage->(dbSkip())
         ENDDO
         lne->(dbSkip())
      ENDDO
   ENDIF

//@ nLastRow,10 SAY Chr( 201 ) + Chr( 205 ) + Chr( 187 ) + Chr( 186 ) + ; /* "╔═╗║╝═╚║" */
//                          Chr( 188 ) + Chr( 205 ) + Chr( 200 ) + Chr( 186 )
   @ nLastRow,10 SAY Chr( 200 )+Replicate(Chr( 205 ),49)+Chr( 188 )
ENDIF
SInkey(0,128)

//SetColor(c_five)
/*Scroll( 09, 10, 20, 60 )
SetPos( 09, 10 )
Tr_Box(09,10,20,60)*/
