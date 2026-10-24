PROCEDURE RUN_CreateDB()
   LOCAL cFile,nDBF,aDBF,cDir
   LOCAL hStructs

   cDir := HB_CmdArgArgV()
   cDir := SubStr(cDir,1,RAt(HB_OSPATHSEPARATOR(),cDir))+".."+HB_OSPATHSEPARATOR()+"config"+HB_OSPATHSEPARATOR()
   cFile := cDir+"dbstruct.json"
   IF ! File(cFile)
      Tr_MsgBox("Config file not found. "+cFile)
      RETURN
   ENDIF
   hStructs := HB_JsonDecode(MemoRead(cFile))
   nDBF := AChoice(0,0,MaxRow(),MaxCol(), HGetKeys(hStructs))
   IF nDBF == 0 .OR. LastKey() == 27
      RETURN
   ENDIF
   aDBF := HGetValueAt(hStructs,nDBF)
   IF File(Path(HgetKeyAt(hStructs,nDBF)))
      TR_MsgBox("Datei bereits vorhanden")
      RETURN
   ENDIF
RETURN
