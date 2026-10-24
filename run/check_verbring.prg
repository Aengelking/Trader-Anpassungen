FUNCTION RUN_CHECK_VERBRING
   LOCAL aData := {{"Datum","Rech.nr.","EUR","Versandart","1. Paket"}}
   LOCAL aLine

   Head("Export Rechnungen")

   NetUse("englsre","re")
   re->(dbSetOrder( 9 )) //Dtos(rechdat)+kunde

   NetUse("ups","ups")
   ups->(dbSetOrder( 3 )) //Str(Rechnr)

   NetUSe( "versand" ,"vers")
   NetUse( "PAKNUM" ,"PNUM" )


   re->(dbSetFilter({|| re->reposnr == 0 .AND. re->Taxcode != 0 .AND. re->Poswt != 0 },"reposnr == 0 .AND. taxcode == 3"))
   re->(dbSeek( "20150101",.T. ))

   DO WHILE ! re->(EOF())
      aLine := {re->Rechdat,re->Rechnr,re->Poswt}
      IF ups->(dbSeek( Str(re->Rechnr,10) ))
         IF ups->Versandart == -1            
            Aadd(aLine,"mit: "+Trim(ups->Versandopt))
            ups->(dbSetOrder( 4 ))
            IF ups->(dbSeek( Val(ups->Versandopt) )) .AND. ! Empty(ups->Rechnr)
               aLine[Len(aLine)] += " Rechnung "+LTrim(Str(ups->Rechnr))
            ENDIF            
            ups->(dbSetOrder( 3 ))
         ELSE
            vers->(dbGoto( ups->Versandart ))         
            Aadd(aLine,vers->Firma)
            pnum->(dbSeek( ups->Nr ))
            Aadd(aLine,pnum->Nummer)
         ENDIF
      ELSE
         Aadd(aLine,"nicht versandt")
      ENDIF
      Aadd(aData,aLine)
      re->(dbSkip())
   ENDDO

   SaveAsCSVInterFace(aData,.T.)
   