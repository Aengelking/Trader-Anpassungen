FUNCTION RUN_REPORT_ELEKTROG
   LOCAL dEnd := StoD("20181231") //Bom(Date())-1
   LOCAL dStart := BoY(dEnd) //Bom(dEnd)
   LOCAL hArtikel := {=>}
   LOCAL nMenge,oExtra
   LOCAL aData := {},nGewicht
   LOCAL nMonat := Month(Date())-1
   LOCAL nJahr := Year(Date())
   LOCAL getlist := {}
   LOCAL lIT

   IF nMonat == 0
      nJahr--
      nMonat := 12
   ENDIF

   Head("Mengenberechnung ElektroG")

   @ 01,00 SAY "Monat" GET nMonat VALID nMonat >= 0 .AND. nMonat <= 12 PICTURE "99"
   @ 01,11 SAY "0=Jahrebericht"
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
   
   NetUse("englsre","re")
   re->(dbSetOrder( 9 ))
   NetUse("artikel","art")
   art->(dbSetOrder( 2 ))

   re->(dbSetFilter( {|| re->Reposnr != 0 .AND. re->AoQty != 0 } ))
   re->(dbSeek( DtoS(dStart),.T.))

   DO WHILE ! re->(EOF()) .AND. re->Rechdat >= dStart .AND. re->RechDat <= dEnd 
      //? re->Rechnr
      IF ! HHasKey(hArtikel,re->Artikelnr)
         hArtikel[re->Artikelnr] := 0
      ENDIF
      hArtikel[re->Artikelnr] += re->AoQty

      re->(dbSkip())
   ENDDO

   Aadd(aData,{"Berichtszeitraum:",DtoC(dStart),DtoC(dEnd)})
   Aadd(aData,{"Matchcode","Artikelnummer","Gesamtgewicht (kg)","Kleinger„te (5.1)","Kleinger„te IT (6)","Kommentar"})

   FOR EACH nMenge IN hArtikel
      art->(dbSeek( Str(nMenge:__eNumKey(),6) ))
      oExtra := art->(ExtraData():New(art->Artikelnr))
      IF oExtra:ElektroG
         nGewicht := nMenge*art->Gewicht/1000
         lIT := art->Gruppe!="KONK"
         IF AT("KS20989/3",art->Matchcode) == 1
            lIT := .F.
         ENDIF
         Aadd(aData,{Trim(art->Matchcode),art->Artikelnr,nGewicht,IF(!lIT,nGewicht,0),IF(lIt,nGewicht,0),IF(art->Gewicht==0,"Kein Gewicht vorhanden ("+LTrim(Transform(nMenge,Me(art->Me)))+art->Me+")","")})
      ENDIF
   NEXT

   SaveAsCSVInterface(aData)

RETURN NIL
