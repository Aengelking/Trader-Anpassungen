PROC WD_RUN(xProg,lBruecke)
   Default(@lBruecke,.T.)
   IF ! IsFeiertag(Date(),GetConfigValue("STATE"),lBruecke) .AND. ! StoD(Date()) $ Hook("get_firmclosed",{Year(Date())},{})   
      IF ValType(xProg) == "C"
         MBaseRun(Path("run\"+xProg))
      ELSEIF ValType(xProg) == "B"
         Eval(xProg)
      ENDIF
   ELSE
      //Tr_MsgBox("Firma geschlossen")
   ENDIF
RETURN