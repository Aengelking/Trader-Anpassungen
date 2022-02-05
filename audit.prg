PROC RUN_AUDIT
   LOCAL cText,nX,aData,aCount

   NetUse("viewlog","vlog")
   NetUse("exportlog","expl")

   aData := vlog->(LETO_GROUPBY("USER","NUMMER,1","DATUM>=DATE()-7"))
   
   cText := "Aufrufe Adressen<br>"
   FOR nX := 1 TO Len(aData)
      aCount := vlog->(LETO_GROUPBY("NUMMER","NUMMER,1","USER =="+LTrim(Str(aData[nX,1]))+" .AND. DATUM >= DATE()-7" )) 
      cText += "Benutzer: "+Str(aData[nX,1],2)+" Abrufe: "+LTrim(Str(aData[nX,3]))+" Adressen: "+LTrim(Str(Len(aCount)))+"<br>"
   NEXT

   cText += "<p>Exporte aus Adressstamm<br>"
   expl->(dbSetFilter({|| StoT(expl->TimeStamp) >= StoT(DtoS(Date()-7)) },"StoT(TimeStamp) >= StoT(DtoS(Date()-7))"))
   DO WHILE ! expl->(EOF())
      cText += "Benutzer: "+Str(expl->User,2)+" Daten: "+expl->Data+"<br>"
      expl->(dbSkip())
   ENDDO

   SendMail({{"amos.engelking@engelking.de","Amos"}},"Trader Auditbericht",cText,,,,.T.)
RETURN
   