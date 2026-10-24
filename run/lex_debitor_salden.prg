#include '\\EK-Server4\data\harbour\trader\source\include\lexware.ch'

PROC RUN_LEX_DEBITOR_SALDEN
   LOCAL nYear := Year(Date())-1
   LOCAL getlist := {}
   LOCAL aAccounts,nAccount
   LOCAL dEoY,nSaldo,nSaldo2,hAccSalden,aOPs
   LOCAL hSalden := {=>},hAccount
   LOCAL aData := {{"Konto","Saldo"}},nX

   Head("Debitor Salden fr Steuerberater")
   IF ! LX_Start()
   	Alert("Keine Verbindung zu Lexware")
	   RETURN
   ENDIF

   @ 01,00 SAY "Jahr" GET nYear PICTURE "9999" VALID nYear >= 2010 .AND. nYear <= Year(Date())
   READ

   IF LastKey() == 27
      RETURN
   ENDIF

   dEoY := StoD(Str(nYear,4)+"1231")
   aAccounts := LX_GetAccountsInCat(LX_CAT_DEBITOR)

   FOR EACH nAccount IN aAccounts
      nSaldo := LX_GetSaldo(nAccount,dEoY)
      nOPSaldo := 0
      nRest  := nSaldo
      hAccSalden := {=>}
      IF nSaldo != 0
         ? nAccount,nSaldo
         IF nAccount == 22429
            AltD()
         ENDIF
         aOPs := LX_GetOffenePosten(nAccount,,nYear)
         AEval(aOPs,{|hData| 
            IF ! HHasKey(hAccSalden,hData["STEUERKONTO"])
               hAccSalden[hData["STEUERKONTO"]] := 0
            ENDIF
            hAccSalden[hData["STEUERKONTO"]] += hData["REST"]
            nRest -= hData["REST"]
            //nOPSaldo += hData["BETRAG"]-hData["REST"]
            RETURN NIL
         })
         IF nAccount == 22429
            Alert(ValToPrg(aOps))
            //EXIT
         ENDIF
         hAccSalden["KEIN OP"] := nSaldo         
         Aadd(aData,Array(Len(aData[1])))         
         ATail(aData)[1] := nAccount
         ATail(aData)[2] := nSaldo
         FOR EACH nSaldo2 IN hAccSalden
            ?? nSaldo2:__eNumKey(),":",nSaldo2
            nX := AScan(aData[1],nSaldo2:__eNumKey())
            IF nX == 0
               Aadd(aData[1],nSaldo2:__eNumKey())
               Aadd(ATail(aData),0)
               nX := Len(aData[1])
            ENDIF
            ATail(aData)[nX] := nSaldo2
         NEXT                  
      ENDIF
      IF nAccount == 17048
         //EXIT
      ENDIF 
   NEXT

   //Alert(ValToPRg(aData))
 
   SaveAsCSV(Wvt_GetOpenFileName( 0,"" , "CSV Datei", { {"Comma separated file (*.csv)","*.csv"},{"Alle Dateien (*.*)","*.*"} }, , Trim(Tr_getini(1))+"\export\" ),aData)

RETURN
