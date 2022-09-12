//gets all the turnover with piezo products

LOCAL aBase := {"FT-9T-18A1","7BB-12-9"}  //parts required to make it a piezo product
LOCAL aMakeActive := {"ATTINY13-10SSUSOIC-8","ATTINY13-20MU","ATTINY25-15MT","ATTINY25-20MU","ATTINY45V-10MU"} //Matchcodes to make it active
LOCAL aActive := {}
LOCAL aUnknown := {}
LOCAL aProds := {}
LOCAL aData := {}
LOCAL aList,nActive := 0,nPassive := 0
LOCAL nYear

LOCAL nB

//aBase := {"p5029.LP.002"}

Head(t("Umsätze mit Piezo Produkten"))

NetUse("artikel","art")
NetUse("parts","part")
NetUse("englsre","re")

art->(dbSetFilter( {|| AT(".PRG",art->Matchcode)!=0} , 'AT(".PRG",Matchcode)!=0' ))
art->(dbSeek( "p" ))
DO WHILE Left(art->Matchcode,1) == "p"
   Aadd(aMakeActive,art->Matchcode)
   art->(dbSkip())
ENDDO
art->(dbClearFilter())

FOR nX := 1 TO 2
   IF nX == 1
      aList := aMakeActive
   ELSE
      aList := aBase
   ENDIF
   FOR nB := 1 TO Len(aList)
      art->(dbSetOrder( 1 ))
      IF art->(dbSeek( aList[nB] ))
         nArtnr := art->Artikelnr
         art->(dbSetOrder( 2 ))
         part->(dbSetOrder( 2 ))
         part->(dbSeek( Str(nArtnr,6) ))
         DO WHILE part->Partart == nArtnr
            art->(dbSeek( Str(part->Listart,6) ))
            IF art->Bezug >= 5  //nur Fertigungsartikel einbeziehn, vermeidet, dass falsche Produkte (alte Stüli) einbezigen werden
               IF ! Trim(art->Matchcode) $ aList //add this part to the list of parts, this way we achieve a recursion
                  Aadd(aList,Trim(art->Matchcode))
               ENDIF
               IF nX == 1 .AND. ! Trim(art->Matchcode) $ aActive
                  Aadd(aActive,Trim(art->Matchcode))
               ELSEIF nX == 2 .AND.  ! Trim(art->Matchcode) $ aProds
                  Aadd(aProds,Trim(art->Matchcode))
               ENDIF
            ENDIF
            part->(dbSkip())
         ENDDO
      ENDIF
   NEXT
NEXT

//add all parts which are in the Pizeo Group and Manufacturer Engelking
art->(dbSetOrder( 4 ))
art->(dbSeek( "SWPM" ))
DO WHILE art->Gruppe == "SWPM"      
   IF art->Manufactur == 6 .AND. ! Trim(art->Matchcode) $ aList //add this part to the list of parts, this way we achieve a recursion
      Aadd(aProds,Trim(art->Matchcode))
      Aadd(aUnknown,Trim(art->Matchcode))
   ENDIF
   art->(dbSkip())
ENDDO

re->(dbSetOrder( 6 ))
part->(dbSetOrder( 1 ))

cFormat := "@E 99,999,999"

Aadd(aData,Array(Year(Date())-2009+3))
ATail(aData)[1] := "Artikel"
Atail(aData)[2] := "Aktiv"

FOR nYear := 2009 TO Year(Date())
   ATail(aData)[nYear-2009+3] := nYear
NEXT

FOR nX := 1 TO Len(aProds)
   re->(dbSeek( aProds[nX] ))
   ? aProds[nX]
   FOR nYear := 2009 TO Year(Date())
      nTurn := re->(Leto_Sum("poswt","reposnr!=0 .AND. Year(rechdat)=="+LTrim(Str(nYear))+" .AND. aoqty!=0",Pad(aProds[nX],25),Pad(aProds[nX],25) ))
      IF nTurn != 0
         IF AScan(aData,{|x| x[1] == aProds[nX]}) == 0
            Aadd(aData,Array(Year(Date())-2009+3))
            AFill(ATail(aData),0)
            ATail(aData)[1] := aProds[nX]
            ATail(aData)[2] := IF(aProds[nX] $ aActive,"Ja",IF(aProds[nX] $ aUnknown,"Unbekannt","Nein"))
         ENDIF
         ATail(aData)[nYear-2009+3]  += nTurn
      ENDIF
   NEXT
NEXT
cFile := Wvt_GetSaveFileName( 0,"" , "CSV Datei", { {"Comma Separated File (*.csv)","*.csv"},{"Text File (*.txt)","*.txt"} }, , Trim(Tr_Getini(1))+"\export\" )
IF AT(".",cFile) == 0
   cFile += ".csv"
ENDIF
SaveAsCSV(cFile,aData)
WAPI_ShellExecute(,"open",cFile)
