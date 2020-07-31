hFields := {"BH_OFFENEPOSTEN"=>"szMatchcode","BH_JOURNAL"=>"szText"}
cField := NIL
cODBCStr := "DSN=LexwareTrader;"
soDB := TODBC():New( cODBCStr)

FOR EACH cField IN hFields
	aRec := {}
	cDB := cField:__eNumKey()
	cSQL := "SELECT * FROM F1."+cDB+" WHERE "+cField+" LIKE '%hrungsdifferenz%'"
	soDB:SetSQL(cSQL)
	IF ! soDB:Open()
		cErrorMsg := NIL
		SQLError( soDB:hEnv, soDB:hDbc, soDB:hStmt, , , @cErrorMsg )
		Alert("SQL SELECT failed "+cErrorMsg)
	ELSE
		FOR nX := 1 TO soDb:RecCount()
			soDB:LoadData(nX)
			Aadd(aRec,{"FIELD"=>soDB:FieldByName(cField):Value,"NR"=>soDB:FieldByName("lNr"):Value,"JAHR"=>soDB:FieldByName("lJahr"):Value})
		NEXT
		FOR nX := 1 TO Len(aRec)
//			cNew := HB_AnsiToOem("Währungsdifferenz")+SubStr(aRec[nX,1],At("sdifferenz",aRec[nX,1])+10)
			cNew := StrTran(aRec[nX]:Field,Chr(26),HB_AnsiToOem("ä"))
			cNew := StrTran(cNew,"ä",HB_AnsiToOem("ä"))  //just in case
			IF Trim(cNew) != Trim(aRec[nX]:Field)
				cSQL := "UPDATE F1."+cDB+" SET "+cField+"='"+Trim(cNew)+"' WHERE lNr="+LTrim(Str(aRec[nX]:Nr))+" AND lJahr="+LTrim(Str(aRec[nX]:Jahr))
				//"+cField+" = '"+aRec[nX]:Field+"'"

				? cSQL
				soDB:SetSQL(cSQL)
				IF ! soDB:Open()
					cErrorMsg := NIL
					SQLError( soDB:hEnv, soDB:hDbc, soDB:hStmt, , , @cErrorMsg )
					Alert("SQL UPDATE failed "+cErrorMsg)
				ENDIF
			ENDIF
		NEXT
	ENDIF
NEXT

Inkey(0,128)
