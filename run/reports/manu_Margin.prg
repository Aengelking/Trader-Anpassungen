PROC Run_Report_Manu_Margin
	LOCAL aData := {}
   LOCAL nYear := Year(Date())
   LOCAL cBeginYear := Str(nYear-5,4)
   LOCAL cFilt
   LOCAL cName
   LOCAL nX,cKey,aRow,aSaveData,nY

	Head("Margen pro Hersteller")

	NetUse("umsatz","um")
   NetUse("manufact","man")

	um->(dbSetorder(2)) //Year+Month+Group
   cFilt := 'group != "SUMM" .AND. Year >= "'+cBeginYear+'"'

	um->(dbSetFilter({|| um->(&(cFilt)) }, cFilt ))
   um->(dbGoTop())


	DO WHILE ! um->(Eof())
		IF man->(dbSeek( Str(um->Manufactur,5) ))
			cName := man->Short
		ELSE
			cName := "? "+LTrim(Str(um->Manufactur,5))
		ENDIF
		nX := AScan(aData,{|x| x["Hersteller"] == cName})
		IF nX == 0
			Aadd(aData,{"Hersteller"=>cName})
         nX := Len(aData)
		ENDIF
      IF ! HHAsKey(aData[nX],um->Year)
         aData[nX][um->Year] := 0
      ENDIF
      aData[nX][um->Year] += um->UmsatzDB

      um->(dbSkip())
   ENDDO

   aSaveData := {{"Hersteller"}}
   FOR nX := 1 TO Len(aData)
      aRow := Array(Len(aSaveData[1]),0)
      aRow[1] := {}
      FOR EACH cKey IN HGetKeys(aData[nX])
         nY := AScan(aSaveData[1],cKey)
         IF nY == 0
            Aadd(aSaveData[1],cKey)
            Aadd(aRow,0)
            nY := Len(aSaveData[1])
         ENDIF
         aRow[nY] := aData[nX][cKey]
      NEXT
      Aadd(aSaveData,aRow)
   NEXT
      

   SaveToOO_Interface(aSaveData,,"XLSX")