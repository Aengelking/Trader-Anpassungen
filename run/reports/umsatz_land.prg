PROC  RUN_BERICHT_VORKASSE
LOCAL nYear := Year(Date())-1
LOCAL nTotal := 0
LOCAL nFactoring := 0
LOCAL nPrePay := 0
LOCAL getList := {}
LOCAL nTotD := 0,nTotUSCA := 0,nTotRest := 0,nTotEU := 0,nKFZ := 0
LOCAL oExtra
LOCAL hEU := {=>},hRest := {=>},nCountryTot
LOCAL nValue
LOCAL nDACH,nRow
LOCAL nEuropa


Head("Umsätze nach Regionen + KFZ")

@ 01,00 SAY "Jahr" GET nYear PICTURE "9999"
READ

IF LastKey() == 27
   RETURN
ENDIF

NetUse("englsre","re")
NetUse("engkund","ku")
NetUse("skontoa","sk")
NetUSe("countri2","ct2")

re->(dbSetOrder(9))
dbSelectArea("re")
SET FILTER TO re->Reposnr == 0
re->(dbSeek( Str(nYear,4)+"0101",.T. ))

DO WHILE Year(re->Rechdat) == nYear
   @ 02,00 SAY re->Rechnr
   ku->(dbSeek( re->Kunde+"K" ))
   oExtra := ku->(Extradata():New(ku->Nummer))
   nValue := re->PosWt-re->Preis //netto
   IF ku->CountryIso == "DE"
      nTotD += nValue
   ELSEIF ku->CountryIso $ {"US","CA"}
      nTotUSCA += nValue
   ELSEIF ct2->(dbSeek( ku->CountryIso )) .AND. ct2->EG
      nTotEU += nValue
      IF ! HHasKey(hEU,ku->CountryIso)
         hEU[ku->CountryIso] := 0
      ENDIF
      hEU[ku->CountryIso] += nValue
   ELSE
      nTotRest += nValue
      IF ! HHasKey(hRest,ku->CountryIso)
         hRest[ku->CountryIso] := 0
      ENDIF
      hRest[ku->CountryIso] += nValue
   ENDIF
   IF oExtra:KFZ
      nKFZ += nValue
   ENDIF

   nTotal += nValue
   IF sk->(IsPrePay(re->Skonto))
      nPrePay += re->Poswt
   ELSEIF re->State == "FINA"
      nFactoring += re->PosWt
   ENDIF
   re->(dbSkip())
ENDDO
@ 02,00 CLEAR

@ 03,00 SAY "Gesant       : "+Transform(nTotal,"@E 9,999,999.99")
@ 04,00 SAY "  ohne USA/CA: "+Transform(nTotD+nTotEU+nTotRest,"@E 9,999,999.99")
@ 05,00 SAY "Deutschland  : "+Transform(nTotD,"@E 9,999,999.99")+" "+Str(nTotD/nTotal*100,6,2)+"%"
nDACH := nTotD
IF HHasKey(hEU,"AT")
   nDACH += hEU["AT"]
ENDIF
IF HHasKey(hRest,"CH")
   nDACH += hRest["CH"]
ENDIF
@ 06,00 SAY "DACH         : "+Transform(nDach,"@E 9,999,999.99")+" "+Str((nDach)/nTotal*100,6,2)+"%"
@ 07,00 SAY "Ausland      : "+Transform(nTotEU+nTotUSCA+nTotRest,"@E 9,999,999.99")
@ 08,00 SAY "Ausland o.USA: "+Transform(nTotEU+nTotRest,"@E 9,999,999.99")

nEuropa := nTotEU
IF HHasKey(hRest,"CH")
   nEuropa += hRest["CH"]
ENDIF
IF HHasKey(hRest,"GB")
   nEuropa += hRest["GB"]
ENDIF
nRow := 09

@ nRow++,00 SAY "  EUROPA     : "+Transform(nEuropa,"@E 9,999,999.99")+" "+Str(nEuropa/nTotal*100,6,2)+"%"

@ nRow++,00 SAY "  EU         : "+Transform(nTotEU,"@E 9,999,999.99")+" "+Str(nTotEU/nTotal*100,6,2)+"%"

FOR EACH nCountryTot IN hEU
   @ nRow++,00 SAY "   "+nCountryTot:__eNumKey()+"        : "+Transform(nCountryTot,"@E 9,999,999.99")+" "+Str(nCountryTot/nTotal*100,6,2)+"%"
NEXT
@ nRow++,00 SAY "  USA/Kanada : "+Transform(nTotUSCA,"@E 9,999,999.99")+" "+Str(nTotUSCA/nTotal*100,6,2)+"%"
@ nRow++,00 SAY "  Rest       : "+Transform(nTotRest,"@E 9,999,999.99")+" "+Str(nTotRest/nTotal*100,6,2)+"%"
FOR EACH nCountryTot IN hRest
   @ nRow++,00 SAY "   "+nCountryTot:__eNumKey()+"        : "+Transform(nCountryTot,"@E 9,999,999.99")+" "+Str(nCountryTot/nTotal*100,6,2)+"%"
NEXT
@ nRow,00 SAY "KFZ          : "+Transform(nKFZ,"@E 9,999,999.99")



SInkey(0,128)

RETURN
