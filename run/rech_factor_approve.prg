PROC RUN_RECH_FACTOR_APPROVE
   LOCAL nNr := 0   
   LOCAL getList := {}
   LOCAL oRech,oExtra

   NetUse("rechnung","reh")

   Head("Rechnungsfreigabe durch Factoringgesellschaft")

   DO WHILE .T.
      @ 01,00 SAY "Nummer" GET nNr PICTURE "999999" 
      READ
      IF LastKey() == 27
         RETURN
      ENDIF
      @ 01,14 CLEAR TO 01,MaxCol()
      IF ! reh->(dbSeek( Str(nNr,6) ))
         @ 01,14 SAY "NICHT GEFUNDEN"
      ELSE      
         oRech := Rechnung():New()
         oRech:Load(nNr)      
         @ 01,14 SAY oRech:oKunde:cName
         EXIT
      ENDIF
   ENDDO   

   oExtra := reh->(ExtraData():New(nNr))

   IF Empty(oExtra:Factorer)
      Tr_MsgBox("Rechnung befindet sich nicht im Factoring")
      RETURN
   ENDIF

   IF ! Empty(oExtra:FactorAprD)
      Tr_MsgBox("Rechnung wurde bereits am "+DtoC(oExtra:FactorAprD)+" freigegeben")
      RETURN
   ENDIF

   IF Tr_MsgBox("Freigeben?",,{"Nein","Ja"}) == 2      

      IF Empty(oExtra:FactorAprD)
         oExtra:FactorAprD := Date()
         oExtra:Save()
      ENDIF

      IF oRech:State == "FINA" //reset state, this causes the invoice to be sent
         
         oRech := Rechnung():New()
         oRech:Load(nNr)
         //Alert(Str(oRech:Rechnr))
         oRech:State := ""
         oRech:Save()
      ENDIF
   ENDIF