PROCEDURE RUN_CANCEL_SHIPMENT
   LOCAL nRechnr := 0
   LOCAL nEntnr := 0
   LOCAL getlist := {}
   LOCAL oRechnung,oEntnahme,oShipment

   Head("Sendung stornieren")

   NetUse("ups","ups")
   NetUse( "PAKNUM" ,"PNUM" )
   NetUse("post","post")
   NetUse( "LAGERNE","LNE" )

   oRechnung := Rechnung():New()

   DO WHILE .T.
      @ 01,00 SAY "Rechnung" GET nRechnr PICTURE "999999" VALID {||
         IF nRechnr == 0
            RETURN .T.
         ENDIF
         IF ! oRechnung:Load(nRechnr)
            RETURN .F.
         ENDIF
         ups->(dbSetOrder(3))
         ups->(dbSeek(  Str(nRechnr,10) ))
         IF ! oRechnung:Versandt .OR. ! ups->(Found())
            Alert("Sendunng noch nicht versandt")
            RETURN .F.
         ENDIF
         IF oRechnung:Transfer
            Alert("Bereits in der Buchhaltung verbucht. Stornorechnung muss erstellt werden.")
            RETURN .F.
         ENDIF
         IF post->(dbSeek( "RE"+Str(re->Rechnr,6) ))
            Alert("Rechnung bereits an Kunden versandt.")
            RETURN .F.
         ENDIF
         FINDAD(oRechnung:Kunde,"K",1,30)
         oShipment := ups->(Record():New())
         RETURN .T.
      }
      @ 02,00 SAY "Entnahme" GET nEntnr PICTURE "999999" WHEN nRechnr == 0 VALID {||
         IF nEntnr == 0
            RETURN .F.
         ENDIF
         ups->(dbSetOrder( 4 ))
         IF ! ups->(dbSeek( nEntnr ))
            Alert("Sendunng noch nicht versandt")
            RETURN .F.
         ENDIF
         IF ! lne->(Check(nEntnr,"''",01,30,1,0))
            RETURN .F.
         ENDIF
         oEntnahme := lne->(Record():New())
         oShipment := ups->(Record():New())
         RETURN .T.
      }
      READ

      IF LastKey() == 27
         EXIT
      ENDIF

      IF Tr_MsgBox("Wurde die Sendung beim Frachtfhrer storniert?",,{"Nein","Ja"}) == 2         
         IF oShipment != NIL .AND. oShipment:Nr != 0
            DO WHILE pnum->(dbSeek( oShipment:Nr ))
               ? pnum->Nummer
               pnum->(Rec_Lock())
               pnum->(dbDelete())
               pnum->(dbUnLock())
            ENDDO
            oShipment:Delete()
         ENDIF
         IF nRechnr != 0
            oRechnung:Versandt := .F.      
            If sk->(IsPrePay(re->Skonto)) .AND. re->AoQty >= re->Poswt
               oRechnung:Bezahlt := .T.
            Endif
            oRechnung:Save()
         ELSE                        
            oEntnahme:GotoRec()
            DO WHILE lne->Nummer == oEntnahme:Nummer
               lne->(Rec_Lock())
               lne->Packed := .F.
               lne->(dbUnLock())
               lne->(dbSkip())
            ENDDO
         ENDIF
      ENDIF

      
   ENDDO
RETURN