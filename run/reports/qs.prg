PROC Report_QS
   LOCAL dEnd := Date()
	LOCAL dStart   := Boy(dEnd)
   LOCAL getlist := {}
   LOCAL aList := {}
   
   NetUse("QS","qs")
   NetUse("rma","rma")
   NetUSe("rmapos","rmp")

	Head("Reklamationen")

   @ 01,00 SAY "Startdatum" GET dStart VALID dStart <= Date()-1
   @ 02,00 SAY "Enddatum  " GET dEnd VALID dEnd > dStart .AND. dEnd <= Date()
   READ

   IF LastKey() == 27
      RETURN
   ENDIF

   rma->(dbSetOrder( 2 )) //qs

   qs->(dbGotop())
   DO WHILE !qs->(Eof())
      IF qs->Datum >= dStart .AND. qs->Datum <= dEnd .AND. qs->Status != 8              
         rma->(dbSeek( Str(qs->Nummer,6) ))
         ? qs->Nummer
         DO WHILE rma->QS == qs->Nummer
            ? "RMA:",rma->Nummer,rma->BBNR            
            rmp->(dbSeek( Str(rma->Nummer,6) ))
            DO WHILE rmp->Nummer == rma->Nummer
               ? rmp->Pos,rmp->Matchcode
               rmp->(dbSkip())
            ENDDO
            rma->(dbSkip())
         ENDDO
         Aadd(aList,{qs->Nummer,qs->Status,qs->Datum,Trim(qs->Matchcode),Trim(qs->Kunde),Trim(qs->Liefma),Trim(qs->Beschreibu)})
      ENDIF
      qs->(dbSkip())
   ENDDO

   SaveToOO_Interface(aList)

