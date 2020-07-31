FUNC RUN_TEST_WASTAT
LOCAL cForecast := "",cMissing := ""
NetUse("werkauf","wer")

wer->(dbSeek( Str(8526,6) ))
NetUse("werks","we")
NetUse("artikel","art")
AltD()
IF ! WAStatus(,@cMissing,7,@cForecast)
   Alert("Fehlmenge")
   Alert(cMissing)
ENDIF
Alert("Vorschau: "+cForecast)