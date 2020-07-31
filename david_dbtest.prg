LOCAL oDB,cErrorClass,nType,cErrorMsg
oDB := TODBC():New( "David" ,"sa","0gakemur54")
SQLError( oDB:hEnv, oDB:hDbc, oDB:hStmt, @cErrorClass, @nType, @cErrorMsg )
IF ! Empty(cErrorclass) .AND. cErrorClass != "00000" .AND.  cErrorClass != "01000"
	Alert("Fehler bei der Verbindung zur Datenbank. Error " + cErrorClass + " - " + cErrorMsg)
	RETURN .F.
ENDIF


cQuery := "SELECT TOP 500 arc.Path, msg.srFileName, msg.srSubject, msg.srFrom, msg.srTo, msg.srDocType, msg.srStatusTime, msg.srRecNo, msg.SendRec ";
         +"FROM msg ";
         +"LEFT JOIN arc ";
         +"ON arc.ID=msg.pathID WHERE CONTAINS ((msg.*),N'"+'"bulgin"'+"') ORDER BY msg.srStatusTime DESC"



oDB:SetSQL(cQuery) //"SELECT TOP 50000 * FROM dbo.msg LEFT JOIN dbo.arc ON arc.ID=msg.pathID WHERE CONTAINS ((msg.srTo),N'bulgin') AND arc.Path LIKE '\\bull\david\archive\user\10004000%' ORDER BY msg.srStatusTime ASC") //[David Archive Database].dbo.msg")
//   oDB:SetSQL("SELECT TOP 50000 * FROM dbo.msg LEFT JOIN dbo.arc ON arc.ID=msg.pathID WHERE CONTAINS (("+cSearchItms+"),N'"+hSettings:cSearchTerm+"') AND arc.Path LIKE '"+cSearchIN+"%' ORDER BY msg.srStatusTime ASC") //[David Archive Database].dbo.msg")
IF ! oDB:Open()
   SQLError( oDB:hEnv, oDB:hDbc, oDB:hStmt, @cErrorClass, @nType, @cErrorMsg )
   Alert("Error " + cErrorClass + " - " + cErrorMsg)
ELSE
   CLS
   IF oDB:RecCount() > 0
      oDB:LoadData(1)
      ? "Path:",oDB:FieldByName("Path"):Value
      ? "srFileName",oDB:FieldByName("srFileName"):Value
      ? oDB:FieldByName("srSubject"):Value
      ? oDB:FieldByName("srFrom"):Value
      ? oDB:FieldByName("srTo"):Value
      ? oDB:FieldByName("srDocType"):Value
      ? oDB:FieldByName("srStatusTime"):Value
      ? oDB:FieldByName("srRecNo"):Value
      ? oDB:FieldByName("SendRec"):Value
   ENDIF
   Alert("Records: "+Str(oDB:RecCount()))
ENDIF