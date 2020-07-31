PROC RUN_CHECKPAY()
   IF AddWorkingDays(Date(),-2,"BW",.T.) > GetValue("LASTPAY","D")
      SendMail({{"amos.engelking@engelking.de","Amos"}},"Zahlungen dringend verbuchen","Letzter Zahlungseingang: "+DtoC(GetValue("LASTPAY","D")),,,2)
   ELSE
      //CheckPay()
      //Alert("CHECKPAY")
      //This is run anyway at the momement
   ENDIF
RETURN