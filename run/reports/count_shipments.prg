LOCAL nVersandart := 1
LOCAL hCountries
LOCAL oRechnung,cCountry,aCountry
LOCAL hWeights,hTotWeights
LOCAL dFrom := Date()-365
LOCAL dTo := Date()
LOCAL getlist := {},nTotal,nTotalPak

DO WHILE .T.

   Head("Sendungen/Pakstücke pro Versender")
   
   hCountries := {=>}
   hWeights   := {=>}
   hTotWeights := {=>}

   @ 01,00 SAY "Versandart" GET nVersandart PICTURE "99" VALID nVersandart == 0 .OR. VersBrowse(01,13,01,14,@nVersandart)
   @ 02,00 SAY "ab Datum  " GET dFrom
   @ 03,00 SAY "bis Datum " GET dTo   VALID dTo >= dFrom
   READ
   
   IF LastKey() == 27
      RETURN
   ENDIF
   
   IF nVersandart == 0
      @ 01,13 SAY Pad(" ALLE",50)
   ENDIF

   NetUse("ups","ups")
   NetUse("englsre","re")
   NetUse("lagerne","lne")
   NetUse("engkund","ku")
   NetUse("paknum","pnum")

   ups->(dbSetOrder( 5 )) //Datum
   ups->(dbSetFilter({|| IF(nVersandArt==0,ups->Versand != -1,ups->Versandart == nVersandart) },"versandart "+IF(nVersandArt==0,"!=-1","== "+LTrim(str(nVersandart))) ))
   ups->(dbSeek( dFrom, .T. ))

   re->(dbSetOrder( 4 ))
   lne->(dbSetOrder( 4 ))

   DO WHILE ! ups->(EOF()) .AND. ups->Datum <= dTo
      @ 04,00 SAY ups->Nr
      IF ups->Rechnr != 0
         oRechnung := Rechnung():New(.F.)
         oRechnung:Load(ups->Rechnr)
         IF oRechnung:Brutto <= 0
            ups->(dbSkip())
            LOOP
         ENDIF
         cCountry := oRechnung:oLieferAdresse:CountryIso
      ELSE
         lne->(dbSeek( Str(ups->Nr,6) ))
         IF Empty(lne->KUNDE)
            ups->(dbSkip())
            LOOP
         ENDIF
         ku->(dbSeek( lne->Kunde+lne->Gruppe ))
         cCountry := ku->CountryIso
      ENDIF
      IF ! HHasKey(hCountries,cCountry)
         hCountries[cCountry] := {0,0,0}
      ENDIF
      IF ! HHasKey(hWeights,cCountry)
         hWeights[cCountry] := Array(5)
         AFill(hWeights[cCountry],0)
      ENDIF
      IF ! HHasKey(hTotWeights,cCountry)
         hTotWeights[cCountry] := 0
      ENDIF
      hCountries[cCountry][1]++

      pnum->(dbSeek( ups->Nr ))
      DO WHILE pnum->Nr == ups->Nr
         IF pnum->Type == "CT" .OR. Empty(pnum->Type) //Pakete
            hCountries[cCountry][2]++
            hTotWeights[cCountry] += pnum->Weight
            IF pnum->Weight > 20
               nWG := 5
            ELSEIF pnum->Weight > 10
               nWG := 4
            ELSEIF pnum->Weight > 5
               nWG := 3
            ELSEIF pnum->Weight > 1
               nWG := 2
            ELSE
               nWG := 1
            ENDIF
            hWeights[cCountry][nWG]++
         ELSE //Paletten
            hCountries[cCountry][3]++
         ENDIF
         pnum->(dbSkip())
      ENDDO

      ups->(dbSkip())
   ENDDO

   @ 04,00 CLEAR
   ? Pad("Land",20),Pad("Sendungen",5),Pad("Pakete",5)
   ?? "",PadL("<= 1",5),PadL("<= 5",5),PadL("<= 10",5),PadL("<= 20",5),PadL("> 20",5),Pad("D/S kg",5),"Paletten"

   nTotal := 0
   nTotalPak := 0
   FOR EACH aCountry IN hCountries
      ? Pad(GetCountryName(aCountry:__enumKey()),20),Str(aCountry[1],5),Str(aCountry[2],5)
      FOR nX := 1 TO 5
         ?? "",Str(hWeights[aCountry:__enumKey()][nX],5)
      NEXT
      ?? "",Str(hTotWeights [aCountry:__enumKey()]/aCountry[2],5,2)
      ?? "",Str(aCountry[3],5)
      nTotal += aCountry[1]
      nTotalPak += aCountry[2]
   NEXT
   
   ? Pad("Gesamt",20),Str(nTotal,5),Str(nTotalPak,5)
   Sinkey(0)
   
   ups->(dbClearFilter())
ENDDO
