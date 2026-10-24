//#define S_PERCENT  		hSplitPrice[art->Artikelnr][cKey]["percent"]
//#define S_MANUFACTURER	hSplitPrice[art->Artikelnr][cKey]["manufacturer"]

PROC RUN_REPORT_TURNOVER_STATS
   LOCAL nRec,dUpDate
   LOCAL nPrice
   LOCAL nFromYear := 2021
   LOCAL nY,nX
   LOCAL aEntry := {"",0},aData := {{"Artikel","Hersteller"}},hKeys := {=>},hSplitPrice := {=>},hAvgPrice := {=>}
   //LOCAL cKey
   LOCAL cDataKey
   
   

   Head(t("Umsätze pro Artikel mit Deckungsbeitrag"))
   NetUse("artikel","art")
   NETUSE("ENGLSRE","RE",.F.,0)
	re->(dbSetOrder(0))
   
   
	nRec := re->(lastrec())
	@ 08,01 SAY "Billings"
   @ 09,15 SAY "VON "+STR(NREC,10)
   
   //dUpdate := StoD(Str(nFromYear,4)+"0101")

   //FOR nY := nFromYear TO Year(Date())
   nY := nFromYear
      FOR nX := 1 TO 4         
         Aadd(aEntry,0)
      Next
      Aadd(aData[1],Str(nY,4)+" Menge")
      Aadd(aData[1],Str(nY,4)+" Umsatz")
      Aadd(aData[1],Str(nY,4)+" DB")
      Aadd(aData[1],Str(nY,4)+" EK/HK")
   //NEXT

   ? ValToPrg(aEntry)
      
   art->(dbSetOrder( 2 ))

   re->(dbSetFilter({|| Year(re->RechDat) == nFromYear },"Year(rechdat) == "+LTrim(Str(nFromYear)) ))   
   re->(dbGoTop())   

	while ! re->(EOF()) .AND. Inkey(,128) != 27
      @ 09,0 SAY STR(re->(Recno()),10)
      @ 24,00 SAY Str(re->Rechnr,6)+" "+DtoC(re->Rechdat)
	  
	   IF art->(dbSeek(Str(re->ArtikelNr,6)))

         __GetAvgPrice(hAvgPrice,hSplitPrice,re->Rechdat)

         IF ! art->Lagerart //AT("@",art->Matchcode) == 1
            hAvgPrice[art->Artikelnr] := 0
         ENDIF
          nPrice := RE->PREIS*currate(re->money,"V")/If(re->Pe==0,1,re->pe)
          nY := Year(re->Rechdat)-nFromYear+1
            //For nX := 1 To Len(hSplitPrice[art->Artikelnr])
               //cKey := HGetKeyAt(hSplitPrice[art->Artikelnr],nX)
               cDataKey := art->Matchcode+Str(art->Manufactur,2) //Str(S_MANUFACTURER,2)
               IF ! HHasKey(hKeys,cDataKey)
                  Aadd(aData,AClone(aEntry))                  
                  hKeys[cDataKey] := Len(aData)
                  aData[hKeys[cDataKey]][1] := art->Matchcode
                  aData[hKeys[cDataKey]][2] := art->Manufactur //S_MANUFACTURER
               ENDIF
               
               aData[hKeys[cDataKey]][3] += re->AoQty
               aData[hKeys[cDataKey]][4] += (nPrice*re->AoQty) //*S_PERCENT)
               
               aData[hKeys[cDataKey]][6] := hAvgPrice[art->Artikelnr]

               IF ! re->Folge .OR. nPrice != 0
                  aData[hKeys[cDataKey]][5] += (nPrice-hAvgPrice[art->Artikelnr])*re->AoQty //*S_PERCENT                  
               ENDIF
			   //Next
	   ENDIF
	   re->(dbSkip(1))
	ENDDO
   re->(dbCloseArea())
   SaveAsCSVInterface(aData)
   



STATIC Function __GetAvgPrice(hAvgPrice) //,hSplitPrice,dDate)
   LOCAL oArt
   LOCAL aEnv := SaveEnv()

	//If ! HHasKey(hAvgPrice,art->Artikelnr) // .OR. ! HHasKey(hSplitPrice,art->Artikelnr)

    	//If art->Artikelnr != 0
    		/*If art->Bezug >= 5
    			hSplitPrice[art->Artikelnr] := {=>}
            StCalc(art->Artikelnr,5,999,.T.,dDate,hSplitPrice[art->Artikelnr])  //use this for Spltting, AvgPrice would be too complicated
               
         Else
            hSplitPrice[art->Artikelnr] := {"X"=>{"percent"=>1,"group"=>art->Gruppe,"manufacturer"=>art->manufactur}} //100% to the Manufacturer of this product
         Endif*/
         oArt := Artikel():New()           
         oArt:Load(art->Artikelnr)           
         hAvgPrice[art->Artikelnr] := oArt:GetAvgBuyPrice(re->RechDat)
		/*Else
			hAvgPrice[art->Artikelnr] := 0
      Endif*/
      RestEnv(aEnv,.F.)
  	//Endif
Return NIL