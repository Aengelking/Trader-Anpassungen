
#command @ <top>,<left>,<bottom>,<right> GET <var> LISTBOX <hash> ASSOCIATIVE ;
	[VALID <valid>];
	[WHEN <when>];
	[COLOR <color>];
;
=> GET_AssociativeListBox(getlist,<top>,<left>,<bottom>,<right>,{|v| If(v==NIL,<var>,<var>:=v)},<hash>,<{valid}>, <{when}>,<color>)


PROC RUN_ShowUmlaufVerp()
   LOCAL aArt := {}
   LOCAL cDbId := Pad("ART",5)
   LOCAL cField := Pad("UMLAUF",10)
   LOCAL hVerpack := {=>}
   LOCAL getlist := {}
   LOCAL nArt,cVerp := "",nCount,aMatch

   Head("Umlaufverpackungen")

   NetUse("extraval","exv")
   NetUse("artikel","art")
   NetUse("lager","lag")
   NetUse("engbes","bes")

   exv->(dbsetOrder( 1 ))
   exv->(dbSeek( cDbID+cField ))
   
   DO WHILE exv->DBId == cDbID .AND. exv->Name == cField .AND. ! exv->(EOF())
      
      IF Empty(cVerp)
         cVerp := Trim(exv->Value)
      ENDIF
      hVerpack[Trim(exv->Value)] := Trim(exv->Text)
      exv->(dbSkip())
   ENDDO

   DO WHILE .T.
      @ 01,00 SAY "Verpackung"
      @ 01,11,15,50 GET cVerp LISTBOX hVerpack ASSOCIATIVE
      READ

      IF LastKey() == 27
         RETURN
      ENDIF

      //get all parts with Umlaufverpackungen
      aArt := GetIdsWithExtraField(cDbID,Trim(cField))

      aMatch := HB_Regex("[0-9]+" ,cVerp) // check if cVerp is a number
      IF Len(aMatch) == 0
         Tr_MsgBox("Umlaufverpackung enth„lt keine Zahl!")
         LOOP
      ENDIF

      nCount := Val(aMatch[1]) // convert to number
      nTotal := 0

      art->(dbSetOrder( 2 ))
      FOR EACH nArt IN aArt      
         oExtra := art->(ExtraData():New(nArt))
         
         IF Trim(oExtra:Umlauf) == cVerp
            art->(dbSeek( Str(nArt,6) ))
            ? nArt,art->Matchcode,art->Artikel
            ? "Lager:"
            lag->(dbSeek( nArt ))
            DO WHILE lag->Artikelnr == nArt
               IF Left(lag->Lagerort,3) != "096"
                  ? lag->Lagerort,Ceiling(lag->LagerMenge/nCount)
                  nTotal += Ceiling(lag->LagerMenge/nCount)
               ENDIF
               lag->(dbSkip())
            ENDDO

            ? "Bestellungen:"

            bes->(dbSetOrder( 3 ))
            bes->(dbSeek( art->Matchcode ))
            DO WHILE bes->Matchcode == art->Matchcode                              
               IF bes->BeStat < 3 .AND. bes->BeQty-bes->GelQty > 0                  
                  ? bes->Besnr,bes->Posnr,Ceiling((bes->BeQty-bes->GelQty)/nCount)
                  nTotal += Ceiling((bes->BeQty-bes->GelQty)/nCount)
               ENDIF
               bes->(dbSkip())
            ENDDO
         ENDIF
      NEXT

      ? "Gesamt:",nTotal

      Sinkey(0)
   ENDDO


