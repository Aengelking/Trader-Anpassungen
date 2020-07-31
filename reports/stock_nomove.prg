LOCAL nYearsZug := 2
LOCAL nYearsAbg := 2
LOCAL nYears2Zug := 30
LOCAL nYears2Abg := 30
LOCAL nMinVal := 0
LOCAL nMinQty := 0
//LOCAL nType := 3
//LOCAL aTypes := {t("Zugänge"),t("Abgänge"),t("Zu- und Abgänge")}
LOCAL dZug,dAbg
LOCAL cZugTypes,cAbgTypes
LOCAL dLast := Date()-365*30


NetUse("artikel","art",.F.,0)
NetUse("engabg","abg",.F.,0)
NetUse("lager","lag",.F.,0)
NetUse("me","me",.F.,0)

art->(dbGoTop())

abg->(dbSetOrder( 3 ))

Head(t("Bestände ohne Bewegungen"))



@ 01,00 SAY "Letzter Abgang zwischen" GET nYearsAbg PICTURE "9"
@ 01,26 SAY "und"
@ 01,30 GET nYears2Abg PICTURE "99" VALID nYears2Abg <= 30 .AND. nYears2Abg >= 0
@ 01,33 SAY "Jahren"
@ 02,00 SAY "Letzter Zugang zwischen" GET nYearsZug PICTURE "9"
@ 02,26 SAY "und"
@ 02,30 GET nYears2Zug PICTURE "99" VALID nYears2Zug <= 30 .AND. nYears2Zug >= 0
@ 02,33 SAY "Jahren"

@ 03,00 SAY "Ab Wert            " GET nMinVal PICTURE "9999"
@ 04,00 SAY t("Bestand größer     ") GET nMinQty PICTURE "999"
//@ 04,00 SAY t("Bewegungen         ")
//@ 04,20,10,40 GET nType LISTBOX aTypes DROPDOWN
READ

IF LastKey() == 27
   RETURN
ENDIF

StartPrint(,,"PDF")
oPdf := GetCurrentPrinterObject():Data
oPdf:SetFont("COURIER")
oPdf:NewPage()
oPdf:Bold()
oPdf:AtSay( "Bestände mit letztem Abgang zwischen "+LTrim(Str(nYearsAbg))+" und "+LTrim(Str(nYears2Abg))+" Jahren" )
oPdf:NewLine()
oPdf:AtSay( "         und letztem Zugang zwischen "+LTrim(Str(nYearsZug))+" und "+LTrim(Str(nYears2Zug))+" Jahren" )
oPdf:NewLine()
oPdf:Normal()
oPdf:AtSay( "Bestandswert > EUR "+LTrim(Str(nMinVal,12,2)))
oPdf:NewLine()
oPdf:AtSay( "Bestand > "+LTrim(Str(nMinQty)) )
//oPdf:AtSay( aTypes[nType] )

hStock := {=>}
nTotal := 0
lag->(dbSetOrder( 1 ))
art->(dbSetFilter({|| art->Bestand > nMinQty },'Bestand > '+Str(nMinQty)))
art->(dbGoTop())

cZugTypes :="WE WA ZUG"
cAbgtypes := "RNR ENT ENŽ ABG"

Do While ! art->(Eof())
   //If art->Bestand > nMinQty
      hReqInq := GetProductRequirementAndIncoming(art->Artikelnr)
      If hReqInq["requirement"]+hReqInq["income"] == 0
         dZug := dLast
         dAbg := dLast

         abg->(dbSetFilter({|| Trim(abg->BuArt) $ cTypes },'Trim(BuArt) $ "'+cZugTypes+" "+cAbgTypes+'"'))
         abg->(dbSeek( art->Matchcode ))

         Do While abg->Matchcode == art->Matchcode .AND. ! abg->(Eof())
            If Trim(abg->BuArt) $ cZugTypes
               dZug := abg->Datum
            ELSE
               dAbg := abg->Datum
            ENDIF
            abg->(dbSkip())
         Enddo
         abg->(dbClearFilter())
         IF dZug <= Date()-365*nYearsZug .AND. dAbg <= Date()-365*nYearsAbg .AND. dZug >= Date()-365*nYears2Zug .AND. dAbg >= Date()-365*nYears2Abg
            nPreis := art->avpreis
            /*If art->Bezug >= 5
               nPreis := StCalc(art->artikelnr,5,99,.T.)
            Endif*/

            If nPreis*art->Bestand > nMinVal
               @ 24,00 SAY art->Matchcode
               lag->(dbSeek( art->Artikelnr ))
               Do While lag->Artikelnr == art->Artikelnr .AND. ! lag->(Eof())
                  If ! HHasKey(hStock,lag->Lagerort)
                     hStock[lag->Lagerort] := {=>}
                  Endif
                  If ! HHasKey(hStock[lag->Lagerort],art->Matchcode)
                     hStock[lag->Lagerort][art->Matchcode] := {0,dAbg,dZug,nPreis}
                  Endif
                  hStock[lag->Lagerort][art->Matchcode][1] += lag->Lagermenge
                  lag->(dbSkip())
               Enddo
            Endif
         Endif
      Endif
   //Endif
   art->(dbSkip())
Enddo
art->(dbClearFilter())

@ 24,00 CLEAR

art->(dbSetOrder( 1 ))
nX := 1
Do While nX <= Len(hStock)
   hArt := HGetValueAt(hStock,nX)

   oPdf:NewLine(2)
   oPdf:AtSay("Lagerort: "+HGetKeyAt(hStock,nX))
   oPdf:NewLine()
   oPdf:AtSay(Pad("Matchcode",25)+" "+PadL("Bestand",12)+" "+"Abgang   "+"Zugang   "+PadL("Wert",12))

   nY := 1
   Do While nY <= Len(hArt)
      aVal := HGetValueAt(hArt,nY)
      art->(dbSeek( HGetKeyAt(hArt,nY) ))
      oPdf:NewLine()
      oPdf:AtSay(art->Matchcode+" "+PadL(Transform(aVal[1],Me(art->Me)),12)+" "+IF(aVal[2]==dLast,Pad("nie",8),DToC(aVal[2]))+" "+IF(aVal[3]==dLast,Pad("nie",8),DToC(aVal[3]))+" "+Str(aVal[1]*aVal[4],12,2))
      nY++
   Enddo
   nX++
Enddo

CopyPrint()
