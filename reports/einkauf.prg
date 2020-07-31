LOCAL nYear  := 2016
LOCAL cStart
LOCAL dStart
LOCAL hTotals := {"FRACHT"=>0}
LOCAL nTotal,nTot,nMwSt

Head("Analyse Einkauf")

@ 01,00 SAY "Jahr" GET nYear PICTURE "9999" VALID nYear >= 2000 .AND. nYear <= Year(Date())
READ
IF LastKey() == 27
   RETURN
ENDIF

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
   nMwSt := (rech->GrAmt-rech->NetAmt-rech->Porto)/(rech->NetAmt+rech->Porto)
   hTotals["FRACHT"] += rech->Porto*(1+nMwSt)
   @ MaxRow(),00 SAY rech->Liefma+" "+rech->Rechnr
   rpos->(dbSeek( rech->Liefma+rech->Rechnr ))
   DO WHILE rpos->Liefma == rech->Liefma .AND. rpos->Beleg == rech->Rechnr .AND. ! rpos->(EOF())
      art->(dbSeek( Str(rpos->Artikelnr,6) ))
      cType := art->Type
      IF Trim(art->Type) == "UNFER"  //this cannot be correct, most likely should be RHB
         cType := "RHB"
      ENDIF
//      ? rpos->Liefma,rpos->Beleg,art->Matchcode,rpos->EkPr/rpos->Pe*rpos->Menge,art->Type
      IF ! HHasKey(hTotals,Trim(cType))
         hTotals[Trim(cType)] := 0
      ENDIF

      hTotals[Trim(cType)] += rpos->EkPr/rpos->Pe*rpos->Menge*(1+nMwSt)*rech->Rate

      rpos->(dbSkip())
   ENDDO
   rech->(dbSkip())
ENDDO

@ 01,00 CLEAR //Head("Analyse Einkauf "+Str(nYear,4))
nTot := 0
FOR EACH nTotal IN hTotals
   nTot += nTotal
   ? Pad(nTotal:__eNumKey(),6),nTotal
NEXT
? Space(6),nTot
SInkey(0,128)