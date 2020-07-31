LOCAL aLief := {}
LOCAL cFile := Trim(Tr_Getini(1))+"\export\suppliers.csv"

NetUse("engbes","bes")

bes->(dbSetFilter({|| bes->Besda >= StoD("20150101") },"Besda >= StoD('20150101')"))
IF ! LETO_ISFLTOPTIM()
   Alert("NOT OPTIMISED")
ENDIF
DO WHILE ! bes->(EOF())
   IF Ascan(aLief,{|x| x[1] == bes->Liefma }) == 0
      @ MaxRow(),00 SAY bes->Liefma
      oLief := Adresse():New(.F.)
      oLief:LoadMatchcode(bes->Liefma,"L")
      IF oLief:CountryIso == "DE"
         Aadd(aLief,{bes->Liefma,oLief:cName,oLief:Street,oLief:Plz,oLief:town,oLief:Telefax,oLief:Email})
      ENDIF
   ENDIF
   bes->(dbSkip())
ENDDO

bes->(dbClearFilter())

SaveAsCSV(cFile,aLief)
WAPI_ShellExecute(,"open",cFile)
