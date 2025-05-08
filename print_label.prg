PROC print_label   
   LOCAL aList := {},nChoice

   MEMVAR c_five
   IF Tr_Getini(28) == 9
      /*Alert(ProcName(8)+";"+ProcName(7)+";"+Alias())
      IF Select("LAG") != 0 .AND. !Empty(lag->Batch)
         Alert(lag->Batch)
      ENDIF
*/
   ENDIF

   IF Alias()=="ART" .OR. ProcName(8) == "BROWSEARTIKEL" .OR. ProcName(7) == "BROWSEARTIKEL"
      Aadd(aList,"Ware")
   ENDIF
   IF (ProcName(8)=="SHOWORT" .OR. ProcName(7) == "BROWSEARTIKEL") .AND. Select("LAG") != 0 .AND. !Empty(lag->Batch)
      Aadd(aList,"Charge")      
   ENDIF
   IF Len(aList) == 0
      IF Alias()=="LAGO"
         StickPrint("LAGERORT")   
      ELSEIF Alias()=="ART" .OR. ProcName(8) == "BROWSEARTIKEL" .OR. ProcName(7) == "BROWSEARTIKEL"
         Aadd(aList,"Ware")
         /*IF MaxCol() > 100 .AND. Select("lag") != 0 .AND. ! Empty(lag->Batch) .AND. Tr_MsgBox("Aufkleber w„hlen",,{"Artikel","Charge"}) == 2
         //this does not work
            MBaseRun(Path("run\print_batch_labels"),{Trim(lag->Batch)})
         ELSE*/
            StickPrint("WARE")
         //ENDIF
      ELSEIF Alias()=="KU"
         IF ku->Branch=="AUTO"
            StickPrint("VDA4902")
            StickPrint("PAKET")
         ENDIF
      ELSEIF  ProcName(8) == "PROJECT_BROWSE"      
         StickPrint("PROJEKT")
      ELSEIF Tr_Getini(28) == 9
         Alert(ProcName(1))
      ENDIF
   ELSE   
      IF Len(aList) > 1
         SetColor(c_five)
         nChoice := AMenu(aList)
      ELSE
         nChoice := 1
      ENDIF
      IF nChoice > 0
         DO CASE
            CASE aList[nChoice] == "Charge"
               MBaseRun(Path("run\print_batch_labels"),{Trim(lag->Batch)})
            CASE aList[nChoice] == "Ware"
               StickPrint("WARE")
         ENDCASE
      ENDIF           
   ENDIF

RETURN NIL