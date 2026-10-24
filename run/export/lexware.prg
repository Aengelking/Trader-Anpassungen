/*
* OLD VERSION under obsolete\lexware.prg
*/

LX_ImportInvoice()
/*#define CRLF Chr(13)+Chr(10)

cProtokoll := Trim(Tr_Getini(1))+"\export\lexware_protocol_"+DToS(Date())+"_"+StrTran(Time(),":","-")+".txt"

dStart := CToD("20.10.2010")

Head("Export Buchungsdaten fr Lexware Buchhalter")

NetUse("engkund","ku",.F.,0)
NetUse("englsre","re",.F.,0)
NetUse("engnr","nr",.F.,0)
nr->(Rec_Lock(0));nr->Uebnr := nr->Uebnr+1;nr->(dbUnLock())
nNr := nr->Uebnr

nPH := FCreate( cProtokoll )

If ! Lx_Start()
	FWrite(nPH,"Verbindung zu Lexware konnte nicht hergestellt werden")
Else
	If MsgBox("Import in Lexware Firma "+LX_GetFirma(),,{"Nein","Ja"}) != 2
		FWrite(nPH,"Import durch Benutzer abgebrochen")
		FClose(nPH)
		Return
	Endif
	@ 23,00 SAY "Ausgangsrechnungen"
	re->(dbSetOrder(2))
	re->(dbGoTop())

	Do While .NOT. re->(EOF()) .AND. re->reposnr == 0 .AND. Inkey() <> 27 .AND. LastKey() <>27
	  If re->Rechdat > dStart .AND. ! re->transfer
	  	FWrite(nPH,"Rechnung "+Str(re->rechnr,6)+" "+DToC(re->rechdat)+" ")
	  	If re->transfer
	  		FWrite(nPH,"bereits übertragen")
	  	Elseif ! re->packed //.or. re->code < 2
			FWrite(nPH,If(!re->packed,"nicht gepackt","nicht gedruckt"))
		Elseif re->poswt == 0
			FWrite(nPH,"Nullrechnung")
			re->(Rec_Lock(0))
		    re->transfer := .T.
		    re->(dbUnlock())
		Else
			ku->(dbSetOrder(2))
		    If ! ku->(dbSeek("K"+re->kunde)) //+"K"))
		      FWrite(nPH,"Kunde "+re->Kunde+" nicht gefunden!")
		      re->(dbSkip())
		    Elseif ! LX_CreateDebtor() .OR. ! LX_BookInvoice()
				FWrite(nPH,	LX_GetErrorMessage())
			Else
				FWrite(nPH,"übertragen")
		    	re->(Rec_Lock(0))
		    	re->transfer := .T.
		    	re->(dbUnlock())
		    Endif
	    Endif
	    FWrite(nPH,CRLF)
	  Endif
	  re->(dbSkip())
	Enddo
Endif
FClose(nPH) */