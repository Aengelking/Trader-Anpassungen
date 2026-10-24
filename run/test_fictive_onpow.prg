PROC TEST_FICTIVE_ONPOW
   LOCAL cMatch := "CMI10/AS/R/R/11/12/M/S/20"
   LOCAL cOnPow,nBuyPrice
   LOCAL nTab := 75,cSupplier := Pad("ONPOW",8)
   LOCAL aPriceTab := {},nX,nBasis,nPrice
   LOCAL cTab,cProz

   cOnpow := OnpowPartno(cMatch,3)
   Alert("Part no for "+cMatch+" is "+cOnPow)

   nBasis := OnpowPrices(cOnPow)

   Alert("Buy price for "+cOnPow+" is "+Str(nBasis))
   
   ku->(dbSetOrder( 1 ))
   ku->(dbSeek( cSupplier+"L" ))

   nBasis *= Currate(ku->Money,"E") //convert to Euro if needed

   NetUse("stafprei","stpr")
   IF stpr->(dbSeek( Str(nTab,2) ))
      nBasis += nBasis*stpr->BasicProz //add basic price percentage

      For nX := 1 To 10
			cTab := "TAB"+LTrim(Str(nX))
			cProz := "PROZ"+LTrim(Str(nX))
			If stpr->&cTab != 0
				nPrice := nBasis*stpr->&cProz/100

				Aadd(aPriceTab,{stpr->&cTab,nPrice})
			Endif
		Next
   ENDIF

   Alert("Price table for "+cOnPow+":"+ValToPrg(aPriceTab))

#include 'onpow_part_no.prg'
#include 'onpow_prices.prg'