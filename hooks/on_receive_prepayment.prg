FUNCTION HOOK_ON_RECEIVE_PREPAYMENT()
   LOCAL nOpen := GetCustomerOpenOrders(ku->kunde,.T.)
   LOCAL nCredit := GetCustomerCredit(ku->Kunde)
   LOCAL nMwSt,cMessage
   
   //Alert(Str(hTurn["open"]))
   IF Round(nOpen,2) > Round(nCredit,2)
      //Alert("Vorkasse-Zahlungen reichen nicht aus um Auftr„ge zu decken")
      cMessage := "Hallo,<br><br>wir haben eine Vorkassezahlung von "+ras->Kunde+" erhalten. Diese reicht jedoch nicht aus um die offenen Auftr„ge zu decken.<br><br><pre>"
      cMessage += "Bisherige Zahlung(en): "+LTrim(Str(nCredit,12,2))+"<br>"
      cMessage += "Offene Auftr„ge:       "+LTrim(Str(nOpen,12,2))+"</pre>"
      SendMail({{"info@engelking.de",""}},"Vorkasse nicht ausreichend "+ku->Kunde,cMessage,,,,.T.)
   ENDIF
RETURN .T.