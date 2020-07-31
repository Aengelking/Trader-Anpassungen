#define MONTHS 5
FUNC RUN_REPORT_FREMDWAEHRUNG(lReturn)
LOCAL hOpSummen,nSumme
//LOCAL nBesOpen,nWeOhne
LOCAL nValue,nPayDate
LOCAL hCurs := {=>},hCur
LOCAL hSuppliers := {=>}
LOCAL cSupKey
LOCAL nWait,xMonth,dDelDate
LOCAL cNumFormat := "@E 999,999.99"
LOCAL cCurrency
LOCAL cList
LOCAL bNewHashKey
LOCAL aOPs,nX,nPreis
LOCAL lBes := .T.

Default(@lReturn,.F.)

IF ! lReturn
   Head(t("Fremdwährungsbedarf berechnen"))
   IF Tr_Getini(28) == 9
      lBes := Tr_Msgbox("Mit offenen Bestellungen?",,{"Ja","Nein"}) != 2
      SetPos(0,0)
   ENDIF      
ENDIF

NetUse("fibu","fibu")
NetUse("engkund","ku")
NetUse("engbes","bes")
NetUse("skontob","skb")

LX_Start()
hOpSummen := LX_GetOffenePostenSummen(.F.)

fibu->(dbSetOrder( 2 )) //konto
ku->(dbSetOrder( 8 ))
bes->(dbSetOrder( 2 ))

bNewHashKey := {|lFibu,nKonto|
   IF ! HHasKey(hCurs,cCurrency)
      hCurs[cCurrency] := {"AFTER"=>0}
      FOR nX := 0 TO MONTHS
         hCurs[cCurrency][nX] := 0
      NEXT
   ENDIF
   IF lFibu
      cSupKey := Str(fibu->Adresse,6)+cCurrency
   ELSE
      cSupKey := "K"+Str(nKonto,6)+cCurrency
   ENDIF
   IF ! HHasKey(hSuppliers,cSupKey)
      hSuppliers[cSupKey] := {"AFTER"=>0}
      FOR nX := 0 TO MONTHS
         hSuppliers[cSupKey][nX] := 0
      NEXT
   ENDIF
   RETURN NIL
}


//? Pad("Konto",6),PadL("Lieferant",8),PadL("OP's",9),PadL("WE",9),PadL("BES",9)

FOR EACH nSumme IN hOPSummen   
   fibu->(dbSetOrder( 2 ))
   IF fibu->(dbSeek( Str(nSumme:__eNumKey(),6) )) //.AND. fibu->Currency != "E" .AND. ! Empty(fibu->Currency)
      cCurrency := IF(Empty(fibu->Currency),"E",fibu->Currency)
   ELSE
      fibu->(dbSetOrder( 3 ))
      IF fibu->(dbSeek( Str(nSumme:__eNumKey(),6) )) //WD Konto ignorieren
         LOOP
      ENDIF
      cCurrency := "E"
   ENDIF
      Eval(bNewHashKey,fibu->(Found()),nSumme:__eNumKey())
   
//      ? Pad(nSumme:__eNumKey(),6),ku->Kunde,Str(nSumme,9,2),Str(nWeOhne,9,2),Str(nBesOpen,9,2),Currate(fibu->Currency,"X")
      aOps := LX_GetOffenePosten(nSumme:__eNumKey(),.F.)
      FOR nX := 1 TO Len(aOps)
         xMonth := _GetMonth(aOps[nX]:Faellig) //Month(aOps[nX]:Faellig)-Month(Date())
         hCurs[cCurrency][xMonth] += aOps[nX]:Rest
         hSuppliers[cSupKey][xMonth] += aOps[nX]:Rest
      NEXT
   //ENDIF
NEXT

fibu->(dbSetOrder( 2 ))
fibu->(dbGoTop())
DO WHILE ! fibu->(EOF())
   IF .T. /*fibu->Currency != "E" .AND. ! Empty(fibu->Currency)*/
      cCurrency := IF(Empty(fibu->Currency),"E",fibu->Currency)
      Eval(bNewHashKey,.T.)



      //nWeOhne := 0
      //nBesOpen := 0

      ku->(dbSeek( Str(fibu->Adresse,6) ))
      bes->(dbSetFilter({|| bes->Besda >= Date()-365*2 },"Besda >= Date()-365*2"))
      bes->(dbSeek( ku->Kunde ))

      DO WHILE bes->Liefma == ku->Kunde .AND. bes->BeStat < 3 .AND. ! bes->(EOF())
         nPreis := bes->EkPr/bes->Pe*(1-bes->Rabatt/100)

         IF ! skb->(IsPrePay(ku->Skonto))
            nWait := skb->(GetSkontoWait(ku->Skonto,Date(),Date()))
         ELSE
            nWait := 0
         ENDIF
         nPayDate := Date()+nWait

         //WE ohne Rechnung
         xMonth := IF(nPayDate <= EOM(Date()),0,1)
         nValue := bes->ZoQty*nPreis
         //nWeOhne += nValue
         hCurs[cCurrency][xMonth] += nValue
         hSuppliers[cSupKey][xMonth] += nValue

         dDelDate := CalWD(bes->LTerm)
         IF dDelDate < Date()
            dDelDate := Date()
         ENDIF
         IF ! skb->(IsPrePay(ku->Skonto))
            nWait := skb->(GetSkontoWait(ku->Skonto,dDelDate,Date()))
         ELSE
            nWait := 0
         ENDIF
         nPayDate := dDelDate+nWait

         //Zukünftige Lieferungen
         IF lBes
            nValue := (bes->BeQty-bes->GelQty)*nPreis
            //nBesOpen += nValue
            xMonth := IF(skb->(IsPrePay(ku->Skonto)),0,_GetMonth(nPayDate))
            hCurs[cCurrency][xMonth] += nValue
            hSuppliers[cSupKey][xMonth] += nValue
         ENDIF
         bes->(dbSkip())
      ENDDO
      bes->(dbClearFilter())
   ENDIF
   fibu->(dbSkip())
ENDDO

IF lReturn 
   RETURN {hCurs,hSuppliers}
ENDIF

?
? Space(3)
FOR nX := 0 TO MONTHS
   ?? "",PadL(_MonthName(nX),10)
NEXT
?? "",PadL("Danach",10)
FOR EACH hCur IN hCurs
   ? Currate(hCur:__eNumKey(),"X")
   FOR nX := 0 TO MONTHS
      ?? "",Transform(hCur[nX],cNumformat)
   NEXT
   ?? "",Transform(hCur["AFTER"],cNumformat)
NEXT

?
? 
? Pad("Lieferant",8)+" "+Space(3)
FOR nX := 0 TO MONTHS
   ?? "",PadL(_MonthName(nX),10)
NEXT
?? "",PadL("Danach",10)+Chr(13)+Chr(10)
cList := ""

FOR EACH hCur IN hSuppliers
   IF hCur[0] != 0 .OR. hCur[1] != 0 .OR. hCur[2] != 0 .OR. hCur["AFTER"] != 0
      IF Left(hCur:__eNumKey,1) == "K"
         //cList += Pad(LTrim(SubStr(hCur:__eNumKey,2,6)),8)
         cList += Pad( LX_GetAccountName(Val(SubStr(hCur:__eNumKey,2,6))), 8 )
      ELSE
         ku->(dbSeek(  Left(hCur:__eNumKey(),6) ))
         cList +=  ku->Kunde
      ENDIF
      cList += " "+Currate(Right(hCur:__eNumKey(),1),"X")
      FOR nX := 0 TO MONTHS 
         cList += " "+Transform(hCur[nX],cNumformat)
      NEXT
      cList += " "+Transform(hCur["AFTER"],cNumformat)+Chr(13)+Chr(10)
   ENDIF
NEXT
MemoEdit(cList,Row()+1,00,MaxRow(),MaxCol(),.F.)

RETURN NIL


STATIC Function _GetMonth(dDate)
   LOCAL nMonths
   IF Year(dDate) > Year(Date())
      IF Year(dDate) == Year(Date())+1
         nMonths := Month(dDate)+12-Month(Date())
      ELSE
         nMonths := 99
      ENDIF
   ELSEIF Year(dDate) < Year(Date())
      nMonths := 0
   ELSE
      nMonths := Month(dDate)-Month(Date())
   ENDIF
RETURN IF(nMonths>MONTHS,"AFTER",Max(nMonths,0))

STATIC FUNCTION _MonthName(nMonth)
   LOCAL nMon := Month(Date())+nMonth
   LOCAL aMonths := {"Januar","Februar",t("März"),"April","Mai","Juni","Juli","August","September","Oktober","November","Dezember"}
   IF nMon > 12
      nMon := nMon-12
   ENDIF
RETURN aMonths[nMon]

