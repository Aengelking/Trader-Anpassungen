PARAMETERS aWeights,lRech,nNr,nRechNr

IF AScan(aWeights,{|x| x > 31.5 }) != 0 //Spedition
   IF Tr_MsgBox({"Ein Packstück ist über 31.5kg.","Sendung wirklich per Spedition versenden?"},,{"Nein","Ja"}) == 2
      RETURN 40 //Emons
   ELSE
      RETURN .F.
   ENDIF
/*ELSEIF AScan(aWeights,{|x| x > 31.5}) != 0 //UPS
   RETURN 2*/
ENDIF

//Ab 11.10.17 alles mit UPS
//IF Date() < CtoD("18.11.2013")
	RETURN 2
//ENDIF

/*IF lRech
	re->(dbSetOrder(4))
	re->(dbSeek( Str(nRechnr,6) ))
	GotoRechAddress(.T.)
ELSE
	lne->(dbSetOrder( 1 ))
	lne->(dbSeek( nNr ))
	ku->(dbSetOrder( 1 ))
	ku->(dbSeek( lne->Kunde+lne->Gruppe ))
ENDIF

ups->(dbSetOrder( 5 ))

IF Date() <= StoD("20170419")
   IF ku->CountryISO != "DE"  //Ausland
      RETURN 2 //ausland immer mit UPS
   ENDIF

   IF Month(Date()) == 12 //Dezember immer mit DHL, da zu wenige Pakete
      RETURN 51
   ELSEIF Len(aWeights) == 1 .AND. aWeights[1] <= 1 .AND. ups->(Leto_sum( "pieces","versandart=51",BoM(Date()),EoM(Date()) )) < 55 .AND. ups->(Leto_sum( "pieces","versandart=51",Date(),Date() )) < 5//ein Paket mit max. 1 kg und wir haben weniger als 55 Pakete in diesem Monat mit DHL versandt -> Dann DHL
      RETURN 51
   ENDIF

ELSE
   IF ku->CountryISO != "DE"  //Ausland
      NetUse("countri2","ct2",.F.,0)
      ct2->(dbSetOrder( 1 ))
      ct2->(dbSeek(ku->CountryIso))
      IF (Len(aWeights) == 1 .AND. ct2->EG) .OR. ku->CountryIso == "CH" //innerhalb der EG (wenn ein Paket) oder Schweiz per DPD
         RETURN 3
      ELSE  //sonstiges Ausland
         RETURN 2
      ENDIF
   ENDIF

   //DPD
   IF Month(Date()) == 12 //Dezember immer mit DPD, da zu wenige Pakete
      RETURN 3
   ELSEIF Len(aWeights) == 1 //keine Mehrpaketsendungen, diese immer mit UPS
      nDPD_month := ups->(Leto_sum( "pieces","versandart=3",BoM(Date()),EoM(Date()) ))
      nDPD_Day   := ups->(Leto_sum( "pieces","versandart=3",Date(),Date() ))
      IF aWeights[1] >= 20 .AND. nDPD_Month < 50 .AND. nDPD_Day < 10 //mehr als 20kg und noch keine 50 Pakete im Monat bzw. 10 Pakete heute
         RETURN 3
      ELSEIF nDPD_Month < 50 .AND. nDPD_Day < 2
         RETURN 3
      ELSEIF ups->(Leto_sum( "pieces","versandart=2",BoM(Date()),EoM(Date()) )) >= 320 .AND. ups->(Leto_sum( "pieces","versandart=2",Date(),Date() )) >= 2  //we have reached 320 booxes with UPS in this month
         RETURN 3
      ENDIF
   ENDIF
ENDIF

RETURN 2  */