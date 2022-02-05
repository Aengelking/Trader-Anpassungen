PROC RUN_TEST_WERKPARTS
   LOCAL lCurrentParts

   NetUse("werkauf","wer")
   NetUse("werks","we")
   NetUse("engbes","bes")
   NetUse("parts","part")
   Select("wer")
   SET FILTER TO wer->Status < 4 /*.AND. Empty(wer->Liefma)*/ .AND. wer->Qty-wer->PlanBad > 0 .AND. Right(Str(wer->TerminFrue,4),2) != "99"
   wer->(dbGotop())
   DO WHILE ! wer->(EOF())      
      IF wer->Status >= 1 .OR.  ! Empty(wer->Liefma) //AScan(aItemSuppliers,{|x| x[1] == wer->Artno },2) != 0 //we only add orders which are in production or also can be purchased externaly
         //@ MaxRow()/2+2,MaxCol()/2-4 SAY "["+Str(wer->Aufno,6)+"]" COLOR c_five     
         ? wer->Aufno
         IF ! Empty(wer->Liefma)
            bes->(dbSetOrder( 1 ))
            bes->(dbSeek( Str(wer->Besnr,6) )) 
         ENDIF
         
         //check to make sure the order is using the current parts list
         lCurrentParts := .T.
         //Select("part")
         //SET FILTER TO part->Pos != 0
         IF !part->(dbSeek( Str(wer->Artno,6) )) 
            ?? "no parts"
         ENDIF
         we->(dbSeek( Str(wer->Aufno,6) ))
         DO WHILE part->Listart == wer->Artno .AND. we->Aufno == wer->Aufno
            IF part->Pos != 0
               IF wer->Aufno == 8737
                  ? we->Pos,we->Partart
                  ? part->Pos,part->Partart
               ENDIF               
               IF we->Pos != part->Pos .OR. we->Partart != part->Partart .OR. we->ListQty != part->Qty .OR. we->ListAdd != part->AddQty .OR. we->ListPerc != part->AddPercent;
                  .OR. we->Me != part->Me .OR. we->Factor != part->Factor .OR. we->Variant != part->Variant
                  lCurrentParts := .F.
                  ? part->Pos,"weicht ab",we->Partart,part->Partart
                  EXIT
               ENDIF                                               
               we->(dbSkip())            
            ENDIF
            part->(dbSkip())
         ENDDO
         IF ! lCurrentParts
            ? wer->Aufno
         ENDIF
         //part->(dbClearFilter())
      ENDIF
      wer->(dbSkip())
      IF Inkey() == 27
         EXIT
      ENDIF
   ENDDO
   Sinkey(0)
RETURN
