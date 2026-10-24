FUNC HOOK_AFTER_SO_MOVED(nAbnr,hChangedWeeks)
   LOCAL nX

   FOR nX := 1 TO Len(hChangedWeeks)
      //Alert( ValToPrg(HGetKeyAt(hChangedWeeks,nX))+" -> "+ValToPrg(HGetValueAt(hChangedWeeks,nX)))
      IF Right(Str(HGetKeyAt(hChangedWeeks,nX),4),2) == "97" //if any week was xx97 then we just send the email
         //SendMail({{"amos.engelking@engelking.de","Amos"}},"AB "+LTrim(Str(nAbnr))+" wurde von 'Termin folgt' verschoben")
         RETURN .T. //send standard message
      ENDIF
   NEXT

   IF ku->Nummer == 35565 .AND. Date() <= StoD("20231031") //deactivate printing for Optris until the 31.08.23 - extended until 31.10.23
      SendMail({{"amos.engelking@engelking.de","Amos"}},"AB "+LTrim(Str(nAbnr))+" fr Optris wurde verschoben")
      RETURN .T. //send standard message
   ENDIF

   //print terminänderung
   EnAbDr(nAbnr,1)

RETURN .F. //do not send message