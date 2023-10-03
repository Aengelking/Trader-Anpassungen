
FUNCTION HOOK_ON_SAMPLE_READY( nNummer )
   NetUse("engnr","nr")
   IF ! nr->Inventur
      //SendMail({{"amos.engelking@engelking.de","Amos"}},"Muster werden ausgeliefert "+LTrim(Str(nNummer)))
      MusterCreateDelnote(nNummer)         
   ENDIF
   //SendMail({{"amos.engelking@engelking.de","Amos"}},"Muster ausgeliefert "+LTrim(Str(nNummer)))  //+LTrim(Str(mirenr,6)), mirenr is not available for some reason
   
   nr->(dbCloseArea())
RETURN .F. //keine Miteilung versenden      
