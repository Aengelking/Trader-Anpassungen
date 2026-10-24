NetUse("engkund","ku")
ku->(dbSetOrder( 2 ))
Select("ku")
//SET FILTER TO Empty(compform)
SET FILTER TO Trim(compform) == "GMBH" .AND. countryiso != "DE"

ku->(dbSeek( "K" ))
DO WHILE ku->Group == "K" .AND. ! ku->(EOF()) .AND. LastKey() != 27
   cNewForm := ""
   cName := Trim(Trim(ku->Name1)+" "+ku->Name2)+" "
   IF HB_RegexMatch("[\.\s]KG\s",cName,.F.)
      cNewForm := "KG"
   ELSEIF HB_RegexMatch("\sAG\s",cName,.F.)
      cNewForm := "AG"
   ELSEIF HB_RegexMatch("\sGMBH\s",cName,.F.) .OR.  HB_RegexMatch("Ges(ellsch(aft)?|\.).*mbh\s",cName,.F.)
      cNewForm := "GMBH"
   ELSEIF HB_RegexMatch("\sLTD[\.,\s]",cName,.F.)
      cNewForm := "LTD"
   ELSEIF HB_RegexMatch("\sS\.?R\.?L\.?\s",cName,.F.)
      cNewForm := "SRL"
   ELSEIF HB_RegexMatch("\sS\.?N\.?C\.?\s",cName,.F.)
      cNewForm := "SNC"
   ELSEIF HB_RegexMatch("\sS\.?A\.?R\.?L\.?\s",cName,.F.)
      cNewForm := "SARL"
   ELSEIF HB_RegexMatch("S\.?R\.?O\.?\s",cName,.F.)
      cNewForm := "SRO"
   ELSEIF HB_RegexMatch("\sB\.?V\.?\s",cName,.F.)
      cNewForm := "BV"
   ELSEIF HB_RegexMatch("\sO\.?Y\.?\s",cName,.F.)
      cNewForm := "OY"
   ELSEIF HB_RegexMatch("\sA/S\s",cName,.F.)
      cNewForm := "APS"
   ELSEIF HB_RegexMatch("\sInc\.?\s",cName,.F.)
      cNewForm := "INC"
   ELSEIF  HB_RegexMatch("\sAB\s",cName,.F.)
      cNewForm := "AB"
   ELSEIF HB_RegexMatch("\sL\.?L\.?C\.?\s",cName,.F.)
      cNewForm := "LLC"
   ELSEIF HB_RegexMatch("\sK\.?F\.?T\.?\s",cName,.F.)
      cNewFomr := "KFT"
   ELSEIF HB_RegexMatch("\sOHG\s",cName,.F.)
      cNewForm := "OHG"
   ELSEIF HB_RegexMatch("\sE.V.\s",cName,.F.)
      cNewForm := "EV"
   ELSEIF HB_RegexMatch("\sE.K.\s",cName,.F.)
      cNewForm := "EK"
   ELSEIF HB_RegexMatch("\sE\.?G\.?\s",cName,.F.)
      cNewForm := "EG"
   ELSEIF HB_RegexMatch("\sUG\s",cName,.F.)
      cNewForm := "UG"
   ELSEIF HB_RegexMatch("\sGBR\s",cName,.F.)
      cNewForm := "GBR"
   ELSEIF HB_RegexMatch("^HERR",cName,.F.) .OR. HB_RegexMatch("^FRAU",cName,.F.)
      cNewForm := "PRIVA"
   ENDIF
   IF cNewForm != ku->CompForm
      ku->(Rec_Lock())
      ku->CompForm := cNewForm
      ku->(dbUnLock())
   ENDIF
   ? ku->Kunde,cName,">>",cNewForm
   IF Upper(Chr(Inkey())) == "P"
      Sinkey(0)
   ENDIF
   ku->(dbSkip())
ENDDO

ku->(dbClearFilter())