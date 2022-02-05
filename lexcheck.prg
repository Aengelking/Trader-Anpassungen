PROC RUN_LEXCHECK
LOCAL hDebitoren := {=>}
LOCAL nX
LOCAL nYear := Year(Date())
LOCAL dEoY
LOCAL getlist := {}
LOCAL oPDF
LOCAL aInvoices,nR,hOps,nSumme,nKonto,nLXSaldo,hSummen
LOCAL nNummer,nSaldo

Head("Abstimmung Lexware")

NetUse("englsre","re",.F.,0)
NetUse("engkund","ku")
NetUse("fibu","fibu")

IF ! LX_Start()
	Alert("Keine Verbindung zu Lexware")
	Return
ENDIF

IF LastKey() == 27
	RETURN
ENDIF

@ 01,00 SAY "Jahr" GET nYear PICTURE "9999"
READ

IF LastKey() == 27
   RETURN 
ENDIF

dEoY := StoD(Str(nYear,4)+"1231")

StartPrint(,,"PDF")
oPdf := GetCurrentPrinterObject():Data
oPdf:NewPage()





@ 09,00 SAY "Debitoren"
re->(dbSetOrder( 3 ))
re->(dbSetFilter({|| re->Reposnr == 0 .AND. re->Packed .AND. re->Code != 3 .AND. re->poswt != 0 .AND. re->RechDat <= dEoY },"Reposnr == 0 .AND. Packed .AND. Code != 3 .AND. poswt != 0 .AND. RechDat <= StoD("+DtoS(dEoY)+")"))
re->(dbGoTop())
ku->(dbSetOrder( 1 ))
DO WHILE re->Status < 3  .AND. ! re->(Eof())
	//IF re->Reposnr == 0 .AND. re->Packed .AND. re->Code != 3 .AND. re->poswt != 0
		@ 09,10 SAY re->Rechnr
		ku->(dbSeek( re->Kunde+"K" ))
		IF ! HHasKey(hDebitoren,ku->Nummer)
			hDebitoren[ku->Nummer] := {"saldo"=>0,"lastdate"=>Date(),"invoices"=>{}}
		ENDIF
		hDebitoren[ku->Nummer]["saldo"] += re->PosWt-re->AoQty
		hDebitoren[ku->Nummer]["lastdate"] := Min(hDebitoren[ku->Nummer]["lastdate"],re->Rechdat)
        Aadd(hDebitoren[ku->Nummer]["invoices"],re->Rechnr)
	//ENDIF
	//IF re->Reposnr == 0
		re->(dbSkip())
	/*ELSE
		re->(dbSeeK( Str(re->Status+1) ))
	ENDIF*/
ENDDO
re->(dbClearFilter())

@ 10,00 SAY "Offeneposten"

oPdf:SetFont("Courier-Bold",0,14)
oPdf:AtSay("Differenzen zwischen OP und Debitorenkonto")
oPdf:SetFont("Courier",0,12)
oPdf:NewLine()
oPdf:AtSay(PadL("Konto",6)+" "+PadL("OP",10)+" "+PadL("Debitor",10))

hOps := LX_GetOffenePostenSummen(,nYear)
nSumme := 0

FOR EACH nSumme IN hOps
	nKonto := nSumme:__eNumKey()
	@ 10,13 SAY nKonto
	nLXSaldo := LX_GetSaldo(nKonto,dEoY)
	IF ! HHAsKey(hDebitoren,nKonto) .AND. nLxSaldo == 0 //.AND. nSumme > 0
		/*Aadd(aReset,{nKonto,.T.,""})
		aOps := LX_GetOffenePosten(nKonto)
		hOp := NIL
		FOR EACH hOp IN aOps
			IF ! LX_ResetOffenerPosten(hOp:Nr)
				ATail(aReset)[2] := .F.
				ATail(aReset)[3] += LX_GetErrorMessage()+";"
			ENDIF
		NEXT*/
	ELSEIF Round(nLxSaldo,2) != Round(nSumme,2)
		oPdf:NewLine()
		oPdf:AtSay(Str(nKonto,6)+" "+Str(nSumme,10,2)+" "+Str(nLxSaldo,10,2))
	ENDIF
NEXT

fibu->(dbSetOrder( 3 ))

oPdf:NewPage()
oPdf:SetFont("Courier-Bold",0,14)
oPdf:AtSay("Differenzen zwischen OP und Kreditorenkonto")
oPdf:SetFont("Courier",0,12)
oPdf:NewLine()
oPdf:AtSay(PadL("Konto",6)+" "+Space(30)+" "+PadL("OP",10)+" "+PadL("Kreditor",10))

hOps := LX_GetOffenePostenSummen(.F.,nYear)
nSumme := 0

FOR EACH nSumme IN hOps
	nKonto := nSumme:__eNumKey()
	@ 10,13 SAY nKonto
	//IF ! fibu->(dbSeek( Str(nKonto,6) )) //Währungsdifferenzkonten ignorieren, da diese sowieso zum Monatsende abgelichen werden und dadurch auch Differenzen zwischen OP und Kreditorenkten entstehen können
   	nLXSaldo := LX_GetSaldo(nKonto,dEoY)
   	hSummen := LX_GetSummen(nKonto,StoD("20000101"),dEoY,.T.,.F.) //all bookings in the stapel
   	nLXSaldo += hSummen:Haben-hSummen:Soll
   	IF Abs(nLxSaldo-nSumme) > 0.03
   		oPdf:NewLine()
   		oPdf:AtSay(Str(nKonto,6)+" "+Pad(LX_GetAccountName(nKonto),30)+" "+Str(nSumme,10,2)+" "+Str(nLxSaldo,10,2))
   	ENDIF
   //ENDIF
NEXT

/*oPdf:NewPage()
oPdf:SetFont("Courier-Bold",0,14)
FOR nX := 1 TO 2
	IF nX == 2
		oPdf:NewLine(2)
	ENDIF
	oPdf:AtSay("Offeneposten für folgende Konten "+IF(nX==1,"wurden","konnten NICHT")+" zurückgesetzt"+IF(nX==2," werden",""))
	oPdf:SetFont("Courier",0,12)
	oPdf:NewLine()
	oPdf:AtSay(Pad("Konto",6))
	aKonto := {}
	FOR EACH aKonto IN aReset
		IF (nX == 1 .AND. aKonto[2]) .OR. (nX==2 .AND. ! aKonto[2])
			oPdf:NewLine()
			oPdf:AtSay(LTrim(str(aKonto[1])))
			IF nX == 2
				oPdf:AtSay(" "+aKonto[3])
			ENDIF
		ENDIF
	NEXT
NEXT */

oPdf:NewPage()
oPdf:SetFont("Courier-Bold",0,14)
oPdf:AtSay("Konten mit Saldendifferenzen")
oPdf:SetFont("Courier",0,12)
oPdf:NewLine()
oPdf:AtSay(PadL("Konto",6)+" "+PadL("Trader",10)+" "+PadL("Lexware",10))
FOR nX := 1 TO Len(hDebitoren)
	nNummer := HGetKeyAt(hDebitoren,nX)
	nSaldo  := HGetValueAt(hDebitoren,nX)["saldo"]
	nLxSaldo := LX_GetSaldo(HGetKeyAt(hDebitoren,nX),dEoY)
	IF nLxSaldo == 0 .AND. nSaldo != 0 .AND. HGetValueAt(hDebitoren,nX)["lastdate"] <= Date()-(4*365)
		aInvoices := HGetValueAt(hDebitoren,nX)["invoices"]
		FOR nR := 1 TO Len(aInvoices)
			re->(dbSetOrder( 12 ))
			re->(dbSeek( Str(aInvoices[nR],6)+Str(0,3) ))
			oPdf:NewLine()
			oPdf:AtSay("Rechnung "+LTrim(Str(aInvoices[nR],6))+" vom "+DToC(re->Rechdat)+" auf erledigt gesetzt")
			re->(Rec_Lock())
			re->Status := 3 //auf erledigt setzten
			re->(dbUnLOck())
		NEXT

	ELSEIF Round(nSaldo,2) != Round(nLXSaldo,2)
		oPdf:NewLine()
		oPdf:AtSay(Str(nNummer,6)+" "+Str(nSaldo,10,2)+" "+Str(nLXSaldo,10,2))
    ENDIF
NEXT

CopyPrint()
//Inkey(0,128)
LX_Close()