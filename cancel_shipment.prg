PROCEDURE RUN_CANCEL_SHIPMENT
   LOCAL nRechnr := 0
   LOCAL getlist := {}
   LOCAL oRechnung

   Head("Sendung stornieren")

   NetUse("ups","ups")
   NetUse( "PAKNUM" ,"PNUM" )
   NetUse("post","post")

   oRechnung := Rechnung():New()

   DO WHILE .T.
      @ 01,00 SAY "Rechnung" GET nRechnr PICTURE "999999" VALID oRechnung:Load(nRechnr)
      READ

      IF LastKey() == 27
         EXIT
      ENDIF

      FINDAD(oRechnung:Kunde,"K",1,30)

      IF ! oRechnung:Versandt
         Alert("Sendunng noch nicht versandt")
         LOOP
      ENDIF

      IF oRechnung:Transfer
         Alert("Bereits in der Buchhaltung verbucht. Stornorechnung muss erstellt werden.")
         LOOP
      ENDIF

      IF post->(dbSeek( "RE"+Str(re->Rechnr,6) ))
         Alert("Rechnung bereits an Kunden versandt.")
         LOOP
      ENDIF

      IF Tr_MsgBox("Wurde die Sendung beim Frachtfhrer storniert?",,{"Nein","Ja"}) == 2
         ups->(dbSetOrder(3))
         IF ups->(dbSeek(  Str(nRechnr,10) )) .AND. ups->Nr != 0
            DO WHILE pnum->(dbSeek(ups->Nr))
               pnum->(Rec_Lock())
               pnum->(dbDelete())
               pnum->(dbUnLock())
            ENDDO
            ups->(Rec_Lock())
            ups->(dbDelete())
            ups->(dbUnLock())
            //Alert("Versandeintr„ge werden gel”scht "+Str(ups->Nr))
         ENDIF
         oRechnung:Versandt := .F.      
         If sk->(IsPrePay(re->Skonto)) .AND. re->AoQty >= re->Poswt
            oRechnung:Bezahlt := .T.
         Endif
         oRechnung:Save()

      ENDIF

      
   ENDDO
RETURN