PROC WD_RUN(xProg)
   IF ! IsFeiertag(Date(),GetConfigValue("STATE"),.T.)      
      IF ValType(xProg) == "C"
         MBaseRun(Path("run\"+xProg))
      ELSEIF ValType(xProg) == "B"
         Eval(xProg)
      ENDIF
   ENDIF
RETURN