#include 'inkey.ch'
#define MONTHS 5
FUNC RUN_REPORT_FREMDWAEHRUNG(lReturn)
LOCAL hOpSummen,nSumme
//LOCAL nBesOpen,nWeOhne
LOCAL nValue,nPayDate
LOCAL hCurs := {=>},hCur
LOCAL hSuppliers := {=>}
LOCAL cSupKey
LOCAL nWait,xMonth,dDelDate
LOCAL cNumFormat := "@E 9,999,999.99"
LOCAL cCurrency
LOCAL cList
LOCAL bNewHashKey
LOCAL aOPs,nX,nPreis
LOCAL lBes := .T.

LOCAL hCurrencies := {"E","P","U"}
LOCAL getlist := {},nTop,lDummy
//LOCAL hCurrencies := {"P"}

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
   //IF cCurrency $ hCurrencies
      Eval(bNewHashKey,fibu->(Found()),nSumme:__eNumKey())
   
//      ? Pad(nSumme:__eNumKey(),6),ku->Kunde,Str(nSumme,9,2),Str(nWeOhne,9,2),Str(nBesOpen,9,2),Currate(fibu->Currency,"X")
      aOps := LX_GetOffenePosten(nSumme:__eNumKey(),.F.)
      FOR nX := 1 TO Len(aOps)
         xMonth := _GetMonth(aOps[nX]:Faellig-IF(Month(aOps[nX]:Datum)==1 .AND.  Month(aOps[nX]:Faellig) == 3,2,0)) //Month(aOps[nX]:Faellig)-Month(Date())
         hCurs[cCurrency][xMonth] += aOps[nX]:Rest
         hSuppliers[cSupKey][xMonth] += aOps[nX]:Rest
      NEXT
   //ENDIF
   //ENDIF
NEXT

fibu->(dbSetOrder( 2 ))
fibu->(dbGoTop())
DO WHILE ! fibu->(EOF())   
   IF .T. /*fibu->Currency != "E" .AND. ! Empty(fibu->Currency)*/
      cCurrency := IF(Empty(fibu->Currency),"E",fibu->Currency)
      //IF cCurrency $ hCurrencies
         Eval(bNewHashKey,.T.)



         //nWeOhne := 0
         //nBesOpen := 0

         ku->(dbSeek( Str(fibu->Adresse,6) ))
         //? ku->Kunde
         bes->(dbSetFilter({|| bes->Besda >= Date()-365*2 },"Besda >= Date()-365*2"))
         bes->(dbSeek( ku->Kunde ))

         DO WHILE bes->Liefma == ku->Kunde .AND. bes->BeStat < 3 .AND. ! bes->(EOF())
            nPreis := bes->EkPr/bes->Pe*(1-bes->Rabatt/100)

            IF ! skb->(IsPrePay(ku->Skonto))
               nWait := skb->(GetSkontoWait(ku->Skonto,Date(),Date()))
               IF nWait >= 30 .AND.  Month(Date()) == 1
                  nWait -= 2
               ENDIF
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
               IF nWait >= 30 .AND.  Month(dDeldate) == 1
                  nWait -= 2
               ENDIF

            ELSE
               nWait := 0
            ENDIF
            nPayDate := dDelDate+nWait

            //Zukünftige Lieferungen
            IF lBes
               nValue := (bes->BeQty-bes->GelQty)*nPreis
               //nBesOpen += nValue
               xMonth := IF(skb->(IsPrePay(ku->Skonto)),0,_GetMonth(nPayDate))
               //? bes->Besnr,dDeldate,nWait,nPayDate,xMonth
               hCurs[cCurrency][xMonth] += nValue
               hSuppliers[cSupKey][xMonth] += nValue
            ENDIF
            bes->(dbSkip())
         ENDDO
         bes->(dbClearFilter())
      //ENDIF
   ENDIF
   fibu->(dbSkip())
ENDDO
//Sinkey(0)

IF lReturn 
   RETURN {hCurs,hSuppliers}
ENDIF

?
? Space(3)
FOR nX := 0 TO MONTHS
   ?? "",PadL(_MonthName(nX),12)
NEXT
?? "",PadL("Danach",12)
FOR EACH hCur IN hCurs
   ? Currate(hCur:__eNumKey(),"X")
   FOR nX := 0 TO MONTHS
      ?? "",Transform(hCur[nX],cNumformat)
   NEXT
   ?? "",Transform(hCur["AFTER"],cNumformat)
NEXT

nTop := Row()+2

lDummy := .T.
FOR EACH hCur IN hCurs
   @ nTop,(hCur:__eNumIndex()-1)*8 GET lDummy CHECKBOX CAPTION Currate(hCur:__eNumKey(),"X")
   Atail(getlist):Cargo := hCur:__eNumKey()
NEXT

DO WHILE LastKey() != 27      
   hCurrencies := {}
   FOR nX := 1 TO Len(getlist)
      IF getlist[nX]:Control:Buffer
         Aadd(hCurrencies,getlist[nX]:Cargo)
      ENDIF
   NEXT
   SetPos(nTop+1,00)
   ?? Pad("Lieferant",8)+" "+Space(3)
   FOR nX := 0 TO MONTHS
      ?? "",PadL(_MonthName(nX),10)
   NEXT
   ?? "",PadL("Danach",10)+Chr(13)+Chr(10)
   cList := ""



   FOR EACH hCur IN hSuppliers
      IF Right(hCur:__eNumKey(),1) $ hCurrencies .AND. (hCur[0] != 0 .OR. hCur[1] != 0 .OR. hCur[2] != 0 .OR. hCur["AFTER"] != 0)
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
   MemoEdit(cList,nTop+2,00,MaxRow(),MaxCol(),.F.,"_FW_UF")
   IF LastKey() == K_LBUTTONDOWN      
      FOR nX := 1 TO Len(getlist)
         IF getlist[nX]:control:hittest(Mrow(),mCol()) != 0
            getlist[nX]:control:select()            
            EXIT
         ENDIF
      NEXT
   ENDIF
ENDDO

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

FUNCTION _FW_UF //(nMode,nRow,nCol)
   IF LastKey() == K_LBUTTONDOWN          
      RETURN K_ESC //exit
   ENDIF
RETURN 0

