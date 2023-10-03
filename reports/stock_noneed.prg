LOCAL nMinVal := 50
LOCAL nMinQty := 1
LOCAL dZug,dAbg
LOCAL cZugTypes := ""
LOCAL dLastMin := StoD("")
LOCAL dLastMax := Date()
LOCAL lWE := .T.
LOCAL lZug := .T.
LOCAL nMonths := 12
LOCAL nTotal := 0
LOCAL nTotOver := 0
//LOCAL cAbgtypes := "RNR ENT ENé ABG"

LOCAL nManu := 1
LOCAL getlist := {}



NetUse("artikel","art",.F.,0)
NetUse("engabg","abg",.F.,0)
NetUse("lager","lag",.F.,0)
NetUse("me","me",.F.,0)
NetUSe("manufact","manu",.F.,0)

art->(dbGoTop())

abg->(dbSetOrder( 3 ))

Head(t("Best‰nde ohne Bedarf"))

@ 01,00 SAY "Hersteller (Fertigartikel)"
aManu := GetManufacturerArray()
HB_AIns(aManu[2],1,"Alle",.T.)

//AIns(aManu,
@ 01,11,15,25 GET nManu LISTBOX aManu[2] DROPDOWN

@ 02,00 SAY "Ab Wert             " GET nMinVal PICTURE "9999"
@ 03,00 SAY t("Bestand grˆﬂer      ") GET nMinQty PICTURE "999"
@ 04,00 SAY "Letzter Zugang >=   " GET dLastMin VALID dLastMin < dLastMax
@ 05,00 SAY "Letzter Zugang <=   " GET dLastMax VALID dLastMin < dLastMax
@ 06,00 SAY "Wareneingang        " GET lWE CHECKBOX
@ 07,00 SAY t("Zug‰nge             ") GET lZug CHECKBOX
@ 08,00 SAY "Bestand fÅr x Monate" GET nMonths VALID nMonths > 0
//@ 04,00 SAY t("Bewegungen         ")
//@ 04,20,10,40 GET nType LISTBOX aTypes DROPDOWN
READ

IF LastKey() == 27
   RETURN
ENDIF

IF lWE
   cZugTypes += "WE WA "
ENDIF
IF lZug
   cZugTypes += "ZUG"
ENDIF

StartPrint(,,"PDF")
oPdf := GetCurrentPrinterObject():Data
oPdf:SetFont("COURIER")
oPdf:NewPage()
oPdf:Bold()
oPdf:AtSay( "Best‰nde ohne Bedarf" )
oPdf:NewLine()
oPdf:Normal()
oPdf:AtSay( "Bestandswert > EUR "+LTrim(Str(nMinVal,12,2)))
oPdf:NewLine()
oPdf:AtSay( "Bestand > "+LTrim(Str(nMinQty)) )

hStock := {=>}
nTotal := 0
lag->(dbSetOrder( 1 ))
art->(dbSetFilter({|| art->Bestand > nMinQty .AND. (nManu == 1 .OR. art->Manufactur == aManu[1,nManu-1]) },'Bestand > '+Str(nMinQty)+IF(nManu!=1,' .AND. Manufactur == '+Str(aManu[1,nManu-1]),'') ))
art->(dbGoTop())


Do While ! art->(Eof())
   //If art->Bestand > nMinQty
      hReqInq := GetProductRequirementAndIncoming(art->Artikelnr)
      IF hReqInq["income"]-hReqInq["requirement"]+art->Bestand > hReqInq["avgrequirement"]*nMonths
         nPreis := art->avPreis/art->Pe
         IF Trim(art->matchcode) == "80-599021"
            /*oArt := Artikel():New()
            oArt:Load(art->Artikelnr)
            nPreis := oArt:GetAvgBuyPrice(Date())*/
         ENDIF
         If nPreis*art->Bestand > nMinVal
         
            abg->(dbSetFilter({|| Trim(abg->BuArt) $ cZugTypes },'Trim(BuArt) $ "'+cZugTypes+'"'))
            abg->(OrdScope(0,art->Matchcode))
            abg->(OrdScope(1,art->Matchcode))
            abg->(dbGoBottom())
//            abg->(dbSeek( art->Matchcode ))
            dZug := abg->Datum
            abg->(OrdScope(0,NIL))
            abg->(OrdScope(1,NIL))
            abg->(dbClearFilter())
            IF dZug >= dLastMin .AND. dZug <= dLastMax
               @ 24,00 SAY art->Matchcode
               hStock[art->Matchcode] := {"STOCK"=>art->Bestand-hReqInq["requirement"]+hReqInq["income"],"PREIS"=>nPreis,"DS"=>hReqInq["avgrequirement"],"ZUGANG"=>dZug}
            ENDIF
         Endif

      Endif
   //Endif
   art->(dbSkip())
Enddo
art->(dbClearFilter())

@ 24,00 CLEAR

art->(dbSetOrder( 1 ))
nX := 1
   oPdf:NewLine(2)
   oPdf:AtSay(Pad("Matchcode",25)+" "+PadL("Bestand",12)+" "+PadL("Bedarf p.a.",12)+" "+PadL("Wert",12)+PadL("Wert Åber",12)+" l. Zugang")

   nY := 1
   Do While nY <= Len(hStock)
      aVal := HGetValueAt(hStock,nY)
      art->(dbSeek( HGetKeyAt(hStock,nY) ))
      oPdf:NewLine()
      nTotal += aVal["STOCK"]*aVal["PREIS"]
      nTotOver += (aVal["STOCK"]-aVal["DS"]*nMonths)*aVal["PREIS"]
      oPdf:AtSay(art->Matchcode+" "+PadL(Transform(aVal["STOCK"],Me(art->Me)),12)+" "+PadL(Transform(aVal["DS"]*nMonths,Me(art->Me)),12)+" "+Str(aVal["STOCK"]*aVal["PREIS"],12,2)+" "+Str((aVal["STOCK"]-aVal["DS"]*nMonths)*aVal["PREIS"],12,2)+" "+DToC(aVal["ZUGANG"]))
      nY++
   Enddo
   nX++
   oPdf:NewLine()
   oPdf:AtSay(Space(25+1+12+1+12)+" "+Str(nTotal,12,2)+" "+Str(nTotOver,12,2))
CopyPrint()
