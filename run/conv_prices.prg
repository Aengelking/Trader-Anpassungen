nNr := 0

NetUse("stafprei","stpr",.F.,0)


Do While nNr < 100
   @ 01,00 SAY "Tabelle "+LTrim(Str(nNr))+" wird importiert..."

   pr    := "PRICES" + ALLTRIM( STR( nNr,2 ) ) + ".MEM"
   @ 02,00 SAY "aus Datei "+pr
   if FILE(pr)
      RESTORE FROM &pr ADDITIVE

	 stpr->(Add_Rec( 0 ))
	 stpr->Staffel := nNr
	 stpr->Basis := pibas

	 i := 1
         Do While i <= 6
            tab := "pitab"  + ALLTRIM( STR( i,1 ) )
            pro := "piproz" + ALLTRIM( STR( i,1 ) )

            cNewTab := "TAB"+LTrim(Str(i))
	    cNewPro := "PROZ"+Ltrim(Str(i))

            if ! EMPTY( &tab )
	       stpr->&cNewTab := &tab
	       stpr->&cNewPro := &pro
            endif

	    i++
         enddo

         stpr->(dbUnLock())

	Endif
      nNr++
enddo
stpr->(dbCloseArea())
