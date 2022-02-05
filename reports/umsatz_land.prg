PROC  RUN_BERICHT_VORKASSE
LOCAL nYear := Year(Date())-1
LOCAL nTotal := 0
LOCAL nFactoring := 0
LOCAL nPrePay := 0
LOCAL getList := {}
LOCAL nTotD := 0,nTotUSCA := 0,nTotRest := 0,nTotEU := 0

Head("Umsätze nach Regionen")

@ 01,00 SAY "Jahr" GET nYear PICTURE "9999"
READ

IF LastKey() == 27
   RETURN
ENDIF

NetUse("englsre","re")
NetUse("skontoa","sk")
NetUSe("countri2","ct2")

re->(dbSetOrder(9))
dbSelectArea("re")
SET FILTER TO re->Reposnr == 0
re->(dbSeek( Str(nYear,4)+"0101",.T. ))

DO WHILE Year(re->Rechdat) == nYear
   @ 02,00 SAY re->Rechnr
   ku->(dbSeek( re->Kunde+"K" ))
   IF ku->CountryIso == "DE"
      nTotD += re->PosWt-re->Preis
   ELSEIF ku->CountryIso $ {"US","CA"}
      nTotUSCA += re->PosWt-re->Preis
   ELSEIF ct2->(dbSeek( ku->CountryIso )) .AND. ct2->EG
      nTotEU += re->PosWt-re->Preis
   ELSE
      nTotRest += re->Poswt-re->Preis
   ENDIF

   nTotal += re->PosWt
   IF sk->(IsPrePay(re->Skonto))
      nPrePay += re->Poswt
   ELSEIF re->State == "FINA"
      nFactoring += re->PosWt
   ENDIF
   re->(dbSkip())
ENDDO
@ 02,00 CLEAR
@ 03,00 SAY "Deutschland : "+Transform(nTotD,"@E 9,999,999.99")
@ 04,00 SAY "EU          : "+Transform(nTotEU,"@E 9,999,999.99")
@ 05,00 SAY "USA/Kanada  : "+Transform(nTotUSCA,"@E 9,999,999.99")
@ 06,00 SAY "Rest        : "+Transform(nTotRest,"@E 9,999,999.99")
SInkey(0,128)

RETURN
