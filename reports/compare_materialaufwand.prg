LOCAL aData1,aData2,aData3,hDiff1,hDiff2,nTot1,nTot2,nVal,hEK1,hEK2
LOCAL nEk1,nEk2,nEk1o,nEk2o,nDiff1,nDiff2,nUm1,nUm2
LOCAL aExport
LOCAL cFile := Trim(Tr_Getini(1))+"\export\ma_vergleich_2015_2016.csv",nH

Head("Materialaufwand pro Hersteller mit Vorjahr vergleichen")

IF (nH := FCreate(cFile)) <= 0
   Tr_MsgBox(t("Fehler beim Öffnen der Datei"))
   RETURN
ENDIF

NetUse("artikel","art")
NetUse("manufact","manu")
NetUSe("umsatz","um")

aData1 := GetInventur(2014)
aData2 := GetInventur(2015)
aData3 := GetInventur(2016)

hDiff1 := CompareYears(aData1,aData2)
hDiff2 := CompareYears(aData2,aData3)

hEK1 := GetEinkauf(2015)
hEK2 := GetEinkauf(2016)

um->(dbSetOrder( 1 ))
manu->(dbGoTop())

? Space(15),Pad(t("Bestandsveränderung"),15),Pad("Materialaufwand",15),Pad("Umsatz",15)
? Pad("Hersteller",15),PadL("2015",7),PadL("2016",7),PadL("2015",7),PadL("2016",7),PadL("2015",7),PadL("2016",7),PadL("2015",7),PadL("2016",7)

aExport := {{"Hersteller","BV 2015","BV 2016","MA EUR 2015","MA 2015","MA EUR 2016","MA 2016","Umsatz 2015","Umsatz 2016"}}

DO WHILE ! manu->(EOF())
   nDiff1 := IF(HHasKey(hDiff1,manu->ID),hDiff1[manu->ID],0)
   nDiff2 := IF(HHasKey(hDiff2,manu->ID),hDiff2[manu->ID],0)
   nEK1 := IF(HHasKey(hEK1,manu->ID),hEK1[manu->ID,2],0)
   nEK2 := IF(HHasKey(hEK2,manu->ID),hEK2[manu->ID,2],0)
   nEK1o := IF(HHasKey(hEK1,manu->ID),hEK1[manu->ID,2],0)
   nEK2o := IF(HHasKey(hEK2,manu->ID),hEK2[manu->ID,2],0)

   nUm1 := um->(LETO_SUM("umsatz","year == '2015'",Str(manu->ID,5),Str(manu->ID,5) ))
   nUm2 := um->(LETO_SUM("umsatz","year == '2016'",Str(manu->ID,5),Str(manu->ID,5) ))

   ? manu->Short,Str(nDiff1,7,0),Str(nDiff2,7,0)
   ?? "",Str(nEk1,7,0),Str(nEk2,7,0)
   ? Space(15+1+7+1+7),Str(IF(HHasKey(hEK1,manu->ID),hEK1[manu->ID,1],0),7,0),Str(IF(HHasKey(hEK2,manu->ID),hEK2[manu->ID,1],0),7,0)

   ?? "",Str(nUm1,7,0) // ,LTrim(Str(manu->ID)),LTrim(Str(manu->ID)) ))
   ?? "",Str(nUm2,7,0) // ,LTrim(Str(manu->ID)),LTrim(Str(manu->ID)) ))
   ?? "",str(nUm1-nEK1+nDiff1,7,0)
   ?? "",Str(nUm2-nEK2+nDiff2,7,0)
   Aadd(aExport,{manu->Short,Round(nDiff1,2),Round(nDiff2,2),Round(nEk1,2),IF(HHasKey(hEK1,manu->ID),hEK1[manu->ID,1],0),Round(nEk2,2),IF(HHasKey(hEK2,manu->ID),hEK2[manu->ID,1],0),nUm1,nUm2})
   manu->(dbSkip())
ENDDO

FClose(nH)
SaveASCsv(cFile,aExport)
Wapi_ShellExecute(,"open",cFile)

SInkey(0,128)

STATIC Function CompareYears(aData1,aData2)
   LOCAL aRec,nX
   LOCAL hManu := {=>}

   art->(dbSetORder( 2 ))
   FOR EACH aRec IN aData1
      IF AScan(aData2,{|x| x[1] == aRec[1]}) == 0 //not in next year
         Aadd(aData2,{aRec[1],aRec[2],0,aRec[4],0,0})
      ENDIF
   NEXT
   FOR EACH aRec IN aData2
      art->(dbSeek( PadL(aRec[2],6) ))
      IF ! HHasKey(hManu,art->Manufactur)
         hManu[art->Manufactur] := 0
      ENDIF
      IF (nX := AScan(aData1,{|x| x[1] == aRec[1]})) != 0 //in previous year
         hManu[art->Manufactur] += aRec[6]-aData1[nX,6]
      ELSE
         hManu[art->Manufactur] += aRec[6]
      ENDIF
   NEXT
RETURN hManu



STATIC Function GetInventur(nYear)
   LOCAL aDir
   LOCAL cPath := Trim(Tr_Getini(1))+"\export\"
   LOCAL aInventur := {}

   aDir := Directory(cPath+"inventur_"+IF(nYear==Year(Date()),DtoS(Date()-1),Str(nYear,4)+"1231")+"*")

   IF Len(aDir) >= 1
//      Alert(ATail(aDir)[1])
      aInventur := FParse(cPath+ATail(aDir)[1],";")
      AEval(aInventur,{|x,y|
         x[3] := __StrToNum(x[3])
         x[5] := __StrToNum(x[5])
         x[6] := __StrToNum(x[6])
         RETURN NIL
      })
   ENDIF
RETURN aInventur

STATIC FUNCTION __StrToNum(nX)
RETURN Val(StrTran(nX,",","."))


STATIC FUNCTION GetEinkauf(nYear)
   LOCAL cStart
   LOCAL dStart
   LOCAL hTotals := {=>} //"FRACHT"=>0}
   LOCAL nTotal,nTot,nMwSt


   cStart := Str(nYear,4)+"0101"
   dStart := StoD( cStart )

   NetUse("engrech","rech")
   NetUse("rechpos","rpos")
   NetUSe("artikel","art")
   
   rech->(dbSetOrder( 3 ))
   rpos->(dbSetOrder( 1 ))
   art->(dbSetOrder( 2 ))
   
   rech->(dbSeek( cStart, .T.))
   
   DO WHILE ! rech->(Eof()) .AND. rech->RechDat <= EoY(dStart)
      //nMwSt := (rech->GrAmt-(rech->NetAmt+rech->Porto))/(rech->NetAmt+rech->Porto)
      //hTotals["FRACHT"] += rech->Porto*(1+nMwSt)
      rpos->(dbSeek( rech->Liefma+rech->Rechnr ))
      DO WHILE rpos->Liefma == rech->Liefma .AND. rpos->Beleg == rech->Rechnr .AND. ! rpos->(EOF())
         art->(dbSeek( Str(rpos->Artikelnr,6) ))

         //? rpos->Liefma,rpos->Beleg,art->Matchcode,rpos->EkPr/rpos->Pe*rpos->Menge,art->Type

         IF ! HHasKey(hTotals,art->Manufactur)
            hTotals[art->Manufactur] := {0,0}
         ENDIF
         hTotals[art->Manufactur][1] += rpos->EkPr/rpos->Pe*rpos->Menge
         hTotals[art->Manufactur][2] += rpos->EkPr/rpos->Pe*rpos->Menge*rech->Rate
         rpos->(dbSkip())
      ENDDO
      rech->(dbSkip())
   ENDDO
RETURN hTotals