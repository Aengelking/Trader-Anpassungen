//#define TEST
LOCAL nX,lPrintQtyOnly
LOCAL lRePrint := .F. //.T.   //when this is set it just reprints ALL existings picks

Head("Picklist")

NetUse("englsre","re",.F.,0)
NetUse("lagrech","lagr",.F.,0)
NetUse("artikel","art",.F.,0)
NetUse("lagerne","lne",.F.,0)
NetUse("lagent","lage",.F.,0)

aRecs := {}
aOrte := {}
aUsedNums := {}

#ifdef TEST
IF Tr_Getini(28) != 9
   Alert("Programm befindet sich im Wartungsmodus")
   RETURN
ENDIF
#endif

nMaxInvCount := 0
IF ! lRePrint
   nMaxInvCount := GetBox(12,"Maximale Anzahl Lieferscheine")
   If LastKey() == 27
      Return
   Endif
ENDIF


//collect data from invoice file

re->( dbSetOrder(5) ) //packed

@ 01,00 SAY "Rechnungen sammeln..."
#ifdef TEST
   re->(dbSetFilter({|| re->Rechdat == Date() .AND. re->Reposnr == 0 },"Rechdat == Date() .AND. Reposnr == 0"))
#else
   re->(dbSetFilter({|| re->Reposnr == 0 .AND. re->Code == 1 },"Reposnr == 0 .AND. Code == 1"))
#endif
re->( dbGoTop() )
#ifdef TEST
   DO WHILE ! re->(EOF())
#else
   Do While ! re->Packed .AND. ! re->(EOF())
#endif
   //If re->RePosnr == 0 .AND. re->code == 1 //only unprinted invoices
      @ 01,22 SAY re->Rechnr
      #ifdef TEST
       IF re->State != "PICK" //.OR. Empty(re->State)
      #else
      If (! lRePrint .AND. Empty(re->State)) .OR. (lRePrint .AND. re->State == "PICK")
      #endif
         Aadd(aRecs,{"type"=>"R","nr"=>re->rechnr,"kunde"=>re->Kunde,"person"=>re->Person,"date"=>re->rechdat,"express"=>re->Express,"ready"=>re->code >=1,"pos"=>0,"inuse"=>re->Code>1,"state"=>re->State })
      Elseif re->State == "PICK"
         Aadd(aUsedNums,re->Termin)
      ELSE
       ? re->Rechnr,re->State
      Endif
   //Endif

   re->(dbSkip())
Enddo
re->(dbClearFilter())

@ 02,00 SAY "Entnahmen sammeln..."

lne->(dbSetOrder(1))
lne->(dbSetFilter({|| ! lne->Packed .AND. lne->Status == 1 },"! Packed .AND. Status == 1"))
lne->(dbGotop())
Do While ! lne->(Eof())
   lAdded := .F.
   If ! lne->Packed .AND. lne->Status == 1
      @ 02,22 SAY lne->Nummer
      If (! lRePrint .AND. Empty(lne->State)) .OR. (lRePrint .AND. lne->State == "PICK")
         lAdded := .T.
         Aadd(aRecs,{"type"=>"L","nr"=>lne->Nummer,"kunde"=>lne->Kunde,"person"=>lne->Buyer,"date"=>lne->Datum,"express"=>lne->Express,"ready"=>lne->Status>=1,"pos"=>0,"inuse"=>lne->Status>=2,"state"=>lne->State,"pnum"=>lne->PickNum})
      Elseif lne->State == "PICK"
         Aadd(aUsedNums,lne->Picknum)
      Endif
   Endif
   nNr := lne->Nummer
   Do While ! lne->(Eof()) .AND. lne->Nummer == nNr
      If lAdded
         aRecs[-1]["pos"] ++
      Endif
      lne->(dbSkip())
   Enddo
Enddo
lne->(dbClearFilter())

#ifdef TEST
//Aadd(aRecs,{"type"=>"L","nr"=>124036,"kunde"=>lne->Kunde,"person"=>32,"date"=>StoD("20170127"),"express"=>.F.,"ready"=>.T.,"pos"=>30,"inuse"=>.F.,"state"=>"","pnum"=>0})
#endif

//@ 01,00 CLEAR
@ 03,00 SAY "Daten sortieren..."

ASort(aRecs,,,{|x,y| x["express"]})
bBlock2 := {|x,y| x["express"] != y["express"] }
AGroupSort(aRecs,bBlock2,{|x,y| x["date"] < y["date"] })
bBlock3 := {|x,y| Eval(bBlock2,x,y) .OR. x["date"] != y["date"] }
AGroupSort(aRecs,bBlock3,{|x,y| x["nr"] < y["nr"] })

//If ! lPick .AND.
If nMaxInvCount > 0
   ASize(aRecs,Min(Len(aRecs),nMaxInvCount))
Endif

//@ 01,00 CLEAR
@ 04,00 SAY "Artikel sammeln..."

nR := 1
aArt := {}
Do While nR <= Len(aRecs)
   nNr := aRecs[nR]["nr"]

   If aRecs[nR]["type"] == "R"
      re->(dbSetOrder(4))
      re->(dbSeek( Str(nNr,6) ))
      @ 01,20 SAY re->Rechnr
      nRePos := 0

      Do While ! re->(EOF()) .AND. re->Rechnr == nNr

         If re->reposnr != 0 .AND. re->AoQty != 0
            aRecs[nR]["pos"]++
            nRePos++
            If (nX := AScan(aArt,{|x| x["matchcode"] == re->matchcode })) != 0
               aArt[nX]["qty"] += re->AoQty
            Else
               Aadd(aArt,{"matchcode"=>re->matchcode,"qty"=>re->AoQty })
            Endif
   
            art->(dbSetOrder( 1 ))
            art->(dbSeek( re->Matchcode ))
            If art->Lagerart
               lagr->(dbSeek(STR(re->Rechnr,6)+STR(re->Reposnr,3)+STR(re->AbNr,6)))  //reposnr depends on abnr
               Do While lagr->RechNr == re->Rechnr .AND. lagr->RePosNr == re->Reposnr .AND. lagr->ABNR == re->AbNr
                  IF (nX := AScan(aOrte,{|x| x["type"] == "R" .AND. x["nr"] == lagr->Rechnr .AND. x["matchcode"] == re->matchcode .AND. x["ort"] == lagr->Lagerort})) != 0 //if this same place in one the same invoice add together
                      aOrte[nX]["qty"] += lagr->LAGERMENGE
                  ELSE
                     Aadd(aOrte,{"type"=>"R","nr"=>lagr->RechNr,"me"=>re->Me,"matchcode"=>re->matchcode,"ort"=>lagr->Lagerort,"qty"=>lagr->LAGERMENGE})
                  ENDIF
                  lagr->(DBSKIP())
               Enddo
            Endif

         Endif
         re->(dbSkip())
      Enddo
   Else
      lne->(dbSetORder(1))
      lne->(dbSeek( nNr ))
      Do While lne->Nummer == nNr
         If (nX := AScan(aArt,{|x| x["matchcode"] == lne->matchcode })) != 0
            aArt[nX]["qty"] += lne->menge
         Else
            Aadd(aArt,{"matchcode"=>lne->matchcode,"qty"=>lne->menge })
         Endif
   
         art->(dbSetOrder( 1 ))
         art->(dbSeek( lne->Matchcode ))
         If art->Lagerart
            lage->(dbSeek(STR(lne->Nummer,6)+STR(lne->Pos,3) ))
            Do While lage->Nummer == lne->Nummer .AND. lage->Pos == lne->Pos
/*               IF (nX := AScan(aOrte,{|x| x["type"] == "L" .AND. x["nr"] == lage->Nummer .AND. x["matchcode"] == lne->matchcode .AND. x["ort"] == lage->Lagerort})) != 0
                  aOrte[nX]["qty"] += lage->LAGERMENGE
               ELSE*/
                  Aadd(aOrte,{"type"=>"L","nr"=>lage->Nummer,"pos"=>lage->Pos,"me"=>art->Me,"matchcode"=>lne->matchcode,"ort"=>lage->Lagerort,"qty"=>lage->LAGERMENGE})
//               ENDIF
               lage->(DBSKIP())
            Enddo
         Endif
         lne->(dbSkip())
      Enddo
   Endif
   nR++
Enddo

nPosCount := 0
AEval(aRecs,{|x| x["start"] := nPosCount+1, nPosCount += x["pos"] })

@ 01,00 CLEAR

@ 10,00 CLEAR TO 13,MaxCol()
@ 10,00 SAY "Anzahl Lieferscheine: "+LTrim(Str(Len(aRecs)))
@ 11,00 SAY "Anzahl Positionen   : "+LTrim(Str(nPosCount))
@ 12,00 SAY "Anzahl Artikel      : "+LTrim(Str(Len(aArt)))
@ 13,00 SAY "Anzahl Orte         : "+LTrim(Str(Len(aOrte)))


ASort(aOrte,,,{|x,y|
   LOCAL nLager1 := Val(Left(x["ort"],3))
   LOCAL nLager2 := Val(Left(y["ort"],3))
   LOCAL nReihe1,nReihe2,cSpalte1,cSpalte2,nFach1,nFach2

   IF nLager1 == nLager2 .AND. nLager1 <= 1 //lager 1 oder 0
      nReihe1 := Val(SubStr(x["ort"],5,2))
      nReihe2 := Val(SubStr(y["ort"],5,2))
      cSpalte1 := SubStr(x["ort"],7,1)
      cSpalte2 := SubStr(y["ort"],7,1)
      nFach1 := Val(SubStr(x["ort"],8,3))
      nFach2 := Val(SubStr(y["ort"],8,3))

      IF nReihe1 < nReihe2
         RETURN .T.
      ELSEIF nReihe1 == nReihe2
         IF cSpalte1 == cSpalte2
            IF nFach1 == nFach2
               RETURN x["matchcode"] < y["matchcode"]
            ELSE
               RETURN nFach1 < nFach2
            ENDIF
         ELSEIF nReihe1 % 2 == 0
            RETURN cSpalte1 > cSpalte2
         ELSE
            RETURN cSpalte1 < cSpalte2
         ENDIF
      ENDIF
   ENDIF
   RETURN x["ort"] < y["ort"]
})

StartPrint("picklist",,"PDF")
oPrinter := GetCurrentPrinterObject()
oPdf := oPrinter:Data

oPdf:NewPage()
//oPdf:PDFTOP := 5

oPdf:SetFont("Courier-Bold",0,14)

oPdf:AtSay("PICKLISTE",1)
oPdf:NewLine(2)


oPdf:SetFont("Courier",0,12)
oPdf:AtSay( "P-Nr"+" "+Pad("Lagerort",12)+" "+Pad(t("Matchcode"),25)+" "+Pad(t("Menge"),8)+Space(4)+" "+Pad("Gewicht",10) )
oPdf:NewLine(2)



nX := 1
nPNum := 0

Do While nX <= Len(aOrte)
   nR := AScan(aRecs,{|x| x["nr"] == aOrte[nX]["nr"] .AND. x["type"] == aOrte[nX]["type"] })
   lPrintQtyOnly := .F.
   IF nX > 1 .AND. aOrte[nX-1]["nr"] == aOrte[nX]["nr"] .AND. aOrte[nX-1]["type"] == aOrte[nX]["type"] .AND. aOrte[nX-1]["ort"] == aOrte[nX]["ort"] .AND. aOrte[nX-1]["matchcode"] == aOrte[nX]["matchcode"]
      lPrintQtyOnly := .T.
   ENDIF
   If nR == 0
      //Alert("Upps!!")
   Endif
   //nPnum := nR //aRecs[nR]["start"]+aOrte[nX]["repos"]-1
   nPNum++
   Do While AScan(aUsedNums,nPNum) != 0
      nPNum++
   Enddo

   If aOrte[nX]["type"] == "R"
      re->(dbSetOrder( 12 ))
      If re->(dbSeek( Str(aOrte[nX]["nr"],6)+Str(0,3) )) .AND. re->State != "PICK" //save the Pnum to the invoice file and set the state of the invoice to beeing picked
         aRecs[nR]["pickno"] := nPNum
         #ifndef TEST
         IF ! lRePrint
            re->(Rec_Lock(0))
            re->Termin := nPnum //we missuse this field for the moment
            re->State := "PICK"
            re->(dbUnLock())
         ENDIF
         #endif
      Else
         nPNum--
         aRecs[nR]["pickno"] := re->Termin
      Endif
   Else

      lne->(dbSetOrder( 1 ))
      If lne->(dbSeek( aOrte[nX]["nr"] )) .AND. lne->State != "PICK"
         aRecs[nR]["pickno"] := nPNum
         #ifndef TEST
         IF ! lRePrint
            lne->(Rec_Lock())
            lne->PickNum := nPNum
            lne->State := "PICK"
            lne->(dbUnLock())
         ENDIF
         #endif
      Else
         nPNum--
         aRecs[nR]["pickno"] := lne->Picknum
      Endif
   Endif
   
   art->(dbSetOrder( 1 ))
   art->(dbSeek( aOrte[nX]["matchcode"] ))
   IF ! lPrintQtyOnly
      oPdf:AtSay( Str(aRecs[nR]["pickno"],4)+" "+aOrte[nX]["ort"]+" "+aOrte[nX]["matchcode"]+" "+Pad(Transform(aOrte[nX]["qty"],Me(art->me)),8)+IF(art->Me!="STCK",art->Me,Space(4))+" "+If(art->Gewicht>0,Str(art->Gewicht,10,4),Space(7)) )
      oPdf:NewLine(1)
      oPdf:ReportLine += .5
      oPdf:ReportCol := oPdf:M2X(16)
      oPdf:AtSay( "Art.Nr. "+Str(art->Artikelnr,6) )
      //MBaseRun(Trim(Tr_Getini(1))+Chr(92)+"run"+Chr(92)+"barcode",{oPrinter,"C128",AllTrim(aOrte[nX]["matchcode"]),20})
   ELSE
      oPdf:AtSay( Space(44)+Pad(Transform(aOrte[nX]["qty"],Me(art->me)),8)+IF(art->Me!="STCK",art->Me,Space(4))+" "+Space(7) )
   ENDIF
   oPdf:NewLine(2)
// oPdf:ReportLine += .5
   //oPdf:Box(oPdf:R2D(oPdf:ReportLine),0,oPdf:R2D(oPdf:ReportLine),oPdf:R2D(oPdf:ReportWidth),1,,"D")
   nRow := oPdf:PageY - oPdf:R2D( oPdf:ReportLine+oPdf:PdfTop )-7
   oPdf:Box(nRow,oPdf:M2X( oPdf:PDFLEFT ),nRow,oPdf:M2X(200),1,,"D") //oPdf:ReportWidth-40
   oPdf:SetFont("Courier",0,5)
   oPdf:NewLine()
   oPdf:SetFont("Courier",0,12)
   nX++
Enddo
CopyPrint()



If Tr_MsgBox("Etiketten drucken?",,{"Ja","Nein"}) == 1
   SetPrinterMethodType(5) //stickers
   nX := 1
   Do While nX <= Len(aOrte)
      nR := AScan(aRecs,{|x| x["nr"] == aOrte[nX]["nr"] })

      mcPickNo := Str(aRecs[nR]["pickno"],3) //Str(aOrte[nX]["nr"],6)+"/"+LTrim(Str(aOrte[nX]["repos"]))
      mnPickQty := aOrte[nX]["qty"]
           art->(dbSetOrder( 1 ))
      art->(dbSeek( aOrte[nX]["matchcode"] ))
//    Alert("Printing Sticker for "+art->Matchcode)
      StickPrint("WARE",1)
      nX++

   Enddo
   mcPickNo := mnPickQty := NIL
   SetPrinterMethodType(0)
Endif
