
PROC RUN_MAINTANANCE_CORRECT_WER_END
   LOCAL nKW
   LOCAL cLief := Pad("WHTECH",8)

   NetUse("engbes","bes")   
   NetUse("werkauf","wer")

   CLS

   bes->(dbSetOrder( 2 ))
   bes->(dbSeek( cLief ))
   ? "Bes.Nr","Pos","Aktuell"," Korrekt ","Matchcode"
   DO WHILE bes->Liefma == cLief .AND. bes->Bestat < 3 .AND. ! bes->(EOF())
      IF bes->Confirmed == "Y" .AND. bes->BeQty-bes->GelQty > 0         
         nKW := IF(Val(Right(Str(bes->Lterm,4),2))<=52,bes->Lterm+bes->ShipTime,bes->Lterm)

         wer->(dbSetOrder(6)) //Besnr
         If wer->(dbSeek( Str(bes->Besnr,6)+Str(bes->Posnr,3) )) .AND. Right(Str(wer->End,4),2) != "99"  .AND. wer->End != nKW
            ? bes->Besnr,bes->Posnr,Niceweek(wer->End),NiceWeek(nKW),wer->Matchcode
            wer->(Rec_Lock(0))
            wer->end := nKW
            wer->(dbUnlock())
         Endif
      ENDIF
      bes->(dbSkip())
   ENDDO
   ? "DONE"
   Sinkey(0)