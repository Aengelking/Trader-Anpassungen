PROC RUN_CHECK_COMPNO
   LOCAL aKunde := {}
   LOCAL cRegArt,cCompNo,oAddress,nX
   NetUse("engkund","ku")
   ku->(dbSetFilter( {|| ku->CountryIso == "DE" },"countryiso =='DE'" ))
   ku->(dbSetOrder( 2 ))
   ku->(dbSeek( "K" ))
   DO WHILE ku->Group == "K"
      IF ! Empty(ku->Compno)
         Aadd(aKunde,ku->Nummer)
      ENDIF
      ku->(dbSkip())
   ENDDO

   FOR nX := 1 TO Len(aKunde)
      oAddress := Adresse():New()
      oAddress:Load(aKunde[nX])

      IF Trim(oAddress:CompForm) $ {"GMBH","AG","UG","KGaA","SE"}
         cRegart := "HRB"
      ELSEIF Trim(oAddress:CompForm) $ {"KG","EK","OHG"}
         cRegArt := "HRA"
      ELSEIF Trim(oAddress:CompForm) == "EV"
         cRegArt := "VR"
      ELSEIF Trim(oAddress:CompForm) == "EG"
         cRegArt := "GnR"
      ELSE
         cRegArt := ""
      ENDIF
   
      cCompNo := Alltrim(SubStr(oAddress:CompNo,Len(cRegArt)+1))
      IF Trim(oAddress:CompNo) != cRegart+" "+cCompNo  //reformat the company no.
         oAddress:CompNo := cRegart+" "+cCompNo
      ENDIF

      ku->(dbSetOrder( 9 ))
      Select("ku")
      ku->(dbSetFilter( {|| ku->group == oAddress:Group },'group == "'+oAddress:Group+'"'))
      
      IF ! Empty(oAddress:CompNo) .AND. ku->(dbSeek( oAddress:CountryIso+Str(oAddress:Gericht,4,0)+Upper(oAddress:CompNo) )) .AND. ku->Nummer != oAddress:Nummer
         ? oAddress:Kunde,"doppel mit",ku->Kunde         
      ENDIF
      ku->(dbClearFilter())
   NEXT
   Sinkey(0)
