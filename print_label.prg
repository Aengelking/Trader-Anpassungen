PROC print_label   
   IF ProcName(8)=="SHOWORT" .AND.!Empty(lag->Batch)
      MBaseRun(Path("run\print_batch_labels"),{Trim(lag->Batch)})
   ELSEIF Alias()=="LAGO"
      StickPrint("LAGERORT")
   ELSEIF Alias()=="KU"
      IF ku->Branch=="AUTO"
         StickPrint("VDA4902")
         StickPrint("PAKET")
      ENDIF
   ELSEIF Alias()=="ART" .OR. ProcName(8) == "BROWSEARTIKEL" .OR. ProcName(7) == "BROWSEARTIKEL"
      StickPrint("WARE")
   ENDIF
RETURN NIL