PROC RUN_AUDIT
   LOCAL cText,nX,aData,aCount
      

   NetUse("viewlog","vlog")
   NetUse("exportlog","expl")

   aData := vlog->(LETO_GROUPBY("USER","NUMMER,1","DATUM>=DATE()-6"))
   
   cText := "Aufrufe Adressen<br><pre>"
   FOR nX := 1 TO Len(aData)
      aCount := vlog->(LETO_GROUPBY("NUMMER","NUMMER,1","USER =="+LTrim(Str(aData[nX,1]))+" .AND. DATUM >= DATE()-6" )) 
      cText += "Benutzer: "+Str(aData[nX,1],2)+" Abrufe: "+Str(aData[nX,3],3)+" Adressen: "+Str(Len(aCount),3)+"<br>"
   NEXT

   cText += "</ore><p>Exporte aus Adressstamm<br>"
   expl->(dbSetFilter({|| StoT(expl->TimeStamp) >= StoT(DtoS(Date()-6)) },"StoT(TimeStamp) >= StoT(DtoS(Date()-6))"))
   expl->(dbGoTop())
   DO WHILE ! expl->(EOF())
      cText += "Benutzer: "+Str(expl->User,2)+" Daten: "+expl->Data+"<br>"
      expl->(dbSkip())
   ENDDO

   SendMail({{"amos.engelking@engelking.de","Amos"}},"Trader Auditbericht",cText,,,,.T.)
RETURN
   