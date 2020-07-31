/*3970
7140
7050*/
LOCAL dStart := StoD("20080131"),dDate
LOCAL nWare,nRHB,nUnfert
NetUse("inventur","inv")

If ! Lx_Start()
   Alert(t("Lexware konnte nicht geöffnet werden"))
   RETURN
ENDIF

hKonten := {;
		"WARE"=>Val(AllTrim(LX_GetConfigValue("KONTEN","Ware"))),;
		"RHB"=>Val(AllTrim(LX_GetConfigValue("KONTEN","RHB"))),;
		"UNFERT"=>Val(AllTrim(LX_GetConfigValue("KONTEN","Unfertig")));
}


//dDate := Eom(dStart)
dDate := EoY(dStart)
DO WHILE dDate <= Date()
   //make sure it is a weekday
   IF Dow(dDate) == 7  //saturday
      dDate--
   ELSEIF Dow(dDate) == 1 //sunday
      dDate -= 2
   ENDIF

   //check to see if there is a value for this date
   IF ! inv->(dbSeek( DtoS(dDate) ))
      //get the values from Lexware
      nWare   := LX_GetSaldo(hKonten["WARE"],dDate)
      nRHB    := LX_GetSaldo(hKonten["RHB"],dDate)
      nUnfert := LX_GetSaldo(hKonten["UNFERT"],dDate)

      ? dDate,nWare,nRHB,nUnfert
      
      //insert values into the db
      inv->(Add_Rec())
      inv->Date := dDate
      inv->Ware := nWare
      inv->RHB  := nRHB
      inv->Unfertig := nUnfert
      inv->(dbUnLock())
   ENDIF
   
   //move to the next month, add 3 days to jump weekends at the end of themonth
   //dDate := Eom(dDate+3)

   //move to next year
   dDate := EoY(Addmonth(dDate,1))
ENDDO

Sinkey(0)
