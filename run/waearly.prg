
#define LAG_STOCK_USABLE           2

FUNCTION RUN_WAEARLY(nWAnr)
   LOCAL nWeeks := -1
   LOCAL nLZKw,nLZ
   LOCAL hKWQtys := {=>},aAvail
   LOCAL nCurWeek := CWeek(Date())
   LOCAL nQty,nBestand
   LOCAL hParts := {=>}
   LOCAL nLiefnr

   nWAnr := 7433

   NetUse("werkauf","wer")
   NetUse("werks","we")
   NetUse("artikel","art")
   NetUse("engkund","ku")


   wer->(dbSeek( Str(nWanr,6) ))
   nLiefnr := WAGetLiefnrForStock()
   we->(dbSeek( Str(nWAnr,6) ))
   
   art->(dbSetOrder(2))
CLS
   
   DO WHILE we->aufno == wer->aufno   // check if we can book goods out
      art->(dbSeek( Str(we->partart) ))
      ? art->Matchcode
      IF we->Qty > 0
         IF art->Sperren .OR. (art->LagerArt .AND. art->Inventur)
            RETURN 999 //cannot be produced, date unknown
         ELSEIF art->Lagerart               
            IF ! HHasKey(hKWQtys,we->PartArt)
               hKWQtys[we->PartArt] := GetKWQty(we->PartArt)
            ENDIF
            nLZ := IF(art->LZ==0,GetConfigValue("DEFAULTS_SUPPLIER_DELTIME"),art->LZ)
            nLZKw := AddWeeks(nCurWeek,nLZ)
            nQTY := (we->Qty*we->factor)-we->bookqty
            IF HHasKey(hParts,we->PartArt)
               hParts[we->PartArt] += nQty
               nQty := hParts[we->PartArt]
            ELSE
               hParts[we->PartArt] := nQty
            ENDIF
            ?? nQty
            IF nWeeks == -1 //bisher alles auf Lager
               nBestand := LagGetStock(we->partart,LAG_STOCK_USABLE,nLiefnr)
               ?? " Bestand: ",nBestand
               IF nBestand < nQty //zu wenig Bestand
                  nWeeks := 0
               ENDIF
            ENDIF
            IF nWeeks >= 0 //nicht auf Lager, dann suchen wir die Woche
               FOR EACH aAvail IN hKWQtys[we->PartArt]
                  IF aAvail[1] > nLzKW //reached delivery time
                     ?? " LZ"
                     nWeeks := Max(nWeeks,nLZ)
                     EXIT
                  ENDIF
                  IF aAvail[6] >= IF(aAvail[1] < wer->Termin,nQty,0) //available
                     IF aAvail[1] == 0 //Rückstand
                        ?? " Rueckstand"
                        nWeeks := Max(nWeeks,0)
                     ELSE
                        ?? "",aAvail[1]
                        nWeeks := Max(nWeeks,WeeksBetween(nCurWeek,aAvail[1]))
                        ?? " =>",LTrim(Str(nWeeks))
                     ENDIF
                     EXIT
                  ENDIF
               NEXT
            ENDIF
         ENDIF
      ENDIF      
      we->(dbSkip())
   ENDDO

   Alert(Str(nWeeks))