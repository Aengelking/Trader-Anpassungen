#define LX_OP_KENNUNG_DEBITOR  4
#define LX_OP_KENNUNG_KREDITOR 8

FUNC lex_test_op_aus
LOCAL cFile := Path(GetConfigValue("FIRMPATH")+"\lexware.ini")
LOCAL shIniData := HB_ReadIni(cFile)
LOCAL soDB
LOCAL cFields := "BH_OFFENEPOSTEN.lNr AS lNr,BH_OFFENEPOSTEN.dftBetrag*100 AS dftBetrag,dftRest*100 AS dftRest,BH_OFFENEPOSTEN.datBeleg AS datBeleg,lZahlungsZiel,szMatchcode,lHaben,lSoll,lUst,dftUSt*100 AS dftUst,BH_OFFENEPOSTEN.szBelegNr AS szBelegnr"

LOCAL cSQL,nR
LOCAL  nKonto := 13262
LOCAL lDebitor := .T.
LOCAL nJahr := 2024
LOCAL lAbgeschlossen := .T. // .T. = nur abgeschlossene OPs

LOCAL cErrorMsg

CLS
soDB := TODBC():New( shIniData["DATABASE"]["DSN"] )

   cSql := "SELECT "+cFields+",bRueckgesetzt FROM F1.BH_OFFENEPOSTEN"
   cSQL += " INNER JOIN F1.BH_JOURNAL ON BH_JOURNAL.lNr = BH_OFFENEPOSTEN.lBuchungsnr AND BH_JOURNAL.lJahr = BH_OFFENEPOSTEN.lJahr"
   cSQL += " WHERE lKonto='"+LTrim(Str(nKonto))+"' AND "+IF(!lAbgeschlossen,"dftRest != 0 AND bRueckgesetzt=0 AND","")
   cSQL += " BH_OFFENEPOSTEN.lJahr ="+LTrim(Str(nJahr))+" AND lKennung="+LTrim(Str(IF(lDebitor,LX_OP_KENNUNG_DEBITOR,LX_OP_KENNUNG_KREDITOR)))
   soDB:SetSQL(cSql)
   IF ! soDB:Open()
      ThrowSQLError()
   ELSE
      FOR nR := 1 TO soDb:RecCount()
         soDB:LoadData(nR)
            ? soDB:FieldByName("lNr"):Value,soDB:FieldByName("dftBetrag"):Value/100,soDB:FieldByName("dftRest"):Value/100
            ?? "",soDB:FieldByName("datBeleg"):Value,soDB:FieldByName("szMatchcode"):Value
            ?? "",soDB:FieldByName("bRueckgesetzt"):Value
            //?? "",soDB:FieldByName("dftUst"):Value/100
      NEXT
      soDB:Close()
   ENDIF
? "ENDE OP"
Sinkey(0)
cFields += ",szProgId,bRueckgesetzt,BH_OFFENEPOSTEN.lJahr AS lJahr,BH_OP_AUSBUCHUNG.lJahr AS lAusbuchungsJahr"

      cSql := "SELECT "+cFields+",BH_OP_AUSBUCHUNG.dftBetrag*100 AS Ausbuchung"
      cSQL += " FROM F1.BH_OFFENEPOSTEN "
      cSQL += "INNER JOIN F1.BH_OP_AUSBUCHUNG ON (BH_OFFENEPOSTEN.lNr=F1.BH_OP_AUSBUCHUNG.lOpNr) "
      cSQL += " INNER JOIN F1.BH_JOURNAL ON BH_JOURNAL.lNr = BH_OFFENEPOSTEN.lBuchungsnr AND BH_JOURNAL.lJahr = BH_OFFENEPOSTEN.lJahr "
      cSQL += "WHERE lKonto='"+LTrim(Str(nKonto))+"' AND lKennung="+LTrim(Str(IF(lDebitor,LX_OP_KENNUNG_DEBITOR,LX_OP_KENNUNG_KREDITOR)))+" AND szProgId='B'"  
      //cSQL += " AND bRueckgesetzt=0"
      cSQL += " AND BH_OFFENEPOSTEN.lJahr ="+LTrim(Str(nJahr)) //+" AND BH_OP_AUSBUCHUNG.lJahr > "+LTrim(Str(nJahr))      

      soDB:SetSQL(cSQL)
      IF ! soDB:Open()
         SQLError( soDB:hEnv, soDB:hDbc, soDB:hStmt, , , @cErrorMsg )
         ? cErrorMsg
      ELSE
         FOR nR := 1 TO soDb:RecCount()
            soDB:LoadData(nR)
            ? soDB:FieldByName("lNr"):Value,soDB:FieldByName("dftBetrag"):Value/100,soDB:FieldByName("dftRest"):Value/100
            ?? "",soDB:FieldByName("datBeleg"):Value,soDB:FieldByName("szMatchcode"):Value
            ?? "",soDB:FieldByName("dftUst"):Value/100
            ?? "",soDB:FieldByName("szProgId"):Value
            ?? "",soDB:FieldByName("lJahr"):Value,soDB:FieldByName("bRueckgesetzt"):Value
            ?? "",soDB:FieldByName("lAusbuchungsJahr"):Value
            ?? "",soDB:FieldByName("Ausbuchung"):Value/100
         NEXT
         soDB:Close()
      ENDIF

      ? "fertig"

      Sinkey(0)
