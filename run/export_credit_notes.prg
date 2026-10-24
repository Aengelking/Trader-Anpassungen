PROC RUN_ExportCreditNotes()
   LOCAL nYear := Year(Date())-1
   LOCAL dStart,dEnd   
   LOCAL aList   
   LOCAL getlist := {}

   Head("Gutschriften fr Gew„hrleistung exportieren")

   @ 01,00 SAY "Jahr" GET nYear VALID nYear >= 2019 .AND. nYear <= Year(Date()) PICTURE "9999"
   READ

   IF LastKey() == 27
      RETURN
   ENDIF

   dStart := StoD(Str(nYear,4)+"0101")
   dEnd   := StoD(Str(nYear,4)+"1231")

   NetUse("rma","rma")
   NetUse("englsre","re")
   re->(dbSetOrder(4))
   SET FILTER TO re->Reposnr != 0 .AND. re->AoQty != 0
   NetUse("rechnung","reh")
   SET FILTER TO reh->Rechdat >= dStart .AND. reh->Rechdat <= dEnd .AND. reh->Brutto < 0
   reh->(dbGoTop())   

   aList := {{"Gutschrift","Datum","Debitor","Summe ohne MwSt","RMA","MwSt"}}

   DO WHILE ! reh->(EOF())
      lDefect := .F.

      re->(dbSeek( Str(reh->Rechnr,6) ))
      DO WHILE re->Rechnr == reh->Rechnr                  
         IF re->RefType == "RMA"             
            rma->(dbSeek( Str(re->Ref,6) ))
            IF Trim(rma->Grund) == "DEF"
               Aadd(aList,{reh->Rechnr,reh->Rechdat,reh->Kunummer,reh->Brutto-reh->MwSt,re->Ref,IF(reh->Mwst==0,"Nein","Ja")})
               EXIT
            ENDIF            
         ENDIF
         re->(dbSkip())
      ENDDO
      reh->(dbSkip())
   ENDDO

   SaveAsCSVInterface(aList)
