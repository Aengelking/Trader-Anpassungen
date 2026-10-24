FUNC HOOK_before_change_deldate_so(nAufnr,nItmnr,nMoveWeek)
   IF art->Manufactur == 6 .AND. art->Bezug == 5 //ENGELKING und Fertigungsartikel
      IF Right(Str(auf->Dterm,4),2) != "97" .AND. IF(Trim(auf->RemindStat)!="NOSTOCK",0,auf->RemindCoun+1) >= 3
         Sendmail({{"amos.engelking@engelking.de","Amos"}},"SO "+LTrim(Str(nAufnr))+" NOT moved from "+NiceWeek(auf->Dterm)+" to "+NiceWeek(nMoveWeek),"Reminder: "+LTrim(Str(IF(Trim(auf->RemindStat)!="NOSTOCK",0,auf->RemindCoun+1))))
      ENDIF
      RETURN .F.
   ELSE
      //Sendmail({{"amos.engelking@engelking.de","Amos"}},"Moving SO "+LTrim(Str(nAufnr))+" from "+NiceWeek(auf->Dterm)+" to "+NiceWeek(nMoveWeek))
   ENDIF
RETURN .T.