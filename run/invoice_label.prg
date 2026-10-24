PROCEDURE RUN_INVOICE_LABEL
LOCAL aPrinters := {"Adobe PDF","Pica 108/12","Pica 104/8","Micra 104/8"}
LOCAL nYear := Year(Date())
LOCAL nPrinter := 1
LOCAL nX,nNum := 1
LOCAL nStart := 1
LOCAL getlist := {}

Head("Barcodeetiketten drucken")

NetUse("idx","idx")

@ 01,00 SAY "Belegjahr" GET nYear PICTURE "9999" VALID nYear > 2000 .AND. nYear <= Year(Date())+1
@ 02,00 SAY "Start    " GET nStart PICTURE "999999" VALID nStart >= 1
@ 03,00 SAY "Anzahl   " GET nNum PICTURE "999" VALID nNum > 0
@ 04,00 SAY "Drucker"
@ 04,10,10,30 GET nPrinter LISTBOX aPrinters
READ

IF LastKey() == 27
   RETURN
ENDIF

/*BEGIN SEQUENCE
   LETO_BEGINTRANSACTION()
   IF ! idx->(dbSeek(Pad("REB",5)+Str(nYear,4)+"1"))
      idx->(Add_rec(0))
      idx->Alias := "REB"
      idx->Year  := nYear
      idx->Type  := 1
   ELSE
      idx->(Rec_Lock())
   ENDIF*/
   FOR nX := nStart TO nStart+nNum-1
//      idx->ID++
      MBaseRun(Trim(Tr_Getini(1))+"\run\labelstar",{"\\EK-SERVER4\Data\Dokumente und Einstellungen\All Users\Dokumente\Aufkleber\Allgemein\document.lbex",1,{"ID"=>"ER"+Right(Str(nYear,4),2)+"1"+StrZero(nX,6)},aPrinters[nPrinter]})
   NEXT
/*   LETO_COMMITTRANSACTION()
RECOVER
   LETO_ROLLBACK()
END*/
