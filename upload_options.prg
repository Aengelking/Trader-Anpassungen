NetUse("artikel","art")

cTempDBF := GetEnv("TEMP")+"\option.dbf"
cTempFTP := GetEnv("TEMP")+"\ftp.txt"
? cTempDBF
Select(0)
dbCreate(cTempDBF,{{"TABKEY","C",10,0},{"DESCRIPT","C",35,0},{"FUNKTION","C",25,0},{"TABLENR","N",2,0}},"DBFCDX",.T.,"temp")

oBase := OptionBase():New()
oBase:Load("NZ/")
oBase:oTables:Each({|oTable|
   ? oTable:Funktion
   oTable:oKeys:Each({|oKey|
      temp->(dbAppend())
      temp->TabKey   := oKey:TabKey
      temp->Descript := HB_OemToAnsi(oKey:Descript)
      temp->Funktion := HB_OemToAnsi(oKey:oTable:Funktion)
      temp->TableNr  := oKey:oTable:Table
   })
})
temp->(dbCloseArea())
Inkey(0,128)
FErase(cTempDBF)
