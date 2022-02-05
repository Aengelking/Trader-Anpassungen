FUNCTION RUN_testScrap()
      LOCAL nTotQty  := 0      
      LOCAL nTotBad  := 0
      LOCAL nArtnr := 16830
      NetUse("werkauf","wer")
CLS
      wer->(dbSetOrder( 2 )) // Str(artno)
      wer->(dbSeek( Str(nArtnr,6) ))  
      Select("wer")    
      SET FILTER TO wer->Status >= 4 .AND. wer->Qty > 0 .AND. wer->Date >= StoD("20150601")
      
      DO WHILE wer->Artno == nArtnr .AND. ! wer->(EOF())
         ? Str(wer->Aufno,6)+" Ausschuss "+Ltrim(Str(wer->BadQty))+"/"+LTrim(Str(wer->Qty-wer->GelQty))
         nTotQty += wer->Qty
         nTotBad += wer->BadQty+(wer->Qty-wer->GelQty)           
         wer->(dbSkip())
      ENDDO
      wer->(dbClearFilter())
      IF nTotQty <= 0
         Alert("Scrap: 0")
      ENDIF
      
RETURN Alert("Scrap: "+Str(nTotBad/nTotQty))