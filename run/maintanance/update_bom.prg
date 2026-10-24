PROC RUN_UPDATE_BOM
   LOCAL nTotQty
   LOCAL nTotBad

   NetUse("bom","bom")
   NetUse("parts","part")
   NetUse("werkauf","wer")

   Select("part")
   SET FILTER TO part->pos == 0

   part->(dbGotop())
   DO WHILE ! part->(EOF())      
      ? part->ListArt,part->Partart,part->Notes
      /*IF Empty(CtoD(part->Notes))
         part->(Rec_Lock())
         part->(dbDelete())
         part->(dbUnLock())
      ELSE*/

      nTotQty  := 0      
      nTotBad  := 0
      
      wer->(dbSetOrder( 2 )) // Str(artno)
      wer->(dbSeek( Str(part->Listart,6) ))  
      Select("wer")    
      SET FILTER TO wer->Status >= 4 .AND. wer->Qty > 0 .AND. wer->Date >= StoD("20150601")
         
      DO WHILE wer->Artno == part->Listart .AND. ! wer->(EOF())            
         nTotQty += wer->Qty
         nTotBad += wer->BadQty
         wer->(dbSkip())
      ENDDO
      wer->(dbClearFilter())

      IF ! bom->(dbSeek( Str(part->Listart,6) ))
         bom->(Add_Rec(0))
         bom->Artikelnr := part->Listart
      ELSE
         bom->(Rec_Lock(0))
      ENDIF
      IF part->Partart < 1000 //I believe these must be a bug
         bom->Index := part->Partart
      ENDIF
      bom->Date := CTod(part->Notes)
      bom->Used := part->Factor != 0
      IF nTotQty > 0
         bom->Scrap := Min(nTotBad/nTotQty,0.9999)
      ENDIF
      bom->(dbUnLock())

   //ENDIF
      part->(dbSkip())


   ENDDO

   part->(dbClearFilter())
RETURN