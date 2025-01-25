
PROC RUN_FIND_FA_PRODUCABLE
   LOCAL hKWQtys,cForecastMissing,aMissingForecast
   LOCAL nMissing := 0
   LOCAL getlist := {}
   NetUse("werkauf","wer")
   NetUse("werks","we")
   NetUse("artikel","art")

   Head("Fertigbare Auftr„ge")
   @ 01,00 SAY "Fehlende Artikel" GET nMissing PICTURE "99" VALID nMissing >= 0
   READ
   IF LastKey() == 27
      RETURN 
   ENDIF

   wer->(dbSetOrder( 10 ))
   wer->(dbGoTop())
   @ 02,00 SAY "Nummer"
   IF nMissing > 0
      @ 02,07 SAY "Fehlende Artikel"
   ENDIF

   DO WHILE wer->Status < 2 .AND. ! wer->(Eof()) .AND. Inkey() != 27
      IF Empty(wer->Liefma) .AND. wer->Qty != 0 .AND. wer->StartDate > Date()
         cForecastMissing := ""
         aMissingForecast := {}
         
         WAStatus(@hKWQtys,,CountWorkingDays(Date(),wer->StartDate,GetConfigValue("STATE"),.T.),@cForecastMissing,,@aMissingForecast)
         IF Len(aMissingForecast)  <= nMissing
            ? wer->Aufno,StrTran(cForecastMissing,Chr(13)+Chr(10)," | ")
         ENDIF

         
      ENDIF
      wer->(dbSkip())
   ENDDO

   ? "abgeschlossen"
   Sinkey(0)

