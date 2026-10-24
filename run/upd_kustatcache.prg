LOCAL cNextKu
NetUse("engkund","ku")
NetUse("englsre","re")
NetUse("angebot","ang")

Head("Statistikcache Kunden aktualisieren")

ku->(dbSetOrder( 2 ))
re->(dbSetOrder( 2 ))
ang->(dbSetOrder( 2 ))
ku->(dbseek( "K" ))
DO WHILE ku->Group == "K"
   @ 24,00 SAY ku->Kunde
   cNextKu := Left(ku->Kunde,7)+Chr(Asc(Right(ku->Kunde,1))+1)
   re->(dbSeek( Str(0,3)+cNextKu, .T.  )) //goto the record after the last one of this customer
   re->(dbSkip( -1 )) //this should move us to the last header
   IF re->Kunde == ku->Kunde .AND. re->reposnr == 0 .AND. re->Rechdat >= ku->TurnUpd
      @ 24,10 SAY re->Rechdat
      GetCustomerTurnover(ku->Kunde) //this updates the cache
   ENDIF
   
   ang->(dbSeek( cNextKu, .T. ))
   ang->(dbSkip( -1 ))
   IF ang->Kundma == ku->Kunde .AND. ang->Besda >= ku->QuoteUpd
      @ 24,20 SAY ang->Besda
      GetCustomerOpenEnquiries(ku->Kunde)
   ENDIF
   ku->(dbSkip())
ENDDO