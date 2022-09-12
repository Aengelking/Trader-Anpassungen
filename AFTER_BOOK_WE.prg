FUNCTION HOOK_AFTER_BOOK_WE(hData,oBesPos)

   HB_SYMBOL_UNUSED(oBesPos)

   MbaseRun(Path("run\print_batch_labels"),{hData:cCharge})   

   IF art->Charge
      //SendMail({{"amos.engelking@engelking.de","Amos"}},"Artikel mit Chargenverwaltung eingebucht "+Trim(art->Matchcode))
   ELSEIF Trim(art->Matchcode) == "59-116"
      SendMail({{"amos.engelking@engelking.de","Amos"}},"Artikel "+Trim(art->Matchcode)+" eingebucht")
   ELSEIF Trim(art->Matchcode) == "KS15958/2"
      SendMail({{"dani.24@freenet.de","Dani"}},"Steckerle sind gekommen","Hi Dani, "+Chr(13)+Chr(10)+" es sind wieder Steckerle zu machen.")
   ELSEIF Trim(art->Matchcode) == "KS27732/LINCC700001"
      SendMail({{"thimo.hamma@engelking.de","Thimo"},{"amos.engelking@engelking.de","Amos","BCC"}},"Artikel "+Trim(art->Matchcode)+" eingebucht")
   ENDIF
RETURN NIL