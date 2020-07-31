PARAMETERS cState,cKunde,cText,nMaxDaysOver,nMaxRem,aOpenInvoices

IF Trim(cKunde) == HB_AnsiToOem("HÜGLER") .AND. cState == "NOPAY" .AND. nMaxRem >= 1  //Hügler wird nach der ersten Mahnung ans Inkasso übergeben, sind hierüber auch informiert
   SendMail(GetConfigEmail("SI-NOPAY-SEVERE"),"INKASSO! "+cKunde,cText,,,2,.T.)
   RETURN .F.  //do not send standard emails
ENDIF

RETURN .T.