
PROC CLEAN_BUYPRICE
   NetUse("buyprice","bpr")
   NetUse("artlief","ali")

   DO WHILE ! bpr->(EOF())
      IF ! ali->(dbSeek(bpr->Liefma+Str(bpr->Artikelnr, 6)))
         ? "Artikelnr " + Str(bpr->Artikelnr, 6) + " Liefma " + bpr->Liefma + " not found in artlief"
         bpr->(Rec_Lock())
         bpr->(dbDelete() )
         bpr->(dbUnLock())
      ENDIF
      bpr->(dbSkip())
      IF Inkey() == 27
         EXIT
      ENDIF
   ENDDO

   Sinkey(0)