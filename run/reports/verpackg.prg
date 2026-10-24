FUNCTION RUN_REPORT_VERPACKG
   LOCAL dEnd,dStart
   LOCAL nMenge,oExtra
   LOCAL aData := {},nGewicht
   LOCAL nMonat := 0 // Month(Date())-1
   LOCAL nJahr := Year(Date())-1
   LOCAL getlist := {}
   LOCAL lKS

   /*IF nMonat == 0
      nJahr--
      nMonat := 12
   ENDIF*/

   Head("Mengenberechnung VerpackG")

   //@ 01,00 SAY "Monat" GET nMonat VALID nMonat >= 0 .AND. nMonat <= 12 PICTURE "99"
   //@ 01,11 SAY "0=Jahrebericht"
   @ 02,00 SAY "Jahr " GET nJahr VALID nJahr >= 2019 .AND. nJahr <= Year(Date()) PICTURE "9999"   
   READ

   

   IF LastKey() == 27
      RETURN .F.
   ENDIF

   IF nMonat == 0
      dEnd := StoD( Str(nJahr,4)+"1231" )
      dStart := BoY(dEnd)
   ELSE
      dStart := StoD( Str(nJahr,4)+StrZero(nMonat,2)+"01" )
      dEnd   := EoM(dStart)
   ENDIF
   
   NetUse("engabg","abg")
   abg->(dbSetOrder( 3 ))
   NetUse("artikel","art")
   SET FILTER TO art->Type == "VERP "
   art->(dbGoTop())   

   Aadd(aData,{"Berichtszeitraum:",DtoC(dStart),DtoC(dEnd)})
   Aadd(aData,{"Matchcode","Artikelnummer","Menge","Einzelgewicht (g)","Gesamtgewicht (kg)","Kunststoffe","Sonstiges","Kommentar"})

   DO WHILE ! art->(EOF())                    
      abg->(dbSeek( art->Matchcode ))
      nMenge := abg->(LETO_SUM("menge",'Trim(buart)=="ENT" .AND. Datum >= Stod("'+Dtos(dStart)+'")  .AND. Datum <= Stod("'+Dtos(dEnd)+'")',art->Matchcode,art->Matchcode))
      nMenge -= abg->(LETO_SUM("menge",'Trim(buart)=="WAZ" .AND. Datum >= Stod("'+Dtos(dStart)+'")  .AND. Datum <= Stod("'+Dtos(dEnd)+'")',art->Matchcode,art->Matchcode))
      nMenge += abg->(LETO_SUM("menge",'Trim(buart)=="ABG" .AND. Datum >= Stod("'+Dtos(dStart)+'")  .AND. Datum <= Stod("'+Dtos(dEnd)+'")',art->Matchcode,art->Matchcode))
      abg->(OrdScope(0,""))
      abg->(OrdScope(1,""))

      nGewicht := nMenge*art->Gewicht/1000
      lKS := AT("BEUTEL",art->Matchcode) == 1 .OR. AT("LUFTPOLSTFOLIE",art->Matchcode) == 1 .OR. AT("LUFTKISSEN",art->Matchcode) == 1
      IF nMenge != 0
         Aadd(aData,{Trim(art->Matchcode),art->Artikelnr,Transform(nMenge,Me(art->Me)),art->Gewicht,nGewicht,IF(lKS,nGewicht,0),IF(!lKS,nGewicht,0),IF(art->Gewicht==0,"Kein Gewicht vorhanden ("+LTrim(Transform(nMenge,Me(art->Me)))+art->Me+")","")})      
      ENDIF
      art->(dbSkip())
   ENDDO

   SaveAsCSVInterface(aData)

RETURN NIL
