LOCAL cErrorClass,nType,cErrorMsg

cODBCStr := "DSN=LexwareTrader;"
oDB := TODBC():New( cODBCStr)
SQLError( oDB:hEnv, oDB:hDbc, oDB:hStmt, @cErrorClass, @nType, @cErrorMsg )
If Val(cErrorClass) != 0
   oDB := NIL
   scErrorMessage += "Fehler bei der Verbindung zur Lexware Datenbank. Error " + cErrorClass + " - " + cErrorMsg
   Return .F.
Endif

cSql := "SELECT lKonto,dftSaldoEUR*100 AS dftSaldoEUR,lArt FROM F1.BH_SALDEN"
cSQL += " INNER JOIN F1.BH_KONTENPLAN ON BH_KONTENPLAN.lNr = BH_SALDEN.lKonto"
cSQL += " INNER JOIN F1.BH_GUV_STD ON BH_KONTENPLAN.lGuv=BH_GUV_STD.lNr"
cSQL += " WHERE lJahr=2013 AND lGuv!=0 AND lPeriode=1000" // AND lKonto=3435"

oDB:SetSQL(cSQL)
IF ! oDB:Open()
   SQLError( oDB:hEnv, oDB:hDbc, oDB:hStmt, @cErrorClass, @nType, @cErrorMsg )
   Alert( cErrorClass+" "+cErrorMsg+" "+oDB:cSQL )
   RETURN NIL
ELSEIF oDB:RecCount() > 0
   nTotal := 0
   /*StartPrint()
   SET DEVICE TO PRINTER
   SET PRINTER ON */
   FOR nX := 1 To oDB:RecCount()
      oDB:LoadData(nX)
      ? oDb:FieldByName("lKonto"):Value,Transform( oDB:FieldByName("dftSaldoEUR"):Value/100*IF(oDB:FieldByName("lArt"):Value==1,-1,1), "999 999 999.99" )
      nTotal += oDB:FieldByName("dftSaldoEUR"):Value/100*IF(oDB:FieldByName("lArt"):Value==1,-1,1)
   NEXT
/*   Set DEVICE TO SCREEN
   SET PRINTER OFF
   CopyPrint()*/
   //Inkey(0,128)
   /*oDB:LoadData(1)
   Alert( Transform( oDB:FieldByName("JU"):Value, "999 999 999.99" ) ) */
   oDB:Close()
ENDIF

nTotal2 := 0
? "---"

FOR nX := 1 TO 2
   //get konten
   cSql := "SELECT SUM(dftNetto)*100 AS dftNetto,lArt,BH_KONTENPLAN.lNr AS lKonto FROM F1.BH_JOURNAL"
   cSQL += " INNER JOIN F1.BH_KONTENPLAN ON BH_KONTENPLAN.lNr="+IF(nX==1,"lSoll","lHaben")
   cSQL += " INNER JOIN F1.BH_GUV_STD ON BH_KONTENPLAN.lGuv=BH_GUV_STD.lNr"
   cSQL += " WHERE lJahr=2013 AND lGuv!=0GROUP BY BH_KONTENPLAN.lNr AND lArt" // AND lKonto=3435"
   oDB:SetSQL(cSQL)
   IF ! oDB:Open()
      SQLError( oDB:hEnv, oDB:hDbc, oDB:hStmt, @cErrorClass, @nType, @cErrorMsg )
      Alert( cErrorClass+" "+cErrorMsg+" "+oDB:cSQL )
      RETURN NIL
   ELSE
      FOR nY := 1 To oDB:RecCount()
         oDB:LoadData(nY)
         ? oDb:FieldByName("lKonto"):Value,Transform( oDB:FieldByName("dftNetto"):Value/100*IF(oDB:FieldByName("lArt"):Value==1,-1,1)*IF(nX==2,-1,1), "999 999 999.99" )
         nTotal2 += (oDB:FieldByName("dftNetto"):Value/100)*IF(nX==1,-1,1)*IF(oDB:FieldByName("lArt"):Value==1,-1,1)
      NEXT
      oDB:Close()
   ENDIF
NEXT

   Alert( Transform( nTotal, "999 999 999.99" )+";"+Transform( nTotal2, "999 999 999.99" ) )

oDB:Destroy()
