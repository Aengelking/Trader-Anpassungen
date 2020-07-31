LOCAL cODBCStr := "DSN=LexwareTrader;"
LOCAL oDB
LOCAL cErrorClass, cErrorMsg, nType

Head("Bereinigungsprogramm für Lexware")


IF Tr_MsgBox(t("ACHTUNG! Dieses Programm führt Löschungen in der Datenbank durch!"),,{"Abbrechen","Fortfahren"}) != 2
   RETURN
ENDIF

SetPos(1,0)

oDB := TODBC():New( cODBCStr )
SQLError( oDB:hEnv, oDB:hDbc, oDB:hStmt, @cErrorClass, @nType, @cErrorMsg )
IF Val(cErrorClass) != 0
	Alert("Fehler bei der Verbindung zur Lexware Datenbank. Error " + cErrorClass + " - " + cErrorMsg)
	RETURN .F.
ENDIF

oDB:SetSQL("SELECT Count(*) AS count FROM F1.BH_OFFENEPOSTEN WHERE szBelegNr LIKE 'EB'")
IF ! oDB:Open()
   ThrowSQLError()
ELSE
   oDB:LoadData(1)
   ? t("Es werden "+LTrim(Str(oDB:FieldByName("count"):Value))+" EB Einträge aus den OPs gelöscht")
ENDIF

INKEY(0,128)
