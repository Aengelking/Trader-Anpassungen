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
      /*IF MaxCol() > 100 .AND. Select("lag") != 0 .AND. ! Empty(lag->Batch) .AND. Tr_MsgBox("Aufkleber w„hlen",,{"Artikel","Charge"}) == 2
      //this does not work
         MBaseRun(Path("run\print_batch_labels"),{Trim(lag->Batch)})
      ELSE*/
         StickPrint("WARE")
      //ENDIF
   ELSEIF  ProcName(8) == "PROJECT_BROWSE"      
      StickPrint("PROJEKT")
   ELSEIF Tr_Getini(28) == 9
      Alert(ProcName(1))
   ENDIF
RETURN NIL