#define CRLF Chr(13)+Chr(10)
FUNCTION HOOK_AFTER_BOOK_WE(hData,oBesPos)
   LOCAL cGrund,aTo

   //HB_SYMBOL_UNUSED(oBesPos)

   MbaseRun(Path("run\print_batch_labels"),{hData:cCharge})   

   IF Trim(art->Matchcode) $ {"KS34350/2"}
      SendMail({{"amos.engelking@engelking.de","Amos"}},"Artikel "+Trim(art->Matchcode)+" eingebucht")
   ENDIF

   IF art->Charge
      //SendMail({{"amos.engelking@engelking.de","Amos"}},"Artikel mit Chargenverwaltung eingebucht "+Trim(art->Matchcode))
   /*ELSEIF Trim(art->Matchcode) == "59-116"
      SendMail({{"amos.engelking@engelking.de","Amos"}},"Artikel "+Trim(art->Matchcode)+" eingebucht")
   ELSEIF Trim(art->Matchcode) == "KS15958/2"
      SendMail({{"dani.24@freenet.de","Dani"}},"Steckerle sind gekommen","Hi Dani, "+Chr(13)+Chr(10)+" es sind wieder Steckerle zu machen.")
   ELSEIF Trim(art->Matchcode) == "KS27732/LINCC700001"
      SendMail({{"thimo.hamma@engelking.de","Thimo"},{"amos.engelking@engelking.de","Amos","BCC"}},"Artikel "+Trim(art->Matchcode)+" eingebucht")*/
   ENDIF
   IF HHasKey(hData,"CLAGERORT")
      NetUse("lagerort","lago")
      lago->(dbSeek(hData:cLagerort))
      IF lago->SperrLager .AND. (! lago->TempSperr .OR. Left(hData:cLagerort,3) == "093")
         cGrund := MBaseRun(Path("run\print_sperrvermerk"),{.T.,oBesPos:Liefma,hData:cBeleg})
         
         IF Date() >= GetValue("HOLIDAY-AMOS-START") .AND. Date() <= GetValue("HOLIDAY-AMOS-END")
            aTo := {{"joel.engelking@engelking.de","Joel"}}
         ELSE
            aTo := {{"amos.engelking@engelking.de","Amos"}}
         ENDIF 
         SendMail(aTo,Trim(art->Matchcode)+" wurde im WE gesperrt","Lagerort:"+hData:cLagerort+CRLF+"Menge: "+Transform(hData:nMenge,Me(art->Me))+CRLF+cGrund)
      ENDIF
   ENDIF
RETURN NIL