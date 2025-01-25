PROC RUN_FIND_BATCH
   LOCAL cFilter,cFilter2
   LOCAL cBatch := Space(30)
   LOCAL getlist := {},bRechnungen
   NetUse("englsre","re")
   NetUse("lagrech","lagr")
   NetUse("lagent","lage")
   NetUse("lagerne","lne")
   NetUSe("artikel","art")

   Head("Chargennummer suchen")

   DO WHILE .T.

      @ 01,00 SAY "Charge" GET cBatch VALID ! Empty(cBatch)
      READ

      IF LastKey() == 27
         RETURN
      ENDIF

      
      //Eval({||NetUse("rma","rma"),rma->(dbSeek(PadL(mipar,6))),IF(!Empty(rma->BBNr),"Ihre Nummer: "+rma->BBNr,"")})

      @ 02,00 CLEAR
      @ 02,00 SAY "Rechnr Pos Ent.Nr. Pos Menge"
      
      bRechnungen := {|cBatch|
         cFilter := 'Trim(batch) == "'+Trim(cBatch)+'"'
         lagr->(dbSetFilter({|| lagr->(&(cFilter)) },cFilter))
         lagr->(dbGoTop())
         DO WHILE ! lagr->(EOF())
            ? lagr->Rechnr,lagr->RePosnr,Space(6),Space(3),Transform(lagr->LagerMenge,"9999")
            lagr->(dbSkip())
         ENDDO
         lagr->(dbClearFilter())
      }
      Eval(bRechnungen,cBatch)
    
      
      cFilter2 := 'Trim(batch) == "'+Trim(cBatch)+'"'
      lage->(dbSetFilter({|| lage->(&(cFilter2)) },cFilter2))
      lage->(dbGoTop())
      lne->(dbSetOrder( 3 ))
      DO WHILE ! lage->(EOF())
         lne->(dbSeek( Str(lage->Pos,3)+Str(lage->Nummer,6) ))
         ? Space(6),Space(3),lage->Nummer,lage->Pos,lne->Reftyp,lne->Refbeleg
         IF lne->Reftyp == "WA"
            Eval(bRechnungen,LTrim(Str(lne->Refbeleg)))
         ENDIF
         lage->(dbSkip())
      ENDDO
      lage->(dbClearFilter())

   ENDDO
