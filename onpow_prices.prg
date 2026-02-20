FUNC ONPOWPRICES(xValue)
//#define TEST
//#define DEBUG
LOCAL cMainPath := "Y:\Dokumente und Einstellungen\All Users\Dokumente\Lieferanten\Onpow\Preise\dbf\"
LOCAL cPath
LOCAL aMatches
LOCAL cSup := Pad("ONPOW",8)
LOCAL aSeries := {},hSeries
LOCAL nAddPrice,nPrice,nFinalPrice := 0
LOCAL aDir,cFile
LOCAL dStart := StoD(""),dDate
LOCAL hRabatte := {1=>0,5000=>5}
LOCAL cSearch,lSingle,lSingleDual
LOCAL nX,aCompare,nLedPins
LOCAL cArtlief,lArtLiefPassed := .F.,lNewAli := .F.

MEMVAR cFilter
PUBLIC cFilter

IF ValType(xValue) == "L"
   lNewAli := xValue
ELSE
   IF ValType(xValue) == "C" 
      #ifdef DEBUG
      Alert("Getting price for article: "+xValue)
      #endif
      cArtLief := Pad(xValue,35)
      lNewAli := .T.
      lArtLiefPassed := .T.
   ENDIF
ENDIF

IF ! lNewAli
   Head("ONPOW Preisliste einlesen")
ENDIF

//look for youngest directory
aDir := Directory(cMainpath+"*.*","D")
ASort(aDir,{|x,y| x[3] > y[3] .OR. (x[3]==y[3] .AND. x[4]>y[4]) })
FOR nX := 1 TO Len(aDir)
   IF "D" $ aDir[nX,5] .AND. Lower(aDir[nX,1]) != "obsolete" .AND. Left(aDir[nX,1],1) != "."
      dDate := StoD("20"+Left(aDir[nX,1],6))
      IF dDate > dStart
         cPath := aDir[nX,1]
         dStart := dDate
      ENDIF
   ENDIF
NEXT

IF ! lNewAli .AND. Tr_MsgBox("Start date: "+DtoC(dStart),,{"OK","abbrechen"}) != 1
   RETURN
ENDIF

Aadd(aSeries,{;
   "FILE"=>"gq12",;
   "SEARCH"=>"GQ12",;
   "REGEX"=>"^(GQ12[B,S]?-?A?[F,H]?-10[D,E]?)((?:\/J)?)\/(.{1,5})\/.{2,4}\/[A-Z](\/FP)?",;
   "MATCH"=>{|aMatch,aCompare| aMatch[2]+aMatch[3] == aCompare[2] },;
   "REGEXNOLED"=>"^GQ12([B,S]?)(-?A?[F,H]?-10)((?:\/J)?)(\/[A-Z])(\/FP)?",;
   "MATCHNOLED"=>{|aMatch,aCompare|
      IF Empty(aMatch[2]) .AND. Len(aCompare) >= 2
         IF AT("-A",aMatch[3]) != 0
//            ? "GQ12"+aMatch[3]+aMatch[4],"==",aCompare[2],aCompare[1]
         ENDIF
         RETURN "GQ12"+aMatch[3]+aMatch[4] == aCompare[2]
      ENDIF
      RETURN aMatch[1] == aCompare[1]
   },;
   "LED"=>4,;
   "ADDCOSTLED"=>{31=>0.9,32=>0.9,2=>0.35},;
   "IP"=>6,;
   "COSTIP"=>0.2,;
   "COSTNOIP"=>0,;
   "VPE"=>50;
   };
)

Aadd(aSeries,{;
   "FILE"=>"gq16",;
   "SEARCH"=>"GQ16",; 
   "REGEX"=>"^(GQ16)P?([F,H,B]-[^\/]*)(\/[JL])?\/(.{1,5})\/.{2,4}(\/.)",;
   "MATCH"=>{|aMatch,aCompare|
      IF AT("ET",aMatch[3]) != 0
         aMatch[4] := ""
      ENDIF
      RETURN aMatch[2]+aMatch[3]+aMatch[4] == aCompare[2]
   },;
   "REGEXNOLED"=>"^(GQ16)P?([F,H,B]-.*\/?J?)L?(\/.)",;
   "MATCHNOLED"=>{|aMatch,aCompare|
      IF aMatch[4] == "/N"
         RETURN aMatch[2]+aMatch[3]+aMatch[4] == aCompare[1]
      ENDIF
      RETURN Len(aCompare) >= 2 .AND. aMatch[2]+aMatch[3] == aCompare[2]
   },;
   "LED"=>5,;
   "ADDCOSTLED"=>{41=>1.28,42=>1.28,31=>0.77,32=>0.77,2=>0.3},;
   "VPE"=>40;
   };
)

Aadd(aSeries,{;
   "FILE"=>"gq19",;
   "SEARCH"=>"GQ19",;
   "REGEX"=>"^(GQ19S?)P?([F,H]-10[D,E])(\/J)?\/(.{1,3})\/.{2,4}(\/[A-Z])",;
   "MATCH"=>{|aMatch,aCompare| aMatch[2]+aMatch[3]+aMatch[5]+aMatch[6] == aCompare[1]  },;
   "REGEXNOLED"=>"^(GQ19S?)P?([F,H,B]-.[^\/]*)(\/J)?(\/.)",;
   "MATCHNOLED"=>{|aMatch,aCompare| aMatch[2]+aMatch[3]+IF(aMatch[5]=="A","S",aMatch[5]) == aCompare[1] },;
   "LED"=>4,;
   "ADDCOSTLED"=>{31=>0.9,32=>0.9,2=>0.35},;
   "MATERIAL"=>6,; 
   "MATERIALADDCOST"=>{"A"=>0.43},;
   "VPE"=>40;      
   };
)
   //"MATERIALNOLED"=>4,;

FOR EACH cSearch IN {"GQ2","GQ30"}
   Aadd(aSeries,{;
      "FILE"=>"gq2",;
      "SEARCH"=>cSearch,;
      "REGEX"=>"^(GQ(?:2[2,5,8]|30))P?F?(-.{2}Z?)([D,E,T]{0,2})\/([^\/]{1,5})\/[^\/]{2,4}\/[A-Z](\/FP)?",; 
      "MATCH"=>{|aMatch,aCompare| 
         IF AT("T/",aCompare[2]) != 0 .OR. AT("T",aMatch[4]) != 0
            RETURN aMatch[2]+aMatch[3]+aMatch[4] == aCompare[2]
         ENDIF
         RETURN aMatch[2]+aMatch[3] == aCompare[2]
      },;
      "REGEXNOLED"=>"^(GQ(?:2[2,5,8]|30))P?F?(-.{2}Z?)\/[A-Z](\/FP)?",;
      "MATCHNOLED"=>{|aMatch,aCompare|
         RETURN aMatch[2]+aMatch[3] == aCompare[2]
      },;
      "LED"=>5,;
      "ADDCOSTLED"=>{31=>0.9,32=>0.9,41=>1.5,42=>1.5,4=>0.9,2=>0.35},;
      "LEDTYPE"=>4,;
      "IP"=>6,;
      "IPNOLED"=>4,;
      "COSTIP"=>0,;
      "COSTNOIP"=>-0.2,;
      "VPE"=>IF(cSearch=="GQ2",20,10);
      };
   )
NEXT

Aadd(aSeries,{;
   "FILE"=>"las2gq",;
   "SEARCH"=>"LAS2GQ",;
   "REGEX"=>"^(LAS2GQ)P?([F,H]-[0-9]{2}Z?)([D,E,T]{0,2})\/([^\/]{1,5})\/[^\/]{2,4}\/([A-Z])(\/FP)?",;
   "MATCH"=>{|aMatch,aCompare|
      IF aMatch[6] == "A"
         RETURN aMatch[2]+aMatch[3]+"/A" == aCompare[2]+aCompare[3]
      ENDIF
      RETURN aMatch[2]+aMatch[3]+"/S" == aCompare[2]+aCompare[3]
   },;
   "REGEXNOLED"=>"^(LAS2GQ)P?([F,H]-[0-9]{2}Z?)\/([A-Z])(\/FP)?",;
   "MATCHNOLED"=>{|aMatch,aCompare|
      RETURN aMatch[2]+aMatch[3] == aCompare[2]
   },;
   "LED"=>5,;
   "ADDCOSTLED"=>{41=>1.5,42=>1.5,31=>0.9,32=>0.9,2=>0.35},;
   "IP"=>7,;
   "IPNOLED"=>5,;
   "COSTIP"=>0,;
   "COSTNOIP"=>-0.35,;
   "MATERIAL"=>6,;
   "MATERIALNOLED"=>4,;
   "MATERIALADDCOST"=>{"N"=>-0.4},;
   "LEDTYPE"=>4,;
   "POWERADDCOST"=>0.35,;
   "VPE"=>40;
   };
)

Aadd(aSeries,{;
   "FILE"=>"las1gq",;
   "SEARCH"=>"LAS1GQ",;
   "REGEX"=>"^(LAS1GQ)P?F?(H?-[0-9]{2}Z?)([DET]{0,2})((?:\/L)?)\/?([^\/]{1,5})\/[^\/]{2,4}\/([A-Z])(\/FP)?",;
   "MATCH"=>{|aMatch,aCompare|
      IF AT("T/",aCompare[2]) != 0 .OR. AT("T",aMatch[4]) != 0
         RETURN aMatch[2]+aMatch[3]+aMatch[4]+aMatch[5] == aCompare[2]
      ENDIF
      RETURN aMatch[2]+aMatch[3]+aMatch[5] == aCompare[2]
   },;
   "REGEXNOLED"=>"^(LAS1GQ)P?F?(H?-[0-9]{2}Z?)((?:\/L)?)\/?([A-Z])(\/FP)?",;
   "MATCHNOLED"=>{|aMatch,aCompare| aMatch[2]+aMatch[3]+aMatch[4] == aCompare[2] },;
   "LED"=>6,;
   "ADDCOSTLED"=>{41=>1.5,42=>1.5,31=>0.9,32=>0.9,2=>0.35},;
   "IP"=>8,;
   "IPNOLED"=>6,;
   "COSTIP"=>0,;
   "COSTNOIP"=>-0.2,;
   "LEDTYPE"=>4,;
      "VPE"=>40;
   };
)

Aadd(aSeries,{;
   "FILE"=>"las1agq",;
   "SEARCH"=>"LAS1-AGQ",;
   "REGEX"=>"^(LAS1-AGQ)P?(H?-[0-9]{2}Z?)([D,E,T]{0,2})\/?([^\/]{1,5})\/[^\/]{2,4}\/([A-Z])(\/FP)?",;
   "MATCH"=>{|aMatch,aCompare|           
      IF Len(aCompare) < 3
         RETURN .F.
      ENDIF
      
      IF aMatch[6] == "N"
         RETURN aCompare[3] == "/N" .AND. aMatch[2]+aMatch[3] == aCompare[2]
      ENDIF
      RETURN aCompare[3] == "/S" .AND. aMatch[2]+aMatch[3] == aCompare[2]
   },;
   "REGEXNOLED"=>"^(LAS1-AGQ)P?(H?-[0-9]{2}Z?)\/([A-Z])(\/FP)?",;
   "MATCHNOLED"=>{|aMatch,aCompare|
      IF Len(aCompare) < 3
         RETURN .F.
      ENDIF
      IF aMatch[4] == "N"
         RETURN aCompare[3] == "/N" .AND. aMatch[2]+aMatch[3] == aCompare[2]
      ENDIF
      RETURN aCompare[3] == "/S" .AND. aMatch[2]+aMatch[3] == aCompare[2]
   },;
   "LED"=>5,;
   "ADDCOSTLED"=>{41=>1.5,42=>1.5,31=>1.35,32=>1.35,2=>0.35},;
   "IP"=>7,;
   "IPNOLED"=>5,;
   "COSTIP"=>0,;
   "COSTNOIP"=>0,;
   "LEDTYPE"=>4,;
   "POWERADDCOST"=>0.35,;
      "VPE"=>40;
   };
)

Aadd(aSeries,{;
   "FILE"=>"ts",;
   "SEARCH"=>"TS",;
   "REGEX"=>"^(TS(?:19|22|25))([A-Z])(\/[0-9,Z,T,C]{2,5})\/Y\/SS\/([^\/]{2,5})\/[0-9]{1,2}V(-[3,5]W)?",;
   "MATCH"=>{|aMatch,aCompare|
      RETURN aMatch[2]+aMatch[4] == Trim(aCompare[1])
   },;
   "LED"=>5,;
   "SINGLEDUAL"=>.T.,;
   "ADDCOSTLEDSINGLE"=>{2=>0.77},;
   "ADDCOSTLEDDUAL"=>{41=>2.30,42=>2.30,31=>1.85,32=>1.85,2=>0.77},;
   "BODY"=>3,;
   "BODYADDCOST"=>{"A"=>0.35,"C"=>0.35,"D"=>0.35,"F"=>0.35},;
   "LEDCOLORCOSTREGEX"=>"^[0-9]{0,2}[N,R,G]{1,2}$",;
   "LEDCOLORADDCOST"=>1.10;
   };
)
Aadd(aSeries,{;
   "FILE"=>"indicator",;
   "SEARCH"=>"GQ",;
   "REGEX"=>"^(GQ[0-9]{1,2}[T,G,F]-D)\/?L?\/([^\/]{1,5})\/[^\/]{2,4}\/(.)",;
   "MATCH"=>{|aMatch,aCompare|
      IF aMatch[4] == "A"
         RETURN aMatch[2]+"/N" == aCompare[2]+aCompare[3]
      ENDIF
      RETURN aMatch[2]+"/"+aMatch[4] == aCompare[2]+aCompare[3]
   },;
   "LED"=>3,;
   "ADDCOSTLED"=>{41=>1.5,42=>1.5,31=>0.9,32=>0.9,2=>0.35};
   };
)


NetUse("artlief","ali")
NetUse("buyprice","bpr")
NetUse("artikel","art")


/**
   Deactivate old price lists if we are not just adding a new part
**/
IF ! lNewAli
   bpr->(dbSetOrder(1))
   /*bpr->(dbSetFilter({|| Trim(bpr->Type) == "LIST" .AND. Trim(bpr->Number) != cPath .AND. bpr->StartDate < dStart .AND. (Empty(bpr->EndDate) .OR. bpr->EndDate > dStart) },;
      'Trim(Type) == "LIST" .AND. Trim(Number) != "'+cPath+'" .AND. StartDate < StoD("'+DtoS(dStart)+'") .AND. (Empty(EndDate) .OR. EndDate > StoD("'+DtoS(dStart)+'"))'))*/
   cFilter := 'Trim(Type) == "LIST" .AND. ((Trim(Number) != "'+cPath+'" .AND. StartDate < StoD("'+DtoS(dStart)+'") .OR. Trim(Number) == "'+cPath+'") .AND. (Empty(enddate) .OR. EndDate > StoD("'+DtoS(dStart)+'")))'
   bpr->(dbSetFilter({|| bpr->(&cFilter) },cFilter ))
   
   bpr->(dbSeek( cSup ))
   @ 01,00 SAY "Alte Preislisten werden deaktiviert "
   DO WHILE ! bpr->(EOF()) .AND. bpr->Liefma == cSup
      #ifndef TEST
      bpr->(Rec_Lock( 0 ))
      bpr->EndDate := dStart-1
      bpr->(dbUnLock())
      #endif
      @ 01,37 SAY bpr->Artikelnr
      @ 01,45 SAY bpr->Number
   
      bpr->(dbSkip())
   ENDDO
   bpr->(dbClearFilter())
ENDIF

ali->(dbSetOrder(3))
art->(dbSetOrder( 2 ))
IF ! lNewAli
   @ 02,00 SAY "Preise werden aktualisiert"
ENDIF
FOR EACH hSeries IN aSeries
   cFile := cMainPath+cPath+"\"+hSeries:File
   IF ! File(cFile+".dbf")
      ? "No File",cFile+".dbf"
   ELSE
      IF Select("oppl") != 0
         oppl->(dbCloseArea())
      ENDIF
      Net_Use(cFile,"oppl",.F.,0,"DBFNTX")
      oppl->(dbGoTop())

      DO WHILE (! lNewAli .OR. nFinalPrice == 0) .AND. ! oppl->(EOF())
         IF oppl->(FieldPos("NOLED")) != 0 .AND. ! Empty(oppl->NoLed)
            IF HHasKey(hSeries,"REGEXNOLED")
               aCompare := HB_Regex("([^\/]*(?:\/[JL])?)(\/[ANS])(\/FP)?",oppl->Part)
               IF Len(aCompare) == 0
                  aCompare := {oppl->Part}
               ENDIF

               #ifdef DEBUG               
               ? oppl->Part,"NO LED"               
               #endif               
               IF ! lNewAli 
                  IF ! ali->(dbSeek( cSup+hSeries:Search, .T. ))
                     #ifdef DEBUG
                     ?? " Not found"
                     #endif
                     LOOP
                  ELSE
                     cArtLief := ali->Artlief
                  ENDIF
               ELSEIF Empty(cArtLief)
                  cArtLief := Space(35)  //not sure what to put here but otherwise the loop condition fails
               ENDIF
               #ifdef DEBUG
               IF At(hSeries:Search,cArtLief) != 1
                  ?? " no match"
               ENDIF
               #endif
               DO WHILE (lArtLiefPassed .OR. ali->Kunde == cSup) .AND. At(hSeries:Search,cArtLief) == 1
                  IF ! lArtLiefPassed
                     art->(dbSeek( Str(ali->Artikelnr,6) ))  //need to use artikel DB as some ali->Matchcode's have not been updated on a change!

                     IF Left(art->Matchcode,2) $ "CS KS"
                        IF ! lNewAli
                           ali->(dbSkip())
                           LOOP
                        ELSE
                           RETURN
                        ENDIF
                     ENDIF
                  ENDIF
                  IF Upper(Chr(Inkey())) == "S"
                     IF Upper(Chr(Sinkey(0))) == "C"
                        RETURN
                     ENDIF
                  ENDIF

                  aMatches := HB_Regex(hSeries:RegexNoLed,cArtLief)

                  IF aMatches != NIL .AND. Len(aMatches) > 0 .AND. Eval(hSeries:MatchNoLed,aMatches,aCompare)
                     #ifdef DEBUG
                     ? " ",cArtLief
                     #else
                     @ 02,37 SAY cArtLief
                     #endif
                     nAddPrice := 0
                     IF HHasKey(hSeries,"IPNOLED")
                        IF Len(aMatches) >= hSeries["IPNOLED"] .AND. aMatches[hSeries["IPNOLED"]] == "/FP"
                           nAddPrice += hSeries["COSTIP"]
                        ELSEIF AT("/FP",oppl->Part) != 0
                           nAddPrice += hSeries["COSTNOIP"]
                        ENDIF
                     ENDIF
                     IF HHasKey(hSeries,"MATERIALNOLED")
                        IF Len(aMatches) >= hSeries["MATERIALNOLED"] .AND. HHasKey(hSeries:MaterialAddCost,aMatches[hSeries["MATERIALNOLED"]])
                           nAddPrice += hSeries:MaterialAddCost[aMatches[hSeries["MATERIALNOLED"]]]
                        ENDIF
                     ENDIF
                     nFinalPrice := oppl->NoLed+nAddPrice
                     IF ! lArtLiefPassed
                        #ifndef TEST                  
                        IF HHasKey(hSeries,"VPE") 
                           art->(Rec_Lock(0))
                           art->VPE := hSeries:VPE
                           art->(dbUnLock())
                        ENDIF
                        #endif

                        AddPrices(nFinalPrice,hRabatte,cPath,cSup,dStart)
                     ENDIF
                     #ifdef DEBUG
                     ? " price found",nFinalPrice
                     Sinkey(0)
                     #endif
                  ELSE
                     #ifdef DEBUG
                        ?? " no price found"
                     #endif
                  ENDIF
                  IF ! lNewAli
                     ali->(dbSkip())
                     cArtLief := ali->Artlief
                  ELSE
                     EXIT
                  ENDIF
               ENDDO
            ELSE
               #ifdef DEBUG
               ? oppl->Part," NO LED direct"
               #endif
               IF lArtLiefPassed .OR. ali->(dbSeek( cSup+Pad(oppl->Part,35) )) //IF no regex and there is a match between DB an the part on the list
                  nFinalPrice := oppl->NoLed
                  IF ! lArtLiefPassed
                     #ifdef DEBUG                  
                     ? " ",ali->Artikelnr
                     #endif
                     
                     #ifndef TEST                  
                     IF HHasKey(hSeries,"VPE") 
                        art->(Rec_Lock(0))
                        art->VPE := hSeries:VPE
                        art->(dbUnLock())
                     ENDIF
                     #endif

                     AddPrices(nFinalPrice,hRabatte,cPath,cSup,dStart)
                  ENDIF
                  #ifdef DEBUG
                  ? " price found",nFinalPrice
                  Sinkey(0)
                  #endif
               ELSE
                  #ifdef DEBUG
                  ? " not found"
                  #endif
               ENDIF
            ENDIF
         ENDIF
         IF  (oppl->(FieldPos("LED")) != 0 .AND. ! Empty(oppl->LED)) .OR. (oppl->(FieldPos("DOT")) != 0 .AND. ! Empty(oppl->Dot)) .OR. (oppl->(FieldPos("RING")) != 0 .AND. ! Empty(oppl->Ring));
            .OR. (oppl->(FieldPos("SINGLE")) != 0 .AND. ! Empty(oppl->Single)) .OR. (oppl->(FieldPos("DUAL")) != 0 .AND. ! Empty(oppl->Dual))
            #ifdef DEBUG
            ? oppl->Part
            #endif

            IF ! lNewAli .AND. ! ali->(dbSeek( cSup+hSeries:Search, .T. ))
               #ifdef DEBUG
               ? "Not found"
               #endif
            ENDIF
            #ifdef DEBUG
            IF At(hSeries:Search,cArtLief) != 1
               ?? " no match"
            ENDIF
            #endif

            DO WHILE (lArtLiefPassed .OR. ali->Kunde == cSup) .AND. At(hSeries:Search,cArtLief) == 1
               IF ! lArtLiefPassed
                  cArtLief := ali->Artlief
                  art->(dbSeek( Str(ali->Artikelnr,6) ))  //need to use artikel DB as some ali->Matchcode's have not been updated on a change!

                  IF Left(art->Matchcode,2) $ "CS KS"
                     IF ! lNewAli
                        ali->(dbSkip())
                        LOOP
                     ELSE
                        RETURN 0
                     ENDIF
                  ENDIF
               ENDIF
               IF Upper(Chr(Inkey())) == "S"
                  IF Upper(Chr(Sinkey(0))) == "C"
                     RETURN 0
                  ENDIF
               ENDIF

               aMatches := HB_Regex(hSeries:Regex,cArtLief)

               nAddPrice := 0
               aCompare := HB_Regex("(.*)(\/[S,N,A,P])(\/FP)?",oppl->Part)
               IF Len(aCompare) == 0
                  aCompare := {oppl->Part,"","",""}
               ENDIF
               //Extra Cost for LED
               IF aMatches != NIL .AND. Len(aMatches) > 0 .AND. Eval(hSeries:Match,aMatches,aCompare)
                  #ifdef DEBUG
                   ?? "price found"                  
                  #endif
                  nLedPins := Val(aMatches[hSeries:LED])
                  lSingleDual := HHasKey(hSeries,"SINGLEDUAL") .AND. hSeries:SingleDual

                  IF lSingleDual
                     lSingle := AT("N",aMatches[hSeries:LED]) != 0
                  ENDIF

                  IF nLedPins > 0
                     IF lSingleDual
                        IF lSingle
                           nAddPrice +=  hSeries:AddCostLedSingle[nLedPins]
                        ELSE
                           nAddPrice +=  hSeries:AddCostLedDual[nLedPins]
                        ENDIF
                     ELSE
                        nAddPrice +=  hSeries:AddCostLed[nLedPins]
                     ENDIF
                  ENDIF

                  IF lSingleDual .AND. oppl->(FieldPos("SINGLE")) != 0 .AND. oppl->(FieldPos("DUAL")) != 0
                     IF lSingle
                        nPrice := oppl->Single
                     ELSE
                        nPrice := oppl->Dual
                     ENDIF
                  ELSEIF oppl->(FieldPos("LED")) != 0
                     nPrice := oppl->Led
                  ELSEIF HHasKey(hSeries,"LEDTYPE")
                     IF Right(aMatches[hSeries:LedType],1) == "T" .AND. HHasKey(hSeries,"POWERADDCOST") .AND. ! Empty(hSeries:PowerAddCost) //if there is power add cost, then this is always based on the ring price
                        nPrice := oppl->Ring
                        nAddPrice += hSeries:PowerAddCost
                     ELSE
                        IF Left(aMatches[hSeries:LedType],1) == "D"
                           nPrice := oppl->Dot
                        ELSE
                           nPrice := oppl->Ring
                        ENDIF
                     ENDIF
                  ELSE
                     nPrice := 0
                  ENDIF

                  IF ValType(nPrice) != "N"
                     Alert("Make sure all price fields are numeric. Add zeros to the first line.;"+cFile)
                     RETURN 0
                  ENDIF

                  IF nPrice == 0
                     #ifdef DEBUG
                     ? cArtLief,"no price"
                     #endif
                     ali->(dbSkip())

                     LOOP
                  ENDIF

                  IF HHasKey(hSeries,"LEDCOLORCOSTREGEX")
                     IF Len(HB_Regex(hSeries:LedColorCostRegex,aMatches[hSeries:LED])) == 0
                        nAddPrice += hSeries:LedColorAddCost
                     ENDIF
                  ENDIF

                  IF HHasKey(hSeries,"IP")
                     IF Len(aMatches) >= hSeries["IP"] .AND. aMatches[hSeries["IP"]] == "/FP"
                        nAddPrice += hSeries["COSTIP"]
                     ELSEIF AT("/FP",oppl->Part) != 0
                        nAddPrice += hSeries["COSTNOIP"]
                     ENDIF
                  ENDIF

                  IF HHasKey(hSeries,"MATERIAL")
                     IF Len(aMatches) >= hSeries["MATERIAL"] .AND. HHasKey(hSeries:MaterialAddCost,aMatches[hSeries["MATERIAL"]])
                        nAddPrice += hSeries:MaterialAddCost[aMatches[hSeries["MATERIAL"]]]
                     ENDIF
                  ENDIF
                  IF HHasKey(hSeries,"BODY")
                     IF Len(aMatches) >= hSeries["BODY"] .AND. HHasKey(hSeries:BodyAddCost,aMatches[hSeries["BODY"]])
                        nAddPrice += hSeries:BodyAddCost[aMatches[hSeries["BODY"]]]
                     ENDIF
                  ENDIF

                  #ifdef DEBUG
                  ? " ",cArtLief,art->Artikelnr,Str(nPrice,5,2),"+",Str(nAddPrice,5,2)
                  #else
                  IF ! lArtLiefPassed
                     @ 02,37 SAY cArtLief
                  ENDIF
                  #endif
                  
                  nFinalPrice := nPrice+nAddPrice                     
                  IF ! lArtLiefPassed 
                     #ifndef TEST                  
                     IF HHasKey(hSeries,"VPE") 
                        art->(Rec_Lock(0))
                        art->VPE := hSeries:VPE
                        art->(dbUnLock())
                     ENDIF
                     #endif

                     AddPrices(nFinalPrice,hRabatte,cPath,cSup,dStart)
                  ENDIF
                  #ifdef DEBUG
                  ? " price found",nFinalPrice
                  Sinkey(0)
                  #endif
                     
                  
               ELSE
                  #ifdef DEBUG
                     ?? " no price found" //,"Matches:",ValToPrg(aMatches),"Compare:",ValToPrg(aCompare)
                  #endif
               ENDIF
               IF ! lNewAli
                  ali->(dbSkip())
               ELSE
                  EXIT
               ENDIF
            ENDDO
         ENDIF
         oppl->(dbSkip())
         //EXIT
      ENDDO
      oppl->(dbCloseArea())
   ENDIF
NEXT
IF ! lNewAli
   @ MaxRow(),00 SAY "Abgeschlossen. Weiter mit beliebiger Taste..."
   SInkey(0)
ENDIF

RETURN nFinalPrice

STATIC FUNCTION AddPrices(nPrice,hRabatte,cPath,cSup,dStart)
   LOCAL nRab,nQty
      bpr->(dbSetOrder(1))
      bpr->(dbSetFilter({|| Trim(bpr->Type) == "LIST" .AND. Trim(bpr->Number) == cPath },;
            'Trim(Type) == "LIST" .AND. Trim(Number) == "'+cPath+'"' ))
      FOR EACH nRab IN hRabatte
         nQty := nRab:__enumKey()
         #ifdef DEBUG
         ? nQty,nPrice*(100-nRab)/100
         #endif
         IF bpr->(dbSeek( cSup+Str(ali->Artikelnr,6)+Str(nQty,12,2) ))
            #ifdef DEBUG
            ?? " update"
            #endif
            #ifndef TEST
            bpr->(Rec_Lock())
            #endif
         ELSE
            #ifdef DEBUG
            ?? " new"
            #endif
            #ifndef TEST
            bpr->(Add_Rec())
            bpr->Artikelnr := ali->Artikelnr
            bpr->Qty := nQty
            bpr->Number := cPath
            bpr->Type := "LIST"
            bpr->Liefma := cSup
            #endif
         ENDIF
         #ifndef TEST
         bpr->Price := nPrice*(100-nRab)/100
         bpr->Pe     := 1
         bpr->StartDate := dStart
         bpr->EndDate := CToD("")
         bpr->(dbUnLock())
         #endif
      NEXT
      bpr->(dbClearFilter())
RETURN NIL