PROC RUN_BERICHT_BOOK_YTD_MANU
   LOCAL nThis := Year(Date()),nLast := nThis-1
   LOCAL hBook
   LOCAL cFile
   LOCAL aData := {}
   LOCAL aManu,nManu := 1
   LOCAL getlist := {}
   LOCAL nX

   NetUse("engkund","ku")
   NetUSe("engauf","auf")
   NetUse("artikel","art")

   Head(t("Bookings YTD für einen Hersteller"))

   aManu := GetManufacturerArray()
   @ 01,00 SAY "Hersteller "
   @ 01,12,14,50 GET nManu LISTBOX aManu[2] DROPDOWN
   READ

   IF LastKey() == 27
      RETURN
   ENDIF

   /*cFile := Trim(Tr_Getini(1))+"\export\"+Trim(aManu[2][nManu])+"_book.csv"

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

   auf->(dbSetOrder( 2 ))

   Aadd(aData,{"Kunde",Str(nLast,4)+" YTD",Str(nThis,4)+" YTD"})

   auf->(dbSetFilter({|| (auf->besda>=StoD(LTrim(Str(nLast,4))+"0101") .AND. auf->besda<=StoD(LTrim(Str(nLast,4))+StrZero(Month(Date()),2)+StrZero(Day(Date()),2))) .OR.;
                        (auf->besda>=StoD(LTrim(Str(nThis,4))+"0101") .AND. auf->besda<=StoD(LTrim(Str(nThis,4))+StrZero(Month(Date()),2)+StrZero(Day(Date()),2))) },;
         '(besda>=StoD("'+Str(nLast,4)+'0101") .AND. besda<=StoD("'+Str(nLast,4)+StrZero(Month(Date()),2)+StrZero(Day(Date()),2)+'")) .OR.'+;
         '(besda>=StoD("'+Str(nThis,4)+'0101") .AND. besda<=StoD("'+Str(nThis,4)+StrZero(Month(Date()),2)+StrZero(Day(Date()),2)+'"))'))


   auf->(dbGoTop())
   DO WHILE ! auf->(EOF())
      @ MaxRow(),0 SAY auf->Kundma

      IF art->(dbSeek( auf->Matchcode )) .AND. art->Manufactur == aManu[1][nManu] //.AND. Left(art->Gruppe,2) == "SW"
         @ MaxRow(),0 SAY art->Matchcode

         hBook := {=>}

         nX := AScan(aData,{|x| x[1] == Trim(auf->Kundma)})
         IF nX == 0
            Aadd(aData,{Trim(auf->Kundma),0,0})
            nX := Len(aData)
         ENDIF
         aData[nX][IF(Year(auf->Besda) == nLast,2,3)] += 1/auf->pe*auf->vkpr*auf->vkqty
      ENDIF
      auf->(dbSkip())
   ENDDO

   auf->(dbClearFilter())

   SaveAsCSVInterface(aData,,@cFile)

   WAPI_ShellExecute(,"open",cFile)