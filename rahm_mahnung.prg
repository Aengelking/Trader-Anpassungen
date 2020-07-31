PROCEDURE RUN_RAHM_MAHNUNG
   LOCAL nAbnr := 0
   LOCAL getlist := {}
   LOCAL nLevel,cFile

   NetUse("engauf","auf")
   NetUse("engkund","ku")

   Head("Mahnung Rahmenbestellung drucken")
   @ 01,00 SAY "AB-Nr. " GET nAbnr VALID __CheckAufNr(nAbnr) PICTURE "999999"
   READ

   IF LastKey() == 27
      RETURN
   ENDIF

   nLevel := Tr_MsgBox("Stufe ausw„hlen",,{"Einteilungsaufforderung","Auslieferungsankndigung"})
   
   IF LastKey() == 27
      RETURN
   ENDIF

   cFile := "rahm"+StrZero(nLevel,2)+".brf"
   //MosText(File,SPEC,hOptions)
   ku->(dbSeek( auf->Kundma+"K" ))

   MosText(cFile,,{"CHOOSEFILE"=>.F.,"CHANGEADDRESS"=>.F.,"ARCHTYPE"=>"AUFMAHN","ARCHNR"=>auf->Abnr})
RETURN

STATIC FUNCTION __CheckAufNr(nNr)
   LOCAL oArt
   @ 01,15 CLEAR
   @ 03,00 CLEAR TO 07,MaxCol()
   auf->( dbSetOrder( 1 ) )
   auf->(dbSetFilter({|| Right(Str(auf->Dterm,4),2) == "99" },'Right(Str(Dterm,4),2) == "99"'))
   IF ! auf->(dbSeek( Str(nNr,6) ))
      @ 01,15 SAY "Keinen Auftrag mit Rahmenposition gefunden"
      RETURN .F.
   ENDIF
   auf->(dbClearFilter())
   oArt := Artikel():New()
   oArt:Load(auf->Matchcode)
   @ 03,00 SAY "Kunde:"
   @ 03,14 SAY auf->Kundma
   @ 04,00 SAY "Artikel:"
   @ 04,14 SAY auf->Matchcode
   @ 05,00 SAY "Rahmenmenge:"
   @ 05,14 SAY Transform(auf->Contrqty,Me(oArt:Me))
   @ 06,00 SAY "Offene Menge:"
   @ 06,14 SAY Transform(auf->VkQty,Me(oArt:Me))
   @ 07,00 SAY "Rahmenende"
   @ 07,14 SAY NiceWeek(auf->Wterm)
   IF auf->WTerm >= Val(CalWeek(Date()))
      @ 01,15 SAY "Rahmenende noch nicht erreicht"
      RETURN .F.
   ENDIF
   
RETURN .T.

