//#include 'inkey.ch'
PROCEDURE RUN_BERICHT_LIQUID

LOCAL cMatch,nValue,nKW,dDate
LOCAL hLiquid := {=>}
LOCAL hMonths := {=>},hMonth,cKey,aKeys
LOCAL hWeek
LOCAL dPayDate,dDelDate
LOCAL hOp,nWe
LOCAL hOpSummen,cCurrency,aOps,nX,nSumme,cLief

Head(HB_AnsiToOem("Liquidität"))

LX_Start()

NetUse( "engkund","ku")
NetUse( "engrech","rech")
NetUse( "englsre","re")
NetUse( "skontoa","sk")
NetUse( "skontob","skb")
NetUse( "engkund","ku")
NetUse( "engbes","bes")
NetUse( "engauf","auf")

NetUse("fibu","fibu")

CLS
SET PRINTER ON
SET PRINTER TO (Trim(Tr_Getini(1))+"\export\liquiditaet\out.csv")
?? "Lieferant,Rechnung,Datum,Fällig,KW,Summe,Währung,Offen,Offen EUR"

hOpSummen := LX_GetOffenePostenSummen(.F.)

FOR EACH nSumme IN hOPSummen   
   fibu->(dbSetOrder( 2 ))
   IF fibu->(dbSeek( Str(nSumme:__eNumKey(),6) ))
      cCurrency := IF(Empty(fibu->Currency),"E",fibu->Currency)
      ku->(dbSetOrder( 8 ))
      ku->(dbSeek( Str(fibu->Adresse,6) ))
      cLief := ku->Kunde
   ELSE
      fibu->(dbSetOrder( 3 ))
      IF fibu->(dbSeek( Str(nSumme:__eNumKey(),6) )) //WD Konto ignorieren
         LOOP
      ENDIF
      cCurrency := "E"
      cLief := LX_GetAccountName(nSumme:__eNumKey)
   ENDIF   
      aOps := LX_GetOffenePosten(nSumme:__eNumKey(),.F.)
      FOR nX := 1 TO Len(aOps)
         hOp := aOps[nX]
         nKW := Cweek(hOp:Faellig)
         nValue := hOp:Rest*Currate(cCurrency,"E")
         //LX_GetOffenePosten does not return szBelegNr!
         ? cLief+","+LTrim(Str(hOp:Nr))+","+DToC(hOp:Datum)+","+DToC(hOp:Faellig)+","+NiceWeek(nKW)+","+_CSVNtoS(hOp:Betrag)+","+Currate(cCurrency,"X")+","
         ?? _CSVNtoS(hOP:Rest)+","+_CSVNtoS(nValue)
         _NewLQKW(hLiquid,nKW)
         hLiquid[nKW]:Out += nValue         
         hMonths[_NewMonth(hMonths,hOp:Faellig)]:Out += nValue
      NEXT
   //ENDIF
NEXT


rech->(dbsetorder(1))
rech->(dbGoTop())
DO while ! rech->(eof()) 
	ku->(dbSetOrder(1))
	If ! ku->(dbseek(rech->liefma+"L"))
		Return
	Endif
   //@ 05,00 SAY Str(nCur)
   


	cMatch := rech->liefma

	DO WHILE ! rech->(EOF()) .AND. rech->liefma == cMatch 
		
		IF rech->rechdat >= SToD("20130101") .AND. rech->Booked .AND. rech->Status == 0 .AND. rech->Payme == 0
         
         dDate := IF(Trim(cMatch)$"BULGIN ITW ITWMETAL EDAC SCOLMORE TECHNO",EoM(rech->Rechdat)+30,rech->rechdat+Max(rech->Wait,rech->WaitSkonto))
         nKW    := CWeek( dDate )
         IF rech->Transfer
            /*hOP := LX_GetOffenerPosten(rech->Konto,rech->Rechnr,.F.)
            IF Len(hOP) == 0
               ? rech->Liefma,rech->Rechnr,LX_GetErrorMessage()
            ELSEIF hOP:nRest != 0//noch offen
               nValue := hOp:nRest*Currate(rech->Money,"E")
               ? rech->Liefma+","+rech->Rechnr+","+DToC(rech->rechdat)+","+DToC(dDate)+","+NiceWeek(nKW)+","+_CSVNtoS(rech->netamt)+","+Currate(rech->Money,"X")+","
               ?? _CSVNtoS(hOP:nRest)+","+_CSVNtoS(nValue)
               _NewLQKW(hLiquid,nKW)
               hLiquid[nKW]:Out += nValue
               //nTot+= nValue
            ELSE
                rech->(Rec_Lock(0))
                rech->Status := 1
                rech->(dbUnLock())
            ENDIF*/
         ELSE
            //?  rech->Liefma,rech->Rechnr,t("noch nicht übertragen")
            nValue := rech->Gramt*Currate(rech->Money,"E")
            _NewLQKW(hLiquid,nKW)
            hLiquid[nKW]:Out += nValue
            hMonths[_NewMonth(hMonths,dDate)]:Out += nValue
         ENDIF
		Endif
		rech->(dbSkip( 1 ))
	enddo
ENDDO


SET PRINTER TO  (Trim(Tr_Getini(1))+"\export\liquiditaet\in.csv")
?? "Kunde,Rechnung,Datum,Fällig,Offen"
re->(dbSetOrder( 3 ))
re->(dbSeek( Str( 0,1 )+ Str( 0,3 ) ))
DO WHILE re->Status <= 1 .AND. re->reposnr == 0 .AND. ! re->(Eof())
   IF re->code == 2 //unbezahlt
      nValue := (re->poswt-re->aoqty)*CURRATE(re->money,"V")
      IF nValue != 0
         ku->(dbSetOrder( 1 ))
         ku->(dbSeek( re->Kunde+"K" ))

         ? HB_OemToAnsi(re->Kunde)+","+Str(re->Rechnr)+","+DToc(re->Rechdat)+","+DToc(re->Rechdat+sk->(GetSkontoWait(re->skonto,re->Rechdat,Date())))+","+_CSVNtoS(nValue)
         dDate := re->Rechdat+sk->(GetSkontoWait(re->skonto,re->Rechdat,Date()))
         nKW := CWeek(dDate)
         IF nKW >= CWeek( Date() - 365*3 ) //verjährt
           IF nKW <= CWeek(Date()-60)
              nKW := 0
           ENDIF
           _NewLQKW(hLiquid,nKW)
           hLiquid[nKW]:In += nValue
           hMonths[_NewMonth(hMonths,dDate)]:In += nValue
        ENDIF
      ENDIF
   ENDIF
   re->(dbSkip())
ENDDO

SET PRINTER TO  (Trim(Tr_Getini(1))+"\export\liquiditaet\bes.csv")
?? "Lieferant,Nummer,Artikel,KW,Offen,Wareneingang"
bes->(dbSetOrder( 1 )) //str(besnr)+str(posnr)
bes->(dbGoTop())
DO WHILE ! bes->(EOF())
    IF bes->Besda >= SToD("20120101") .AND. bes->bestat <= 2
   
      nValue := (bes->BeQty-bes->GelQty)*bes->EkPr/bes->pe*Currate(bes->Money,"E")
      IF bes->GelQty > bes->BeQty .AND. bes->ZoQty == bes->GelQty-bes->BeQty  //überliefert
        nValue := 0
      ENDIF
      nWe := bes->ZoQty*bes->EkPr/bes->pe*Currate(bes->Money,"E")

      ku->(dbSeek( bes->Liefma+"L" ))
      dDate  := CalWD(bes->Lterm)
      nKW    := CWeek( dDate+skb->(GetSkontoWait( ku->Skonto, dDate )) )
      IF nKW < CWeek(Date()-60)
        nKW := 0
      ENDIF
      IF ! Right(Str(bes->Lterm,4),2) == "99"
        _NewLQKW(hLiquid,nKW)
        hLiquid[nKW]:Bes += nValue
        hLiquid[nKW]:We += nWE
        cKey := _NewMonth(hMonths,dDate)
        hMonths[cKey]:Bes += nValue
        hMonths[cKey]:We += nValue
      ENDIF
      IF nValue != 0 .OR. nWE != 0
        ? bes->Liefma+","+Str(bes->besnr)+","+bes->matchcode+","+NiceWeek(nKW)+","
        ?? _CSVNToS(nValue)+","
        ?? _CSVNToS(nWe)
      ENDIF
    ENDIF
    bes->(dbSkip())
ENDDO

SET PRINTER TO  (Path("export\liquiditaet\auf.csv"))
auf->(dbSetOrder( 14 ))
dbSelectArea("AUF")
SET FILTER TO Right(Str(auf->Dterm),2) != "99" .AND. auf->GelQty < auf->VkQty
//auf->(dbSeek( Str(0,3) ))
auf->(dbGoTop())
?? "Kunde,AB-Nr,Matchcode,KW,Wert,Zahldatum"
DO WHILE auf->bestat < 3 .AND. ! auf->(EOF())
    IF Right(Str(auf->Dterm),2) != "99"  //keine Rahmenpositionen
        ku->(dbSeek( auf->Kundma+"K" ))
        IF ! sk->(IsPrePay(ku->Skonto))
         nValue := (auf->VkQty-auf->GelQty)*auf->vkpr / auf->pe * ( 100 -auf->Rabatt ) / 100 * If(!Empty(auf->money),Currate(auf->Money,"V"),1)
         IF nValue != 0
            IF ku->Justintime
               dDelDate := auf->BDatum
            ELSE
               dDelDate := CalWd(auf->Dterm)
            ENDIF
            dPayDate := dDelDate+sk->(GetSkontoWait(ku->Skonto,Date()))
            nKW    := CWeek( dPayDate )
            ? HB_OemToAnsi(auf->Kundma)+","+Str(auf->Abnr)+","+auf->Matchcode+","+NiceWeek(nKW)+","+_CSVNtoS(nValue)+","+DtoC(dPayDate)
            IF nKW < CWeek( Date() )
               nKW := 0
            ENDIF
            _NewLQKW(hLiquid,nKW)
            hLiquid[nKW]:Auf += nValue
            hMonths[_NewMonth(hMonths,dPayDate)]:Auf += nValue
         ENDIF
      ENDIF
    ENDIF
    auf->(dbSkip())
ENDDO

SET PRINTER TO  (Trim(Tr_Getini(1))+"\export\liquiditaet\weeks.csv")
?? "KW,Zufluss,Abgang,Wareneingang,Bestellungen,Aufträge"
FOR EACH hWeek IN hLiquid
   ? NiceWeek(hWeek:__enumKey())+","+_CSVNtoS(hWeek:In)+","+_CSVNtoS(hWeek:Out)+","+_CSVNToS(hWeek:WE)+","+_CSVNToS(hWeek:Bes)+","+_CSVNToS(hWeek:Auf)
NEXT

SET PRINTER OFF
SET PRINTER TO

aKeys := HGetKeys(hMonths)
ASort(aKeys)
CLS
? Pad("Monat",6),Pad("Eingang",12),Pad("Ausgang",12),Pad("WE",12),Pad("Bestellungen",12),Pad("Auftr„ge",12)
FOR EACH cKey IN aKeys
   IF Left(cKey,4) >= Str(Year(Date()),4)
      hMonth := hMonths[cKey]
      ? cKey,Str(hMonth:In,12,2),Str(hMonth:Out,12,2),Str(hMonth:WE,12,2),Str(hMonth:Bes,12,2),Str(hMonth:Auf,12,2)
   ENDIF
NEXT
Sinkey(0)

Static Function _NewLQKW(hLiquid,nKW)
  IF ! HHasKey(hLiquid,nKW)
    hLiquid[nKW] := {"IN"=>0,"OUT"=>0,"BES"=>0,"AUF"=>0,"WE"=>0,"UST_IN"=>0,"UST_OUT"=>0}
  ENDIF
RETURN NIL

STATIC Function _NewMonth(hMonths,dDate)
   LOCAL cKey := Str(Year(dDate),4)+StrZero(Month(dDate),2)
   IF ! HHasKey(hMonths,cKey)
      hMonths[cKey] := {"IN"=>0,"OUT"=>0,"BES"=>0,"AUF"=>0,"WE"=>0,"UST_IN"=>0,"UST_OUT"=>0}
   ENDIF
RETURN cKey

Static Function _CSVNtoS(nNum)

RETURN '"'+StrTran(Ltrim(Str(nNum,12,2)),".",",")+'"'