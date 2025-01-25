#define CRLF Chr(13)+Chr(10)

PROC HOOK_AFTER_BOOK_WAZ(nArtnr,cLagerort,nQty)
   LOCAL cGrund,aTo,cText
   LOCAL nTotalBack
   NetUse("lagerort","lago")
   lago->(dbSeek(cLagerort))
   IF lago->SperrLager .AND. (! lago->TempSperr .OR. Left(cLagerort,3) == "093")
      cGrund := MBaseRun(Path("run\print_sperrvermerk"),{.T.,Space(8),Space(35)})
      
      IF Date() >= GetValue("HOLIDAY-AMOS-START") .AND. Date() <= GetValue("HOLIDAY-AMOS-END")
         aTo := {{"joel.engelking@engelking.de","Joel"}}
      ELSE
         aTo := {{"amos.engelking@engelking.de","Amos"}}
      ENDIF 
      SendMail(aTo,Trim(art->Matchcode)+" wurde zur…k geliefert und gesperrt","Lagerort:"+cLagerort+CRLF+"Menge: "+Transform(nQty,Me(art->Me))+CRLF+cGrund)
   ENDIF
   nTotalBack := Round(we->Qty*we->factor,GetMeDecimals(art->Me))-we->BookQty
   IF nTotalBack > we->Qty*we->factor*0.3  .AND. nTotalBack > 1 //30% der Menge wurde zur…kgebucht
      //nQty := (we->ListQty*::Qty*(100+we->ListPerc)/100)+we->ListAdd
      cText := "Fertigungsauftrag: "+LTrim(Str(wer->Aufno))
      cText += CRLF+"Artikel: "+Trim(art->Matchcode)
      cText += CRLF+"Menge: "+Transform(we->Qty*we->factor,Me(art->Me))
      cText += CRLF+"Zur…kgebucht: "+Transform(nTotalBack,Me(art->Me))
      cText += CRLF+"mit dieser Buchung: "+Transform(nQty,Me(art->Me))
      cText += CRLF+"Lagerort: "+cLagerort

      SendMail({{"amos.engelking@engelking.de","Amos"}},Trim(art->Matchcode)+" wurde mehr als 30% zur…k gebucht",cText)
   ENDIF
RETURN