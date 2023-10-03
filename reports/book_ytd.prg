PROC RUN_REPORT_BOOK_YTD
   LOCAL nLast,nThis   
   LOCAL aData := {}
   LOCAL aArtData := {}
   LOCAL cFile,nX,nArt
   LOCAL hManu := GetManufacturerHash()
   LOCAL hManuMap := {=>},cManu,nVal,aNew
   LOCAL nYear,nMonths,nMult
   LOCAL cDebugKunde := "" //"FRANKE" //"TECDESIG"
   LOCAL hGroups := {"BACHMANR"=>"BACHMANX","BACHMANG"=>"BACHMANX","STORZ"=>"STORZXXX","STORZCH"=>"STORZXXX","ELPROMAN"=>"ELPROMAN+PATELEC","PATELEC"=>"ELPROMAN+PATELEC"}

   MEMVAR cFilter
   PUBLIC cFilter

   NetUse("engkund","ku")
   NetUSe("engauf","auf")
   NetUse("artikel","art")

   Head("Bookings YTD pro Kunde")

   /*cFile := Trim(Tr_Getini(1))+"\export\book_ytd.csv"

   DO WHILE LastKey() != 27 .AND. (nHandle := FCreate(cFile)) == -1 .AND. TR_MsgBox("Could not open file",,{"Retry","Cancel"}) == 1
   ENDDO
   IF nHandle == -1
      RETURN
   ENDIF*/

   ku->(dbSetOrder( 2 ))
   ku->(dbSeek( "K" ))

   /*auf->(dbSetFilter({|| auf->Pe == 0 },"pe == 0"))
   auf->(dbGoTop())
   DO WHILE ! auf->(EOF())
      ? auf->Abnr
      auf->(dbSkip())
   ENDDO
   auf->(dbClearFilter())*/

   nThis := Year(Date())
   nLast := nThis-1

   Aadd(aData,{"Kunde",Str(nLast,4)+" YTD",Str(nThis,4)+" YTD"})
   Aadd(aArtData,{"Kunde","Artikel",Str(nLast,4)+" YTD",Str(nThis,4)+" YTD"})
   FOR EACH cManu IN hManu
      hManuMap[cManu:__eNumKey()] := Len(Atail(aData))+1
      Aadd(ATail(aData),Str(nLast,4)+" "+cManu)
      Aadd(ATail(aData),Str(nThis,4)+" "+cManu)
   NEXT
      

   /*DO WHILE ku->Group == "K" //.AND. nCount < 10
      //? ku->Kunde
      hBook := {=>}
      FOR nYear := nLast TO nThis
         auf->(dbGoTop())
         aVal := auf->(LETO_SUM("#,1/pe*vkpr*vkqty",'besda>=StoD("'+LTrim(Str(nYear,4))+'0101") .AND. besda<=StoD("'+LTrim(Str(nYear,4))+StrZero(Month(Date()),2)+StrZero(Day(Date()),2)+'")',ku->Kunde,ku->kunde))
         hBook[nYear] :=  aVal[2]
      NEXT
      IF hBook[nLast] != 0 .OR. hBook[nThis] != 0
         ? ku->Kunde,hBook[nLast],hBook[nThis]
         Aadd(aData,{Trim(ku->Kunde),hBook[nLast],hBook[nThis]})         
      ENDIF
      ku->(dbSkip())
   ENDDO*/
   art->(dbSetORder( 1 ))
   auf->(dbSetOrder( 2 ))

   cFilter := ;
      '((Right(Str(dterm,4),2) != "99" .AND. ('+; //kein Rahmen
         '(besda>=StoD("'+Str(nLast,4)+'0101") .AND. besda<=StoD("'+Str(nLast,4)+StrZero(Month(Date()),2)+StrZero(Day(Date()),2)+'")) .OR.'+;
         '(besda>=StoD("'+Str(nThis,4)+'0101"))'+;
      ')) .OR.'+;
      '(Right(Str(dterm,4),2) == "99" .AND. ('+; //Rahmen
         '(wdatum>=StoD("'+Str(nLast,4)+'0101") .AND. Year(AddMonth(sdatum,-3)) <= '+Str(nThis,4)+')'+; //sdatum<=StoD("'+Str(nThis,4)+StrZero(Month(Date()),2)+StrZero(Day(Date()),2)+'"))'+; //Startdatum heute oder vorher und geplantes Enddatum frhestens Anfang letztes Jahr
       '))) .AND. ContrPos == 0'

   

   auf->(dbSetFilter({|| auf->(&(cFilter)) },cFilter ))


   auf->(dbGoTop())
   DO WHILE ! auf->(EOF())
      @ MaxRow(),0 SAY auf->Kundma

      IF art->(dbSeek( auf->Matchcode )) 
         @ MaxRow(),10 SAY art->Matchcode 
         
         cKunde := Trim(auf->Kundma)
         IF cKunde $ hGroups
            cKunde := hGroups[cKunde]
         ENDIF

         nX := AScan(aData,{|x| x[1] == cKunde })
         IF nX == 0
            aNew := Array(Len(aData[1]))
            AFill(aNew,0,2)
            aNew[1] := cKunde
            Aadd(aData,aNew)
            //Aadd(aData,{Trim(auf->Kundma),0,0})            
            nX := Len(aData)
         ENDIF
         nArt := AScan(aArtData,{|x| x[1] == cKunde .AND. x[2] == Trim(art->Matchcode) })
         IF nArt == 0
            Aadd(aArtData,{cKunde,Trim(art->Matchcode),0,0})
            nArt := Len(aArtData)
         ENDIF
         

         IF Right(Str(auf->Dterm,4),2) == "99"  
            nVal := 1/auf->pe*auf->vkpr*auf->ContrQty //auf->vkqty                     
            nMonths := Round((auf->WDatum-auf->SDatum)/30,0)
            IF nMonths <= 0
               ? "Monate <= 0",auf->AbNr,auf->WDatum,auf->SDatum
               nMonths := 1
            ENDIF           

            IF Trim(auf->Kundma) == cDebugKunde
               ? auf->Abnr,auf->SDatum,auf->WDatum
               ? "LZ","Jahr","Mon.","Wert"
            ENDIF
            
            dSDatum := Max(auf->Besda,AddMonth(auf->SDatum,-3))

            FOR nYear := nLast TO nThis
               IF Year(dSDatum) == nYear //started in the year
                  nMult := Min(12,nMonths) //12months or nMonths if sorter
               ELSEIF Year(dSDatum) <= nYear //started before this year
                  nMult := Min(Max(nMonths-(nYear-Year(dSDatum))*12,0),12)  //12 months or the remaining months which ever is shorter
               ELSE 
                  nMult := 0 //did not start last year or before
               ENDIF
               IF Trim(auf->Kundma) == cDebugKunde
                  ? Str(nMonths,2),Str(nYear,4),Str(nMult,2),(nVal/nMonths)*nMult
               ENDIF
               IF nMonths <= 0 //start datum wurde nach ursprnglichen end datum verschoben
                  Alert("Months <= 0 AB "+Str(auf->Abnr))
               ELSE
                  aData[nX][IF(nYear == nLast,2,3)] += (nVal/nMonths)*nMult
                  aArtData[nArt][IF(nYear == nLast,3,4)] += (nVal/nMonths)*nMult
                  aData[nX][hManuMap[art->Manufactur]+IF(nYear == nLast,0,1)] += (nVal/nMonths)*nMult     
               ENDIF
            NEXT
            IF Trim(auf->Kundma) == cDebugKunde
               ? ""
               Sinkey(0)
            ENDIF         
         ELSE
            nVal := 1/auf->pe*auf->vkpr*auf->vkqty
            nYear := Year(auf->Besda)
            //nYear := Year(auf->BDatum)

            IF Trim(auf->Kundma) == cDebugKunde
               ? auf->Abnr,auf->Itmnr
               ? Space(2),"Jahr",Space(2),"Wert"
               ? Space(2),Space(2),Str(nYear,4),nVal
            ENDIF

            aData[nX][IF(nYear == nLast,2,3)] += nVal
            aArtData[nArt][IF(nYear == nLast,3,4)] += nVal
            aData[nX][hManuMap[art->Manufactur]+IF(nYear == nLast,0,1)] += nVal         
            
         ENDIF
         IF Trim(auf->Kundma) == cDebugKunde
            ?
         ENDIF
      ENDIF
      auf->(dbSkip())
   ENDDO

   auf->(dbClearFilter())

   //FClose(nHandle)
   DO WHILE .T.
      cFile := Wvt_GetSaveFileName( 0,cFile , "ODT Spreadsheet", { {"Spreadsheet (*.odt)","*.odt"},{"Alle Dateien (*.*)","*.*"} } )
      IF Empty(cFile) 
         IF Tr_msgbox("abbrechen?",,{"Nein","Ja"}) == 2
            RETURN
         ELSE
            LOOP
         ENDIF
      ENDIF
      IF AT(".",cFile) == 0
         cFile := cFile+".ods"
      ENDIF
      EXIT
   ENDDO
   SaveToOO(cFile,{"Summen"=>aData,"Artikel"=>aArtData},,,.T.,{|nTot,nCur| 
      @ 24,00 SAY Ltrim(Str(nCur))+"/"+Ltrim(Str(nTot)) 
   })

   //SaveAsCSVInterface(aData,,@cFile)

   //WAPI_ShellExecute(,"open",cFile)

   #include 'x:\run\savetooo.prg'