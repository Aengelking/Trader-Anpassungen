#define CRLF Chr(13)+Chr(10)

PROC HOOK_AFTER_BOOK_WAZ(nArtnr,cLagerort,nQty)
   LOCAL cGrund,aTo
   NetUse("lagerort","lago")
   lago->(dbSeek(cLagerort))
   IF lago->SperrLager .AND. (! lago->TempSperr .OR. Left(cLagerort,3) == "093")
      cGrund := MBaseRun(Path("run\print_sperrvermerk"),{.T.,Space(8),Space(35)})
      
      IF Date() >= GetValue("HOLIDAY-AMOS-START") .AND. Date() <= GetValue("HOLIDAY-AMOS-END")
         aTo := {{"joel.engelking@engelking.de","Joel"}}
      ELSE
         aTo := {{"amos.engelking@engelking.de","Amos"}}
      ENDIF 
      SendMail(aTo,Trim(art->Matchcode)+" wurde zurck geliefert und gesperrt","Lagerort:"+cLagerort+CRLF+"Menge: "+Transform(nQty,Me(art->Me))+CRLF+cGrund)
   ENDIF
RETURN