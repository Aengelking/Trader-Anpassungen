PROC  RUN_BERICHT_VORKASSE
LOCAL nYear := Year(Date())-1
LOCAL nTotal := 0
LOCAL nFactoring := 0
LOCAL nPrePay := 0
LOCAL getList := {}

Head("Ums„tze fr WKV Meldung berechnen")

@ 01,00 SAY "Jahr" GET nYear PICTURE "9999"
READ

IF LastKey() == 27
   RETURN
ENDIF

NetUse("englsre","re")
NetUse("skontoa","sk")

re->(dbSetOrder(9))
dbSelectArea("re")
SET FILTER TO re->Reposnr == 0
re->(dbSeek( Str(nYear,4)+"0101",.T. ))

DO WHILE Year(re->Rechdat) == nYear
   @ 02,00 SAY re->Rechnr
   nTotal += re->PosWt
   IF sk->(IsPrePay(re->Skonto))
      nPrePay += re->Poswt
   ELSEIF re->State == "FINA"
      nFactoring += re->PosWt
   ENDIF
   re->(dbSkip())
ENDDO
@ 02,00 CLEAR
@ 03,00 SAY "Gesamt           : "+Transform(nTotal,"@E 9,999,999.99")+" inkl. MwSt"
@ 04,00 SAY "Vorkasse         : "+Transform(nPrePay,"@E 9,999,999.99")+" inkl. MwSt"
@ 05,00 SAY "Factoring        : "+Transform(nFactoring,"@E 9,999,999.99")+" inkl. MwSt"
@ 06,00 SAY "Gesamt Barumsatz : "+Transform(nPrePay+nFactoring,"@E 9,999,999.99")+" inkl. MwSt"
@ 07,00 SAY "Ohne Barumsatz   : "+Transform(nTotal-nPrePay-nFactoring,"@E 9,999,999.99")+" inkl. MwSt"
SInkey(0,128)

RETURN
