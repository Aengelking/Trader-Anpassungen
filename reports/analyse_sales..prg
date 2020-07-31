LOCAL aReps := GetReps()
LOCAL nRep  := 1
LOCAL nCurrent := 0
LOCAL nLast := 0
LOCAL nBeforeLast := 0
LOCAL nOpen := 0,nKuOpen
LOCAL nQuote := 0
LOCAL hTurn,aQuote
LOCAL cSaveData := ""
LOCAL cFile     := Trim(Tr_Getini(1))+"\export\rep_"+LTrim(Str(aReps[1][nRep]))+"_sales.csv"
LOCAl cFormat   := "@E9,999,999.99"
MEMVAR c_one_list

NetUse("engkund","ku",.F.,0)
NetUse("buyer","buy",.F.,0)

Head(t("Analyse Verkäufe Außendienst"))
@ 02,05 SAY t("Verkäufer")
@ 02,15,14,40 GET nRep LISTBOX aReps[2] DROPDOWN COLOR c_one_list STATE ReadUpdated(.T.)
READ

ku->(dbSetOrder( 2 ))
ku->(dbSeek( "K" ))
cSaveData := "Kunde;Umsatz aktuell;Umsatz Vorjahr;Umsatz X-2;Offene Aufträge;Angebote min.;Angebote max"

DO WHILE ku->Group == "K" .AND. ! ku->(Eof())
	@ 10,05 SAY ku->Kunde
	IF ku->Rep == aReps[1][nRep]
		hTurn := GetCustomerTurnover(ku->Kunde)
    	nCurrent += hTurn["current"]
      nLast	 += hTurn["last"]
      nBeforeLast += hTurn["before-last"]
		nKuOpen  := GetCustomerOpenOrders(ku->Kunde)
		nOpen    += nKuOpen
		aQuote := GetCustomerOpenEnquiries(ku->Kunde)
		nQuote += aQuote[2]

		cSaveData += Chr(13)+Chr(10)+HB_AnsiToOem(ku->Kunde)+";"+StrTran(LTrim(Str(hTurn["current"]))+";"+LTrim(Str(hTurn["last"]))+";"+LTrim(Str(hTurn["before-last"]))+";"+LTrim(Str(nKuOpen))+";"+LTrim(Str(aQuote[1]))+";"+LTrim(Str(aQuote[2])),".",",")
	ENDIF
	ku->(dbSkip())
ENDDO
MemoWrit(cFile,cSaveData)
WAPI_ShellExecute(,"open",cFile)
@ 10,05 SAY Space(8)
? "Aktuelles Jahr ",Transform(nCurrent,cFormat)
? "Letztes Jahr   ",Transform(nLast,cFormat)
? "Vorletztes Jahr",Transform(nBeforeLast,cFormat)
? t("Offene Aufträge"),Transform(nOpen,cFormat)
? "Angebote (max.)",Transform(nQuote,cFormat)
Sinkey(0)