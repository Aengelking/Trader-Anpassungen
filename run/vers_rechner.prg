#command @ <top>,<left>,<bottom>,<right> GET <var> LISTBOX <hash> ASSOCIATIVE ;
	[VALID <valid>];
	[WHEN <when>];
	[COLOR <color>];
;
=> GET_AssociativeListBox(getlist,<top>,<left>,<bottom>,<right>,{|v| If(v==NIL,<var>,<var>:=v)},<hash>,<{valid}>, <{when}>,<color>)

PROC RUN_VERS_RECHNER
LOCAL aWeight := {}
LOCAL aPakData := {}
LOCAL hArten := {"CT"=>"Karton","EP"=>"Europalette","HP"=>"Halbpalette","FP"=>"Flachpalette","GP"=>"Gitterpalette"}
LOCAL hSizes := {"CT"=>{"W"=>1,"H"=>1,"L"=>1},"EP"=>{"W"=>80,"H"=>0,"L"=>120},"HP"=>{"W"=>80,"H"=>0,"L"=>60},"FP"=>{"W"=>0,"H"=>0,"L"=>0},"GP"=>{"W"=>80,"H"=>0,"L"=>120}}
LOCAL nPakNum := 1
LOCAL X
LOCAL getlist := {}
LOCAL cKunde := Space(8),cGruppe := "K"
LOCAL nDHL    := 0
LOCAL nDHLEx  := 0
LOCAL nDHLEE  := 0
LOCAL nHugg   := 0
LOCAL nSchenk := 0
LOCAL nEmons  := 0
LOCAL nTotWeight := 0
LOCAL nTotVolume := 0
LOCAL nRechnr := 0
LOCAL nQty,oArtGet,oHGet,oLGet,oWGet
LOCAL nPr,cSpedArt,hWeights


NetUse("engkund","ku")
NetUSe( "versand" ,"vers",.F.,0)
NetUse( "zone"   ,"ZO"   ,.F.,0)
NetUse( "verspr" ,"VP"   ,.F.,0)
netUse("englsre","re")

Head("Versandkostenrechner")

DO WHILE .T.
   @ 01,01 SAY "Rechnung" GET nRechnr PICTURE "999999"
   READ
   IF LastKey() == 27
      RETURN
   ENDIF
   re->(dbSetOrder( 4 ))
   IF ! Empty(nRechnr) .AND. re->(dbSeek( Str(nRechnr,6) ))
      GotoRechnungsTaxCustomer(re->Kunde,re->AbNr,re->DelAd)
      cKunde := ku->Kunde
      cGruppe := ku->Group
   ENDIF
   @ 01,00 CLEAR
   @ 01,01 SAY "Adresse" GET cKunde PICTURE "@!"
   @ 01,18 SAY "Gruppe" GET cGruppe PICTURE "!"
   @ 02,01 SAY t("Unterschiedliche Packstücke") GET nPakNum PICTURE "9" VALID nPakNum > 0
   READ
   IF LastKey() == 27
      RETURN
   ENDIF
   IF ku->(dbSeek( cKunde+cGruppe ))
      @ 01,29 SAY ku->Name1+" "+GetCountryName(ku->CountryIso)
      EXIT
   ENDIF
ENDDO

@ 02,37 SAY "DHL"
@ 02,44 SAY "DHL Ex"
@ 02,51 SAY "DHL EE"
@ 02,58 SAY "Hugger"
@ 02,65 SAY "Schenk"
@ 02,72 SAY "EMONS"

FOR X := 1 TO nPakNum
   AADD(aWeight,0.00)
   aPakData := {"L"=>0,"W"=>0,"H"=>0,"TYPE"=>"CT"}
   nQty := 1

   @ 03+(X-1)*4,01 SAY "Anzahl" GET nQty PICTURE "99"
   @ 03+(X-1)*4,15 CLEAR TO 18,28
   @ 04+(X-1)*4,01 SAY t("Packstückart")
   @ 04+(X-1)*4,17,09+(X-1)*4,34 GET aPakData["TYPE"] LISTBOX hArten ASSOCIATIVE
   oArtGet := ATail(getlist)
   oArtGet:cargo := {|cArt|
//            LOCAL cArt := oArtGet:control:buffer
     aPakData["L"] := hSizes[cArt]["L"]
     aPakData["W"]  := hSizes[cArt]["W"]
     aPakData["H"] := hSizes[cArt]["H"]
     IF oHGet != NIL
         oHGet:Display()
         oLGet:Display()
         oWGet:Display()
     ENDIF
     ReadUpdated(.T.)
     RETURN .T.
   }
   @ 05+(X-1)*4,01 SAY t("Größe LxBxH")
   @ 05+(X-1)*4,17 GET aPakData["L"] PICTURE "999" /*WHEN Empty(hSizes[aPakData["TYPE"]]["L"])*/ VALID aPakData["L"] > 0
   oLGet := ATail(getlist)
   @ 05+(X-1)*4,20 SAY "x"
   @ 05+(X-1)*4,21 GET aPakData["W"] PICTURE "999"  /*WHEN Empty(hSizes[aPakData["TYPE"]]["W"])*/ VALID aPakData["W"] > 0
   oWGet := ATail(getlist)
   @ 05+(X-1)*4,24 SAY "x"
   @ 05+(X-1)*4,25 GET aPakData["H"] PICTURE "999" /*WHEN Empty(hSizes[aPakData["TYPE"]]["H"])*/ VALID aPakData["H"] > 0
   oHGet := ATail(getlist)
   Eval(oArtGet:cargo,aPakData["TYPE"])
   @ 05+(X-1)*4,28 SAY "cm"
   @ 06+(X-1)*4,01 SAY t("Gewicht")
   @ 06+(X-1)*4,17 GET aWeight[X] picture "999.99"
   @ 06+(X-1)*4,17+6+1 SAY "kg"
   READ
   IF LASTKEY() == 27
      RETURN
   ENDIF
   
   nPr := PakPreis(51,aWeight[X],aPakData)*nQty
   nDHL += nPR
   @ 03+(X-1)*4,37 SAY nPr  PICTURE "999.99"

   nPr := PakPreis(60,aWeight[X],aPakData)*nQty
   nDHLEE += nPr
   @ 03+(X-1)*4,51 SAY nPr  PICTURE "999.99" //DHL Express Economy

   IF aPakData["TYPE"] == "CT"
      nTotWeight += aWeight[X]*nQty
   ELSE
      nPr := PakPreis(57,aWeight[X],aPakData)*nQty
      nHugg += nPr
      @ 03+(X-1)*4,58 SAY nPr PICTURE "999.99"

      nPr := PakPreis(58,aWeight[X],aPakData)*nQty
      nSchenk += nPr
      @ 03+(X-1)*4,65 SAY nPr  PICTURE "999.99"
      
      nPr := PakPreis(40,aWeight[X],aPakData)*nQty
      nEmons += nPr
      @ 03+(X-1)*4,72 SAY nPr  PICTURE "999.99"
   ENDIF
   
   nTotVolume += aPakData["L"]*aPakData["W"]*aPakData["H"]*nQty
NEXT

IF nTotWeight != 0

   nDHLEx := PakPreis(59,nTotWeight,{"L"=>nTotVolume,"W"=>1,"H"=>1,"TYPE"=>"CT"})

   @ 04+(X-1)*4+1,01 SAY t("Packstück Sped.")
   cSpedArt := "EP"
   @ 04+(X-1)*4+1,17,09+(X-1)*4,34 GET cSpedArt LISTBOX hArten ASSOCIATIVE
   READ
   IF LastKey() == 27
      RETURN
   ENDIF
   hWeights := {"EP"=>15,"FP"=>10,"HP"=>6,"GP"=>85}
   IF HHasKey(hWeights,cSpedArt)
      nTotWeight += hWeights[cSpedArt]
   ENDIF
   nHugg   += PakPreis(57,nTotWeight,{"L"=>0,"W"=>0,"H"=>0,"TYPE"=>cSpedArt})
   nSchenk += PakPreis(58,nTotWeight,{"L"=>0,"W"=>0,"H"=>0,"TYPE"=>cSpedArt})
   nEmons += PakPreis(40,nTotWeight,{"L"=>0,"W"=>0,"H"=>0,"TYPE"=>cSpedArt})


ENDIF

@ 03+(X-1)*4+1,37 SAY Replicate("-",34)
@ 03+(X-1)*4+2,37 SAY nDHL PICTURE "999.99"
@ 03+(X-1)*4+2,44 SAY nDHLEx PICTURE "999.99"
@ 03+(X-1)*4+2,51 SAY nDHLEE PICTURE "999.99"
@ 03+(X-1)*4+2,58 SAY nHugg PICTURE "999.99"
@ 03+(X-1)*4+2,65 SAY nSchenk PICTURE "999.99"
@ 03+(X-1)*4+2,72 SAY nEmons PICTURE "999.99"

@ 03+(X-1)*4+3,58 SAY "+Maut"
@ 03+(X-1)*4+3,65 SAY "+Maut"
@ 03+(X-1)*4+3,72 SAY "+Maut"


//nKM := MBaseRun(Trim(Tr_Getini(1))+"\run\getdistance",{"Tuningen, 78609",Trim(ku->Town)+","+Trim(ku->PLZ)})



SInkey(0)


