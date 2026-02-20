PROC  RUN_BERICHT_VORKASSE
LOCAL nYear := Year(Date())-1
LOCAL nTotal := 0
LOCAL nNet := 0
LOCAL nFactoring := 0
LOCAL nFactoringNet := 0
LOCAL nPrePay := 0
LOCAL nPrePayNet := 0
LOCAL nBarTotal := 0
LOCAL nBarTotalNet := 0
LOCAL nTotalAll := 0
LOCAL nNetAll := 0
LOCAL getList := {}
LOCAL cPath

Head("Ums„tze fr WKV Meldung berechnen")

@ 01,00 SAY "Jahr" GET nYear PICTURE "9999"
READ

IF LastKey() == 27
   RETURN
ENDIF

@ 02,00 CLEAR
nR := 3

FOR EACH cPath IN {"","automotive\"}

   dbCloseAll()

   nTotal := 0
   nNet := 0
   nFactoring := 0
   nFactoringNet := 0
   nPrePay := 0
   nPrePayNet := 0


   NetUse(cPath+"englsre","re")
   NetUse(cPath+"skontoa","sk")

   re->(dbSetOrder(9))
   dbSelectArea("re")
   SET FILTER TO re->Reposnr == 0
   re->(dbSeek( Str(nYear,4)+"0101",.T. ))

   DO WHILE Year(re->Rechdat) == nYear
      @ 02,00 SAY re->Rechnr
      nTotal += re->PosWt
      nNet   += re->PosWt-re->Preis
      IF sk->(IsPrePay(re->Skonto))
         nPrePay += re->Poswt
         nPrePayNet += re->Poswt-re->Preis
      ELSEIF re->State == "FINA"
         nFactoring += re->PosWt
         nFactoringNet += re->PosWt-re->Preis
      ENDIF
      re->(dbSkip())
   ENDDO

@ nR++,00 SAY "Firma: "+IF(cPath=="","Engelking Elektronik GmbH","Engelking Automotive GmbH")
@ nR++,00 SAY "                   "+Pad("inkl. MwSt.",12)+" "+Pad("ohne MwSt.",12)
@ nR++,00 SAY "Gesamt           : "+Transform(nTotal,"@E 9,999,999.99")+" "+Transform(nNet,"@E 9,999,999.99")
@ nR++,00 SAY "Vorkasse         : "+Transform(nPrePay,"@E 9,999,999.99")+" "+Transform(nPrePayNet,"@E 9,999,999.99")
//@ nR++,00 SAY "Factoring        : "+Transform(nFactoring,"@E 9,999,999.99")+" "+Transform(nFactoringNet,"@E 9,999,999.99")
nBarTotal += nPrePay - nFactoring
nBarTotalNet += nPrePayNet - nFactoringNet
nTotalAll += nTotal
nNetAll += nNet
nr++
NEXT

@ nR++,00 SAY "Gesamt Barumsatz : "+Transform(nBarTotal,"@E 9,999,999.99")+" "+Transform(nBarTotalNet,"@E 9,999,999.99")
@ nR++,00 SAY "Ohne Barumsatz   : "+Transform(nTotalAll-nBarTotal,"@E 9,999,999.99")+" "+Transform(nNetAll-nBarTotalNet,"@E 9,999,999.99")

SInkey(0,128)

RETURN
