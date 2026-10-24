Head("Export Buchungsdaten fr Lexware Buchhalter")
cFax := "@@NUMMER"
cEnt := Chr(13)+Chr(10)
NetUse("anrede","an",.F.,0)
NetUse("engkund","ku",.F.,0)
NetUse("engpay","pay",.F.,0)
NetUse("englsre","re",.F.,0)
NetUse("vat","vat",.F.,0)
NetUse("engnr","nr",.F.,0)
nr->(Rec_Lock(0));nr->Uebnr := nr->Uebnr+1;nr->(dbUnLock())
nNr := nr->Uebnr

cPath := Trim(If(!Empty(Tr_Getini(35)),Tr_getini(35),Tr_GetIni(1)))+"\export\lexware\"


// ONLY CURRENT MONTH OR EARLIER !!!!!
dbSelectArea("pay")
NetUse("skontob","sk",.F.,0)
@ 23,00 SAY "Eingangsrechnungen"
cF := cPath+"buchung.txt"
@ 02,00 SAY "Buchungen werden nach "+cF+" exportiert"
If File(cF)
  FErase(cF)
Endif
nBuch := FCreate( cF )

cF := cPath+"kreditor.txt"
@ 03,00 SAY "Kreditoren werden nach "+cF+" exportiert"
If File(cF)
  FErase(cF)
Endif
nKu := FCreate( cF )

cF := cPath+"debitor.txt"
@ 04,00 SAY "Debitoren werden nach "+cF+" exportiert"
If File(cF)
  FErase(cF)
Endif
nKu := FCreate( cF )

Do While ! pay->(EOF()) .AND. Inkey() <> 27
  @ 24,00 SAY pay->Rechnr
    If pay->booking == 1 .AND. pay->status <= 1 .AND. ! pay->transfer .AND. ku->(dbSeek(pay->kundma+"L")) .AND. ! pay->Betrag == 0
    vat->(dbGoTo(pay->Steuer))
    cKonto := If(pay->Rechdat>=vat->Date,vat->ekneu,vat->ekalt)
    //can't find these fields in the db!!
	//nSteuer:= If(pay->Rechdat>=vat->Date,vat->vorstneu,vat->vorstalt)
	nSteuer := vat->vatvorst
    cSoll := If(pay->Betrag>=0,If(pay->Steuer==0,"3200",cKonto),Str(ku->Nummer))
    cHaben := If(pay->Betrag<0,If(pay->Steuer==0,"3200",cKonto),Str(ku->Nummer))
    cBeleg := ""
    nX := 1
    Do While nX <= Len(pay->Rechnr)
      cBeleg := cBeleg+Str(Val(SubStr(pay->Rechnr,nX,1)),1)
      nX := nX+1
    Enddo
    nBetW := Abs(pay->Betrag)
    nBetrag := nBetW*If(pay->Money=="D",1,Currate(pay->Money,"E"))
    cCur := If(pay->Money=="D","DM","EUR")

    FWrite(nBuch, DToC(pay->Rechdat)+",ER,"+cBeleg+","+Str(nBetrag)+","+cCur+","+cSoll+","+cHaben+","+Str(nSteuer,1) )
    FWrite(nBuch,",("+Str(nNr,5)+") "+If(pay->Betrag<0,"Belastungsanzeige ",""))
    FWrite(nBuch,If(!pay->Money=="E".AND. !pay->Money=="D",Currate(pay->Money,"X")+" "+LTrim(Str(Abs(nBetW))) ,"" )+" "+pay->REchnr+cEnt )

    cAnrede := If(ku->language=="D","Sehr geehrte Damen und Herren","Dear")
    If ! Empty(ku->Person)
      ko_pers := 1
      cAnrede := StrTran(Anrede(),Trim(ku->Person),"")
    Endif
    sk->(dbGoTo(ku->Skonto+1))

    FWrite(nKu,Str(ku->Nummer)+","+ku->Kunde+",")
    FWrite(nKu,Trim(ku->Name1)+" "+ku->Name2+","+ku->Street+","+ku->Plz+","+StrTran(ku->Town,",","-")+",")
    FWrite(nKu,ku->Telefon+","+Trim(cFax)+ku->TeleFax+","+cAnrede+","+ku->Person+",")
    FWrite(nKu,ku->Bank+","+ku->Blz+","+ku->Konto +","+Str(ku->CredLimit)+",E,")
    FWrite(nKu,If(sk->rate1==0,Str(sk->ziel1)+",0,0",Str(sk->rate2)+","+Str(sk->rate1)+","+Str(sk->ziel1) ) +cEnt)

    pay->(REC_LOCK(0))
    //pay->transfer := .T.
    pay->(dbUnLock())
  Endif
  pay->(dbSkip())
Enddo

FClose(nKu)

NetUse("skontoa","sk",.F.,0)
@ 23,00 SAY "Ausgangsrechnungen"
re->(dbSetOrder(2))
re->(dbGoTop())

Do While .NOT. re->(EOF()) .AND. re->reposnr == 0 .AND. Inkey() <> 27 .AND. LastKey() <>27
  @ 24,00 SAY re->Rechnr
  If re->code == 2 .AND. ! re->transfer .AND. re->Packed .AND. ! (re->poswt-re->aoqty) == 0
    If !  ku->(dbSeek(re->kunde+"K"))
      Alert("Kunde "+re->Kunde+" nicht gefunden!")
      re->(dbSkip())
      Loop
    Endif
    re->(Rec_Lock())
*    If Empty(re->Rate)
//      re->Rate := Currate(re->Money,"V")
*    Endif
    re->(dbUnLock())
    nBetW := (re->poswt-re->aoqty)
    nBetrag := nBetW*If(re->Money=="D",1,re->rate)
    cCur := If(re->Money=="D","DM","EUR")
    vat->(dbGoTo(re->taxcode))
    cKonto := If(re->Rechdat>=vat->Date,vat->verkneu,vat->verkalt)
    //nSteuer:= If(re->Rechdat>=vat->Date,vat->umstneu,umstalt)
    nSteuer := vat->vatumst
    cSoll := If(nBetrag<0,If(re->taxcode==0,"8120",cKonto),Str(ku->Nummer))
    cHaben := If(nBetrag>=0,If(re->taxcode==0,"8120",cKonto),Str(ku->Nummer))
    FWrite(nBuch, DToC(re->Rechdat)+",AR,"+Str(re->Rechnr)+","+Str(Abs(nBetrag))+","+cCur+","+cSoll+","+cHaben+","+Str(nSteuer,1))
    FWrite(nBuch,",("+Str(nNr,5)+") "+If(nBetrag<0,"Gutschrift ",""))
    FWrite(nBuch,If(!re->Money=="E".AND.!re->Money=="D" ,Currate(re->Money,"X")+" "+LTrim(Str(Abs(nBetW))),"") +cEnt)

      cAnrede := If(ku->language=="D","Sehr geehrte Damen und Herren","Dear")
      If ! Empty(ku->Person)
        ko_pers := 1
        cAnrede := StrTran(Anrede(),Trim(ku->Person),"")
      Endif
      sk->(dbGoTo(ku->Skonto+1))
    FWrite(nKu,Str(ku->Nummer)+","+ku->Kunde+",")
    FWrite(nKu,Trim(ku->Name1)+" "+ku->Name2+","+ku->Street+","+ku->Plz+","+StrTran(ku->Town,",","-")+",")
    FWrite(nKu,ku->Telefon+","+Trim(cFax)+ku->TeleFax+","+cAnrede+","+ku->Person+",")
    FWrite(nKu,ku->Bank+","+ku->Blz+","+ku->Konto +","+Str(ku->CredLimit)+",E,")
    FWrite(nKu,If(sk->rate1==0,Str(sk->ziel1)+",0,0",Str(sk->rate2)+","+Str(sk->rate1)+","+Str(sk->ziel1) ) +cEnt)

    re->(Rec_Lock(0))
    //re->transfer := .T.
    re->(dbUnlock())
  Endif
  re->(dbSkip())
ENDDO

FClose(nKu)
FClose(nBuch)
